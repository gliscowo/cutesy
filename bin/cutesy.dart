import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:glfw/glfw.dart';
import 'package:opengl/opengl.dart';
import 'package:vector_math/vector_math_64.dart';

import 'shader.dart';
import 'text.dart';
import 'vertex.dart';
import 'window.dart';

typedef GLFWkeyfun = Void Function(Pointer<GLFWwindow>, Int32, Int32, Int32, Int32);
typedef GLFWcharfun = Void Function(Pointer<GLFWwindow>, Int32);
typedef GLFWcursorposfun = Void Function(Pointer<GLFWwindow>, Double, Double);
typedef GLFWerrorfun = Void Function(Int32, Pointer<Utf8>);

typedef GlErrorCallback = Void Function(Int32, Int32, Int32, Int32, Int32, Pointer<Utf8>, Pointer<Void>);

bool _running = true;

double mouseX = 0;
double mouseY = 0;

late final Window _window;

void onGlfwError(int errorCode, Pointer<Utf8> description) {
  print("GLFW Error: ${description.toDartString()} ($errorCode)");
}

void onGlError(int source, int type, int id, int severity, int length, Pointer<Utf8> message, Pointer<Void> userParam) {
  print(
      "OpenGL Debug Message, type ${messageTypeString(type)} severity ${severityString(severity)}: ${message.toDartString()}");
}

void main(List<String> args) {
  DynamicLibrary.open("resources/lib/libglfw.so.3");

  if (glfwInit() != GLFW_TRUE) {
    print("GLFW init failed");
    exit(-1);
  }

  glfwSetErrorCallback(Pointer.fromFunction<GLFWerrorfun>(onGlfwError));

  _window = Window(800, 400, "this is cursed", debug: true);

  glfwSetKeyCallback(_window.handle, Pointer.fromFunction<GLFWkeyfun>(onKey));
  glfwSetCharCallback(_window.handle, Pointer.fromFunction<GLFWcharfun>(onChar));
  glfwSetCursorPosCallback(_window.handle, Pointer.fromFunction<GLFWcursorposfun>(onCursorPos));

  glfwMakeContextCurrent(_window.handle);

  glEnable(GL_DEBUG_OUTPUT);
  glEnable(GL_DEBUG_OUTPUT_SYNCHRONOUS);
  glDebugMessageCallback(Pointer.fromFunction<GlErrorCallback>(onGlError), nullptr);

  final program = GlProgram([
    GlShader.vertex(File("resources/shader/position.vert")),
    GlShader.fragment(File("resources/shader/position.frag")),
  ]);

  final projectionLocation = program.uniforms["uProjection"];
  final transformLocation = program.uniforms["uTransform"];

  final textProgram = GlProgram([
    GlShader.vertex(File("resources/shader/text.vert")),
    GlShader.fragment(File("resources/shader/text.frag")),
  ]);

  final projection = makeOrthographicMatrix(0, _window.width.toDouble(), _window.height.toDouble(), 0, 0, 1000);

  _window.onResize.listen((event) {
    glViewport(0, 0, event.width, event.height);
    setOrthographicMatrix(projection, 0, event.width.toDouble(), event.height.toDouble(), 0, 0, 1000);
  });

  final triangleBuffer = BufferBuilder();
  final triangle = GlVertexBuffer()..bind();
  final triangleVao = GlVertexArray()..bind();
  glEnableVertexAttribArray(program.attribs["aPos"]);
  glVertexAttribPointer(program.attribs["aPos"], 3, GL_FLOAT, GL_FALSE, 7 * sizeOf<Float>(), 0);
  glEnableVertexAttribArray(program.attribs["aColor"]);
  glVertexAttribPointer(program.attribs["aColor"], 4, GL_FLOAT, GL_FALSE, 7 * sizeOf<Float>(), 3 * sizeOf<Float>());

  final aaaa = GlVertexBuffer()..bind();
  final aaaaVao = GlVertexArray()..bind();
  glEnableVertexAttribArray(textProgram.attribs["aVertex"]);
  glVertexAttribPointer(textProgram.attribs["aVertex"], 4, GL_FLOAT, GL_FALSE, 4 * sizeOf<Float>(), 0);

  textProgram.use();
  glUniform3f(textProgram.uniforms["uTextColor"], 1, 0, 1);

  double lastTime = glfwGetTime();
  int frames = 0;
  int lastFps = 0;
  double passedTime = 0;
  glfwSwapInterval(0);

  double triX = -100;
  double triY = -100;

  initTextRenderer();
  updateCursor();

  final notSoGood = "bruv, that's not so good !=".toVisual().shape();
  while (_running && glfwWindowShouldClose(_window.handle) != GLFW_TRUE) {
    glClearColor(0, 0, 0, 0);
    glClear(GL_COLOR_BUFFER_BIT);

    final hue = (DateTime.now().millisecondsSinceEpoch % 5000) / 5000;

    final delta = glfwGetTime() - lastTime;
    lastTime = glfwGetTime();

    triX += (mouseX - triX - 100) * delta * 7.5;
    triY += (mouseY - triY - 100) * delta * 7.5;

    final transform = Matrix4.translation(Vector3(triX, triY, 0));
    var data = Float32List.fromList(transform.storage);

    final buffer = malloc.allocate<Float>(data.lengthInBytes);
    buffer.asTypedList(data.length).setRange(0, data.length, data);

    program.use();
    glUniformMatrix4fv(transformLocation, 1, GL_FALSE, buffer);

    data = Float32List.fromList(projection.storage);
    buffer.asTypedList(data.length).setRange(0, data.length, data);

    glUniformMatrix4fv(projectionLocation, 1, GL_FALSE, buffer);

    triangle
      ..upload(triangleBuffer
        ..rewind()
        ..float3(0, 200, 0)
        ..float4(hue, 1, 1, 1)
        ..float3(200, 200, 0)
        ..float4(hue + 1 / 3, 1, 1, 1)
        ..float3(100, 0, 0)
        ..float4(hue, 1, 1, 1))
      ..draw(triangleBuffer.elements(sizeOf<Float>() * 7), vao: triangleVao);

    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    drawText(100, 100, .75, notSoGood, textProgram, aaaa, aaaaVao, projection, Vector3.all(1));

    // final fpsBuffer = "turns out the bee movie script is too long".toVisual().shape();
    // drawText(2, 0, .5, fpsBuffer, textProgram, aaaa, aaaaVao, projection, Vector3.all(1));
    // fpsBuffer.destroy();

    _window.nextFrame();

    if (passedTime >= 1) {
      lastFps = frames;
      frames = 0;
      passedTime = 0;

      print("$lastFps FPS");
    }

    passedTime += delta;
    frames++;
  }

  glfwTerminate();
}

