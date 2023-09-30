import '../../color.dart';
import '../../context.dart';
import '../component.dart';
import '../sizing.dart';

class Slider extends Component {
  double progress = 0;
  void Function(double)? listener;

  @override
  void draw(DrawContext context, int mouseX, int mouseY, double delta) {
    context.primitives.rect(
      x.toDouble() + 5,
      y.toDouble() + (height - 2) / 2,
      width.toDouble() - 10,
      2,
      Color.black,
      context.projection,
    );

    context.primitives.circle(
      x.toDouble() + (width - 10) * progress,
      y.toDouble(),
      10,
      Color.ofRgb(0x323232),
      context.projection,
    );
  }

  @override
  bool canFocus(FocusSource source) => true;

  @override
  int determineVerticalContentSize(Sizing sizing) => 20;

  @override
  int determineHorizontalContentSize(Sizing sizing) => 150;

  void _updateForCursorPos(double mouseX) {
    progress = (mouseX / width).clamp(0, 1);
    if (listener != null) listener!(progress);
  }

  @override
  bool onMouseDown(double mouseX, double mouseY, int button) {
    super.onMouseDown(mouseX, mouseY, button);

    _updateForCursorPos(mouseX);
    return true;
  }

  @override
  bool onMouseDrag(double mouseX, double mouseY, double deltaX, double deltaY, int button) {
    super.onMouseDrag(mouseX, mouseY, deltaX, deltaY, button);

    _updateForCursorPos(mouseX);
    return true;
  }
}
