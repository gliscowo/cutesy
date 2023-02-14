import '../../color.dart';
import '../../context.dart';
import '../../text/text.dart';
import '../animation.dart';
import '../component.dart';
import '../math.dart';

class Label extends Component {
  Text _text;
  Size? _textSize;

  final AnimatableProperty<Color> color = AnimatableProperty.create(Color.white);
  final Observable<int> maxWidth = Observable.create(-1);

  VerticalAlignment verticalTextAlignment = VerticalAlignment.top;
  HorizontalAlignment horizontalTextAlignment = HorizontalAlignment.left;
  double scale = 1;

  Label(this._text);

  @override
  void draw(DrawContext context, int mouseX, int mouseY, double partialTicks, double delta) {
    final textSize = _textSize ??= context.textRenderer.sizeOf(text, scale: scale);

    final xOffset = horizontalTextAlignment.align(textSize.width, width);
    final yOffset = verticalTextAlignment.align(textSize.height, height);

    context.textRenderer
        .drawText(x + xOffset, y + yOffset, _text, context.projection, color: color.value, scale: scale);
  }

  Text get text => _text;

  set text(Text text) {
    _text = text;
    _textSize = null;
  }
}
