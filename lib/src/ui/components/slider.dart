import 'package:diamond_gl/diamond_gl.dart';

import '../../context.dart';
import '../animation.dart';
import '../component.dart';
import '../sizing.dart';

class Slider extends Component {
  final Observable<double> _progress = 0.0.observable;
  void Function(double)? listener;

  Slider() {
    _progress.observe((p0) {
      if (listener != null) listener!(p0);
    });
  }

  double get progress => _progress.value;
  set progress(double value) => _progress(value);

  @override
  void draw(DrawContext context, int mouseX, int mouseY, double delta) {
    context.primitives.roundedRect(
      x.toDouble() + 10,
      y.toDouble() + (height - 2) / 2,
      width.toDouble() - 20,
      2,
      1,
      Color.white,
      context.projection,
    );

    context.primitives.circle(
      x.toDouble() + (width - 20) * _progress.value,
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

  void _updateForCursorPos(double mouseX) => _progress(((mouseX - 10) / (width - 20)).clamp(0, 1));

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

  @override
  bool onMouseScroll(double mouseX, double mouseY, double amount) {
    super.onMouseScroll(mouseX, mouseY, amount);

    _progress((_progress.value + amount / 20).clamp(0, 1));
    return true;
  }
}
