import 'component.dart';

class FocusHandler {
  final ParentComponent _root;
  Component? _focused;
  FocusSource? _lastFocusSource;

  FocusHandler(this._root);

  void updateClickFocus(double mouseX, double mouseY) {
    var clicked = _root.childAt(mouseX.toInt(), mouseY.toInt());
    focus(clicked != null && clicked.canFocus(FocusSource.mouseClick) ? clicked : null, FocusSource.mouseClick);
  }

  Component? get focused => _focused;
  FocusSource? get lastFocusSource => _lastFocusSource;

  void cycle(bool forwards) {
    var allChildren = <Component>[];
    _root.collectDescendants(allChildren);

    allChildren.removeWhere((component) => !component.canFocus(FocusSource.keyboardCycle));
    if (allChildren.isEmpty) return;

    int newIndex = _focused == null
        ? forwards
            ? 0
            : allChildren.length - 1
        : (allChildren.indexOf(_focused!)) + (forwards ? 1 : -1);

    if (newIndex >= allChildren.length) newIndex -= allChildren.length;
    if (newIndex < 0) newIndex += allChildren.length;

    focus(allChildren[newIndex], FocusSource.keyboardCycle);
  }

  // void moveFocus(int keyCode) {
  //     if (this.focused == null) return;

  //     var allChildren = new ArrayList<Component>();
  //     this.root.collectChildren(allChildren);

  //     allChildren.removeIf(component -> !component.canFocus(FocusSource.keyboardCycle));
  //     if (allChildren.isEmpty()) return;

  //     var closest = this.focused;
  //     switch (keyCode) {
  //         case GLFW.GLFW_KEY_RIGHT -> {
  //             int closestX = Integer.MAX_VALUE, closestY = Integer.MAX_VALUE;

  //             for (var child : allChildren) {
  //                 if (child == this.focused) continue;
  //                 if (child.x() < this.focused.x() + this.focused.width() ||
  //                         child.x() > closestX || Math.abs(child.y() - this.focused.y()) > closestY) continue;

  //                 closest = child;
  //                 closestX = child.x();
  //                 closestY = Math.abs(child.y() - this.focused.y());
  //             }
  //         }
  //         case GLFW.GLFW_KEY_LEFT -> {
  //             int closestX = 0, closestY = Integer.MAX_VALUE;

  //             for (var child : allChildren) {
  //                 if (child == this.focused) continue;
  //                 if (child.x() + child.width() > this.focused.x() ||
  //                         child.x() + child.width() < closestX || Math.abs(child.y() - this.focused.y()) > closestY) continue;

  //                 closest = child;
  //                 closestX = child.x() + child.width();
  //                 closestY = Math.abs(child.y() - this.focused.y());
  //             }
  //         }
  //         case GLFW.GLFW_KEY_UP -> {
  //             int closestX = Integer.MAX_VALUE, closestY = 0;

  //             for (var child : allChildren) {
  //                 if (child == this.focused) continue;
  //                 if (child.y() + child.height() > this.focused.y() ||
  //                         child.y() + child.height() < closestY || Math.abs(child.x() - this.focused.x()) > closestX) continue;

  //                 closest = child;
  //                 closestX = Math.abs(child.x() - this.focused.x());
  //                 closestY = child.y() + child.height();
  //             }
  //         }
  //         case GLFW.GLFW_KEY_DOWN -> {
  //             int closestX = Integer.MAX_VALUE, closestY = Integer.MAX_VALUE;

  //             for (var child : allChildren) {
  //                 if (child == this.focused) continue;
  //                 if (child.y() < this.focused.y() + this.focused.height() ||
  //                         child.y() + child.height() > closestY || Math.abs(child.x() - this.focused.x()) > closestX) continue;

  //                 closest = child;
  //                 closestX = Math.abs(child.x() - this.focused.x());
  //                 closestY = child.y() + child.height();
  //             }
  //         }
  //     }

  //     this.focus(closest, FocusSource.keyboardCycle);
  // }

  void focus(Component? component, FocusSource source) {
    if (focused != component) {
      if (focused != null) {
        focused!.onFocusLost();
      }

      if ((_focused = component) != null) {
        focused!.onFocusGained(source);
        _lastFocusSource = source;
      } else {
        _lastFocusSource = null;
      }
    }
  }
}
