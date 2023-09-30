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
    context.primitives.roundedRect(
      x.toDouble(),
      y.toDouble(),
      width.toDouble(),
      height.toDouble(),
      5,
      Color.black,
      context.projection,
    );

    context.primitives.roundedRect(
      x.toDouble(),
      y.toDouble(),
      width.toDouble(),
      height.toDouble(),
      5,
      focusHandler?.focused == this ? Color.ofRgb(0x828282) : Color.ofRgb(0x323232),
      context.projection,
      outlineThickness: 1.5,
    );

    final renderText = Text.string(_content, style: TextStyle(fontFamily: "CascadiaCode"));
    final renderTextSize = context.textRenderer.sizeOf(renderText);

    context.primitives.roundedRect(
      x.toDouble() + 5 + renderTextSize.width + _cursorOffset(renderText),
      y.toDouble() + 7,
      2,
      height.toDouble() - 14,
      1,
      Color.white.interpolate(Color(Vector4.zero()), sin(DateTime.now().millisecondsSinceEpoch * .005)),
      context.projection,
    );

    if (_content.isEmpty) return;

    final fontSize = renderText.glyphs.first.font.size;
    context.textRenderer.drawText(
        x + 5, y + (height - fontSize) ~/ 2 + (fontSize - renderTextSize.height), renderText, context.projection);

    var clusters = Text.string("$_cursorPosition", style: TextStyle(fontFamily: "CascadiaCode"));
    context.textRenderer.drawText(x + 5, y + 5 + height, clusters, context.projection, scale: .8);
  }

  @override
  void drawFocusHighlight(DrawContext context, int mouseX, int mouseY, double delta) {}

  double _cursorOffset(Text text) {
    if (text.glyphs.isEmpty) return 0;
    double offset = 0;

    var remaining = -_cursorPosition;
    var glyphs = text.glyphs;

    if (remaining > 0) {
      offset -= glyphs.last.font[glyphs.last.index].width;
      remaining--;
    }

    while (remaining > 0) {
      var glyph = glyphs[glyphs.length - remaining];
      offset -= (glyph.advance.x / 64) * glyph.font.size;
      remaining--;
    }

    return offset;
  }

  void _insert(String insertion) {
    final runes = _content.runes.toList();
    runes.insertAll(runes.length + _cursorPosition, insertion.runes);
    _content = String.fromCharCodes(runes);
  }

  @override
  bool canFocus(FocusSource source) => true;

  @override
  bool onCharTyped(String chr, int ruvmodifiers) {
    _insert(chr);
    return true;
  }

  @override
  bool onKeyPress(int keyCode, int scanCode, int modifiers) {
    if (keyCode == glfwKeyBackspace) {
      if (_content.isEmpty) return true;

      final runes = _content.runes.toList();
      runes.removeAt(runes.length - 1 + _cursorPosition);
      _content = String.fromCharCodes(runes);
      return true;
    } else if (keyCode == glfwKeyV && (modifiers & glfwModControl) != 0) {
      _insert(glfw.getClipboardString(layoutContext!.window.handle).cast<Utf8>().toDartString());
      return true;
    } else if (keyCode == glfwKeyLeft) {
      _cursorPosition = max(-_content.runes.length, _cursorPosition - 1);
      return true;
    } else if (keyCode == glfwKeyRight) {
      _cursorPosition = min(0, _cursorPosition + 1);
      return true;
    } else {
      return false;
    }
  }
}
