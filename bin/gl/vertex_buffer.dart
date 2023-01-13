import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:opengl/opengl.dart';
import 'package:vector_math/vector_math.dart';

import 'shader.dart';
import 'vertex_descriptor.dart';

class VertexRenderObject<VB extends VertexBuilder> {
  final GlVertexBuffer _vbo = GlVertexBuffer();
  final GlVertexArray _vao = GlVertexArray();

  final BufferBuilder _buffer;

  final VertexDescriptor _descriptor;
  late final VB builder;

  VertexRenderObject(VertexDescriptor<VB> descriptor, GlProgram program, {int initialBufferSize = 1024})
      : _descriptor = descriptor,
        _buffer = BufferBuilder(initialBufferSize) {
    _vbo.bind();
    _vao.bind();

    descriptor.prepareAttributes(program.getAttributeLocation);

    _vao.unbind();
    _vbo.unbind();

    builder = descriptor.createBuilder(_buffer);
  }

  void upload({bool static = false}) {
    _vbo.upload(_buffer, static: static);
  }

  void draw() {
    _vbo.draw(_buffer._cursor ~/ _descriptor.vertexSize, vao: _vao);
  }
}

class GlVertexBuffer {
  late final int _id;

  GlVertexBuffer() {
    final idPointer = malloc<Uint32>();
    glGenBuffers(1, idPointer);
    _id = idPointer.value;
    malloc.free(idPointer);
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

  void upload(BufferBuilder data, {bool static = true}) {
    final bytes = data._data.buffer.asUint8List();

    final buffer = malloc<Uint8>(data._cursor);
    buffer.asTypedList(data._cursor).setRange(0, data._cursor, bytes);

    glBindBuffer(GL_ARRAY_BUFFER, _id);
    glBufferData(GL_ARRAY_BUFFER, data._cursor, buffer, static ? GL_STATIC_DRAW : GL_DYNAMIC_DRAW);
    glBindBuffer(GL_ARRAY_BUFFER, 0);

    malloc.free(buffer);
  }

  void delete() {
    final idPointer = malloc<Uint32>();
    glDeleteBuffers(1, idPointer);
    malloc.free(idPointer);
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
  static const int _float32Size = 4;

  ByteData _data;
  int _cursor = 0;

  BufferBuilder([int initialSize = 64]) : _data = ByteData(initialSize);

  void vec3(Vector3 vec) => float3(vec.x, vec.y, vec.z);
  void float3(double a, double b, double c) {
    _ensureCapacity(_float32Size * 3);

    _data
      ..setFloat32(_cursor + _float32Size * 0, a, Endian.host)
      ..setFloat32(_cursor + _float32Size * 1, b, Endian.host)
      ..setFloat32(_cursor + _float32Size * 2, c, Endian.host);
    _cursor += _float32Size * 3;
  }

  void vec4(Vector4 vec) => float4(vec.x, vec.y, vec.z, vec.w);
  void float4(double a, double b, double c, double d) {
    _ensureCapacity(_float32Size * 4);

    _data
      ..setFloat32(_cursor + _float32Size * 0, a, Endian.host)
      ..setFloat32(_cursor + _float32Size * 1, b, Endian.host)
      ..setFloat32(_cursor + _float32Size * 2, c, Endian.host)
      ..setFloat32(_cursor + _float32Size * 3, d, Endian.host);
    _cursor += _float32Size * 4;
  }

  void rewind() {
    _cursor = 0;
  }

  int elements(int vertexSizeInBytes) => _cursor ~/ vertexSizeInBytes;

  void _ensureCapacity(int bytes) {
    if (_cursor + bytes <= _data.lengthInBytes) return;

    print(
        "Growing BufferBuilder $hashCode from ${_data.lengthInBytes} to ${_data.lengthInBytes * 2} bytes to fit ${_cursor + bytes}");

    final newData = ByteData(_data.lengthInBytes * 2);
    newData.buffer.asUint8List().setRange(0, _data.lengthInBytes, _data.buffer.asUint8List());
    _data = newData;
  }
}
