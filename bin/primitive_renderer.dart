import 'package:dart_opengl/dart_opengl.dart';
import 'package:vector_math/vector_math.dart';

import 'color.dart';
import 'context.dart';
import 'cutesy.dart';
import 'gl/framebuffer.dart';
import 'gl/vertex_buffer.dart';
import 'gl/vertex_descriptor.dart';

class ImmediatePrimitiveRenderer {
  final RenderContext _context;

  final MeshBuffer<PosColorVertexFunction> _posColorBuffer;
  final MeshBuffer<PosColorVertexFunction> _roundedBuffer;
  final MeshBuffer<PosColorVertexFunction> _roundedOutlineBuffer;
  final MeshBuffer<PosColorVertexFunction> _circleBuffer;
  final MeshBuffer<PosColorVertexFunction> _blurBuffer;

  final GlFramebuffer _blurFramebuffer;

  ImmediatePrimitiveRenderer(this._context)
      : _posColorBuffer = MeshBuffer(posColorVertexDescriptor, _context.findProgram("pos_color")),
        _circleBuffer = MeshBuffer(posColorVertexDescriptor, _context.findProgram("circle")),
        _blurBuffer = MeshBuffer(posColorVertexDescriptor, _context.findProgram("blur")),
        _roundedBuffer = MeshBuffer(posColorVertexDescriptor, _context.findProgram("rounded_rect")),
        _roundedOutlineBuffer = MeshBuffer(posColorVertexDescriptor, _context.findProgram("rounded_rect_outline")),
        _blurFramebuffer = GlFramebuffer.trackingWindow(_context.window);

  void roundedRect(double x, double y, double width, double height, double radius, Color color, Matrix4 projection,
      {double? outlineThickness}) {
    final buffer = outlineThickness == null ? _roundedBuffer : _roundedOutlineBuffer;
    buffer.program
      ..use()
      ..uniformMat4("uTransform", Matrix4.identity())
      ..uniformMat4("uProjection", projection)
      ..uniform1f("uRadius", radius)
      ..uniform2f("uLocation", x, _context.window.height - y - height)
      ..uniform2f("uSize", width, height);

    if (outlineThickness != null) buffer.program.uniform1f("uThickness", outlineThickness);

    gl.blendFunc(glSrcAlpha, glOneMinusSrcAlpha);

    buffer.clear();
    buildRect(buffer.vertex, x, y, width, height, color);
    buffer
      ..upload(dynamic: true)
      ..draw();
  }

  void rect(double x, double y, double width, double height, Color color, Matrix4 projection) {
    _posColorBuffer.program
      ..use()
      ..uniformMat4("uTransform", Matrix4.identity())
      ..uniformMat4("uProjection", projection);

    gl.blendFunc(glSrcAlpha, glOneMinusSrcAlpha);

    _posColorBuffer.clear();
    buildRect(_posColorBuffer.vertex, x, y, width, height, color);
    _posColorBuffer
      ..upload(dynamic: true)
      ..draw();
  }

  void blur(double x, double y, double width, double height, Color color, Matrix4 projection) {
    _blurFramebuffer
      ..bind(read: false)
      ..clear(Color.black);
    gl.blitFramebuffer(0, 0, _context.window.width, _context.window.height, 0, 0, _blurFramebuffer.width,
        _blurFramebuffer.height, glColorBufferBit, glLinear);
    _blurFramebuffer.unbind(read: false);

    _blurBuffer.program
      ..use()
      ..uniformMat4("uTransform", Matrix4.identity())
      ..uniformMat4("uProjection", projection)
      ..uniformSampler("uInput", _blurFramebuffer.colorAttachment, 0)
      ..uniform2f("uInputResolution", _blurFramebuffer.width.toDouble(), _blurFramebuffer.height.toDouble())
      ..uniform1f("uDirections", 16)
      ..uniform1f("uQuality", 3)
      ..uniform1f("uSize", 5);

    gl.disable(glBlend);

    _posColorBuffer.clear();
    buildRect(_posColorBuffer.vertex, x, y, width, height, color);
    _posColorBuffer
      ..upload(dynamic: true)
      ..draw();

    gl.enable(glBlend);
  }

  void circle(double x, double y, double radius, Color color, Matrix4 projection) {
    _circleBuffer.program
      ..use()
      ..uniformMat4("uTransform", Matrix4.identity())
      ..uniformMat4("uProjection", projection)
      ..uniform2f("uLocation", x, _context.window.height - y - radius * 2)
      ..uniform1f("uRadius", radius);

    gl.blendFunc(glSrcAlpha, glOneMinusSrcAlpha);

    _circleBuffer.clear();
    buildRect(_circleBuffer.vertex, x, y, radius * 2, radius * 2, color);
    _circleBuffer
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
    vertex(Vector3(x, y, 0), color);
    vertex(Vector3(x, y + height, 0), color);
    vertex(Vector3(x + width, y + height, 0), color);
    vertex(Vector3(x + width, y + height, 0), color);
    vertex(Vector3(x + width, y, 0), color);
    vertex(Vector3(x, y, 0), color);
  }
}
