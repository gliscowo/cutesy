import '../../color.dart';
import '../../context.dart';
import '../../text/text.dart';
import '../animation.dart';
import '../component.dart';
import '../math.dart';
import '../sizing.dart';

class Label extends Component {
  Text _text;
  Size? _textSizeCache;

  final AnimatableProperty<Color> color = AnimatableProperty.create(Color.white);
  final Observable<int> maxWidth = Observable.create(-1);

  VerticalAlignment verticalTextAlignment = VerticalAlignment.top;
  HorizontalAlignment horizontalTextAlignment = HorizontalAlignment.left;
  double scale = 1;

  Label(this._text);

  @override
  int determineHorizontalContentSize(Sizing sizing) => _textSize!.width + 2;

  @override
  int determineVerticalContentSize(Sizing sizing) => _textSize!.height + 2;

  @override
  void draw(DrawContext context, int mouseX, int mouseY, double delta) {
    final xOffset = horizontalTextAlignment.align(_textSize!.width, width);
    final yOffset = verticalTextAlignment.align(_textSize!.height, height);

    context.textRenderer
        .drawText(x + xOffset, y + yOffset, _text, context.projection, color: color.value, scale: scale);
  }

  Size? get _textSize => _textSizeCache ??= layoutContext?.textRenderer.sizeOf(text, scale: scale);

  Text get text => _text;

  set text(Text text) {
    _text = text;
    _textSizeCache = null;
  }
}
