import '../component.dart';
import '../math.dart';
import '../positioning.dart';

typedef ComponentSink = void Function(Component?, Size, void Function(Component));

class MountingHelper {
  final ComponentSink _sink;
  final List<Component> _lateChildren = [];
  final Size _childSpace;

  MountingHelper.mountEarly(
      this._sink, List<Component> children, this._childSpace, void Function(Component) layoutFunc) {
    var lateChildren = <Component>[];

    for (final child in children) {
      if (child.positioning.value.type != PositioningType.relative) {
        _sink(child, _childSpace, layoutFunc);
      } else {
        lateChildren.add(child);
      }
    }
  }

  void mountLate() {
    for (var child in _lateChildren) {
      _sink(child, _childSpace, (p0) => throw StateError("A layout-positioned child was mounted late"));
    }
    _lateChildren.clear();
  }
}
