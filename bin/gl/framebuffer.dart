import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:opengl/opengl.dart';

import '../color.dart';
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
    final idPointer = malloc<Uint32>();
    glGenFramebuffers(1, idPointer);
    _id = idPointer.value;
    malloc.free(idPointer);

    bind();

    _colorAttachmentId = _genGlObject(glGenTextures);
    glBindTexture(GL_TEXTURE_2D, _colorAttachmentId);

    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, _width, _height, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _colorAttachmentId, 0);

    if (_stencil) {
      final depthStencilRenderbuffer = _genGlObject(glGenRenderbuffers);
      glBindRenderbuffer(GL_RENDERBUFFER, depthStencilRenderbuffer);
      glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, _width, _height);
      glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_RENDERBUFFER, depthStencilRenderbuffer);
    } else {
      final depthRenderbuffer = _genGlObject(glGenRenderbuffers);
      glBindRenderbuffer(GL_RENDERBUFFER, depthRenderbuffer);
      glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT, _width, _height);
      glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthRenderbuffer);
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
    glClearColor(color.r, color.g, color.b, color.a);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
  }

  void bind({bool draw = true, bool read = true}) {
    glBindFramebuffer(_target(draw, read), _id);
  }

  void unbind({bool draw = true, bool read = true}) {
    glBindFramebuffer(_target(draw, read), 0);
  }

  void delete() {
    _deleteGlObject(glDeleteFramebuffers, _id);
    _deleteGlObject(glDeleteTextures, _colorAttachmentId);
  }

  int get width => _width;
  int get height => _height;
  int get colorAttachment => _colorAttachmentId;

  int _target(bool draw, bool read) {
    int target;
    if (draw && read) {
      target = GL_FRAMEBUFFER;
    } else if (draw && !read) {
      target = GL_DRAW_FRAMEBUFFER;
    } else if (!draw && read) {
      target = GL_READ_FRAMEBUFFER;
    } else {
      throw ArgumentError("Either draw or read must be set");
    }

    return target;
  }

  int _genGlObject(void Function(int, Pointer<Uint32>) factory) {
    final object = malloc<Uint32>();
    factory(1, object);
    final objectId = object.value;
    malloc.free(object);

    return objectId;
  }

  int _deleteGlObject(void Function(int, Pointer<Uint32>) destructor, int resource) {
    final object = malloc<Uint32>();
    object.value = resource;

    destructor(1, object);
    final objectId = object.value;
    malloc.free(object);

    return objectId;
  }
}
