import 'dart:ffi';
import 'dart:typed_data';

import 'package:dart_opengl/dart_opengl.dart';
import 'package:ffi/ffi.dart';
import 'package:logging/logging.dart';
import 'package:vector_math/vector_math.dart';

import '../cutesy.dart';
import 'shader.dart';
import 'vertex_descriptor.dart';

class MeshBuffer<VF extends Function> {
  final GlVertexBuffer _vbo = GlVertexBuffer();
  final GlVertexArray _vao = GlVertexArray();

  final BufferWriter _buffer;
  final VertexDescriptor _descriptor;

  final GlProgram program;
  late final VF vertex;

  MeshBuffer(VertexDescriptor<VF> descriptor, this.program, {int initialBufferSize = 1024})
      : _descriptor = descriptor,
        _buffer = BufferWriter(initialBufferSize) {
    _vbo.bind();
    _vao.bind();

    descriptor.prepareAttributes(program.getAttributeLocation);

    _vao.unbind();
    _vbo.unbind();

    vertex = descriptor.createBuilder(_buffer);
  }

  void upload({bool dynamic = false}) {
    _vbo.upload(_buffer, dynamic: dynamic);
  }

  void clear() {
    _buffer.rewind();
  }

  void draw() {
    _vao.draw(_buffer._cursor ~/ _descriptor.vertexSize);
  }

  void delete() {
    _vbo.delete();
    _vao.delete();
  }
}

class GlVertexBuffer {
  late final int _id;
  int _vboSize = 0;

  GlVertexBuffer() {
    final idPointer = malloc<UnsignedInt>();
    gl.genBuffers(1, idPointer);
    _id = idPointer.value;
    malloc.free(idPointer);
  }

  void bind() {
    gl.bindBuffer(glArrayBuffer, _id);
  }

  void unbind() {
    gl.bindBuffer(glArrayBuffer, 0);
  }

  void upload(BufferWriter data, {bool dynamic = false}) {
    final bytes = data._data.buffer.asUint8List();

    final buffer = malloc<Uint8>(data._cursor);
    buffer.asTypedList(data._cursor).setRange(0, data._cursor, bytes);

    gl.bindBuffer(glArrayBuffer, _id);

    if (data._cursor > _vboSize) {
      gl.bufferData(glArrayBuffer, data._cursor, buffer.cast(), dynamic ? glDynamicDraw : glStaticDraw);
      _vboSize = data._cursor;
    } else {
      gl.bufferSubData(glArrayBuffer, 0, data._cursor, buffer.cast());
    }

    gl.bindBuffer(glArrayBuffer, 0);

    malloc.free(buffer);
  }

  void delete() {
    final idPointer = malloc<UnsignedInt>();
    idPointer[0] = _id;
    gl.deleteBuffers(1, idPointer);
    malloc.free(idPointer);
  }
}

class GlVertexArray {
  late final int _id;

  GlVertexArray() {
    final idPointer = calloc<UnsignedInt>();
    gl.genVertexArrays(1, idPointer);
    _id = idPointer.value;
  }

  void draw(int count) {
    bind();
    gl.drawArrays(glTriangles, 0, count);
    unbind();
  }

  void bind() {
    gl.bindVertexArray(_id);
  }

  void unbind() {
    gl.bindVertexArray(0);
  }

  void delete() {
    final idPointer = malloc<UnsignedInt>();
    idPointer[0] = _id;
    gl.deleteVertexArrays(1, idPointer);
    malloc.free(idPointer);
  }
}

class BufferWriter {
  static final Logger _logger = Logger("cutesy.buffer_writer");
  static const int _float32Size = 4;

  ByteData _data;
  int _cursor = 0;

  BufferWriter([int initialSize = 64]) : _data = ByteData(initialSize);

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

    _logger.fine(
      "Growing BufferWriter $hashCode from ${_data.lengthInBytes} to ${_data.lengthInBytes * 2} bytes to fit ${_cursor + bytes}",
    );

    final newData = ByteData(_data.lengthInBytes * 2);
    newData.buffer.asUint8List().setRange(0, _data.lengthInBytes, _data.buffer.asUint8List());
    _data = newData;
  }
}
