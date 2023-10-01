import '../component.dart';
import '../positioning.dart';

typedef ComponentSink = void Function(Component?, LayoutContext, void Function(Component));

class MountingHelper {
  final ComponentSink _sink;
  final List<Component> _lateChildren = [];
  final LayoutContext _childContext;

  MountingHelper.mountEarly(
    this._sink,
    List<Component> children,
    this._childContext,
    void Function(Component) layoutFunc,
  ) {
    for (final child in children) {
      if (child.positioning.value.type != PositioningType.relative) {
        _sink(child, _childContext, layoutFunc);
      } else {
        _lateChildren.add(child);
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
