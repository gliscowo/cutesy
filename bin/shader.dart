import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:opengl/opengl.dart';
import 'package:path/path.dart';

import 'cutesy.dart';

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
  final int _id;
  late final SubscriptSupplier<String, int> _attribs;
  late final SubscriptSupplier<String, int> _uniforms;

  GlProgram(List<GlShader> shaders) : _id = glCreateProgram() {
    for (final shader in shaders) {
      glAttachShader(_id, shader.id);
    }

    glLinkProgram(_id);

    for (final shader in shaders) {
      glDeleteShader(shader.id);
    }

    malloc.withAlloc<Int32>((success) {
      glGetProgramiv(_id, GL_LINK_STATUS, success);
      print("Program '$_id' link success: ${success.value}");
    }, sizeOf<Int32>());

    _attribs = SubscriptSupplier._((String name) => glGetAttribLocation(_id, name.toNativeUtf8()));
    _uniforms = SubscriptSupplier._((String name) => glGetUniformLocation(_id, name.toNativeUtf8()));
  }

  SubscriptSupplier get attribs => _attribs;
  SubscriptSupplier get uniforms => _uniforms;
  int get id => _id;

  void use() => glUseProgram(_id);
}

class SubscriptSupplier<T, U> {
  final U Function(T) _getter;
  SubscriptSupplier._(this._getter);

  U operator [](T query) => _getter(query);
}
