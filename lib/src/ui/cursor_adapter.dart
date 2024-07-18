import 'dart:ffi';

import 'package:dart_glfw/dart_glfw.dart';
import 'package:diamond_gl/diamond_gl.dart';

import 'widget.dart';

class CursorAdapter {
  static const List<CursorStyle> activeStyles = [
    CursorStyle.pointer,
    CursorStyle.text,
    CursorStyle.hand,
    CursorStyle.move
  ];

  final Map<CursorStyle, Pointer<GLFWcursor>> _cursors = {};
  final Window _window;

  CursorStyle _lastCursorStyle = CursorStyle.pointer;
  bool _disposed = false;

  CursorAdapter.ofWindow(this._window) {
    for (final style in activeStyles) {
      _cursors[style] = glfw.createStandardCursor(style.glfw);
    }
  }

  void applyStyle(CursorStyle style) {
    if (_disposed || _lastCursorStyle == style) return;

    if (style == CursorStyle.none) {
      glfw.setCursor(_window.handle, nullptr);
    } else {
      glfw.setCursor(_window.handle, _cursors[style]!);
    }

    _lastCursorStyle = style;
  }

  void dispose() {
    if (_disposed) return;

    _cursors.values.forEach(glfw.destroyCursor);
    _disposed = true;
  }
}
