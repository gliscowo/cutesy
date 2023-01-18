import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:ffi/ffi.dart';
import 'package:opengl/opengl.dart';
import 'package:vector_math/vector_math.dart';

import '../gl/shader.dart';
import '../gl/vertex_buffer.dart';
import '../gl/vertex_descriptor.dart';
import '../native/freetype.dart';
import '../native/harfbuzz.dart';
import 'text.dart';

final freetype = FreetypeLibrary(DynamicLibrary.open("resources/lib/libfreetype.so"));
final harfbuzz = HarfbuzzLibrary(DynamicLibrary.open("resources/lib/libharfbuzz.so"));

class FontFamily {
  final List<Font> _allFonts = [];

  late final Font defaultFont;
  late final Font boldFont, italicFont, boldItalicFont;

  FontFamily(String familyName, int size) {
    final fontFiles = Directory("resources/font/$familyName")
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith(".otf"));

    for (final font in fontFiles) {
      _allFonts.add(Font(font.absolute.path, size));
    }

    Font Function() defaultAndWarn(String type) {
      return () {
        print("Could not find a '$type' font in family $familyName");
        return defaultFont;
      };
    }

    defaultFont = _allFonts.firstWhere((font) => !font.bold && !font.italic, orElse: () => _allFonts.first);
    boldFont = _allFonts.firstWhere((font) => font.bold && !font.italic, orElse: defaultAndWarn("bold"));
    italicFont = _allFonts.firstWhere((font) => !font.bold && font.italic, orElse: defaultAndWarn("italic"));
    boldItalicFont = _allFonts.firstWhere((font) => font.bold && font.italic, orElse: defaultAndWarn("bold & italic"));
  }

  Font fontForStyle(TextStyle style) {
    if (style.bold && !style.italic) return boldFont;
    if (!style.bold && style.italic) return italicFont;
    if (style.bold && style.italic) return boldItalicFont;
    return defaultFont;
  }
}

class Font {
  static FT_Library? _ftInstance;
  static final List<int> _glyphTextures = [];
  static int _nextGlyphX = 1024, _nextGlyphY = 1024;
  static int _currentRowHeight = 0;

  late final Pointer<hb_font_t> _hbFont;
  late final FT_Face _ftFace;

  final Map<int, Glyph> _glyphs = {};
  final int size;

  late final bool bold, italic;

  Font(String path, this.size) {
    // _glyphTextures.add(_createGlyphAtlasTexture());

    final nativePath = path.toNativeUtf8().cast<Char>();

    final face = malloc<FT_Face>();
    if (freetype.FT_New_Face(_ftLibrary, nativePath, 0, face) != 0) {
      throw ArgumentError.value(path, "path", "Could not load font");
    }

    final faceStruct = face.value.ref;
    bold = faceStruct.style_flags & FT_STYLE_FLAG_BOLD != 0;
    italic = faceStruct.style_flags & FT_STYLE_FLAG_ITALIC != 0;

    _ftFace = face.value;
    freetype.FT_Set_Pixel_Sizes(_ftFace, 0, size);

    // HarfBuzz
    final blob = harfbuzz.hb_blob_create_from_file(nativePath);
    final hbFace = harfbuzz.hb_face_create(blob, 0);
    _hbFont = harfbuzz.hb_font_create(hbFace);
    harfbuzz.hb_font_set_scale(_hbFont, 64, 64);

    malloc.free(nativePath);
  }

  Glyph operator [](int index) => _glyphs[index] ?? _loadGlyph(index);

  Glyph _loadGlyph(int index) {
    if (freetype.FT_Load_Glyph(_ftFace, index, FT_LOAD_RENDER) != 0) {
      throw Exception("Failed to load glyph ${String.fromCharCode(index)}");
    }

    final location = _allocateGlpyhPosition(_ftFace.ref.glyph.ref.bitmap.width, _ftFace.ref.glyph.ref.bitmap.rows);

    glBindTexture(GL_TEXTURE_2D, _glyphTextures.first);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    glTexSubImage2D(GL_TEXTURE_2D, 0, location.u, location.v, _ftFace.ref.glyph.ref.bitmap.width,
        _ftFace.ref.glyph.ref.bitmap.rows, GL_RED, GL_UNSIGNED_BYTE, _ftFace.ref.glyph.ref.bitmap.buffer);

    return _glyphs[index] = Glyph(
      _glyphTextures.first,
      location.u,
      location.v,
      _ftFace.ref.glyph.ref.bitmap.width,
      _ftFace.ref.glyph.ref.bitmap.rows,
      _ftFace.ref.glyph.ref.bitmap_left,
      _ftFace.ref.glyph.ref.bitmap_top,
    );
  }

