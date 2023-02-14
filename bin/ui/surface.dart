// ignore_for_file: prefer_function_declarations_over_variables

import '../color.dart';
import '../context.dart';
import 'component.dart';

typedef Surface = void Function(DrawContext, Component);

class Surfaces {
  static final Surface blank = (context, component) {};

  static Surface flat(Color color) => (context, component) {
        context.primitiveRenderer.rect(
          component.x.toDouble(),
          component.y.toDouble(),
          component.width.toDouble(),
          component.height.toDouble(),
          color,
          context.projection,
        );
      };

  static Surface outline(Color color, [int thickness = 2]) => (context, component) {
        context.primitiveRenderer.roundedRect(
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
