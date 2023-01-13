import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:glfw/glfw.dart';
import 'package:opengl/opengl.dart';
import 'package:vector_math/vector_math.dart';

import 'gl/debug.dart';
import 'gl/shader.dart';
import 'gl/vertex_buffer.dart';
import 'gl/vertex_descriptor.dart';
import 'text.dart';
import 'window.dart';

typedef GLFWerrorfun = Void Function(Int32, Pointer<Utf8>);

bool _running = true;

late final Window _window;

void onGlfwError(int errorCode, Pointer<Utf8> description) {
  print("GLFW Error: ${description.toDartString()} ($errorCode)");
}

void main(List<String> args) {
  DynamicLibrary.open("resources/lib/libglfw.so.3");

  if (glfwInit() != GLFW_TRUE) {
    print("GLFW init failed");
    exit(-1);
  }

  glfwSetErrorCallback(Pointer.fromFunction<GLFWerrorfun>(onGlfwError));

  _window = Window(800, 400, "this is cursed", debug: true);

  glfwMakeContextCurrent(_window.handle);
  attachGlErrorCallback();

  final program = GlProgram([
    GlShader.vertex(File("resources/shader/position.vert")),
    GlShader.fragment(File("resources/shader/position.frag")),
  ]);

  final textProgram = GlProgram([
    GlShader.vertex(File("resources/shader/text.vert")),
    GlShader.fragment(File("resources/shader/text.frag")),
  ]);

  final projection = makeOrthographicMatrix(0, _window.width.toDouble(), _window.height.toDouble(), 0, 0, 1000);

  _window.onResize.listen((event) {
    glViewport(0, 0, event.width, event.height);
    setOrthographicMatrix(projection, 0, event.width.toDouble(), event.height.toDouble(), 0, 0, 1000);
  });

  final triangle = VertexRenderObject(HsvVertexBuilder.descriptor, program);

  textProgram.use();
  program.uniform3f("uTextColor", 1, 0, 1);

  double lastTime = glfwGetTime();
  int frames = 0;
  int lastFps = 0;
  double passedTime = 0;
  glfwSwapInterval(0);

  double triX = -100;
  double triY = -100;

  initTextRenderer();
  _nextCursor();

  _window.onKey.where((event) => event.action == GLFW_PRESS).map((event) => event.key).listen((key) {
    if (key == GLFW_KEY_ESCAPE) _running = false;
    if (key == GLFW_KEY_F11) _window.toggleFullscreen();
    if (key == GLFW_KEY_SPACE) _nextCursor();
  });

  _window.onChar.map(String.fromCharCode).listen((char) {
    print("got char: $char");
  });

  final notSoGood = "bruv, that's not so good !=".toVisual().shape();
  while (_running && glfwWindowShouldClose(_window.handle) != GLFW_TRUE) {
    glClearColor(0, 0, 0, 0);
    glClear(GL_COLOR_BUFFER_BIT);

    final hue = (DateTime.now().millisecondsSinceEpoch % 5000) / 5000;

    final delta = glfwGetTime() - lastTime;
    lastTime = glfwGetTime();

    triX += (_window.cursorX - triX - 100) * delta * 7.5;
    triY += (_window.cursorY - triY - 100) * delta * 7.5;

    final transform = Matrix4.translation(Vector3(triX, triY, 0));

    program.use();
    program.uniformMat4("uTransform", transform);
    program.uniformMat4("uProjection", projection);

    triangle.builder
      ..reset()
      ..vertex(Vector3(0, 200, 0), Vector4(hue, 1, 1, 1))
      ..vertex(Vector3(200, 200, 0), Vector4(hue + 1 / 3, 1, 1, 1))
      ..vertex(Vector3(100, 0, 0), Vector4(hue, 1, 1, 1));

    triangle
      ..upload()
      ..draw();

    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    drawText(100, 100, .75, notSoGood, textProgram, projection, Vector3.all(1));

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

extension CString on String {
  T withAsNative<T>(T Function(Pointer<Utf8>) action) {
    final pointer = toNativeUtf8();
    final result = action(pointer);
    malloc.free(pointer);

    return result;
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

void _nextCursor() {
  if (_currentCursor != null) {
    glfwDestroyCursor(_currentCursor!);
  }

  _nextCursorIndex = (_nextCursorIndex + 1) % _allCursors.length;
  _currentCursor = glfwCreateStandardCursor(_allCursors[_nextCursorIndex]);

  glfwSetCursor(_window.handle, _currentCursor!);
}

String actionString(int action) {
  if (action == GLFW_PRESS) return "PRESS";
  if (action == GLFW_RELEASE) return "RELEASE";
  if (action == GLFW_REPEAT) return "REPEAT";

  return "UNKNOWN";
}
