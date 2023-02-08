import 'gl/shader.dart';
import 'window.dart';

typedef ProgramLookup = GlProgram Function(String);

class RenderContext {
  final Window window;
  final Map<String, GlProgram> _programStore = {};

  RenderContext(this.window, List<GlProgram> programs) {
    for (final program in programs) {
      _programStore[program.name] = program;
    }
  }

  GlProgram lookupProgram(String name) {
    final program = _programStore[name];
    if (program == null) throw StateError("Missing required program $name");

    return program;
  }
}
