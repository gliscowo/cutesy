import 'package:diamond_gl/diamond_gl.dart';

import '../context.dart';
import 'widget.dart';

typedef Surface = void Function(DrawContext, Widget);

class Surfaces {
  static void blank(DrawContext context, Widget widget) {}

  static Surface flat(Color color) => (context, widget) {
        context.primitives.rect(
          widget.x.toDouble(),
          widget.y.toDouble(),
          widget.width.toDouble(),
          widget.height.toDouble(),
          color,
          context.projection,
        );
      };

  static Surface outline(Color color, [int thickness = 2]) => (context, widget) {
        context.primitives.roundedRect(
          widget.x.toDouble(),
          widget.y.toDouble(),
          widget.width.toDouble(),
          widget.height.toDouble(),
          0,
          color,
          context.projection,
          outlineThickness: thickness.toDouble(),
        );
      };
}
