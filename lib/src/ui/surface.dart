import 'package:diamond_gl/diamond_gl.dart';

import '../context.dart';
import 'component.dart';

typedef Surface = void Function(DrawContext, Component);

class Surfaces {
  static void blank(DrawContext context, Component component) {}

  static Surface flat(Color color) => (context, component) {
        context.primitives.rect(
          component.x.toDouble(),
          component.y.toDouble(),
          component.width.toDouble(),
          component.height.toDouble(),
          color,
          context.projection,
        );
      };

  static Surface outline(Color color, [int thickness = 2]) => (context, component) {
        context.primitives.roundedRect(
          component.x.toDouble(),
          component.y.toDouble(),
          component.width.toDouble(),
          component.height.toDouble(),
          0,
          color,
          context.projection,
          outlineThickness: thickness.toDouble(),
        );
      };
}
