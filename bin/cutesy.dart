import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math';

import 'package:dart_glfw/dart_glfw.dart';
import 'package:dart_opengl/dart_opengl.dart';
import 'package:ffi/ffi.dart' as ffi;
import 'package:logging/logging.dart';
import 'package:vector_math/vector_math.dart';

import 'color.dart';
import 'context.dart';
import 'gl/debug.dart';
import 'gl/shader.dart';
import 'gl/vertex_buffer.dart';
import 'gl/vertex_descriptor.dart';
import 'primitive_renderer.dart';
import 'text/text.dart';
import 'text/text_renderer.dart';
import 'ui/component.dart';
import 'ui/components/button.dart';
import 'ui/components/label.dart';
import 'ui/components/slider.dart';
import 'ui/components/text_field.dart';
import 'ui/containers/flow_layout.dart';
import 'ui/insets.dart';
import 'ui/inspector.dart';
import 'ui/sizing.dart';
import 'ui/surface.dart';
import 'ui/ui_controller.dart';
import 'window.dart';

typedef GLFWerrorfun = ffi.Void Function(ffi.Int, ffi.Pointer<ffi.Char>);

bool _running = true;

late final Window _window;

final Logger _logger = Logger("cutesy");
final Logger _glfwLogger = Logger("cutesy.glfw");

final gl = loadOpenGL();
final glfw = loadGLFW("resources/lib/libglfw.so.3");

