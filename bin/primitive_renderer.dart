import 'package:opengl/opengl.dart';
import 'package:vector_math/vector_math.dart';

import 'color.dart';
import 'gl/framebuffer.dart';
import 'gl/vertex_buffer.dart';
import 'gl/vertex_descriptor.dart';
import 'render_context.dart';

class ImmediatePrimitiveRenderer {
  final RenderContext _context;

  final VertexRenderObject<PosColorVertexFunction> _posColorVro;
  final VertexRenderObject<PosColorVertexFunction> _roundedVro;
  final VertexRenderObject<PosColorVertexFunction> _circleVro;
  final VertexRenderObject<PosColorVertexFunction> _blurVro;

  final GlFramebuffer _blurFramebuffer;

  ImmediatePrimitiveRenderer(this._context)
      : _posColorVro = VertexRenderObject(posColorVertexDescriptor, _context.lookupProgram("pos_color")),
        _circleVro = VertexRenderObject(posColorVertexDescriptor, _context.lookupProgram("circle")),
        _blurVro = VertexRenderObject(posColorVertexDescriptor, _context.lookupProgram("blur")),
        _roundedVro = VertexRenderObject(posColorVertexDescriptor, _context.lookupProgram("rounded_rect")),
        _blurFramebuffer = GlFramebuffer(_context.window.width, _context.window.height)..trackWindow(_context.window);

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
    _buildRect(_posColorVro, x, y, width, height, color);
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
