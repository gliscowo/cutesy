import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:opengl/opengl.dart';
import 'package:path/path.dart';
import 'package:vector_math/vector_math_64.dart';

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
    print("Shader '${basename(source.path)}' compile success: ${success.value}");

    malloc.free(sourceArray);
    malloc.free(success);
  }
}

class GlProgram {
  static final Pointer<Float> _floatBuffer = malloc<Float>(16);
  // static final Pointer<Int> _intBuffer = malloc<Float>(16);

  final int _id;
  final Map<String, int> _uniformCache = {};

  GlProgram(List<GlShader> shaders) : _id = glCreateProgram() {
    for (final shader in shaders) {
      glAttachShader(_id, shader.id);
    }

    glLinkProgram(_id);

    for (final shader in shaders) {
      glDeleteShader(shader.id);
    }

    final success = malloc<Int32>();
    glGetProgramiv(_id, GL_LINK_STATUS, success);
    print("Program '$_id' link success: ${success.value}");
    malloc.free(success);
  }

  void use() => glUseProgram(_id);

  void uniformMat4(String uniform, Matrix4 value) {
    final floats = Float32List.fromList(value.storage);
    _floatBuffer.asTypedList(floats.length).setRange(0, floats.length, floats);
    glUniformMatrix4fv(_uniformLocation(uniform), 1, GL_FALSE, _floatBuffer);
  }

  void uniform3vf(String uniform, Vector3 vec) => uniform3f(uniform, vec.x, vec.y, vec.z);
  void uniform3f(String uniform, double x, double y, double z) {
    glUniform3f(_uniformLocation(uniform), x, y, z);
  }

  int _uniformLocation(String uniform) =>
      _uniformCache.putIfAbsent(uniform, () => glGetUniformLocation(_id, uniform.toNativeUtf8()));

  int attributeLocation(String attibute) {
    return glGetAttribLocation(_id, attibute.toNativeUtf8());
  }

  int get id => _id;
}
