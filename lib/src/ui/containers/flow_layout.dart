import 'dart:collection';
import 'dart:core';

import '../../context.dart';
import '../animation.dart';
import '../math.dart';
import '../sizing.dart';
import '../widget.dart';
import 'mounting_helper.dart';

typedef _LayoutFunc = void Function(FlowLayout);

class FlowLayout extends ParentWidget {
  final List<Widget> _children = [];
  late final List<Widget> _childrenView = UnmodifiableListView(_children);

  final Observable<int> gap = 0.observable;

  final _LayoutFunc _algorithm;
  Size _contentSize = Size.zero;

  FlowLayout._(this._algorithm);

  FlowLayout.vertical() : this._(_layoutVertical);
  FlowLayout.horizontal() : this._(_layoutHorizontal);

  @override
  int determineHorizontalContentSize(Sizing sizing) => _contentSize.width + padding.value.horizontal;

  @override
  int determineVerticalContentSize(Sizing sizing) => _contentSize.height + padding.value.vertical;

  @override
  void layout(LayoutContext context) => _algorithm(this);

  @override
  List<Widget> get children => _childrenView;

  @override
  void draw(DrawContext matrices, int mouseX, int mouseY, double delta) {
    super.draw(matrices, mouseX, mouseY, delta);
    drawChildren(matrices, mouseX, mouseY, delta, _children);
  }

  /// Add [child] to this layout. If you need to add multiple
  /// children, use [addChildren] instead
  void addChild(Widget child, {int? index}) {
    if (index == null) {
      _children.add(child);
    } else {
      _children.insert(index, child);
    }
    updateLayout();
  }

  /// Insert [children] into this layout. If you only need to
  /// insert a single child to, use [addChild] instead
  void addChildren(Iterable<Widget> children, {int? index}) {
    if (index == null) {
      _children.addAll(children);
    } else {
      _children.insertAll(index, children);
    }
    updateLayout();
  }

  @override
  void removeChild(Widget child) {
    if (_children.remove(child)) {
      child.dismount(DismountReason.removed);
      updateLayout();
    }
  }

  /// Remove all children from this layout
  void clearChildren() {
    for (var child in _children) {
      child.dismount(DismountReason.removed);
    }

    _children.clear();
    updateLayout();
  }

  // @Override
  // public void parseProperties(UIModel model, Element element, Map<String, Element> children) {
  //     super.parseProperties(model, element, children);

  //     UIParsing.apply(children, "gap", UIParsing::parseSignedInt, this::gap);

  //     final components = UIParsing
  //             .get(children, "children", e -> UIParsing.<Element>allChildrenOfType(e, Node.ELEMENT_NODE))
  //             .orElse(Collections.emptyList());

  //     for (var child : components) {
  //         this.child(model.parseComponent(Component.class, child));
  //     }
  // }

  // public static FlowLayout parse(Element element) {
  //     UIParsing.expectAttributes(element, "direction");

  //     return element.getAttribute("direction").equals("vertical")
  //             ? Containers.verticalFlow(Sizing.content(), Sizing.content())
  //             : Containers.horizontalFlow(Sizing.content(), Sizing.content());
  // }

  static void _layoutHorizontal(FlowLayout container) {
    var layoutWidth = 0;
    var layoutHeight = 0;

    final layout = <Widget>[];
    final padding = container.padding.value;
    final childContext = container.childContext;

    var mountState = MountingHelper.mountEarly(container.mountChild, container.children, childContext, (child) {
      layout.add(child);

      child.inflate(childContext);
      child.mount(container, container.x + padding.left + child.margins.value.left + layoutWidth,
          container.y + padding.top + child.margins.value.top);

      final childSize = child.fullSize;
      layoutWidth += childSize.width + container.gap.value;
      if (childSize.height > layoutHeight) {
        layoutHeight = childSize.height;
      }
    });

    layoutWidth -= container.gap.value;

    container._contentSize = Size(layoutWidth, layoutHeight);
    container.applySizing();

    if (container.verticalAlignment.value != VerticalAlignment.top) {
      for (var widget in layout) {
        widget.updateY(widget.y +
            container.verticalAlignment.value.align(widget.fullSize.height, container.height - padding.vertical));
      }
    }

    if (container.horizontalAlignment.value != HorizontalAlignment.left) {
      for (var widget in layout) {
        if (container.horizontalAlignment.value == HorizontalAlignment.center) {
          widget.updateX(widget.x + (container.width - padding.horizontal - layoutWidth) ~/ 2);
        } else {
          widget.updateX(widget.x + (container.width - padding.horizontal - layoutWidth));
        }
      }
    }

    mountState.mountLate();
  }

  static void _layoutVertical(FlowLayout container) {
    var layoutHeight = 0;
    var layoutWidth = 0;

    final layout = <Widget>[];
    final padding = container.padding.value;
    final childContext = container.childContext;

    var mountState = MountingHelper.mountEarly(container.mountChild, container.children, childContext, (child) {
      layout.add(child);

      child.inflate(childContext);
      child.mount(container, container.x + padding.left + child.margins.value.left,
          container.y + padding.top + child.margins.value.top + layoutHeight);

      final childSize = child.fullSize;
      layoutHeight += childSize.height + container.gap.value;
      if (childSize.width > layoutWidth) {
        layoutWidth = childSize.width;
      }
    });

    layoutHeight -= container.gap.value;

    container._contentSize = Size(layoutWidth, layoutHeight);
    container.applySizing();

    if (container.horizontalAlignment.value != HorizontalAlignment.left) {
      for (final widget in layout) {
        widget.updateX(widget.x +
            container.horizontalAlignment.value.align(widget.fullSize.width, container.width - padding.horizontal));
      }
    }

    if (container.verticalAlignment.value != VerticalAlignment.top) {
      for (final widget in layout) {
        if (container.verticalAlignment.value == VerticalAlignment.center) {
          widget.updateY(widget.y + (container.height - padding.vertical - layoutHeight) ~/ 2);
        } else {
          widget.updateY(widget.y + (container.height - padding.vertical - layoutHeight));
        }
      }
    }

    mountState.mountLate();
  }
}