void main(List<String> args) {
  Logger.root.level = Level.FINE;
  Logger.root.onRecord.listen((event) {
    print("[${event.loggerName}] (${event.level.toString().toLowerCase()}) ${event.message}");
  });

  if (glfw.init() != glfwTrue) {
    _logger.severe("GLFW init failed");
    exit(-1);
  }

  glfw.setErrorCallback(ffi.Pointer.fromFunction<GLFWerrorfun>(onGlfwError));

  _window = Window(800, 450, "cutesy", debug: true);

  glfw.makeContextCurrent(_window.handle);
  attachGlErrorCallback();

  final projection = makeOrthographicMatrix(0, _window.width.toDouble(), _window.height.toDouble(), 0, 0, 1000);

  _window.onResize.listen((event) {
    gl.viewport(0, 0, event.width, event.height);
    setOrthographicMatrix(projection, 0, event.width.toDouble(), event.height.toDouble(), 0, 0, 1000);
  });

  final nunito = FontFamily("Nunito", 30);
  final cascadia = FontFamily("CascadiaCode", 20);

  _window.onKey.where((event) => event.action == glfwPress).map((event) => event.key).listen((key) {
    if (key == glfwKeyEscape) _running = false;
    if (key == glfwKeyF11) _window.toggleFullscreen();
  });

  bool inspector = false;
  _window.onKey.where((event) => event.action == glfwPress).listen((event) {
    if (event.key != glfwKeyLeftShift || (event.mods & glfwModControl) == 0) return;
    inspector = !inspector;
  });

  _window.onChar.map(String.fromCharCode).listen((char) {
    _logger.info("got char: $char");
  });

  double lastTime = glfw.getTime();
  int frames = 0;
  int lastFps = 0;
  double passedTime = 0;
  glfw.swapInterval(0);

  final renderContext = RenderContext(_window, [
    GlProgram.vertexFragment("hsv", "position", "hsv"),
    GlProgram.vertexFragment("pos_color", "position", "position"),
    GlProgram.vertexFragment("text", "text", "text"),
    GlProgram.vertexFragment("rounded_rect", "position", "rounded"),
    GlProgram.vertexFragment("rounded_rect_outline", "position", "rounded_outline"),
    GlProgram.vertexFragment("circle", "position", "circle"),
    GlProgram.vertexFragment("blur", "position", "blur"),
  ]);

  final primitiveRenderer = ImmediatePrimitiveRenderer(renderContext);
  final textRenderer = TextRenderer(renderContext, nunito, {"Nunito": nunito, "CascadiaCode": cascadia});

  final ui = UIController.ofWindow(
    _window,
    textRenderer,
    (horizontal, vertical) => FlowLayout.vertical()
      ..horizontalSizing(horizontal)
      ..verticalSizing(vertical),
  );

  var showGraph = false;
  var hue = 0.0, sat = 0.0, value = 0.0;

  ui.root
    ..addChild(FlowLayout.horizontal()
      ..addChild(Button(Text.string("Button", style: TextStyle(bold: true)), (p0) => _logger.info("button 1"))
        ..id = "Button 1")
      ..addChild(Button(Text.string("Button 2", style: TextStyle(bold: true)), (p0) {
        _logger.info("button 2");
        showGraph = !showGraph;
      })
        ..id = "Button 2")
      ..addChild(FlowLayout.vertical()
        ..addChild(Label(Text.string("AAA"))
          ..color(Color.black)
          ..verticalTextAlignment = VerticalAlignment.center
          ..horizontalTextAlignment = HorizontalAlignment.center
          ..scale = .75)
        ..addChild(Button(Text.string("hmmm"), (_) {})))
      ..addChild(TextField()
        ..id = "text-field"
        ..verticalSizing(Sizing.fixed(50))
        ..horizontalSizing(Sizing.fixed(750)))
      ..padding(Insets.all(10))
      ..gap(5)
      ..surface = Surfaces.flat(Color.rgb(0, 0, 0, .5)))
    ..addChild(FlowLayout.horizontal()
      ..addChild(Label(Text.string("Hue")))
      ..addChild(Slider()..listener = (p0) => hue = p0))
    ..addChild(FlowLayout.horizontal()
      ..addChild(Label(Text.string("Saturation")))
      ..addChild(Slider()..listener = (p0) => sat = p0))
    ..addChild(FlowLayout.horizontal()
      ..addChild(Label(Text.string("Value")))
      ..addChild(Slider()..listener = (p0) => value = p0))
    ..gap(25)
    ..horizontalAlignment(HorizontalAlignment.center)
    ..verticalAlignment(VerticalAlignment.center);

  ui.inflateAndMount();

  final frameMesh = MeshBuffer(posColorVertexDescriptor, renderContext.findProgram("pos_color"));
  final fps = <int>[];

  while (_running && glfw.windowShouldClose(_window.handle) != glfwTrue) {
    var clearColor = Color.ofHsv(hue, sat, value);

    gl.clearColor(clearColor.r, clearColor.g, clearColor.b, 0);
    gl.clear(glColorBufferBit);
    gl.enable(glBlend);

    final delta = glfw.getTime() - lastTime;
    lastTime = glfw.getTime();

    textRenderer.drawText(5, 5, Text.string("$lastFps FPS", style: TextStyle(fontFamily: "CascadiaCode")), projection,
        color: Color.black, scale: .75);

    textRenderer.drawText(
      5,
      25,
      Text.string("${(delta * 1000).toStringAsPrecision(2)} ms", style: TextStyle(fontFamily: "CascadiaCode")),
      projection,
      color: Color.black,
      scale: .75,
    );

    final drawContext = DrawContext(renderContext, primitiveRenderer, projection, textRenderer);
    ui.render(drawContext, delta);

    if (inspector) {
      Inspector.drawInspector(drawContext, ui.root, _window.cursorX, _window.cursorY, true);
    }

    if (showGraph) {
      frameMesh.clear();
      primitiveRenderer.buildRect(frameMesh.vertex, 0, _window.height - 100, 200, 1, Color.black);
      for (var (idx, measure) in fps.indexed) {
        final height = (1000 / measure) * 100;
        primitiveRenderer.buildRect(frameMesh.vertex, idx.toDouble() * 2, _window.height - height, 2, height,
            Color.red.interpolate(Color.green, min(1, measure / 1000)));
      }

      gl.blendFunc(glSrcAlpha, glOneMinusSrcAlpha);

      frameMesh.program
        ..use()
        ..uniformMat4("uTransform", Matrix4.identity())
        ..uniformMat4("uProjection", projection);

      frameMesh
        ..upload(dynamic: true)
        ..draw();
    }

    _window.nextFrame();

    if (passedTime >= .1) {
      fps.add(lastFps);
      if (fps.length > 100) fps.removeAt(0);
      lastFps = frames * 10;
      // _logger.fine("${lastFps} FPS");

      frames = 0;
      passedTime = 0;
    }

    passedTime += delta;
    frames++;
  }

  glfw.terminate();
}

void onGlfwError(int errorCode, ffi.Pointer<ffi.Char> description) {
  _glfwLogger.severe("GLFW Error: ${description.cast<ffi.Utf8>().toDartString()} ($errorCode)");
}

extension CString on String {
  T withAsNative<T>(T Function(ffi.Pointer<ffi.Utf8>) action) {
    final pointer = toNativeUtf8();
    final result = action(pointer);
    ffi.malloc.free(pointer);

    return result;
  }
}
