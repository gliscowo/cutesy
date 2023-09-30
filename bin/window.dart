import 'dart:async';
import 'dart:ffi';

import 'package:dart_glfw/dart_glfw.dart';
import 'package:ffi/ffi.dart';
import 'package:vector_math/vector_math.dart';

import 'cutesy.dart';

typedef _GLFWwindowresizefun = Void Function(Pointer<GLFWwindow>, Int, Int);
typedef _GLFWwindowposfun = Void Function(Pointer<GLFWwindow>, Int, Int);

typedef _GLFWkeyfun = Void Function(Pointer<GLFWwindow>, Int, Int, Int, Int);
typedef _GLFWcharfun = Void Function(Pointer<GLFWwindow>, UnsignedInt);
typedef _GLFWcursorposfun = Void Function(Pointer<GLFWwindow>, Double, Double);
typedef _GLFWmousebuttonfun = Void Function(Pointer<GLFWwindow>, Int, Int, Int);

class Window {
  static final Map<int, Window> _knownWindows = {};

  late final Pointer<GLFWwindow> _handle;
  final StreamController<Window> _resizeListeners = StreamController.broadcast(sync: true);
  final StreamController<int> _charInputListeners = StreamController.broadcast(sync: true);
  final StreamController<KeyInputEvent> _keyInputListeners = StreamController.broadcast(sync: true);
  final StreamController<MouseInputEvent> _mouseInputListeners = StreamController.broadcast(sync: true);
  final StreamController<MouseMoveEvent> _mouseMoveListeners = StreamController.broadcast(sync: true);
  final Vector2 _cursorPos = Vector2.zero();

  late int _x;
  late int _y;
  int _width;
  int _height;

  bool _fullscreen = false;
  int _restoreX = 0;
  int _restoreY = 0;
  int _restoreWidth = 0;
  int _restoreHeight = 0;

  Window(int width, int height, String title, {bool debug = false, int samples = 0})
      : _width = width,
        _height = height {
    glfw.windowHint(glfwContextVersionMajor, 4);
    glfw.windowHint(glfwContextVersionMinor, 5);
    glfw.windowHint(glfwOpenglProfile, glfwOpenglCoreProfile);

    glfw.windowHint(glfwFloating, glfwTrue);

    if (debug) glfw.windowHint(glfwOpenglDebugContext, glfwTrue);
    if (samples != 0) glfw.windowHint(glfwSamples, samples);

    _handle = title.withAsNative((utf8) => glfw.createWindow(width, height, utf8.cast(), nullptr, nullptr));

    if (_handle.address == 0) {
      glfw.terminate();
      throw Exception("Failed to create window");
    }

    final windowX = malloc<Int>();
    final windowY = malloc<Int>();

    glfw.getWindowPos(_handle, windowX, windowY);
    _x = windowX.value;
    _y = windowY.value;

    malloc.free(windowX);
    malloc.free(windowY);

    _knownWindows[_handle.address] = this;
    glfw.setWindowSizeCallback(_handle, Pointer.fromFunction<_GLFWwindowresizefun>(_onResize));
    glfw.setWindowPosCallback(_handle, Pointer.fromFunction<_GLFWwindowposfun>(_onMove));
    glfw.setCursorPosCallback(_handle, Pointer.fromFunction<_GLFWcursorposfun>(_onMousePos));
    glfw.setMouseButtonCallback(_handle, Pointer.fromFunction<_GLFWmousebuttonfun>(_onMouseButton));
    glfw.setCharCallback(_handle, Pointer.fromFunction<_GLFWcharfun>(_onChar));
    glfw.setKeyCallback(_handle, Pointer.fromFunction<_GLFWkeyfun>(_onKey));
  }

  static void _onMove(Pointer<GLFWwindow> handle, int x, int y) {
    if (!_knownWindows.containsKey(handle.address)) return;
    final window = _knownWindows[handle.address]!;

    window._x = x;
    window._y = y;
  }

  static void _onResize(Pointer<GLFWwindow> handle, int width, int height) {
    if (!_knownWindows.containsKey(handle.address)) return;
    final window = _knownWindows[handle.address]!;

    window._width = width;
    window._height = height;

    window._resizeListeners.add(window);
  }

  static void _onMousePos(Pointer<GLFWwindow> handle, double mouseX, double mouseY) {
    if (!_knownWindows.containsKey(handle.address)) return;
    final window = _knownWindows[handle.address]!;

    final deltaX = mouseX - window._cursorPos.x, deltaY = mouseY - window._cursorPos.y;
    if (deltaX != 0 || deltaY != 0) {
      window._mouseMoveListeners.add(MouseMoveEvent(deltaX, deltaY));
    }

    window._cursorPos.x = mouseX;
    window._cursorPos.y = mouseY;
  }

  static void _onMouseButton(Pointer<GLFWwindow> handle, int button, int action, int mods) {
    if (!_knownWindows.containsKey(handle.address)) return;
    final window = _knownWindows[handle.address]!;

    window._mouseInputListeners.add(MouseInputEvent(button, action, mods));
  }

  static void _onChar(Pointer<GLFWwindow> handle, int codepoint) {
    if (!_knownWindows.containsKey(handle.address)) return;
    final window = _knownWindows[handle.address]!;

    window._charInputListeners.add(codepoint);
  }

  static void _onKey(Pointer<GLFWwindow> handle, int key, int scancode, int action, int mods) {
    if (!_knownWindows.containsKey(handle.address)) return;
    final window = _knownWindows[handle.address]!;

    window._keyInputListeners.add(KeyInputEvent(key, scancode, action, mods));
  }

  void toggleFullscreen() {
    if (_fullscreen) {
      glfw.setWindowMonitor(_handle, nullptr, _restoreX, _restoreY, _restoreWidth, _restoreHeight, glfwDontCare);
      _fullscreen = false;
    } else {
      _restoreX = _x;
      _restoreY = _y;
      _restoreWidth = _width;
      _restoreHeight = _height;

      final width = malloc<Int>();
      final height = malloc<Int>();
      final monitors = malloc<Int>();

      final monitor = glfw.getMonitors(monitors)[0];
      glfw.getMonitorWorkarea(monitor, nullptr, nullptr, width, height);

      glfw.setWindowMonitor(_handle, monitor, 0, 0, width.value, height.value, glfwDontCare);

      malloc.free(width);
      malloc.free(height);
      malloc.free(monitors);

      _fullscreen = true;
    }
  }

  void nextFrame() {
    glfw.swapBuffers(_handle);
    glfw.pollEvents();
  }

  double get cursorX => _cursorPos.x;
  double get cursorY => _cursorPos.y;
  Vector2 get cursorPos => _cursorPos.xy;

  Stream<Window> get onResize => _resizeListeners.stream;
  Stream<int> get onChar => _charInputListeners.stream;
  Stream<KeyInputEvent> get onKey => _keyInputListeners.stream;
  Stream<MouseInputEvent> get onMouseButton => _mouseInputListeners.stream;
  Stream<MouseMoveEvent> get onMouseMove => _mouseMoveListeners.stream;

  int get x => _x;
  int get y => _y;
  int get width => _width;
  int get height => _height;
  Pointer<GLFWwindow> get handle => _handle;
}

class KeyInputEvent {
  final int key, scancode, action, mods;
  KeyInputEvent(this.key, this.scancode, this.action, this.mods);
}

class MouseInputEvent {
  final int button, action, mods;
  MouseInputEvent(this.button, this.action, this.mods);
}

class MouseMoveEvent {
  final double deltaX, deltaY;
  MouseMoveEvent(this.deltaX, this.deltaY);
}
