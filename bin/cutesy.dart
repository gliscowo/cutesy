import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:dart_glfw/dart_glfw.dart';
import 'package:dart_opengl/dart_opengl.dart';
import 'package:diamond_gl/diamond_gl.dart';
import 'package:ffi/ffi.dart' as ffi;
import 'package:ffi/ffi.dart';
import 'package:logging/logging.dart';
import 'package:vector_math/vector_math.dart';

import 'context.dart';
import 'obj.dart';
import 'primitive_renderer.dart';
import 'text/text.dart';
import 'text/text_renderer.dart';
import 'ui/animation.dart';
import 'ui/component.dart';
import 'ui/components/button.dart';
import 'ui/components/label.dart';
import 'ui/components/metrics.dart';
import 'ui/components/slider.dart';
import 'ui/components/text_field.dart';
import 'ui/containers/flow_layout.dart';
import 'ui/insets.dart';
import 'ui/inspector.dart';
import 'ui/positioning.dart';
import 'ui/sizing.dart';
import 'ui/surface.dart';
import 'ui/ui_controller.dart';
import 'vertex_descriptors.dart';

typedef GLFWerrorfun = ffi.Void Function(ffi.Int, ffi.Pointer<ffi.Char>);

bool _running = true;

late final Window _window;

final Logger _logger = Logger("cutesy");
final Logger _glfwLogger = Logger("cutesy.glfw");

Future<GlProgram> vertFragProgram(String name, String vert, String frag) async {
  final shaders = await Future.wait([
    GlShader.fromFile(File("resources/shader/$vert.vert"), GlShaderType.vertex),
    GlShader.fromFile(File("resources/shader/$frag.frag"), GlShaderType.fragment),
  ]);

  return GlProgram(name, shaders);
}

