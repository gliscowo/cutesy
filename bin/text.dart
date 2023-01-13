import 'dart:ffi';
import 'dart:io';

import 'package:bidi/bidi.dart';
import 'package:ffi/ffi.dart';
import 'package:opengl/opengl.dart';
import 'package:vector_math/vector_math.dart';

import 'lib/freetype.dart';
import 'lib/harfbuzz.dart';
import 'shader.dart';
import 'vertex.dart';

class Glyph {
  final Vector2 uv;
  final Vector2 size;
  final Vector2 bearing;
  Glyph(this.uv, this.size, this.bearing);
}

const fontPath = "resources/font/CascadiaCode_Regular.otf";
const fontSize = 36;

final _glyphs = <int, Glyph>{};
final _ft = FreetypeLibrary(DynamicLibrary.open("resources/lib/libfreetype.so"));
late final FT_Face _ftFace;

final _hb = HarfbuzzLibrary(DynamicLibrary.open("resources/lib/libharfbuzz.so"));
late final Pointer<hb_font_t> _hbFont;

late final int glyphTexture;

extension StringDrawingExtensions on String {
  String toVisual() => String.fromCharCodes(logicalToVisual(this));

  Pointer<hb_buffer_t> shape() {
    // final now = DateTime.now();

    final hbFeatures = malloc<hb_feature_t>();
    _hb.hb_feature_from_string("calt on".toNativeUtf8().cast(), -1, hbFeatures);

    final buffer = _hb.hb_buffer_create();
    _hb.hb_buffer_add_utf8(buffer, String.fromCharCodes(logicalToVisual(this)).toNativeUtf8().cast(), -1, 0, -1);
    _hb.hb_buffer_set_direction(buffer, hb_direction_t.HB_DIRECTION_LTR);
    _hb.hb_buffer_set_script(buffer, hb_script_t.HB_SCRIPT_LATIN);
    _hb.hb_buffer_set_language(buffer, _hb.hb_language_from_string("en".toNativeUtf8().cast(), -1));
    _hb.hb_shape(_hbFont, buffer, hbFeatures, 1);
    malloc.free(hbFeatures);

    // print(
    //     "took ${(DateTime.now().microsecondsSinceEpoch - now.microsecondsSinceEpoch) / 1000}ms to shape ${text.length} chars");

    return buffer;
  }
}

extension DestoryBuffer on Pointer<hb_buffer_t> {
  void destroy() => _hb.hb_buffer_destroy(this);
}

final _textBuffer = BufferBuilder(4096);
void drawText(double x, double y, double scale, Pointer<hb_buffer_t> hbBuffer, GlProgram program, GlVertexBuffer vbo,
    GlVertexArray vao, Matrix4 projection, Vector3 color) {
  program.use();
  program.uniform3vf("uTextColor", color);
  program.uniformMat4("uProjection", projection);

  glActiveTexture(GL_TEXTURE0);

  final glyphCount = malloc<UnsignedInt>();
  final glyphInfo = _hb.hb_buffer_get_glyph_infos(hbBuffer, glyphCount);
  final glyphPos = _hb.hb_buffer_get_glyph_positions(hbBuffer, glyphCount);

  int cursorX = 0, cursorY = 0;
  _textBuffer.rewind();

  for (int i = 0; i < glyphCount.value; i++) {
    int codepoint = glyphInfo[i].codepoint;
    int xOffset = (glyphPos[i].x_offset / 64 * fontSize * scale).round();
    int yOffset = (glyphPos[i].y_offset / 64 * fontSize * scale).round();
    int xAdvance = (glyphPos[i].x_advance / 64 * fontSize * scale).round();
    int yAdvance = (glyphPos[i].y_advance / 64 * fontSize * scale).round();

    final glyph = _getGlyph(codepoint);
    final xpos = x + cursorX + xOffset + glyph.bearing.x * scale;
    final ypos = y + cursorY + yOffset + (fontSize - glyph.bearing.y) * scale;
    final width = glyph.size.x * scale, height = glyph.size.y * scale;

    final u0 = (glyph.uv.x / 1024), u1 = (glyph.uv.x / 1024) + (glyph.size.x / 1024);
    final v0 = (glyph.uv.y / 1024), v1 = (glyph.uv.y / 1024) + (glyph.size.y / 1024);

    _textBuffer
      ..float4(xpos, ypos, u0, v0)
      ..float4(xpos, ypos + height, u0, v1)
      ..float4(xpos + width, ypos, u1, v0)
      ..float4(xpos + width, ypos, u1, v0)
      ..float4(xpos, ypos + height, u0, v1)
      ..float4(xpos + width, ypos + height, u1, v1);

    cursorX += xAdvance;
    cursorY += yAdvance;
  }

  glBindTexture(GL_TEXTURE_2D, glyphTexture);
  vbo
    ..upload(_textBuffer, static: false)
    ..draw(glyphCount.value * 6, vao: vao);
}

