import 'package:opengl/opengl.dart';
import 'package:vector_math/vector_math.dart';

import 'color.dart';
import 'context.dart';
import 'gl/framebuffer.dart';
import 'gl/vertex_buffer.dart';
import 'gl/vertex_descriptor.dart';

class ImmediatePrimitiveRenderer {
  final RenderContext _context;

  final VertexRenderObject<PosColorVertexFunction> _posColorVro;
  final VertexRenderObject<PosColorVertexFunction> _roundedVro;
  final VertexRenderObject<PosColorVertexFunction> _roundedOutlineVro;
  final VertexRenderObject<PosColorVertexFunction> _circleVro;
  final VertexRenderObject<PosColorVertexFunction> _blurVro;

  final GlFramebuffer _blurFramebuffer;

  ImmediatePrimitiveRenderer(this._context)
      : _posColorVro = VertexRenderObject(posColorVertexDescriptor, _context.findProgram("pos_color")),
        _circleVro = VertexRenderObject(posColorVertexDescriptor, _context.findProgram("circle")),
        _blurVro = VertexRenderObject(posColorVertexDescriptor, _context.findProgram("blur")),
        _roundedVro = VertexRenderObject(posColorVertexDescriptor, _context.findProgram("rounded_rect")),
        _roundedOutlineVro = VertexRenderObject(posColorVertexDescriptor, _context.findProgram("rounded_rect_outline")),
        _blurFramebuffer = GlFramebuffer(_context.window.width, _context.window.height)..trackWindow(_context.window);

  void roundedRect(double x, double y, double width, double height, double radius, Color color, Matrix4 projection,
      {double? outlineThickness}) {
    final vro = outlineThickness == null ? _roundedVro : _roundedOutlineVro;
    vro.program
      ..use()
      ..uniformMat4("uTransform", Matrix4.identity())
      ..uniformMat4("uProjection", projection)
      ..uniform1f("uRadius", radius)
      ..uniform2f("uLocation", x, _context.window.height - y - height)
      ..uniform2f("uSize", width, height);

    if (outlineThickness != null) vro.program.uniform1f("uThickness", outlineThickness);

    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    vro.clear();
    buildRect(vro.vertex, x, y, width, height, color);
    vro
      ..upload(dynamic: true)
      ..draw();
  }

  void rect(double x, double y, double width, double height, Color color, Matrix4 projection) {
    _posColorVro.program
      ..use()
      ..uniformMat4("uTransform", Matrix4.identity())
      ..uniformMat4("uProjection", projection);

    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    _posColorVro.clear();
    buildRect(_posColorVro.vertex, x, y, width, height, color);
    _posColorVro
      ..upload(dynamic: true)
      ..draw();
  }

  void blur(double x, double y, double width, double height, Color color, Matrix4 projection) {
    _blurFramebuffer
      ..bind(read: false)
      ..clear(Color.black);
    glBlitFramebuffer(0, 0, _context.window.width, _context.window.height, 0, 0, _blurFramebuffer.width,
        _blurFramebuffer.height, GL_COLOR_BUFFER_BIT, GL_LINEAR);
    _blurFramebuffer.unbind(read: false);

    _blurVro.program
      ..use()
      ..uniformMat4("uTransform", Matrix4.identity())
      ..uniformMat4("uProjection", projection)
      ..uniformSampler("uInput", _blurFramebuffer.colorAttachment, 0)
      ..uniform2f("uInputResolution", _blurFramebuffer.width.toDouble(), _blurFramebuffer.height.toDouble())
      ..uniform1f("uDirections", 16)
      ..uniform1f("uQuality", 3)
      ..uniform1f("uSize", 5);

    glDisable(GL_BLEND);

    _posColorVro.clear();
    buildRect(_posColorVro.vertex, x, y, width, height, color);
    _posColorVro
      ..upload(dynamic: true)
      ..draw();

    glEnable(GL_BLEND);
  }

  void circle(double x, double y, double radius, Color color, Matrix4 projection) {
    _circleVro.program
      ..use()
      ..uniformMat4("uTransform", Matrix4.identity())
      ..uniformMat4("uProjection", projection)
      ..uniform2f("uLocation", x, _context.window.height - y - radius * 2)
      ..uniform1f("uRadius", radius);

    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    _circleVro.clear();
    buildRect(_circleVro.vertex, x, y, radius * 2, radius * 2, color);
    _circleVro
      ..upload(dynamic: true)
      ..draw();
  }

  void buildRect(
    PosColorVertexFunction vertex,
    double x,
    double y,
    double width,
    double height,
    Color color,
  ) {
    vertex(Vector3(x, y, 0), color.asVector());
    vertex(Vector3(x, y + height, 0), color.asVector());
    vertex(Vector3(x + width, y + height, 0), color.asVector());
    vertex(Vector3(x + width, y + height, 0), color.asVector());
    vertex(Vector3(x + width, y, 0), color.asVector());
    vertex(Vector3(x, y, 0), color.asVector());
  }

  void buildTri(
    PosColorVertexFunction vertex,
    double x,
    double y,
    double width,
    double height,
    Color color,
  ) {
    vertex(Vector3(x, y + height, 0), color.asVector());
    vertex(Vector3(x + width, y + height, 0), color.asVector());
    vertex(Vector3(x + width / 2, y, 0), color.asVector());
  }
}
