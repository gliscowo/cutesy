import 'animation.dart';
import 'math.dart';

class Positioning implements Animatable<Positioning> {
  static const Positioning layout = Positioning._(PositioningType.layout, 0, 0);

  final PositioningType type;
  final int x, y;

  const Positioning._(this.type, this.x, this.y);

  const Positioning.absolute(int xPixels, int yPixels) : this._(PositioningType.absolute, xPixels, yPixels);
  const Positioning.relative(int xPixels, int yPixels) : this._(PositioningType.absolute, xPixels, yPixels);

  Positioning copy({PositioningType? type, int? x, int? y}) =>
      Positioning._(type ?? this.type, x ?? this.x, y ?? this.y);

  bool get isLayout => type == PositioningType.layout;

  @override
  Positioning interpolate(Positioning next, double delta) {
    if (next.type != type) return this;
    return Positioning._(type, x.lerp(delta, next.x), y.lerp(delta, next.y));
  }
}

enum PositioningType {
  relative,
  absolute,
  layout;
}
