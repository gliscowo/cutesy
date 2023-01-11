import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:bidi/bidi.dart';
import 'package:ffi/ffi.dart';
import 'package:opengl/opengl.dart';
import 'package:vector_math/vector_math_64.dart';

import 'lib/freetype.dart';
import 'lib/harfbuzz.dart';
import 'shader.dart';
import 'vertex.dart';

class Glyph {
  final int textureId;
  final Vector2 size;
  final Vector2 bearing;
  final int advance;
  Glyph(this.textureId, this.size, this.bearing, this.advance);
}

const fontPath = "resources/font/CascadiaCode_Regular.otf";
const fontSize = 36;

final _glyphs = <int, Glyph>{};
final _ft = FreetypeLibrary(DynamicLibrary.open("resources/lib/libfreetype.so"));
late final FT_Face _ftFace;

final _hb = HarfbuzzLibrary(DynamicLibrary.open("resources/lib/libharfbuzz.so"));
late final Pointer<hb_font_t> _hbFont;

Pointer<hb_buffer_t> bufferFromString(String text) {
  // final now = DateTime.now();

  final hbFeatures = malloc<hb_feature_t>();
  _hb.hb_feature_from_string("calt on".toNativeUtf8().cast(), -1, hbFeatures);

  final hbBuffer = _hb.hb_buffer_create();
  _hb.hb_buffer_add_utf8(hbBuffer, String.fromCharCodes(logicalToVisual(text)).toNativeUtf8().cast(), -1, 0, -1);
  _hb.hb_buffer_set_direction(hbBuffer, hb_direction_t.HB_DIRECTION_LTR);
  _hb.hb_buffer_set_script(hbBuffer, hb_script_t.HB_SCRIPT_LATIN);
  _hb.hb_buffer_set_language(hbBuffer, _hb.hb_language_from_string("en".toNativeUtf8().cast(), -1));
  _hb.hb_shape(_hbFont, hbBuffer, hbFeatures, 1);
  malloc.free(hbFeatures);

  // print(
  //     "took ${(DateTime.now().microsecondsSinceEpoch - now.microsecondsSinceEpoch) / 1000}ms to shape ${text.length} chars");

  return hbBuffer;
}

void freeBuffer(Pointer<hb_buffer_t> buffer) => _hb.hb_buffer_destroy(buffer);

void drawText(double x, double y, double scale, Pointer<hb_buffer_t> hbBuffer, GlProgram program, GlVertexBuffer vbo,
    GlVertexArray vao, Matrix4 projection, Vector3 color) {
  program.use();
  glUniform3f(glGetUniformLocation(program.id, "uTextColor".toNativeUtf8()), color.r, color.g, color.b);

  final projData = Float32List.fromList(projection.storage);
  final buffer = malloc.allocate<Float>(projData.lengthInBytes);
  buffer.asTypedList(projData.length).setRange(0, projData.length, projData);
  glUniformMatrix4fv(glGetUniformLocation(program.id, "uProjection".toNativeUtf8()), 1, GL_FALSE, buffer);
  malloc.free(buffer);

  glActiveTexture(GL_TEXTURE0);

  final glyphCount = malloc<UnsignedInt>();
  final glyphInfo = _hb.hb_buffer_get_glyph_infos(hbBuffer, glyphCount);
  final glyphPos = _hb.hb_buffer_get_glyph_positions(hbBuffer, glyphCount);

  int cursorX = 0;
  int cursorY = 0;
  for (int i = 0; i < glyphCount.value; i++) {
    int codepoint = glyphInfo[i].codepoint;
    int xOffset = (glyphPos[i].x_offset / 64 * fontSize * scale).round();
    int yOffset = (glyphPos[i].y_offset / 64 * fontSize * scale).round();
    int xAdvance = (glyphPos[i].x_advance / 64 * fontSize * scale).round();
    int yAdvance = (glyphPos[i].y_advance / 64 * fontSize * scale).round();

    final glyph = _getGlyph(codepoint);
    final xpos = x + cursorX + xOffset + glyph.bearing.x * scale;
    final ypos = y + cursorY + yOffset + (fontSize - glyph.bearing.y) * scale;
    final width = glyph.size.x * scale;
    final height = glyph.size.y * scale;

    glBindTexture(GL_TEXTURE_2D, glyph.textureId);

    vbo
      ..upload(BufferBuilder()
        ..color(xpos, ypos, 0, 0)
        ..color(xpos, ypos + height, 0, 1)
        ..color(xpos + width, ypos, 1, 0)
        ..color(xpos + width, ypos, 1, 0)
        ..color(xpos, ypos + height, 0, 1)
        ..color(xpos + width, ypos + height, 1, 1))
      ..draw(6, vao: vao);

    cursorX += xAdvance;
    cursorY += yAdvance;
  }
}

void initTextRenderer() {
  // FreeType
  final ft = malloc.allocate<FT_Library>(sizeOf<Pointer<FT_Library>>());
  if (_ft.FT_Init_FreeType(ft) != 0) {
    print("Could not initialize FreeType");
    exit(-1);
  }

  final face = malloc.allocate<FT_Face>(sizeOf<Pointer<FT_Face>>());
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
}

Glyph _getGlyph(int codepoint) {
  return _glyphs[codepoint] ?? _renderGlyph(codepoint);
}

Glyph _renderGlyph(int codepoint) {
  if (_ft.FT_Load_Glyph(_ftFace, codepoint, FT_LOAD_RENDER) != 0) {
    throw Exception("Failed to load glyph ${String.fromCharCode(codepoint)}");
  }

  final textureId = malloc<Uint32>();
  glGenTextures(1, textureId);

  final texture = textureId.value;
  malloc.free(textureId);

  glBindTexture(GL_TEXTURE_2D, texture);

  glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RED, _ftFace.ref.glyph.ref.bitmap.width, _ftFace.ref.glyph.ref.bitmap.rows, 0,
      GL_RED, GL_UNSIGNED_BYTE, _ftFace.ref.glyph.ref.bitmap.buffer);

  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

  return _glyphs[codepoint] = Glyph(
    texture,
    Vector2(_ftFace.ref.glyph.ref.bitmap.width.toDouble(), _ftFace.ref.glyph.ref.bitmap.rows.toDouble()),
    Vector2(_ftFace.ref.glyph.ref.bitmap_left.toDouble(), _ftFace.ref.glyph.ref.bitmap_top.toDouble()),
    _ftFace.ref.glyph.ref.advance.x,
  );
}
