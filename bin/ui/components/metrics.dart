import 'dart:collection';

import 'package:vector_math/vector_math.dart';

import '../../color.dart';
import '../../context.dart';
import '../../gl/vertex_buffer.dart';
import '../../gl/vertex_descriptor.dart';
import '../component.dart';
import '../sizing.dart';

class Metrics extends Component {
  final Queue<double> _frametimes = Queue();

  double _frametimeAccumulator = 0;
  int _countedFrames = 0;

  MeshBuffer<PosColorVertexFunction>? _graphBuffer;

  @override
  int determineHorizontalContentSize(Sizing sizing) => 200;

  @override
  int determineVerticalContentSize(Sizing sizing) => 100;

  @override
  void update(double delta, int mouseX, int mouseY) {
    super.update(delta, mouseX, mouseY);

    _frametimeAccumulator += delta;
    _countedFrames++;

    if (_frametimeAccumulator >= .05) {
      final frametime = _frametimeAccumulator / _countedFrames;

      _frametimeAccumulator = 0;
      _countedFrames = 0;

      _frametimes.add(frametime);
      if (_frametimes.length > 200) _frametimes.removeFirst();
    }
  }

  @override
  void draw(DrawContext context, int mouseX, int mouseY, double delta) {
    final buffer =
        _graphBuffer ??= MeshBuffer(posColorVertexDescriptor, context.renderContext.findProgram("pos_color"));

    buffer.clear();
    context.primitives.buildRect(buffer.vertex, x.toDouble(), y.toDouble(), 200, 1, Color.black);
    for (var (idx, measure) in _frametimes.indexed) {
      final height = (measure * 60) * 100;
      context.primitives
          .buildRect(buffer.vertex, x.toDouble() + idx, y + (this.height - height), 1, height, Color.green);
    }

    buffer.program
      ..use()
      ..uniformMat4("uTransform", Matrix4.identity())
      ..uniformMat4("uProjection", context.projection);

    buffer
      ..upload(dynamic: true)
      ..draw();
  }

  @override
  void dismount(DismountReason reason) {
    super.dismount(reason);

    if (reason == DismountReason.removed) {
      _graphBuffer?.delete();
      _graphBuffer = null;
    }
  }
}
