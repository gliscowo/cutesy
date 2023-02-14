import '../../color.dart';
import '../../text/text.dart';
import '../../text/text_renderer.dart';
import '../component.dart';
import '../math.dart';

typedef ButtonCallback = void Function(Button);

class Button extends Component {
  final Text text;
  ButtonCallback callback;

  double _hoverTime = 0;

  Button(this.text, this.callback) {
    cursorStyle = CursorStyle.hand;
  }

  @override
  void draw(DrawContext context, int mouseX, int mouseY, double partialTicks, double delta) {
    if (isInBoundingBox(mouseX.toDouble(), mouseY.toDouble())) {
      _hoverTime += computeDelta(_hoverTime, 1, delta * 10);
    } else {
      _hoverTime += computeDelta(_hoverTime, 0, delta * 10);
    }

    context.primitiveRenderer.roundedRect(
      x.toDouble() + 1,
      y.toDouble() + 1,
      width.toDouble() - 2,
      height.toDouble() - 2,
      10.0.lerp(_hoverTime, 20.0),
      Color.ofRgb(0x0096FF).interpolate(Color.ofRgb(0x00D7FF), _hoverTime),
      context.projection,
    );

    final textWidth = (text.width / 64) * text.glyphs[0].font.size;
    drawText(x.toDouble() + (width - textWidth) / 2, y.toDouble() + (height - text.height) / 2, 1, text,
        context.renderContext.findProgram("text"), context.projection, Color.white.asVector().rgb);
  }

  @override
  bool onMouseDown(double mouseX, double mouseY, int button) {
    callback(this);
    return true;
  }
}