extension Based on Allocator {
  void withAlloc<T extends NativeType>(void Function(Pointer<T>) action, int size, [int count = 1]) {
    final pointer = allocate<T>(size * count);
    action(pointer);
    free(pointer);
  }
}

int _nextCursorIndex = -1;
const _allCursors = [
  GLFW_ARROW_CURSOR,
  GLFW_IBEAM_CURSOR,
  GLFW_CROSSHAIR_CURSOR,
  GLFW_HAND_CURSOR,
  GLFW_HRESIZE_CURSOR,
  GLFW_VRESIZE_CURSOR
];

Pointer<GLFWcursor>? _currentCursor;

void updateCursor() {
  if (_currentCursor != null) {
    glfwDestroyCursor(_currentCursor!);
  }

  _nextCursorIndex = (_nextCursorIndex + 1) % _allCursors.length;
  _currentCursor = glfwCreateStandardCursor(_allCursors[_nextCursorIndex]);

  glfwSetCursor(_window.handle, _currentCursor!);
}

void onKey(Pointer<GLFWwindow> window, int key, int scancode, int action, int mods) {
  if (key == GLFW_KEY_ESCAPE) {
    _running = false;
  }

  if (key == GLFW_KEY_F11 && action == GLFW_PRESS) {
    _window.toggleFullscreen();
  }

  if (key == GLFW_KEY_SPACE && action == GLFW_PRESS) {
    updateCursor();
  }

  print(
      "Key input on window 0x${window.address.toRadixString(16)}:\n - key: $key\n - scancode: $scancode\n - action: ${actionString(action)}\n - mods: $mods");
}

void onChar(Pointer<GLFWwindow> window, int codepoint) {
  print("Char input on window 0x${window.address.toRadixString(16)}: '${String.fromCharCode(codepoint)}'");
}

void onCursorPos(Pointer<GLFWwindow> window, double cursorX, double cursorY) {
  mouseX = cursorX;
  mouseY = cursorY;
}

String actionString(int action) {
  if (action == GLFW_PRESS) return "PRESS";
  if (action == GLFW_RELEASE) return "RELEASE";
  if (action == GLFW_REPEAT) return "REPEAT";

  return "UNKNOWN";
}

String severityString(int severity) {
  if (severity == GL_DEBUG_SEVERITY_NOTIFICATION) return "NOTIFICATION";
  if (severity == GL_DEBUG_SEVERITY_LOW) return "LOW";
  if (severity == GL_DEBUG_SEVERITY_MEDIUM) return "MEDIUM";
  if (severity == GL_DEBUG_SEVERITY_HIGH) return "HIGH";

  return "UNKNOWN";
}

String messageTypeString(int messageType) {
  if (messageType == GL_DEBUG_TYPE_MARKER) return "MARKER";
  if (messageType == GL_DEBUG_TYPE_DEPRECATED_BEHAVIOR) return "DEPRECATED_BEHAVIOR";
  if (messageType == GL_DEBUG_TYPE_ERROR) return "ERROR";
  if (messageType == GL_DEBUG_TYPE_OTHER) return "OTHER";
  if (messageType == GL_DEBUG_TYPE_PERFORMANCE) return "PERFORMANCE";
  if (messageType == GL_DEBUG_TYPE_PORTABILITY) return "PORTABILITY";
  if (messageType == GL_DEBUG_TYPE_PUSH_GROUP) return "PUSH_GROUP";
  if (messageType == GL_DEBUG_TYPE_POP_GROUP) return "POP_GROUP";

  return "UNKNOWN";
}