void main(List<String> args) async {
  Logger.root.level = Level.FINE;
  Logger.root.onRecord.listen((event) {
    print("[${event.loggerName}] (${event.level.toString().toLowerCase()}) ${event.message}");
  });

  loadOpenGL();
  loadGLFW("resources/lib/libglfw.so.3");
  initDiamondGL(logger: Logger("cutesy"));

  if (glfw.init() != glfwTrue) {
    _logger.severe("GLFW init failed");
    exit(-1);
  }

  glfw.setErrorCallback(ffi.Pointer.fromFunction<GLFWerrorfun>(onGlfwError));

  _window = Window(1000, 550, "cutesy", debug: true);

  glfw.makeContextCurrent(_window.handle);
  attachGlErrorCallback();
  minGlDebugSeverity = glDebugSeverityLow;

  final projection = makeOrthographicMatrix(0, _window.width.toDouble(), _window.height.toDouble(), 0, 0, 1000);

  _window.onResize.listen((event) {
    gl.viewport(0, 0, event.width, event.height);
    setOrthographicMatrix(projection, 0, event.width.toDouble(), event.height.toDouble(), 0, 0, 1000);
  });

  final nunito = FontFamily("Nunito", 30);
  final cascadia = FontFamily("CascadiaCode", 30);
  final notoSans = FontFamily("NotoSans", 30);

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

  final renderContext = RenderContext(
    _window,
    await Future.wait([
      vertFragProgram("hsv", "position", "hsv"),
      vertFragProgram("pos_color", "position", "position"),
      vertFragProgram("text", "text", "text"),
      vertFragProgram("rounded_rect", "position", "rounded"),
      vertFragProgram("rounded_rect_outline", "position", "rounded_outline"),
      vertFragProgram("circle", "position", "circle"),
      vertFragProgram("blur", "position", "blur"),
    ]),
  );

  final primitiveRenderer = ImmediatePrimitiveRenderer(renderContext);
  final textRenderer = TextRenderer(renderContext, notoSans, {
    "NotoSans": notoSans,
    "Nunito": nunito,
    "CascadiaCode": cascadia,
  });

  final ui = UIController.ofWindow(
    _window,
    textRenderer,
    (horizontal, vertical) => FlowLayout.vertical()
      ..horizontalSizing(horizontal)
      ..verticalSizing(vertical),
  );

  var metrics = Metrics()..positioning(Positioning.relative(0, 100));

  final targetFps = 60.observable;
  final opacity = 100.observable
    ..observe((value) {
      glfw.setWindowOpacity(_window.handle, value / 100);
    });

  ui.root
    ..addChild(FlowLayout.horizontal()
      ..addChild(Button(Text.string("Buttgon", style: TextStyle(bold: true)), (p0) => _logger.info("button 1")))
      ..addChild(Button(Text.string("_______", style: TextStyle(bold: true)), (p0) {
        if (metrics.hasParent) {
          metrics.remove();
        } else {
          ui.root.addChild(metrics);
        }
      }))
      ..addChild(FlowLayout.vertical()
        ..addChild(Label(Text.string("Label-time"))
          ..color(Color.black)
          ..verticalTextAlignment = VerticalAlignment.center
          ..horizontalTextAlignment = HorizontalAlignment.center
          ..size = 24)
        ..addChild(Label(Text.string("AAAAAAAAA"))
          ..color(Color.black)
          ..verticalTextAlignment = VerticalAlignment.center
          ..horizontalTextAlignment = HorizontalAlignment.center
          ..size = 24)
        ..addChild(Button(Text.string("hmmm"), (_) {})))
      ..addChild(TextField()
        ..verticalSizing(Sizing.fixed(30))
        ..horizontalSizing(Sizing.fixed(350)))
      ..padding(Insets.all(10))
      ..gap(5)
      ..surface = Surfaces.flat(Color.rgb(0, 0, 0, .5)))
    ..addChild(FlowLayout.vertical()
      ..addChild(Label(Text.string("FPS: ${targetFps.value}"))
        ..size = 15
        ..configure((label) => targetFps.observe((fps) => label.text = Text.string("FPS: $fps"))))
      ..addChild(Slider()
        ..progress = 30 / 300
        ..listener = (p0) => targetFps(30 + (300 * p0).round()))
      ..horizontalAlignment(HorizontalAlignment.center)
      ..gap(5))
    ..addChild(FlowLayout.vertical()
      ..addChild(Label(Text.string("Opacity: ${opacity.value}%"))
        ..size = 15
        ..configure((label) => opacity.observe((opacity) => label.text = Text.string("Opacity: $opacity%"))))
      ..addChild(Slider()
        ..progress = 1
        ..listener = (p0) => opacity((100 * p0).round()))
      ..horizontalAlignment(HorizontalAlignment.center)
      ..gap(5))
    ..gap(25)
    ..horizontalAlignment(HorizontalAlignment.center)
    ..verticalAlignment(VerticalAlignment.center);

  ui.inflateAndMount();

  var lastTime = glfw.getTime();
  var frames = 0;
  var lastFps = 0;
  var passedTime = 0.0;

  glfw.swapInterval(0);

  final cube = loadObj(File("resources/suzanne.obj"));
  final cubeBuffer = MeshBuffer(posColorVertexDescriptor, renderContext.findProgram("pos_color"));
  for (final index in cube.indices) {
    cubeBuffer.vertex(cube.vertices[index - 1], Color.green);
  }
  cubeBuffer.upload();

  while (_running && glfw.windowShouldClose(_window.handle) != glfwTrue) {
    gl.clearColor(.25, .25, .25, 0);
    gl.clear(glColorBufferBit);
    gl.enable(glBlend);

    var delta = glfw.getTime() - lastTime;
    while (delta < 1 / targetFps.value) {
      glfw.waitEventsTimeout(1 / targetFps.value - delta);
      delta = glfw.getTime() - lastTime;
    }

    lastTime = glfw.getTime();

    Text metric(String value, String unit) => Text([
          StyledString(value, style: TextStyle(fontFamily: "CascadiaCode", bold: true, color: Color.ofRgb(0x42FFC2))),
          StyledString(" $unit",
              style: TextStyle(fontFamily: "CascadiaCode", bold: true, color: Color.ofRgb(0x57B2FF))),
        ]);

    textRenderer.drawText(5, 5, metric("$lastFps", "FPS"), 16, projection, color: Color.black);
    textRenderer.drawText(5, 23, metric((delta * 1000).toStringAsPrecision(2), "ms"), 16, projection,
        color: Color.black);

    final drawContext = DrawContext(renderContext, primitiveRenderer, projection, textRenderer);
    ui.render(drawContext, delta);

    if (inspector) {
      Inspector.drawInspector(drawContext, ui.root, _window.cursorX, _window.cursorY, true);
    }

    cubeBuffer.program.uniformMat4("uProjection", projection);
    cubeBuffer.program.uniformMat4(
        "uTransform",
        Matrix4.identity()
          ..translate(200.0, 200.0)
          ..rotateY(45)
          ..rotateX(45)
          ..scale(75.0, 75.0, 75.0));
    cubeBuffer.program.use();
    cubeBuffer.draw();

    _window.nextFrame();

    if (passedTime >= 1) {
      lastFps = frames;
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
