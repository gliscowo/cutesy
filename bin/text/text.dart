import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:vector_math/vector_math_64.dart';

import '../color.dart';
import 'text_renderer.dart';

class StyledString {
  final String content;
  final TextStyle style;
  const StyledString(this.content, {this.style = const TextStyle()});
}

class TextStyle {
  final Color? color;
  final bool bold, italic;
  const TextStyle({this.color, this.bold = false, this.italic = false});
}

class Text {
  final List<StyledString> _segments;
  final List<ShapedGlyph> _shapedGlyphs = [];

  Text.string(String value, {TextStyle style = const TextStyle()}) : this([StyledString(value, style: style)]);

  Text(this._segments) {
    if (_segments.isEmpty) throw ArgumentError("Text must have at least one segment");
  }

  List<ShapedGlyph> get glyphs {
    if (_shapedGlyphs.isEmpty) _shape();
    return _shapedGlyphs;
  }

  void _shape() {
    int cursorX = 0, cursorY = 0;

    for (final segment in _segments) {
      final buffer = segment.content.toVisual().shape();

      final glpyhCount = malloc<UnsignedInt>();
      final glyphInfo = harfbuzz.hb_buffer_get_glyph_infos(buffer, glpyhCount);
      final glyphPos = harfbuzz.hb_buffer_get_glyph_positions(buffer, glpyhCount);

      for (var i = 0; i < glpyhCount.value; i++) {
        _shapedGlyphs.add(ShapedGlyph._(
          glyphInfo[i].codepoint,
          Vector2(
            cursorX + glyphPos[i].x_offset.toDouble(),
            cursorY + glyphPos[i].y_offset.toDouble(),
          ),
          segment.style,
        ));

        cursorX += glyphPos[i].x_advance;
        cursorY += glyphPos[i].y_advance;
      }

      buffer.destroy();
    }
  }
}

class ShapedGlyph {
  final int index;
  final Vector2 position;
  final TextStyle style;
  ShapedGlyph._(this.index, this.position, this.style);
}
