import 'package:diamond_gl/diamond_gl.dart';

import '../../context.dart';
import '../component.dart';

class Box extends Component {
  Color color = Color.black;
  bool outline = false;
  double cornerRadius = 0;

  @override
  void draw(DrawContext context, int mouseX, int mouseY, double delta) {
    if (cornerRadius != 0) {
      context.primitives.roundedRect(
        x.toDouble(),
        y.toDouble(),
        width.toDouble(),
        height.toDouble(),
        cornerRadius,
        color,
        context.projection,
      );
    } else {
      context.primitives.rect(
        x.toDouble(),
        y.toDouble(),
        width.toDouble(),
        height.toDouble(),
        color,
        context.projection,
      );
    }
  }
}
