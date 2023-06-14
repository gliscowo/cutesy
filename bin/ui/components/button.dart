import '../../color.dart';
import '../../context.dart';
import '../../text/text.dart';
import '../component.dart';
import '../math.dart';
import '../sizing.dart';

typedef ButtonCallback = void Function(Button);

class Button extends Component {
  Text text;
  ButtonCallback callback;

  double _hoverTime = 0;

  Button(this.text, this.callback) {
    cursorStyle = CursorStyle.hand;
  }

  @override
  int determineHorizontalContentSize(Sizing sizing) => layoutContext!.textRenderer.sizeOf(text).width + 30;

  @override
  int determineVerticalContentSize(Sizing sizing) => layoutContext!.textRenderer.sizeOf(text).height + 30;

  @override
  void draw(DrawContext context, int mouseX, int mouseY, double delta) {
    if (isInBoundingBox(mouseX.toDouble(), mouseY.toDouble())) {
      _hoverTime += computeDelta(_hoverTime, 1, delta * 10);
    } else {
      _hoverTime += computeDelta(_hoverTime, 0, delta * 10);
    }

    context.primitives.roundedRect(
      x.toDouble(),
      y.toDouble(),
      width.toDouble(),
      height.toDouble(),
      10.0.lerp(_hoverTime, 20),
      Color.ofRgb(0x0096FF).interpolate(Color.ofRgb(0x00D7FF), _hoverTime),
      context.projection,
    );

    final textSize = context.textRenderer.sizeOf(text);
    context.textRenderer.drawText(
      x + (width - textSize.width) ~/ 2,
      y + (height - textSize.height) ~/ 2,
      text,
      context.projection,
    );
  }

  @override
  bool onMouseDown(double mouseX, double mouseY, int button) {
    callback(this);
    return true;
  }
}
