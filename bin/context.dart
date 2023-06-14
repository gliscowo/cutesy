import 'package:vector_math/vector_math.dart';

import 'gl/shader.dart';
import 'primitive_renderer.dart';
import 'text/text_renderer.dart';
import 'window.dart';

typedef ProgramLookup = GlProgram Function(String);

class RenderContext {
  final Window window;
  final Map<String, GlProgram> _programStore = {};

  RenderContext(this.window, List<GlProgram> programs) {
    for (final program in programs) {
      if (_programStore[program.name] != null) {
        throw ArgumentError("Duplicate program name ${program.name}", "programs");
      }

      _programStore[program.name] = program;
    }
  }

  GlProgram findProgram(String name) {
    final program = _programStore[name];
    if (program == null) throw StateError("Missing required program $name");

    return program;
  }
}

class DrawContext {
  final RenderContext renderContext;
  final ImmediatePrimitiveRenderer primitives;

  final Matrix4 projection;

  final TextRenderer textRenderer;

  DrawContext(this.renderContext, this.primitives, this.projection, this.textRenderer);
}
