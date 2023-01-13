import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:opengl/opengl.dart';

typedef _GlErrorCallback = Void Function(Int32, Int32, Int32, Int32, Int32, Pointer<Utf8>, Pointer<Void>);

const Map<int, String> _glMessageTypes = {
  GL_DEBUG_TYPE_MARKER: "MARKER",
  GL_DEBUG_TYPE_DEPRECATED_BEHAVIOR: "DEPRECATED_BEHAVIOR",
  GL_DEBUG_TYPE_ERROR: "ERROR",
  GL_DEBUG_TYPE_OTHER: "OTHER",
  GL_DEBUG_TYPE_PERFORMANCE: "PERFORMANCE",
  GL_DEBUG_TYPE_PORTABILITY: "PORTABILITY",
  GL_DEBUG_TYPE_PUSH_GROUP: "PUSH_GROUP",
  GL_DEBUG_TYPE_POP_GROUP: "POP_GROUP",
};

const Map<int, String> _glSeverities = {
  GL_DEBUG_SEVERITY_NOTIFICATION: "NOTIFICATION",
  GL_DEBUG_SEVERITY_LOW: "LOW",
  GL_DEBUG_SEVERITY_MEDIUM: "MEDIUM",
  GL_DEBUG_SEVERITY_HIGH: "HIGH",
};

void attachGlErrorCallback() {
  glEnable(GL_DEBUG_OUTPUT);
  glEnable(GL_DEBUG_OUTPUT_SYNCHRONOUS);
  glDebugMessageCallback(Pointer.fromFunction<_GlErrorCallback>(_onGlError), nullptr);
}

void _onGlError(
    int source, int type, int id, int severity, int length, Pointer<Utf8> message, Pointer<Void> userParam) {
  print(
      "OpenGL Debug Message, type ${_glMessageTypes[type]} severity ${_glSeverities[severity]}: ${message.toDartString()}");
}
