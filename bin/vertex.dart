import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:opengl/opengl.dart';
import 'package:vector_math/vector_math_64.dart';

import 'shader.dart';

class GlVertexBuffer {
  late final int _id;

  GlVertexBuffer() {
    final idPointer = calloc<Uint32>();
    glGenBuffers(1, idPointer);
    _id = idPointer.value;
  }

  void draw(int count, {required GlVertexArray? vao, GlProgram? program}) {
    if (program != null) program.use();
    if (vao != null) vao.bind();

    glDrawArrays(GL_TRIANGLES, 0, count);

    if (vao != null) vao.unbind();
  }

  void bind() {
    glBindBuffer(GL_ARRAY_BUFFER, _id);
  }

  void unbind() {
    glBindBuffer(GL_ARRAY_BUFFER, 0);
  }

  void upload(BufferBuilder data, {bool unbind = false}) {
    final bytes = data._builder.takeBytes();

    final buffer = malloc.allocate<Uint8>(bytes.length);
    buffer.asTypedList(bytes.length).setRange(0, bytes.length, bytes);

    glBindBuffer(GL_ARRAY_BUFFER, _id);
    glBufferData(GL_ARRAY_BUFFER, bytes.length, buffer, GL_STATIC_DRAW);

    malloc.free(buffer);

    if (unbind) glBindBuffer(GL_ARRAY_BUFFER, 0);
  }
}

class GlVertexArray {
  late final int _id;

  GlVertexArray() {
    final idPointer = calloc<Uint32>();
    glGenVertexArrays(1, idPointer);
    _id = idPointer.value;
  }

  void bind() {
    glBindVertexArray(_id);
  }

  void unbind() {
    glBindVertexArray(0);
  }
}

class BufferBuilder {
  final BytesBuilder _builder = BytesBuilder();

  void vertex(double x, double y, double z) => _float3(x, y, z);
  void vertexV(Vector3 v) => _float3(v.x, v.y, v.z);
  void color(double r, double g, double b, double a) => _float4(r, g, b, a);

  void _float3(double a, double b, double c) {
    final data = ByteData(sizeOf<Float>() * 3)
      ..setFloat32(sizeOf<Float>() * 0, a, Endian.little)
      ..setFloat32(sizeOf<Float>() * 1, b, Endian.little)
      ..setFloat32(sizeOf<Float>() * 2, c, Endian.little);

    _builder.add(data.buffer.asUint8List());
  }

  void _float4(double a, double b, double c, double d) {
    final data = ByteData(sizeOf<Float>() * 4)
      ..setFloat32(sizeOf<Float>() * 0, a, Endian.little)
      ..setFloat32(sizeOf<Float>() * 1, b, Endian.little)
      ..setFloat32(sizeOf<Float>() * 2, c, Endian.little)
      ..setFloat32(sizeOf<Float>() * 3, d, Endian.little);

    _builder.add(data.buffer.asUint8List());
  }
}
