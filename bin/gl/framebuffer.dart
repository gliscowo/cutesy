import 'dart:ffi';

import 'package:dart_opengl/dart_opengl.dart';
import 'package:ffi/ffi.dart';

import '../color.dart';
import '../cutesy.dart';
import '../window.dart';

class GlFramebuffer {
  late int _fbo, _colorAttachmentId;

  int _width, _height;
  late final bool _stencil;

  GlFramebuffer(this._width, this._height, {bool stencil = false}) {
    _stencil = stencil;
    _initGlState();
  }

  factory GlFramebuffer.trackingWindow(Window window, {bool stencil = false}) =>
      GlFramebuffer(window.width, window.height, stencil: stencil)..trackWindow(window);

  void _initGlState() {
    final idPointer = malloc<UnsignedInt>();
    gl.createFramebuffers(1, idPointer);
    _fbo = idPointer.value;
    malloc.free(idPointer);

    _colorAttachmentId = _genGlObject((_, ptr) => gl.createTextures(glTexture2d, 1, ptr));

    gl.textureStorage2D(_fbo, 1, glRgba8, _width, _height);
    gl.textureParameteri(_fbo, glTextureMinFilter, glLinear);
    gl.textureParameteri(_fbo, glTextureMagFilter, glLinear);
    gl.textureParameteri(_fbo, glTextureWrapS, glClampToEdge);
    gl.textureParameteri(_fbo, glTextureWrapT, glClampToEdge);

    gl.namedFramebufferTexture(_fbo, glColorAttachment0, _colorAttachmentId, 0);

    if (_stencil) {
      final depthStencilRenderbuffer = _genGlObject(gl.createRenderbuffers);
      gl.namedRenderbufferStorage(depthStencilRenderbuffer, glDepth24Stencil8, _width, _height);
      gl.namedFramebufferRenderbuffer(_fbo, glDepthStencilAttachment, glRenderbuffer, depthStencilRenderbuffer);
    } else {
      final depthRenderbuffer = _genGlObject(gl.createRenderbuffers);
      gl.namedRenderbufferStorage(depthRenderbuffer, glDepthComponent, _width, _height);
      gl.namedFramebufferRenderbuffer(_fbo, glDepthAttachment, glRenderbuffer, depthRenderbuffer);
    }
  }

  void trackWindow(Window window) {
    window.onResize.listen((window) {
      _width = window.width;
      _height = window.height;

      delete();
      _initGlState();
    });
  }

  void clear({Color? color, double? depth, double? stencil}) {
    if (color != null) {
      final colorPtr = malloc<Float>(4);
      final colors = colorPtr.asTypedList(4);
      colors[0] = color.r;
      colors[1] = color.g;
      colors[2] = color.b;
      colors[3] = color.a;
      gl.clearNamedFramebufferfv(_fbo, glColor, 0, colorPtr);
      malloc.free(colorPtr);
    }

    if (depth != null) {
      final depthPtr = malloc<Float>();
      depthPtr.value = depth;
      gl.clearNamedFramebufferfv(_fbo, glDepth, 0, depthPtr);
      malloc.free(depthPtr);
    }

    if (stencil != null) {
      final stencilPtr = malloc<Float>();
      stencilPtr.value = stencil;
      gl.clearNamedFramebufferfv(_fbo, glStencil, 0, stencilPtr);
      malloc.free(stencilPtr);
    }
  }

  void bind({bool draw = true, bool read = true}) => gl.bindFramebuffer(_target(draw, read), _fbo);
  void unbind({bool draw = true, bool read = true}) => gl.bindFramebuffer(_target(draw, read), 0);

  void delete() {
    _deleteGlObject(gl.deleteFramebuffers, _fbo);
    _deleteGlObject(gl.deleteTextures, _colorAttachmentId);
  }

  int get width => _width;
  int get height => _height;
  int get colorAttachment => _colorAttachmentId;
  int get fbo => _fbo;

  int _target(bool draw, bool read) => switch ((draw, read)) {
        (true, true) => glFramebuffer,
        (true, false) => glDrawFramebuffer,
        (false, true) => glReadFramebuffer,
        _ => throw ArgumentError("Either draw or read must be set")
      };

  int _genGlObject(void Function(int, Pointer<UnsignedInt>) factory) {
    final object = malloc<UnsignedInt>();
    factory(1, object);
    final objectId = object.value;
    malloc.free(object);

    return objectId;
  }

  int _deleteGlObject(void Function(int, Pointer<UnsignedInt>) destructor, int resource) {
    final object = malloc<UnsignedInt>();
    object.value = resource;

    destructor(1, object);
    final objectId = object.value;
    malloc.free(object);

    return objectId;
  }
}
