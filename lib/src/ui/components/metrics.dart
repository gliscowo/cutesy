import 'dart:collection';
import 'dart:math';

import 'package:diamond_gl/diamond_gl.dart';
import 'package:vector_math/vector_math.dart';

import '../../../vertex_descriptors.dart';
import '../../context.dart';
import '../../text/text.dart';
import '../animation.dart';
import '../component.dart';
import '../sizing.dart';

class Metrics extends Component {
  final Queue<double> _frametimes = Queue();

  double _frametimeAccumulator = 0;
  int _countedFrames = 0;

  MeshBuffer<PosColorVertexFunction>? _graphBuffer;

  @override
  int determineHorizontalContentSize(Sizing sizing) => 200 + 60;

  @override
  int determineVerticalContentSize(Sizing sizing) => 100 + 10;

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
      if (_frametimes.length > 100) _frametimes.removeFirst();
    }
  }

  @override
  void draw(DrawContext context, int mouseX, int mouseY, double delta) {
    const textSize = 14.0;
    context.textRenderer.drawText(x + width - 60 + 3, (y + 10 - textSize / 2).round(),
        Text.string("30 FPS", style: TextStyle(fontFamily: "CascadiaCode")), textSize, context.projection);
    context.textRenderer.drawText(x + width - 60 + 3, (y + 10 + height / 2 - textSize / 2).round(),
        Text.string("60 FPS", style: TextStyle(fontFamily: "CascadiaCode")), textSize, context.projection);

    final buffer =
        _graphBuffer ??= MeshBuffer(posColorVertexDescriptor, context.renderContext.findProgram("pos_color"));

    buffer.clear();
    context.primitives.buildRect(buffer.vertex, x.toDouble(), y + 10, width - 60, 1, Color.white);
    context.primitives.buildRect(buffer.vertex, x.toDouble(), y + 10 + (height - 10) / 2, width - 60, 1, Color.white);
    for (var (idx, measure) in _frametimes.indexed) {
      final height = (measure * 60) * ((this.height - 10) / 2);
      context.primitives.buildRect(buffer.vertex, x.toDouble() + idx * 2, y + 10 + (this.height - 10 - height), 2,
          height, Color.green.interpolate(Color.red, max(0, 1 - 1 / (measure * 60))));
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
