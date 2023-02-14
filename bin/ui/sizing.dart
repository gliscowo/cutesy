import 'animation.dart';
import 'math.dart';

class Sizing implements Animatable<Sizing> {
  static const Sizing _contentSizing = Sizing._(SizingMethod.content, 0);

  final SizingMethod method;
  final int value;

  const Sizing._(this.method, this.value);

  const Sizing.fixed(int value) : this._(SizingMethod.fixed, value);
  const Sizing.fill(int value) : this._(SizingMethod.fill, value);
  factory Sizing.content([int? padding]) => padding == null ? _contentSizing : Sizing._(SizingMethod.content, padding);

  bool get isContent => method == SizingMethod.content;

  int inflate(int space, int Function(Sizing) contentSize) {
    switch (method) {
      case SizingMethod.fixed:
        return value;
      case SizingMethod.fill:
        return (value / 100 * space).round();
      case SizingMethod.content:
        return contentSize(this) + value * 2;
    }
  }

  @override
  Sizing interpolate(Sizing next, double delta) {
    if (next.method != method) return this;
    return Sizing._(method, value.lerp(delta, next.value));
  }
}

enum SizingMethod {
  fixed,
  content,
  fill;
}
