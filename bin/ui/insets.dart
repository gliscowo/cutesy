import 'animation.dart';
import 'math.dart';

class Insets implements Animatable<Insets> {
  static const Insets zero = Insets();

  final int top, bottom, left, right;

  const Insets({this.top = 0, this.bottom = 0, this.left = 0, this.right = 0});
  const Insets.all(int all) : this.axis(vertical: all, horizontal: all);
  const Insets.axis({int vertical = 0, int horizontal = 0})
      : top = vertical,
        bottom = vertical,
        left = horizontal,
        right = horizontal;

  int get vertical => top + bottom;
  int get horizontal => left + right;

  Insets get inverted => Insets(top: -top, bottom: -bottom, left: -left, right: -right);

  Insets copy({int? top, int? bottom, int? left, int? right}) =>
      Insets(top: top ?? this.top, bottom: bottom ?? this.bottom, left: left ?? this.left, right: right ?? this.right);

  Insets operator +(Insets other) =>
      Insets(top: top + other.top, bottom: bottom + other.bottom, left: left + other.left, right: right + other.right);

  Insets operator -(Insets other) =>
      Insets(top: top - other.top, bottom: bottom - other.bottom, left: left - other.left, right: right - other.right);

  Insets operator *(Insets other) =>
      Insets(top: top * other.top, bottom: bottom * other.bottom, left: left * other.left, right: right * other.right);

  Insets operator ~/(Insets other) => Insets(
      top: top ~/ other.top, bottom: bottom ~/ other.bottom, left: left ~/ other.left, right: right ~/ other.right);

  @override
  Insets interpolate(Insets next, double delta) => Insets(
        top: top.lerp(delta, next.top),
        bottom: bottom.lerp(delta, next.bottom),
        left: left.lerp(delta, next.left),
        right: right.lerp(delta, next.right),
      );
}
