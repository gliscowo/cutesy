import 'dart:ffi';

import 'package:dart_opengl/dart_opengl.dart';
import 'package:ffi/ffi.dart';

import '../color.dart';
import '../cutesy.dart';
import '../window.dart';

class GlFramebuffer {
  late int _id, _colorAttachmentId;

  int _width, _height;
  late final bool _stencil;

  GlFramebuffer(this._width, this._height, {bool stencil = false}) {
    _stencil = stencil;
    _initGlState();
  }

  void _initGlState() {
    final idPointer = malloc<UnsignedInt>();
    gl.genFramebuffers(1, idPointer);
    _id = idPointer.value;
    malloc.free(idPointer);

    bind();

    _colorAttachmentId = _genGlObject(gl.genTextures);
    gl.bindTexture(glTexture2d, _colorAttachmentId);

    gl.texImage2D(glTexture2d, 0, glRgba, _width, _height, 0, glRgba, glUnsignedByte, nullptr);
    gl.texParameteri(glTexture2d, glTextureMinFilter, glLinear);
    gl.texParameteri(glTexture2d, glTextureMagFilter, glLinear);
    gl.texParameteri(glTexture2d, glTextureWrapS, glClampToEdge);
    gl.texParameteri(glTexture2d, glTextureWrapT, glClampToEdge);

    gl.framebufferTexture2D(glFramebuffer, glColorAttachment0, glTexture2d, _colorAttachmentId, 0);

    if (_stencil) {
      final depthStencilRenderbuffer = _genGlObject(gl.genRenderbuffers);
      gl.bindRenderbuffer(glRenderbuffer, depthStencilRenderbuffer);
      gl.renderbufferStorage(glRenderbuffer, glDepth24Stencil8, _width, _height);
      gl.framebufferRenderbuffer(glFramebuffer, glDepthStencilAttachment, glRenderbuffer, depthStencilRenderbuffer);
    } else {
      final depthRenderbuffer = _genGlObject(gl.genRenderbuffers);
      gl.bindRenderbuffer(glRenderbuffer, depthRenderbuffer);
      gl.renderbufferStorage(glRenderbuffer, glDepthComponent, _width, _height);
      gl.framebufferRenderbuffer(glFramebuffer, glDepthAttachment, glRenderbuffer, depthRenderbuffer);
    }

    unbind();
  }

  void trackWindow(Window window) {
    window.onResize.listen((window) {
      _width = window.width;
      _height = window.height;

      delete();
      _initGlState();
    });
  }

  void clear(Color color) {
    gl.clearColor(color.r, color.g, color.b, color.a);
    gl.clear(glColorBufferBit | glDepthBufferBit);
  }

  void bind({bool draw = true, bool read = true}) {
    gl.bindFramebuffer(_target(draw, read), _id);
  }

  void unbind({bool draw = true, bool read = true}) {
    gl.bindFramebuffer(_target(draw, read), 0);
  }

  void delete() {
    _deleteGlObject(gl.deleteFramebuffers, _id);
    _deleteGlObject(gl.deleteTextures, _colorAttachmentId);
  }

  int get width => _width;
  int get height => _height;
  int get colorAttachment => _colorAttachmentId;

  int _target(bool draw, bool read) {
    int target;
    if (draw && read) {
      target = glFramebuffer;
    } else if (draw && !read) {
      target = glDrawFramebuffer;
    } else if (!draw && read) {
      target = glReadFramebuffer;
    } else {
      throw ArgumentError("Either draw or read must be set");
    }

    return target;
  }

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
