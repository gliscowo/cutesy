import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:glfw/glfw.dart';
import 'package:logging/logging.dart';
import 'package:opengl/opengl.dart';
import 'package:vector_math/vector_math.dart';

import 'color.dart';
import 'gl/debug.dart';
import 'gl/shader.dart';
import 'gl/vertex_buffer.dart';
import 'gl/vertex_descriptor.dart';
import 'text/text.dart';
import 'text/text_renderer.dart';
import 'window.dart';

typedef GLFWerrorfun = Void Function(Int32, Pointer<Utf8>);

bool _running = true;

late final Window _window;

final Logger _logger = Logger("cutesy");
final Logger _glfwLogger = Logger("cutesy.glfw");

void main(List<String> args) {
  Logger.root.level = Level.FINE;
  Logger.root.onRecord.listen((event) {
    print("[${event.loggerName}] (${event.level.toString().toLowerCase()}) ${event.message}");
  });

  DynamicLibrary.open("resources/lib/libglfw.so.3");

  if (glfwInit() != GLFW_TRUE) {
    _logger.severe("GLFW init failed");
    exit(-1);
  }

  glfwSetErrorCallback(Pointer.fromFunction<GLFWerrorfun>(onGlfwError));

  _window = Window(800, 400, "this is cursed", debug: true);

  glfwMakeContextCurrent(_window.handle);
  attachGlErrorCallback();

  final posColorProgram = GlProgram([
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

  final triangle = VertexRenderObject(posColorVertexDescriptor, posColorProgram);

  textProgram.use();
  posColorProgram.uniform3f("uTextColor", 1, 0, 1);

  double lastTime = glfwGetTime();
  int frames = 0;
  int lastFps = 0;
  double passedTime = 0;
  glfwSwapInterval(0);

  double triX = -100;
  double triY = -100;

  final font = FontFamily("CascadiaCode", 36);
  _nextCursor();

  _window.onKey.where((event) => event.action == GLFW_PRESS).map((event) => event.key).listen((key) {
    if (key == GLFW_KEY_ESCAPE) _running = false;
    if (key == GLFW_KEY_F11) _window.toggleFullscreen();
    if (key == GLFW_KEY_SPACE) _nextCursor();
  });

  _window.onChar.map(String.fromCharCode).listen((char) {
    _logger.info("got char: $char");
  });

  final notSoGood = Text([
    StyledString("now, that's "),
    StyledString("some pretty ", style: TextStyle(bold: true)),
    StyledString("epic ", style: TextStyle(italic: true, color: Color.ofHsv(220 / 360, .65, 1))),
    StyledString("text", style: TextStyle(bold: true, italic: true)),
  ])
    ..shape(font);
  while (_running && glfwWindowShouldClose(_window.handle) != GLFW_TRUE) {
    glClearColor(0, 0, 0, 0);
    glClear(GL_COLOR_BUFFER_BIT);

    final hue = (lastTime / 5) % 1;
    final delta = glfwGetTime() - lastTime;
    lastTime = glfwGetTime();

    triX += (_window.cursorX - triX - 100) * delta * 7.5;
    triY += (_window.cursorY - triY - 100) * delta * 7.5;

    posColorProgram
      ..use()
      ..uniformMat4("uTransform", Matrix4.translation(Vector3(triX, triY, 0)))
      ..uniformMat4("uProjection", projection);

    triangle
      ..clear()
      ..vertex(Vector3(0, 200, 0), Vector4(hue, 1, 1, 1))
      ..vertex(Vector3(200, 200, 0), Vector4(hue + 1 / 3, 1, 1, 1))
      ..vertex(Vector3(100, 0, 0), Vector4(hue, 1, 1, 1))
      ..upload(dynamic: true)
      ..draw();

    drawText(50, 100, .75, notSoGood, textProgram, projection, Vector3.all(1));
    drawText(2, 0, .5, Text.string("$lastFps FPS")..shape(font), textProgram, projection, Vector3.all(1));

    _window.nextFrame();

    if (passedTime >= 1) {
      lastFps = frames;
      frames = 0;
      passedTime = 0;

      _logger.fine("$lastFps FPS");
    }

    passedTime += delta;
    frames++;
  }

  glfwTerminate();
}

void onGlfwError(int errorCode, Pointer<Utf8> description) {
  _glfwLogger.severe("GLFW Error: ${description.toDartString()} ($errorCode)");
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
