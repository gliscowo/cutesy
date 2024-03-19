import 'dart:ffi';
import 'dart:typed_data';

import 'package:dart_opengl/dart_opengl.dart';
import 'package:ffi/ffi.dart';
import 'package:logging/logging.dart';

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
    malloc.free(_buffer._pointer);
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
    gl.bindBuffer(glArrayBuffer, _id);

    if (data._cursor > _vboSize) {
      gl.bufferData(glArrayBuffer, data._cursor, data._pointer.cast(), dynamic ? glDynamicDraw : glStaticDraw);
      _vboSize = data._cursor;
    } else {
      gl.bufferSubData(glArrayBuffer, 0, data._cursor, data._pointer.cast());
    }

    gl.bindBuffer(glArrayBuffer, 0);
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
  static const int _float32Size = Float32List.bytesPerElement;

  late ByteData _data;
  late Pointer<Uint8> _pointer;
  int _cursor = 0;

  BufferWriter([int initialSize = 64]) {
    _pointer = malloc<Uint8>(initialSize);
    _data = _pointer.asTypedList(initialSize).buffer.asByteData();
  }

  void float2(double a, double b) {
    _ensureCapacity(_float32Size * 2);

    _data
      ..setFloat32(_cursor + _float32Size * 0, a, Endian.host)
      ..setFloat32(_cursor + _float32Size * 1, b, Endian.host);
    _cursor += _float32Size * 2;
  }

  void float3(double a, double b, double c) {
    _ensureCapacity(_float32Size * 3);

    _data
      ..setFloat32(_cursor + _float32Size * 0, a, Endian.host)
      ..setFloat32(_cursor + _float32Size * 1, b, Endian.host)
      ..setFloat32(_cursor + _float32Size * 2, c, Endian.host);
    _cursor += _float32Size * 3;
  }

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

    final newPointer = malloc<Uint8>(_data.lengthInBytes * 2);
    newPointer.asTypedList(_data.lengthInBytes * 2).setRange(0, _data.lengthInBytes, _data.buffer.asUint8List());
    malloc.free(_pointer);
    _pointer = newPointer;
    _data = _pointer.asTypedList(_data.lengthInBytes * 2).buffer.asByteData();
  }
}
