import 'dart:math';

import 'package:dart_glfw/dart_glfw.dart';
import 'package:ffi/ffi.dart';
import 'package:vector_math/vector_math.dart';

import '../../color.dart';
import '../../context.dart';
import '../../cutesy.dart';
import '../../text/text.dart';
import '../component.dart';

class TextField extends Component {
  String _content = "";
  int _cursorPosition = 0;

  @override
  void draw(DrawContext context, int mouseX, int mouseY, double delta) {
    final focused = focusHandler?.focused == this;

    context.primitives.rect(
      x.toDouble() + 2,
      y.toDouble() + 2,
      width.toDouble() - 4,
      height.toDouble() - 4,
      Color.black,
      context.projection,
    );

    context.primitives.roundedRect(
      x.toDouble(),
      y.toDouble(),
      width.toDouble(),
      height.toDouble(),
      5,
      focused ? Color.ofRgb(0x828282) : Color.ofRgb(0x323232),
      context.projection,
      outlineThickness: 1,
    );

    final renderText = Text.string(_content, style: TextStyle(fontFamily: "CascadiaCode"));
    final renderTextSize = context.textRenderer.sizeOf(renderText, 15);

    if (focused) {
      context.primitives.roundedRect(
        x.toDouble() + 5 + _charIdxToClusterPos(renderText, _cursorPosition, 15),
        y.toDouble() + 6,
        1,
        height.toDouble() - 12,
        1,
        Color.white.interpolate(Color(Vector4.zero()), sin(DateTime.now().millisecondsSinceEpoch * .005)),
        context.projection,
      );
    }

    if (_content.isEmpty) return;
    context.textRenderer.drawText(
      x + 5,
      y + (height - renderTextSize.height).round() ~/ 2,
      renderText,
      15,
      context.projection,
    );
  }

  @override
  void drawFocusHighlight(DrawContext context, int mouseX, int mouseY, double delta) {}

  @override
  CursorStyle get cursorStyle => CursorStyle.text;

  double _charIdxToClusterPos(Text text, int charIdx, double size) {
    if (text.glyphs.isEmpty || charIdx == 0) return 0;

    var pos = 0.0;
    var glyphs = text.glyphs;

    for (var glyphIdx = 0; glyphIdx < glyphs.length && glyphs[glyphIdx].cluster < charIdx; glyphIdx++) {
      var glyph = glyphs[glyphIdx];
      pos += (glyph.advance.x / 64) * (size / glyph.font.size);
    }

    return pos;
  }

  void _insert(String insertion) {
    final runes = _content.runes.toList();
    runes.insertAll(_cursorPosition, insertion.runes);

    _content = String.fromCharCodes(runes);
    _cursorPosition += insertion.runes.length;
  }

  @override
  bool canFocus(FocusSource source) => true;

  @override
  bool onCharTyped(String chr, int modifiers) {
    _insert(chr);
    return true;
  }

  @override
  bool onKeyPress(int keyCode, int scanCode, int modifiers) {
    if (keyCode == glfwKeyBackspace) {
      if (_content.isEmpty) return true;

      final runes = _content.runes.toList();
      runes.removeAt(_cursorPosition - 1);
      _cursorPosition--;

      _content = String.fromCharCodes(runes);
      return true;
    } else if (keyCode == glfwKeyDelete) {
      if (_content.isEmpty) return true;

      final runes = _content.runes.toList();
      runes.removeAt(_cursorPosition);
      _content = String.fromCharCodes(runes);

      return true;
    } else if (keyCode == glfwKeyV && (modifiers & glfwModControl) != 0) {
      _insert(glfw.getClipboardString(layoutContext!.window.handle).cast<Utf8>().toDartString());
      return true;
    } else if (keyCode == glfwKeyLeft) {
      _cursorPosition = max(0, _cursorPosition - 1);
      return true;
    } else if (keyCode == glfwKeyRight) {
      _cursorPosition = min(_content.runes.length, _cursorPosition + 1);
      return true;
    } else if (keyCode == glfwKeyHome) {
      _cursorPosition = 0;
      return true;
    } else if (keyCode == glfwKeyEnd) {
      _cursorPosition = _content.runes.length;
      return true;
    } else {
      return false;
    }
  }
}
