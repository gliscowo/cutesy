import 'dart:ffi';
import 'dart:io';

import 'package:dart_opengl/dart_opengl.dart';
import 'package:ffi/ffi.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart';
import 'package:vector_math/vector_math.dart';

import '../cutesy.dart';

final Logger _logger = Logger("cutesy.shader_compiler");

class GlShader {
  final int _id;

  GlShader.vertex(File source) : _id = gl.createShader(glVertexShader) {
    _loadAndCompile(source);
  }

  GlShader.fragment(File source) : _id = gl.createShader(glFragmentShader) {
    _loadAndCompile(source);
  }

  int get id => _id;

  void _loadAndCompile(File source) {
    final sourceString = source.readAsStringSync().toNativeUtf8();

    final sourceArray = malloc<Pointer<Utf8>>();
    sourceArray[0] = sourceString;

    gl.shaderSource(_id, 1, sourceArray.cast(), nullptr);
    gl.compileShader(_id);

    final success = malloc<Int>();
    gl.getShaderiv(_id, glCompileStatus, success);
    _logger.info("Shader '${basename(source.path)}' compile success: ${success.value}");

    if (success.value != glTrue) {
      final logLength = malloc<Int>();
      gl.getShaderiv(_id, glInfoLogLength, logLength);

      final log = malloc<Char>(logLength.value);
      gl.getShaderInfoLog(_id, logLength.value, nullptr, log);
      _logger.severe("Error: ${log.cast<Utf8>().toDartString()}");

      malloc.free(logLength);
      malloc.free(log);
    }

    malloc.free(sourceString);
    malloc.free(sourceArray);
    malloc.free(success);
  }
}

class GlProgram {
  static final Pointer<Float> _floatBuffer = malloc<Float>(16);
  // static final Pointer<Int> _intBuffer = malloc<Float>(16);

  final int _id;
  final String name;
  final Map<String, int> _uniformCache = {};

  GlProgram.vertexFragment(String name, String vertex, String fragment)
      : this(name, [
          GlShader.vertex(File("resources/shader/$vertex.vert")),
          GlShader.fragment(File("resources/shader/$fragment.frag"))
        ]);

  GlProgram(this.name, List<GlShader> shaders) : _id = gl.createProgram() {
    for (final shader in shaders) {
      gl.attachShader(_id, shader.id);
    }

    gl.linkProgram(_id);

    for (final shader in shaders) {
      gl.deleteShader(shader.id);
    }

    final success = malloc<Int>();
    gl.getProgramiv(_id, glLinkStatus, success);
    _logger.info("Program '$name' link success: ${success.value}");

    if (success.value != glTrue) {
      final logLength = malloc<Int>();
      gl.getProgramiv(_id, glInfoLogLength, logLength);

      final log = malloc<Char>(logLength.value);
      gl.getProgramInfoLog(_id, logLength.value, nullptr, log);
      _logger.severe("Error: ${log.cast<Utf8>().toDartString()}");

      malloc.free(logLength);
      malloc.free(log);
    }

    malloc.free(success);
  }

  int get id => _id;
  void use() => gl.useProgram(_id);

  void uniformMat4(String uniform, Matrix4 value) {
    _floatBuffer.asTypedList(value.storage.length).setRange(0, value.storage.length, value.storage);
    gl.programUniformMatrix4fv(_id, _uniformLocation(uniform), 1, glFalse, _floatBuffer);
  }

  void uniform1f(String uniform, double value) {
    gl.programUniform1f(_id, _uniformLocation(uniform), value);
  }

  void uniform2vf(String uniform, Vector2 vec) => uniform2f(uniform, vec.x, vec.y);
  void uniform2f(String uniform, double x, double y) {
    gl.programUniform2f(_id, _uniformLocation(uniform), x, y);
  }

  void uniform3vf(String uniform, Vector3 vec) => uniform3f(uniform, vec.x, vec.y, vec.z);
  void uniform3f(String uniform, double x, double y, double z) {
    gl.programUniform3f(_id, _uniformLocation(uniform), x, y, z);
  }

  void uniformSampler(String uniform, int texture, int index) {
    gl.programUniform1i(_id, _uniformLocation(uniform), index);
    gl.bindTextureUnit(0, texture);
  }

  int _uniformLocation(String uniform) =>
      _uniformCache.putIfAbsent(uniform, () => uniform.withAsNative((utf8) => gl.getUniformLocation(_id, utf8.cast())));

  int getAttributeLocation(String attibute) => attibute.withAsNative((utf8) => gl.getAttribLocation(_id, utf8.cast()));
}
