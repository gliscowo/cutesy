import 'dart:ffi';

import 'package:bidi/bidi.dart';
import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';
import 'package:vector_math/vector_math_64.dart';

import '../color.dart';
import '../cutesy.dart';
import '../native/harfbuzz.dart';
import 'text_renderer.dart';

class StyledString {
  final String content;
  final TextStyle style;
  const StyledString(this.content, {this.style = const TextStyle()});
}

class TextStyle {
  final Color? color;
  final String? fontFamily;
  final bool bold, italic;

  const TextStyle({this.color, this.fontFamily, this.bold = false, this.italic = false});
}

typedef FontLookup = FontFamily Function(String?);

class Text {
  final List<StyledString> _segments;
  final List<ShapedGlyph> _shapedGlyphs = [];
  bool _isShaped = false;

  Text.string(String value, {TextStyle style = const TextStyle()}) : this([StyledString(value, style: style)]);

  Text(this._segments) {
    if (_segments.isEmpty) throw ArgumentError("Text must have at least one segment");
  }

  @internal
  List<ShapedGlyph> get glyphs => _shapedGlyphs;

  @internal
  bool get isShaped => _isShaped;

  @internal
  void shape(FontLookup fontLookup) {
    int cursorX = 0, cursorY = 0;

    final featureFlag = "calt on".toNativeUtf8().cast<Char>();
    final language = "en".toNativeUtf8().cast<Char>();

    for (final segment in _segments) {
      final segmentFont = fontLookup(segment.style.fontFamily);

      final hbFeatures = malloc<hb_feature>();
      harfbuzz.feature_from_string(featureFlag, -1, hbFeatures);

      final buffer = harfbuzz.buffer_create();
      String.fromCharCodes(logicalToVisual(segment.content))
          .withAsNative((reordered) => harfbuzz.buffer_add_utf8(buffer, reordered.cast(), -1, 0, -1));

      harfbuzz.buffer_set_direction(buffer, hb_direction.HB_DIRECTION_LTR);
      harfbuzz.buffer_set_script(buffer, hb_script.HB_SCRIPT_LATIN);
      harfbuzz.buffer_set_language(buffer, harfbuzz.language_from_string(language, -1));
      harfbuzz.buffer_set_cluster_level(buffer, hb_buffer_cluster_level.HB_BUFFER_CLUSTER_LEVEL_MONOTONE_CHARACTERS);
      harfbuzz.shape(segmentFont.fontForStyle(segment.style).hbFont, buffer, hbFeatures, 1);
      malloc.free(hbFeatures);

      final glpyhCount = malloc<UnsignedInt>();
      final glyphInfo = harfbuzz.buffer_get_glyph_infos(buffer, glpyhCount);
      final glyphPos = harfbuzz.buffer_get_glyph_positions(buffer, glpyhCount);

      final glyphs = glpyhCount.value;
      malloc.free(glpyhCount);

      for (var i = 0; i < glyphs; i++) {
        _shapedGlyphs.add(ShapedGlyph._(
          segmentFont.fontForStyle(segment.style),
          glyphInfo[i].codepoint,
          Vector2(
            cursorX + glyphPos[i].x_offset.toDouble(),
            cursorY + glyphPos[i].y_offset.toDouble(),
          ),
          Vector2(
            glyphPos[i].x_advance.toDouble(),
            glyphPos[i].y_advance.toDouble(),
          ),
          segment.style,
          glyphInfo[i].cluster,
        ));

        cursorX += glyphPos[i].x_advance;
        cursorY += glyphPos[i].y_advance;
      }

      harfbuzz.buffer_destroy(buffer);
    }

    _isShaped = true;
  }
}

class ShapedGlyph {
  final Font font;
  final int index;
  final Vector2 position;
  final Vector2 advance;
  final TextStyle style;
  final int cluster;
  ShapedGlyph._(this.font, this.index, this.position, this.advance, this.style, this.cluster);
}
