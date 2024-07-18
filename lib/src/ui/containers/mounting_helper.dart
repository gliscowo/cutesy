import '../positioning.dart';
import '../widget.dart';

typedef WidgetSink = void Function(Widget?, LayoutContext, void Function(Widget));

class MountingHelper {
  final WidgetSink _sink;
  final List<Widget> _lateChildren = [];
  final LayoutContext _childContext;

  MountingHelper.mountEarly(
    this._sink,
    List<Widget> children,
    this._childContext,
    void Function(Widget) layoutFunc,
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
