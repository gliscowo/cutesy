import 'dart:ffi';

import 'package:opengl/opengl.dart';
import 'package:vector_math/vector_math.dart';

import 'vertex_buffer.dart';

class VertexDescriptor<VB extends VertexBuilder> {
  final void Function(int Function(String) attributeLookup) _attributeBuilder;
  final int _vertexSize;
  final VB Function(BufferBuilder) _builderFactory;

  VertexDescriptor(this._attributeBuilder, this._vertexSize, this._builderFactory);

  void prepareAttributes(int Function(String) attributeLookup) {
    _attributeBuilder(attributeLookup);
  }

  VB createBuilder(BufferBuilder buffer) => _builderFactory(buffer);
  int get vertexSize => _vertexSize;
}

abstract class VertexBuilder {
  final BufferBuilder _buffer;
  VertexBuilder(this._buffer);

  void reset() => _buffer.rewind();
}

class HsvVertexBuilder extends VertexBuilder {
  static VertexDescriptor<HsvVertexBuilder> descriptor = VertexDescriptor((attributeLookup) {
    glEnableVertexAttribArray(attributeLookup("aPos"));
    glVertexAttribPointer(attributeLookup("aPos"), 3, GL_FLOAT, GL_FALSE, 7 * sizeOf<Float>(), 0);
    glEnableVertexAttribArray(attributeLookup("aColor"));
    glVertexAttribPointer(attributeLookup("aColor"), 4, GL_FLOAT, GL_FALSE, 7 * sizeOf<Float>(), 3 * sizeOf<Float>());
  }, 7 * sizeOf<Float>(), (buffer) => HsvVertexBuilder(buffer));

  HsvVertexBuilder(super.buffer);

  void vertex(Vector3 pos, Vector4 color) {
    _buffer.vec3(pos);
    _buffer.vec4(color);
  }
}

class TextVertexBuilder extends VertexBuilder {
  static VertexDescriptor<TextVertexBuilder> descriptor = VertexDescriptor((attributeLookup) {
    glEnableVertexAttribArray(attributeLookup("aVertex"));
    glVertexAttribPointer(attributeLookup("aVertex"), 4, GL_FLOAT, GL_FALSE, 4 * sizeOf<Float>(), 0);
  }, 4 * sizeOf<Float>(), (buffer) => TextVertexBuilder(buffer));

  TextVertexBuilder(super.buffer);

  void vertex(double x, double y, double u, double v) {
    _buffer.float4(x, y, u, v);
  }
}
