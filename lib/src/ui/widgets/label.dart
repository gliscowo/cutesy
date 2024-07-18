import 'package:diamond_gl/diamond_gl.dart';

import '../../context.dart';
import '../../text/text.dart';
import '../animation.dart';
import '../widget.dart';
import '../math.dart';
import '../sizing.dart';

class Label extends Widget {
  final Observable<Text> _text;
  Size? _textSizeCache;

  final AnimatableProperty<Color> color = Color.white.animatable;
  final Observable<int> maxWidth = (-1).observable;

  VerticalAlignment verticalTextAlignment = VerticalAlignment.top;
  HorizontalAlignment horizontalTextAlignment = HorizontalAlignment.left;
  double size = 30;

  Label(Text text) : _text = text.observable {
    _text.observe((value) {
      _textSizeCache = null;
      notifyParentIfMounted();
    });
  }

  @override
  int determineHorizontalContentSize(Sizing sizing) => _textSize!.width;

  @override
  int determineVerticalContentSize(Sizing sizing) => _textSize!.height;

  @override
  void draw(DrawContext context, int mouseX, int mouseY, double delta) {
    final xOffset = horizontalTextAlignment.align(_textSize!.width, width);
    final yOffset = verticalTextAlignment.align(_textSize!.height, height);

    context.textRenderer.drawText(x + xOffset, y + yOffset, _text.value, size, context.projection, color: color.value);
  }

  Size? get _textSize => _textSizeCache ??= layoutContext?.textRenderer.sizeOf(text, size);

  Text get text => _text.value;
  set text(Text text) => _text(text);
}
