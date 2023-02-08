import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:logging/logging.dart';
import 'package:opengl/opengl.dart';
import 'package:path/path.dart';
import 'package:vector_math/vector_math.dart';

import '../cutesy.dart';

final Logger _logger = Logger("cutesy.shader_compiler");

class GlShader {
  final int _id;

  GlShader.vertex(File source) : _id = glCreateShader(GL_VERTEX_SHADER) {
    _loadAndCompile(source);
  }

  GlShader.fragment(File source) : _id = glCreateShader(GL_FRAGMENT_SHADER) {
    _loadAndCompile(source);
  }

  int get id => _id;

  void _loadAndCompile(File source) {
    final sourceString = source.readAsStringSync().toNativeUtf8();

    final sourceArray = malloc<Pointer<Utf8>>();
    sourceArray[0] = sourceString;

    glShaderSource(_id, 1, sourceArray, nullptr);
    glCompileShader(_id);

    final success = malloc<Int32>();
    glGetShaderiv(_id, GL_COMPILE_STATUS, success);
    _logger.info("Shader '${basename(source.path)}' compile success: ${success.value}");

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

  GlProgram(this.name, List<GlShader> shaders) : _id = glCreateProgram() {
    for (final shader in shaders) {
      glAttachShader(_id, shader.id);
    }

    glLinkProgram(_id);

    for (final shader in shaders) {
      glDeleteShader(shader.id);
    }

    final success = malloc<Int32>();
    glGetProgramiv(_id, GL_LINK_STATUS, success);
    _logger.info("Program '$_id' link success: ${success.value}");
    malloc.free(success);
  }

  int get id => _id;
  void use() => glUseProgram(_id);

  void uniformMat4(String uniform, Matrix4 value) {
    _floatBuffer.asTypedList(value.storage.length).setRange(0, value.storage.length, value.storage);
    glUniformMatrix4fv(_uniformLocation(uniform), 1, GL_FALSE, _floatBuffer);
  }

  void uniform1f(String uniform, double value) {
    glUniform1f(_uniformLocation(uniform), value);
  }

  void uniform2vf(String uniform, Vector2 vec) => uniform2f(uniform, vec.x, vec.y);
  void uniform2f(String uniform, double x, double y) {
    glUniform2f(_uniformLocation(uniform), x, y);
  }

  void uniform3vf(String uniform, Vector3 vec) => uniform3f(uniform, vec.x, vec.y, vec.z);
  void uniform3f(String uniform, double x, double y, double z) {
    glUniform3f(_uniformLocation(uniform), x, y, z);
  }

  void uniformSampler(String uniform, int texture, int index) {
    glUniform1i(_uniformLocation(uniform), index);

    glActiveTexture(GL_TEXTURE0 + index);
    glBindTexture(GL_TEXTURE_2D, texture);
  }

  int _uniformLocation(String uniform) =>
      _uniformCache.putIfAbsent(uniform, () => uniform.withAsNative((utf8) => glGetUniformLocation(_id, utf8)));

  int getAttributeLocation(String attibute) => attibute.withAsNative((utf8) => glGetAttribLocation(_id, utf8));
}
