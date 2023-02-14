import '../component.dart';
import '../positioning.dart';

typedef ComponentSink = void Function(Component?, BuildContext, void Function(Component));

class MountingHelper {
  final ComponentSink _sink;
  final List<Component> _lateChildren = [];
  final BuildContext _childContext;

  MountingHelper.mountEarly(
      this._sink, List<Component> children, this._childContext, void Function(Component) layoutFunc) {
    var lateChildren = <Component>[];

    for (final child in children) {
      if (child.positioning.value.type != PositioningType.relative) {
        _sink(child, _childContext, layoutFunc);
      } else {
        lateChildren.add(child);
      }
    }
  }

  void mountLate() {
    for (var child in _lateChildren) {
      _sink(child, _childContext, (p0) => throw StateError("A layout-positioned child was mounted late"));
    }
    _lateChildren.clear();
  }
}
