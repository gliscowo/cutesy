import 'dart:ffi';

import 'package:dart_opengl/dart_opengl.dart';
import 'package:vector_math/vector_math.dart';

import '../cutesy.dart';
import 'vertex_buffer.dart';

enum VertexElement {
  float(4, glFloat);

  final int size, glType;
  const VertexElement(this.size, this.glType);
}

typedef PosColorVertexFunction = void Function(Vector3, Vector4);
final VertexDescriptor<PosColorVertexFunction> posColorVertexDescriptor = VertexDescriptor(
  (attribute) {
    attribute("aPos", VertexElement.float, 3);
    attribute("aColor", VertexElement.float, 4);
  },
  (buffer) => (pos, color) {
    buffer.vec3(pos);
    buffer.vec4(color);
  },
);

typedef TextVertexFunction = void Function(double, double, double, double, Vector4);
final VertexDescriptor<TextVertexFunction> textVertexDescriptor = VertexDescriptor(
  (attribute) {
    attribute("aPos", VertexElement.float, 2);
    attribute("aUv", VertexElement.float, 2);
    attribute("aColor", VertexElement.float, 4);
  },
  (buffer) => (x, y, u, v, color) {
    buffer.float4(x, y, u, v);
    buffer.float4(color.r, color.g, color.b, color.a);
  },
);

class VertexDescriptor<VertexFunction extends Function> {
  final VertexFunction Function(BufferBuilder) _builderFactory;
  final List<_VertexAttribute> _attributes = [];
  int _vertexSize = 0;

  VertexDescriptor(void Function(void Function(String, VertexElement, int)) attributeSetup, this._builderFactory) {
    attributeSetup((name, element, count) {
      _attributes.add(_VertexAttribute(name, element, count, _vertexSize));
      _vertexSize += element.size * count;
    });
  }

  void prepareAttributes(int Function(String) attributeLookup) {
    for (final attr in _attributes) {
      final location = attributeLookup(attr.name);

      gl.enableVertexAttribArray(location);
      gl.vertexAttribPointer(
        location,
        attr.count,
        attr.element.glType,
        glFalse,
        _vertexSize,
        Pointer.fromAddress(attr.offset),
      );
    }
  }

  VertexFunction createBuilder(BufferBuilder buffer) => _builderFactory(buffer);
  int get vertexSize => _vertexSize;
}

class _VertexAttribute {
  final String name;
  final VertexElement element;
  final int count, offset;

  _VertexAttribute(this.name, this.element, this.count, this.offset);
}
