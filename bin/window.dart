import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:glfw/glfw.dart';

typedef GLFWwindowresizefun = Void Function(Pointer<GLFWwindow>, Uint32, Uint32);
typedef GLFWwindowposfun = Void Function(Pointer<GLFWwindow>, Uint32, Uint32);

class Window {
  static final Map<int, Window> _knownWindows = {};

  late final Pointer<GLFWwindow> _handle;
  final StreamController<Window> _resizeListeners = StreamController.broadcast(sync: true);

  late int _x;
  late int _y;
  int _width;
  int _height;

  bool _fullscreen = false;
  int _restoreX = 0;
  int _restoreY = 0;
  int _restoreWidth = 0;
  int _restoreHeight = 0;

  Window(int width, int height, String title, {bool debug = false})
      : _width = width,
        _height = height {
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 6);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

    glfwWindowHint(GLFW_SAMPLES, 8);
    glfwWindowHint(GLFW_FLOATING, GLFW_TRUE);

    if (debug) glfwWindowHint(GLFW_OPENGL_DEBUG_CONTEXT, GLFW_TRUE);

    _handle = glfwCreateWindow(width, height, title.toNativeUtf8(), nullptr, nullptr);

    if (_handle.address == 0) {
      glfwTerminate();
      throw Exception("Failed to create window");
    }

    final windowX = malloc<Int32>();
    final windowY = malloc<Int32>();

    glfwGetWindowPos(_handle, windowX, windowY);
    _x = windowX.value;
    _y = windowY.value;

    malloc.free(windowX);
    malloc.free(windowY);

    _knownWindows[_handle.address] = this;
    glfwSetWindowSizeCallback(_handle, Pointer.fromFunction<GLFWwindowresizefun>(_onResize));
    glfwSetWindowPosCallback(_handle, Pointer.fromFunction<GLFWwindowposfun>(_onMove));
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

  void toggleFullscreen() {
    if (_fullscreen) {
      glfwSetWindowMonitor(_handle, nullptr, _restoreX, _restoreY, _restoreWidth, _restoreHeight, GLFW_DONT_CARE);
      _fullscreen = false;
    } else {
      _restoreX = _x;
      _restoreY = _y;
      _restoreWidth = _width;
      _restoreHeight = _height;

      final width = malloc<Int32>();
      final height = malloc<Int32>();
      final monitors = malloc<Int32>();

      final monitor = glfwGetMonitors(monitors).cast<Pointer<GLFWmonitor>>()[0];
      glfwGetMonitorWorkarea(monitor, nullptr, nullptr, width, height);

      glfwSetWindowMonitor(_handle, monitor, 0, 0, width.value, height.value, GLFW_DONT_CARE);

      malloc.free(width);
      malloc.free(height);
      malloc.free(monitors);

      _fullscreen = true;
    }
  }

  void nextFrame() {
    glfwSwapBuffers(_handle);
    glfwPollEvents();
  }

  int get x => _x;
  int get y => _y;
  int get width => _width;
  int get height => _height;
  Pointer<GLFWwindow> get handle => _handle;
  Stream<Window> get onResize => _resizeListeners.stream;
}