void initTextRenderer() {
  // FreeType
  final ft = malloc<FT_Library>();
  if (_ft.FT_Init_FreeType(ft) != 0) {
    print("Could not initialize FreeType");
    exit(-1);
  }

  final face = malloc<FT_Face>();
  if (_ft.FT_New_Face(ft.value, fontPath.toNativeUtf8().cast(), 0, face) != 0) {
    print("Could not load font");
    exit(-1);
  }

  _ftFace = face.value;
  _ft.FT_Set_Pixel_Sizes(_ftFace, 0, fontSize);

  // HarfBuzz
  final blob = _hb.hb_blob_create_from_file(fontPath.toNativeUtf8().cast());
  final hbFace = _hb.hb_face_create(blob, 0);
  _hbFont = _hb.hb_font_create(hbFace);
  _hb.hb_font_set_scale(_hbFont, 64, 64);

  // Prepare glyph atlas

  final glyphTextureId = malloc<Uint32>();
  glGenTextures(1, glyphTextureId);
  glyphTexture = glyphTextureId.value;
  malloc.free(glyphTextureId);

  glBindTexture(GL_TEXTURE_2D, glyphTexture);

  glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RED, 1024, 1024, 0, GL_RED, GL_UNSIGNED_BYTE, nullptr);

  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
}

Glyph _getGlyph(int codepoint) {
  return _glyphs[codepoint] ?? _renderGlyph(codepoint);
}

int _nextGlyphX = 0;
int _nextGlyphY = 0;

Glyph _renderGlyph(int codepoint) {
  if (_ft.FT_Load_Glyph(_ftFace, codepoint, FT_LOAD_RENDER) != 0) {
    throw Exception("Failed to load glyph ${String.fromCharCode(codepoint)}");
  }

  if (_nextGlyphX + _ftFace.ref.glyph.ref.bitmap.width >= 1024) {
    _nextGlyphY += _ftFace.ref.glyph.ref.bitmap.rows;
    _nextGlyphX = 0;
  }

  int glyphX = _nextGlyphX;
  int glyphY = _nextGlyphY;

  glBindTexture(GL_TEXTURE_2D, glyphTexture);
  glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
  glTexSubImage2D(GL_TEXTURE_2D, 0, glyphX, glyphY, _ftFace.ref.glyph.ref.bitmap.width,
      _ftFace.ref.glyph.ref.bitmap.rows, GL_RED, GL_UNSIGNED_BYTE, _ftFace.ref.glyph.ref.bitmap.buffer);

  _nextGlyphX += _ftFace.ref.glyph.ref.bitmap.width;

  return _glyphs[codepoint] = Glyph(
    Vector2(glyphX.toDouble(), glyphY.toDouble()),
    Vector2(_ftFace.ref.glyph.ref.bitmap.width.toDouble(), _ftFace.ref.glyph.ref.bitmap.rows.toDouble()),
    Vector2(_ftFace.ref.glyph.ref.bitmap_left.toDouble(), _ftFace.ref.glyph.ref.bitmap_top.toDouble()),
  );
}
