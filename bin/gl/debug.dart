import 'dart:ffi';

import 'package:dart_opengl/dart_opengl.dart';
import 'package:ffi/ffi.dart';
import 'package:logging/logging.dart';

import '../cutesy.dart';

typedef _GlErrorCallback = Void Function(
    UnsignedInt, UnsignedInt, UnsignedInt, UnsignedInt, Int, Pointer<Char>, Pointer<Void>);

const Map<int, String> _glMessageTypes = {
  glDebugTypeMarker: "MARKER",
  glDebugTypeDeprecatedBehavior: "DEPRECATED_BEHAVIOR",
  glDebugTypeError: "ERROR",
  glDebugTypeOther: "OTHER",
  glDebugTypePerformance: "PERFORMANCE",
  glDebugTypePortability: "PORTABILITY",
  glDebugTypePushGroup: "PUSH_GROUP",
  glDebugTypePopGroup: "POP_GROUP",
};

const Map<int, String> _glSeverities = {
  glDebugSeverityNotification: "NOTIFICATION",
  glDebugSeverityLow: "LOW",
  glDebugSeverityMedium: "MEDIUM",
  glDebugSeverityHigh: "HIGH",
};

int minGlDebugSeverity = glDebugSeverityNotification;
bool printGlDebugStacktrace = false;

void attachGlErrorCallback() {
  gl.enable(glDebugOutput);
  gl.enable(glDebugOutputSynchronous);
  gl.debugMessageCallback(Pointer.fromFunction<_GlErrorCallback>(_onGlError), nullptr);
}

final Logger _logger = Logger("cutesy.opengl");

void _onGlError(
    int source, int type, int id, int severity, int length, Pointer<Char> message, Pointer<Void> userParam) {
  if (severity < minGlDebugSeverity) return;

  _logger.warning(
      "OpenGL Debug Message, type ${_glMessageTypes[type]} severity ${_glSeverities[severity]}: ${message.cast<Utf8>().toDartString()}");
  if (printGlDebugStacktrace) _logger.warning(StackTrace.current);
}
