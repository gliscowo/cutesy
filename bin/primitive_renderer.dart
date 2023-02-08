import 'package:opengl/opengl.dart';
import 'package:vector_math/vector_math.dart';

import 'color.dart';
import 'gl/vertex_buffer.dart';
import 'gl/vertex_descriptor.dart';
import 'render_context.dart';

class ImmediatePrimitiveRenderer {
  final RenderContext _context;

  final VertexRenderObject<PosColorVertexFunction> _posColorVro;
  final VertexRenderObject<PosColorVertexFunction> _roundedVro;
  final VertexRenderObject<PosColorVertexFunction> _circleVro;

  ImmediatePrimitiveRenderer(this._context)
      : _posColorVro = VertexRenderObject(posColorVertexDescriptor, _context.lookupProgram("pos_color")),
        _circleVro = VertexRenderObject(posColorVertexDescriptor, _context.lookupProgram("circle")),
        _roundedVro = VertexRenderObject(posColorVertexDescriptor, _context.lookupProgram("rounded_rect"));

  void roundedRect(double x, double y, double width, double height, double radius, Color color, Matrix4 projection) {
    _roundedVro.program
      ..use()
      ..uniformMat4("uTransform", Matrix4.identity())
      ..uniformMat4("uProjection", projection)
      ..uniform1f("uRadius", radius)
      ..uniform2f("uLocation", x, _context.window.height - y - height)
      ..uniform2f("uSize", width, height);

    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    _roundedVro.clear();
    _buildRect(_roundedVro, x, y, width, height, color);
    _roundedVro
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
    _buildRect(_posColorVro, x, y, width, height, color);
    _posColorVro
      ..upload(dynamic: true)
      ..draw();
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
    _buildRect(_circleVro, x, y, radius * 2, radius * 2, color);
    _circleVro
      ..upload(dynamic: true)
      ..draw();
  }

  void _buildRect(
    VertexRenderObject<PosColorVertexFunction> vro,
    double x,
    double y,
    double width,
    double height,
    Color color,
  ) {
    vro
      ..vertex(Vector3(x, y, 0), color.asVector())
      ..vertex(Vector3(x, y + height, 0), color.asVector())
      ..vertex(Vector3(x + width, y + height, 0), color.asVector())
      ..vertex(Vector3(x + width, y + height, 0), color.asVector())
      ..vertex(Vector3(x + width, y, 0), color.asVector())
      ..vertex(Vector3(x, y, 0), color.asVector());
  }
}