  static _GlyphLocation _allocateGlpyhPosition(int width, int height) {
    if (_nextGlyphX + width >= 1024) {
      _nextGlyphX = 0;
      _nextGlyphY += _currentRowHeight + 1;
    }

    if (_nextGlyphY + height >= 1024) {
      _glyphTextures.add(_createGlyphAtlasTexture());
      _nextGlyphX = 0;
      _nextGlyphY = 0;
    }

    final textureId = _glyphTextures.last;
    final location = _GlyphLocation(textureId, _nextGlyphX, _nextGlyphY);

    _nextGlyphX += width + 1;
    _currentRowHeight = max(_currentRowHeight, height);

    return location;
  }

  static int _createGlyphAtlasTexture() {
    final texture = malloc<Uint32>();
    glGenTextures(1, texture);
    final textureId = texture.value;
    malloc.free(texture);

    glBindTexture(GL_TEXTURE_2D, textureId);

    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RED, 1024, 1024, 0, GL_RED, GL_UNSIGNED_BYTE, nullptr);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

    return textureId;
  }

  Pointer<hb_font_t> get hbFont => _hbFont;

  static FT_Library get _ftLibrary {
    if (_ftInstance != null) return _ftInstance!;

    final ft = malloc<FT_Library>();
    if (freetype.FT_Init_FreeType(ft) != 0) {
      throw "Failed to initialize FreeType library";
    }

    return _ftInstance = ft.value;
  }
}

class _GlyphLocation {
  final int textureId, u, v;
  _GlyphLocation(this.textureId, this.u, this.v);
}

class Glyph {
  final int textureId;
  final int u, v;
  final int width, height;
  final int bearingX, bearingY;
  Glyph(this.textureId, this.u, this.v, this.width, this.height, this.bearingX, this.bearingY);
}

final _cachedRenderObjects = <int, VertexRenderObject>{};

void drawText(double x, double y, double scale, Text text, GlProgram program, Matrix4 projection, Vector3 color) {
  program.use();
  program.uniformMat4("uProjection", projection);

  final renderObjects = <int, VertexRenderObject>{};
  VertexRenderObject renderObject(int texture) {
    return renderObjects[texture] ??
        (renderObjects[texture] = (_cachedRenderObjects[texture]?..clear()) ??
            (_cachedRenderObjects[texture] = VertexRenderObject(textVertexDescriptor, program)));
  }

  for (final shapedGlyph in text.glyphs) {
    final fontSize = shapedGlyph.font.size;
    final glyph = shapedGlyph.font[shapedGlyph.index];
    final glyphColor = shapedGlyph.style.color?.asVector().rgb ?? color;

    final xPos = x + (shapedGlyph.position.x / 64 * fontSize) * scale + glyph.bearingX * scale;
    final yPos = y + (shapedGlyph.position.y / 64 * fontSize) * scale + (fontSize - glyph.bearingY) * scale;
    final width = glyph.width * scale, height = glyph.height * scale;

    final u0 = (glyph.u / 1024), u1 = (glyph.u / 1024) + (glyph.width / 1024);
    final v0 = (glyph.v / 1024), v1 = (glyph.v / 1024) + (glyph.height / 1024);

    renderObject(glyph.textureId)
      ..vertex(xPos, yPos, u0, v0, glyphColor)
      ..vertex(xPos, yPos + height, u0, v1, glyphColor)
      ..vertex(xPos + width, yPos, u1, v0, glyphColor)
      ..vertex(xPos + width, yPos, u1, v0, glyphColor)
      ..vertex(xPos, yPos + height, u0, v1, glyphColor)
      ..vertex(xPos + width, yPos + height, u1, v1, glyphColor);
  }

  glActiveTexture(GL_TEXTURE0);

  renderObjects.forEach((texture, vro) {
    glBindTexture(GL_TEXTURE_2D, texture);
    vro
      ..upload(dynamic: true)
      ..draw();
  });
}
