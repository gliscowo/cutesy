import 'dart:async';

import 'package:dart_glfw/dart_glfw.dart';
import 'package:dart_opengl/dart_opengl.dart';
import 'package:diamond_gl/diamond_gl.dart';

import '../context.dart';
import '../text/text_renderer.dart';
import 'component.dart';
import 'cursor_adapter.dart';
import 'sizing.dart';

class UIController<R extends ParentComponent> {
  final Window _window;
  final TextRenderer _textRenderer;
  late final CursorAdapter _cursorAdapter;
  late final List<StreamSubscription<Object>> _subscriptions;

  late final R _root;

  UIController.ofWindow(
      this._window, this._textRenderer, R Function(Sizing horizontal, Sizing vertical) rootComponentFactory) {
    _cursorAdapter = CursorAdapter.ofWindow(_window);
    _root = rootComponentFactory(Sizing.fill(), Sizing.fill());

    _subscriptions = [
      _window.onResize.listen((event) => inflateAndMount()),
      _window.onMouseButton.listen((event) {
        switch (event.action) {
          case glfwPress:
            _root.onMouseDown(_window.cursorX, _window.cursorY, event.button);
          case glfwRelease:
            _root.onMouseUp(_window.cursorX, _window.cursorY, event.button);
        }
      }),
      _window.onMouseMove.listen((event) {
        for (final button in const [glfwMouseButtonLeft, glfwMouseButtonRight, glfwMouseButtonMiddle]) {
          if (glfw.getMouseButton(_window.handle, button) == glfwRelease) continue;

          _root.onMouseDrag(_window.cursorX, _window.cursorY, event.deltaX, event.deltaY, button);
          return;
        }
      }),
      _window.onMouseScroll.listen((event) {
        _root.onMouseScroll(_window.cursorX, _window.cursorY, event);
      }),
      _window.onKey.where((event) => event.action == glfwPress || event.action == glfwRepeat).listen((event) {
        _root.onKeyPress(event.key, event.scancode, event.mods);
      }),
      _window.onChar.listen((codePoint) {
        _root.onCharTyped(String.fromCharCode(codePoint), 0);
      })
    ];
  }

  void inflateAndMount() {
    _root.inflate(LayoutContext.ofWindow(_window, _textRenderer));
    _root.mount(null, 0, 0);
  }

  void render(DrawContext context, double delta) {
    _root.update(delta, _window.cursorX.toInt(), _window.cursorY.toInt());

    gl.enable(glScissorTest);
    gl.scissor(0, 0, _window.width, _window.height);

    _root.draw(context, _window.cursorX.toInt(), _window.cursorY.toInt(), delta);

    gl.disable(glScissorTest);

    final hovered = _root.childAt(_window.cursorX.toInt(), _window.cursorY.toInt());
    if (hovered != null) {
      _cursorAdapter.applyStyle(hovered.cursorStyle);
    }
  }

  void dispose() {
    _root.dismount(DismountReason.removed);
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
  }

  R get root => _root;
}
