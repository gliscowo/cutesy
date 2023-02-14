import 'package:glfw/glfw.dart';
import 'package:meta/meta.dart';

import '../color.dart';
import '../context.dart';
import '../text/text.dart';
import '../text/text_renderer.dart';
import '../window.dart';
import 'animation.dart';
import 'events.dart';
import 'insets.dart';
import 'math.dart';
import 'positioning.dart';
import 'sizing.dart';
import 'surface.dart';

abstract class Component with Rectangle {
  int _x = 0, _y = 0, _width = 0, _height = 0;

  ParentComponent? _parent;
  bool _mounted = false;
  BuildContext? _buildContext;

  int _batchedEvents = 0;
  bool _dirty = false;
  bool _hovered = false;

  /// The id of this component. If this is not unique across the hierarchy,
  /// calls to [ParentComponent.childById] may not be deterministic
  String? id;

  /// The Z-Index of this component. This is used
  /// for layering components during rendering
  int zIndex = 0;

  /// The style of cursor to use while the
  /// mouse is hovering this component
  CursorStyle cursorStyle = CursorStyle.none;

  /// Multiple lines of text to display
  /// as a tooltip when hovering this component
  List<Text>? tooltip = const [];

  Component() {
    Observable.observeAll(notifyParentIfMounted, [margins, positioning, horizontalSizing, verticalSizing]);
  }

  /// Draw the current state of this component onto the screen
  ///
  /// @param matrices     The transformation stack
  /// @param mouseX       The mouse pointer's x-coordinate
  /// @param mouseY       The mouse pointer's y-coordinate
  /// @param partialTicks The fraction of the current tick that has passed
  /// @param delta        The duration of the last frame, in partial ticks
  void draw(DrawContext context, int mouseX, int mouseY, double partialTicks, double delta);

  ///
  /// Draw the current tooltip of this component onto the screen
  ///
  /// @param matrices     The transformation stack
  /// @param mouseX       The mouse pointer's x-coordinate
  /// @param mouseY       The mouse pointer's y-coordinate
  /// @param partialTicks The fraction of the current tick that has passed
  /// @param delta        The duration of the last frame, in partial ticks
  ///
  // default void drawTooltip(MatrixStack matrices, int mouseX, int mouseY, double partialTicks, double delta) {
  //     if (!this.shouldDrawTooltip(mouseX, mouseY)) return;
  //     Drawer.drawTooltip(matrices, mouseX, mouseY, this.tooltip());
  // }

  /// Draw something which clearly indicates
  /// that this component is currently focused
  ///
  /// @param matrices     The transformation stack
  /// @param mouseX       The mouse pointer's x-coordinate
  /// @param mouseY       The mouse pointer's y-coordinate
  /// @param partialTicks The fraction of the current tick that has passed
  /// @param delta        The duration of the last frame, in partial ticks
  void drawFocusHighlight(DrawContext context, int mouseX, int mouseY, double partialTicks, double delta) {
    context.primitiveRenderer.roundedRect(
      x.toDouble(),
      y.toDouble(),
      width.toDouble(),
      height.toDouble(),
      0,
      Color.white,
      context.projection,
      outlineThickness: 1,
    );
  }

  /// The parent of this component
  ParentComponent? get parent => _parent;

  ///
  /// @return The focus handler of this component hierarchy
  ///
  // FocusHandler? focusHandler();

  /// The positioning of this component
  final AnimatableProperty<Positioning> positioning = AnimatableProperty.create(Positioning.layout);

  /// The external margins of this component
  final AnimatableProperty<Insets> margins = AnimatableProperty.create(Insets.zero);

  /// Set the method this component uses to determine its size
  /// on both axes to [sizing]
  void sizing(Sizing sizing) {
    horizontalSizing(sizing);
    verticalSizing(sizing);
  }

  /// The sizing method this component uses on the x-axis
  final AnimatableProperty<Sizing> horizontalSizing = AnimatableProperty.create(Sizing.content());

  /// The sizing method this component uses on the y-axis
  final AnimatableProperty<Sizing> verticalSizing = AnimatableProperty.create(Sizing.content());

  ///
  /// Determine if this component should currently
  /// render its tooltip
  ///
  /// @param mouseX The mouse cursor's x-coordinate
  /// @param mouseY The mouse cursor's y-coordinate
  /// @return {@code true} if the tooltip should be rendered
  ///
  bool shouldDrawTooltip(double mouseX, double mouseY) => tooltip != null && isInBoundingBox(mouseX, mouseY);

  int determineHorizontalContentSize(Sizing sizing) =>
      throw UnimplementedError("$runtimeType does not support content-sizing on the horizontal axis");

  int determineVerticalContentSize(Sizing sizing) =>
      throw UnimplementedError("$runtimeType does not support content-sizing on the horizontal axis");

  /// The last known environment in which this
  /// component was built. This is useful when emitting
  /// layout updates from within a parent component
  @protected
  BuildContext? get buildContext => _buildContext;

  /// Inflate this component into some amount
  /// of available space, given by [space]
  void inflate(BuildContext context) {
    _buildContext = context;
    applySizing();
    _dirty = false;
  }

  @protected
  void applySizing() {
    final horizontalSizing = this.horizontalSizing.value;
    final verticalSizing = this.verticalSizing.value;

    final margins = this.margins.value;

    _width = horizontalSizing.inflate(_buildContext!.space.width - margins.horizontal, determineHorizontalContentSize);
    _height = verticalSizing.inflate(_buildContext!.space.height - margins.vertical, determineVerticalContentSize);
  }

  @protected
  void notifyParentIfMounted() {
    if (!hasParent) return;

    if (_batchedEvents > 0) {
      _batchedEvents++;
      return;
    }

    _dirty = true;
    parent!.onChildMutated(this);
  }

  /// Called when this component is mounted onto [parent] during the layout process.
  ///
  /// **This must only ever happen after the component has been inflated**
  void mount(ParentComponent? parent, int x, int y) {
    _parent = parent;
    _mounted = true;
    moveTo(x, y);
  }

  /// Called when this component is being dismounted from its
  /// parent. This usually happens because the layout is being recalculated
  /// or the child has been removed - useful for releasing resources for example
  ///
  /// [reason] describes why this component was dismounted. If it is [DismountReason.layoutInflation],
  /// resources should be held onto as the component will be re-mounted right after
  ///
  /// **Note:** It is currently not guaranteed in any way that this method is
  /// invoked when the component tree becomes itself unreachable. You may still override
  /// this method to release resources if it becomes certain at an early point that
  /// they're not needed anymore, but generally resource management stays the responsibility
  /// of the individual component for the time being
  void dismount(DismountReason reason) {
    _parent = null;
    _mounted = false;
  }

  /// Whether this component currently has a parent
  bool get hasParent => parent != null;

  /// Whether this component currently considers itself
  /// mounted, usually equivalent to [hasParent]
  bool get mounted => _mounted;

  /// Retrieve root component of this component's
  /// tree, or `null` if this component is not mounted
  ParentComponent? get root {
    var root = parent;
    if (root == null) return null;

    while (root!.hasParent) {
      root = root.parent;
    }
    return root;
  }

  /// Remove this component from its
  /// parent, if it is currently mounted
  void remove() {
    if (!hasParent) return;
    parent!.queue(() {
      parent!.removeChild(this);
    });
  }

  ///
  /// Called when the mouse has been clicked inside
  /// the bounding box of this component
  ///
  /// @param mouseX The x coordinate at which the mouse was clicked, relative
  ///               to this component's bounding box root
  /// @param mouseY The y coordinate at which the mouse was clicked, relative
  ///               to this component's bounding box root
  /// @param button The mouse button which was clicked, refer to the constants
  ///               in {@link org.lwjgl.glfw.GLFW}
  /// @return {@code true} if this component handled the click and no more
  /// components should be notified
  ///
  bool onMouseDown(double mouseX, double mouseY, int button) =>
      _mouseDownEvents.dispatch(MouseButtonEvent(mouseX, mouseY, button));

  final EventStream<MouseButtonEvent, bool> _mouseDownEvents = EventStream.withBoolResult();
  EventSource<MouseButtonEvent, bool> get mouseDown => _mouseDownEvents.source;

  ///
  /// Called when a mouse button has been released
  /// while this component is focused
  ///
  /// @param button The mouse button which was released, refer to the constants
  ///               in {@link org.lwjgl.glfw.GLFW}
  /// @return {@code true} if this component handled the event and no more
  /// components should be notified
  ///
  bool onMouseUp(double mouseX, double mouseY, int button) =>
      _mouseUpEvents.dispatch(MouseButtonEvent(mouseX, mouseY, button));

  final EventStream<MouseButtonEvent, bool> _mouseUpEvents = EventStream.withBoolResult();
  EventSource<MouseButtonEvent, bool> get mouseUp => _mouseUpEvents.source;

  ///
  /// Called when the mouse has been scrolled inside
  /// the bounding box of this component
  ///
  /// @param mouseX The x coordinate at which the mouse pointer is, relative
  ///               to this component's bounding box root
  /// @param mouseY The y coordinate at which the mouse pointer is, relative
  ///               to this component's bounding box root
  /// @param amount How far the mouse was scrolled
  /// @return {@code true} if this component handled the scroll event
  /// and no more components should be notified
  ///
  bool onMouseScroll(double mouseX, double mouseY, double amount) =>
      _mouseScrollEvents.dispatch(MouseScrollEvent(mouseX, mouseY, amount));

  final EventStream<MouseScrollEvent, bool> _mouseScrollEvents = EventStream.withBoolResult();
  EventSource<MouseScrollEvent, bool> get mouseScroll => _mouseScrollEvents.source;

  ///
  /// Called when the mouse has been dragged
  /// while this component is focused
  ///
  /// @param mouseX The x coordinate at which the mouse was dragged, relative
  ///               to this component's bounding box root
  /// @param mouseY The y coordinate at which the mouse was dragged, relative
  ///               to this component's bounding box root
  /// @param deltaX How far the mouse was moved on the x-axis
  /// @param deltaY How far the mouse was moved on the y-axis
  /// @param button The mouse button which was clicked, refer to the constants
  ///               in {@link org.lwjgl.glfw.GLFW}
  /// @return {@code true} if this component handled the mouse move and no more
  /// components should be notified
  ///
  bool onMouseDrag(double mouseX, double mouseY, double deltaX, double deltaY, int button) =>
      _mouseDragEvents.dispatch(MouseDragEvent(mouseX, mouseY, deltaX, deltaY, button));

  final EventStream<MouseDragEvent, bool> _mouseDragEvents = EventStream.withBoolResult();
  EventSource<MouseDragEvent, bool> get mouseDrag => _mouseDragEvents.source;

  ///
  /// Called when a key on the keyboard has been pressed
  /// while this component is focused
  ///
  /// @param keyCode   The key token of the pressed key, refer to the constants in {@link org.lwjgl.glfw.GLFW}
  /// @param scanCode  A platform-specific scancode uniquely identifying the exact key that was pressed
  /// @param modifiers A bitfield describing which modifier keys were pressed,
  ///                  refer to <a href="https://www.glfw.org/docs/3.3/group__mods.html">GLFW Modifier key flags</a>
  /// @return {@code true} if this component handled the key-press and no
  /// more components should be notified
  ///
  bool onKeyPress(int keyCode, int scanCode, int modifiers) =>
      _keyPressEvents.dispatch(KeyPressEvent(keyCode, scanCode, modifiers));

  final EventStream<KeyPressEvent, bool> _keyPressEvents = EventStream.withBoolResult();
  EventSource<KeyPressEvent, bool> get keyPress => _keyPressEvents.source;

  ///
  /// Called when a keyboard input event occurred - namely when
  /// a key has been pressed and the OS determined it should result
  /// in a character being typed
  ///
  /// @param chr       The character that was typed
  /// @param modifiers A bitfield describing which modifier keys were pressed,
  ///                  refer to <a href="https://www.glfw.org/docs/3.3/group__mods.html">GLFW Modifier key flags</a>
  /// @return {@code true} if this component handled the input and no
  ////// more components should be notified
  ///
  bool onCharTyped(String chr, int modifiers) => _charTypedEvents.dispatch(CharTypedEvent(chr, modifiers));

  final EventStream<CharTypedEvent, bool> _charTypedEvents = EventStream.withBoolResult();
  EventSource<CharTypedEvent, bool> get charTyped => _charTypedEvents.source;

  ///
  /// @return {@code true} if this component can gain focus
  ///
  bool canFocus(FocusSource source) => false;

  ///
  /// Called when this component gains focus, due
  /// to being clicked or selected via tab-cycling
  ///
  void onFocusGained(FocusSource source) => _focusGainedEvents.dispatch(source);

  final EventStream<FocusSource, void> _focusGainedEvents = EventStream.withoutResult();
  EventSource<FocusSource, void> get focusGained => _focusGainedEvents.source;

  ///
  /// Called when this component loses focus
  ///
  void onFocusLost() => _focusLostEvents.dispatch(null);

  final EventStream<void, void> _focusLostEvents = EventStream.withoutResult();
  EventSource<void, void> get focusLost => _focusLostEvents.source;

  ///
  /// Update the state of this component
  /// before drawing the next frame
  ///
  /// @param delta  The duration of the last frame, in partial ticks
  /// @param mouseX The mouse pointer's x-coordinate
  /// @param mouseY The mouse pointer's y-coordinate
  ///
  void update(double delta, int mouseX, int mouseY) {
    margins.update(delta);
    positioning.update(delta);
    horizontalSizing.update(delta);
    verticalSizing.update(delta);

    final nowHovered = isInBoundingBox(mouseX.toDouble(), mouseY.toDouble());
    if (_hovered != nowHovered) {
      _hovered = nowHovered;

      if (nowHovered) {
        _mouseEnterEvents.dispatch(null);
      } else {
        _mouseLeaveEvents.dispatch(null);
      }
    }
  }

  final EventStream<void, void> _mouseEnterEvents = EventStream.withoutResult();
  EventSource<void, void> get mouseEnter => _mouseEnterEvents.source;

  final EventStream<void, void> _mouseLeaveEvents = EventStream.withoutResult();
  EventSource<void, void> get mouseLeave => _mouseLeaveEvents.source;

  ///
  /// Test whether the given coordinates
  /// are inside this component's bounding box
  ///
  /// @param x The x-coordinate to test
  /// @param y The y-coordinate to test
  /// @return {@code true} if this component's bounding box encloses
  /// the given coordinates
  ///
  @override
  bool isInBoundingBox(double x, double y) {
    return super.isInBoundingBox(x, y);
  }

  ///
  /// @return The current size of this component's content + its margins
  ///
  Size get fullSize {
    final margins = this.margins.value;
    return Size(width + margins.horizontal, height + margins.vertical);
  }

  ///
  /// Read the properties, and potentially children, of this
  /// component from the given XML element
  ///
  /// @param model    The UI model that's being instantiated,
  ///                 used for creating child components
  /// @param element  The XML element representing this component
  /// @param children The child elements of the XML element representing
  ///                 this component by tag name, without duplicates
  ///
  // default void parseProperties(UIModel model, Element element, Map<String, Element> children) {
  //     if (!element.getAttribute("id").isBlank()) {
  //         _idlement.getAttribute("id).strip());
  //     }

  //     UIParsing.apply(children, "margins", Insets::parse, this::margins);
  //     UIParsing.apply(children, "positioning", Positioning::parse, this::positioning);
  //     UIParsing.apply(children, "z-index", UIParsing::parseSignedInt, this::zIndex);
  //     UIParsing.apply(children, "cursor-style", UIParsing.parseEnum(CursorStyle.class), this::cursorStyle);
  //     UIParsing.apply(children, "tooltip-text", UIParsing::parseText, this::tooltip);

  //     if (children.containsKey("sizing")) {
  //         var sizingValues = UIParsing.childElements(children.get("sizing"));
  //         UIParsing.apply(sizingValues, "vertical", Sizing::parse, this::verticalSizing);
  //         UIParsing.apply(sizingValues, "horizontal", Sizing::parse, this::horizontalSizing);
  //     }
  // }

  /// The current width of the bounding box
  /// of this component
  @override
  int get width => _width;

  /// The current height of the bounding box
  /// of this component
  @override
  int get height => _height;

  /// The current x-coordinate of the top-left
  /// corner of the bounding box of this component
  @override
  int get x => _x;

  /// Set the x-coordinate of the top-left corner of the
  /// bounding box of this component to [x]
  ///
  /// This method will usually only be called by the
  /// parent component - users of the API
  /// should instead alter properties to this component
  /// to ensure proper layout updates
  void updateX(int x) => _x = x;

  /// The current y-coordinate of the top-left
  /// corner of the bounding box of this component
  @override
  int get y => _y;

  /// Set the y-coordinate of the top-left corner of the
  /// bounding box of this component to [y]
  ///
  /// This method will usually only be called by the
  /// parent component - users of the API
  /// should instead alter properties to this component
  /// to ensure proper layout updates
  void updateY(int y) => _y = y;

  /// Set the x-coordinate of the top-left corner of the
  /// bounding box of this component to [x], [y]
  ///
  /// This method will usually only be called by the
  /// parent component - users of the API
  /// should instead alter properties to this component
  /// to ensure proper layout updates
  void moveTo(int x, int y) => this
    ..updateX(x)
    ..updateY(y);
}

extension Configure<C extends Component> on C {
  ///
  /// Execute the given [closure] immediately with this
  /// component as the argument. This is primarily useful for calling
  /// methods that don't return the component and could thus not be
  /// called inline when constructing the UI Tree.
  ///
  /// All state updates emitted during execution of the closure are deferred
  /// and consolidated into a single update that's emitted after execution has
  /// finished. Thus, you can also employ this to efficiently update multiple
  /// properties on a component.
  ///
  /// **It is imperative that the type parameter be declared to a type that
  /// this component can be represented as - otherwise an exception is thrown**
  ///
  /// Example:
  ///
  /// ```dart
  /// container.child(Label(Text.string("Click")).configure((label) {
  ///     label.mouseDown().subscribe((mouseX, mouseY, button) {
  ///         System.out.println("Click");
  ///         return true;
  ///     });
  /// }));
  /// ```
  void configure(void Function(C) closure) {
    try {
      _batchedEvents = 1;
      closure(this);
    } finally {
      if (_batchedEvents > 1) {
        _batchedEvents = 0;
        if (this is ParentComponent) {
          (this as ParentComponent).updateLayout();
        } else {
          notifyParentIfMounted();
        }
      } else {
        _batchedEvents = 0;
      }
    }
  }
}

abstract class ParentComponent extends Component {
  List<void Function()>? _taskQueue;

  /// @return How this component vertically arranges its children
  final Observable<VerticalAlignment> verticalAlignment = Observable.create(VerticalAlignment.top);

  /// @return How this component horizontally arranges its children
  final Observable<HorizontalAlignment> horizontalAlignment = Observable.create(HorizontalAlignment.left);

  /// @return The internal padding of this component
  final AnimatableProperty<Insets> padding = AnimatableProperty.create(Insets.zero);

  /// Whether this component allows its
  /// children to overflow its bounding box
  bool allowOverflow = false;

  Surface surface = Surfaces.blank;

  /// The children of this component
  List<Component> get children;

  ParentComponent() {
    Observable.observeAll(updateLayout, [horizontalAlignment, verticalAlignment, padding]);
  }

  /// Recalculate the layout of this component
  void layout(BuildContext context);

  /// Queue [task] to be run after the
  /// entire UI has finished updating
  void queue(void Function() task) {
    if (_taskQueue == null) {
      parent!.queue(task);
    } else {
      _taskQueue!.add(task);
    }
  }

  @override
  void draw(DrawContext context, int mouseX, int mouseY, double partialTicks, double delta) {
    surface(context, this);
  }

  @override
  @nonVirtual
  void update(double delta, int mouseX, int mouseY) {
    super.update(delta, mouseX, mouseY);
    padding.update(delta);

    for (final child in children) {
      child.update(delta, mouseX, mouseY);
    }

    parentUpdate(delta, mouseX, mouseY);

    if (_taskQueue != null) {
      for (final task in _taskQueue!) {
        task();
      }
      _taskQueue!.clear();
    }
  }

  @protected
  void parentUpdate(double delta, int mouseX, int mouseY) {}

  @override
  void mount(ParentComponent? parent, int x, int y) {
    super.mount(parent, x, y);
    if (!hasParent) _taskQueue = [];
  }

  @override
  void inflate(BuildContext context) {
    if (_buildContext == context && !_dirty) return;
    _buildContext = context;

    for (var child in children) {
      child.dismount(DismountReason.layoutInflation);
    }

    super.inflate(context);
    layout(context);
    super.inflate(context);
  }

  /// Called when [child] has been mutated in some way
  /// that would affect the layout of this component
  void onChildMutated(Component child) => updateLayout();

  @protected
  void updateLayout() {
    if (!mounted) return;

    if (_batchedEvents > 0) {
      _batchedEvents++;
      return;
    }

    var previousSize = fullSize;

    _dirty = true;
    inflate(_buildContext!);

    if (previousSize != fullSize && hasParent) {
      parent!.onChildMutated(this);
    }
  }

  /// Remove the given child from this component
  void removeChild(Component child);

  // @override
  // default void drawTooltip(MatrixStack matrices, int mouseX, int mouseY, float partialTicks, float delta) {
  //     Component.super.drawTooltip(matrices, mouseX, mouseY, partialTicks, delta);

  //     if (!this.allowOverflow()) {
  //         var padding = this.padding().get();
  //         ScissorStack.push(this.x() + padding.left(), this.y() + padding.top(), this.width() - padding.horizontal(), this.height() - padding.vertical(), matrices);
  //     }

  //     for (var child : this.children()) {
  //         if (!ScissorStack.isVisible(mouseX, mouseY, matrices)) continue;

  //         matrices.translate(0, 0, child.zIndex());
  //         child.drawTooltip(matrices, mouseX, mouseY, partialTicks, delta);
  //         matrices.translate(0, 0, -child.zIndex());
  //     }

  //     if (!this.allowOverflow()) {
  //         ScissorStack.pop();
  //     }
  // }

  @override
  bool onMouseDown(double mouseX, double mouseY, int button) {
    var iter = children.reversed.iterator;

    while (iter.moveNext()) {
      var child = iter.current;
      if (!child.isInBoundingBox(x + mouseX, y + mouseY)) continue;
      if (child.onMouseDown(x + mouseX - child.x, y + mouseY - child.y, button)) {
        return true;
      }
    }

    return false;
  }

  @override
  bool onMouseScroll(double mouseX, double mouseY, double amount) {
    var iter = children.reversed.iterator;

    while (iter.moveNext()) {
      var child = iter.current;
      if (!child.isInBoundingBox(x + mouseX, y + mouseY)) continue;
      if (child.onMouseScroll(x + mouseX - child.x, y + mouseY - child.y, amount)) {
        return true;
      }
    }

    return false;
  }

  // @Override
  // default void parseProperties(UIModel model, Element element, Map<String, Element> children) {
  //     Component.super.parseProperties(model, element, children);
  //     UIParsing.apply(children, "padding", Insets::parse, this::padding);
  //     UIParsing.apply(children, "surface", Surface::parse, this::surface);
  //     UIParsing.apply(children, "vertical-alignment", VerticalAlignment::parse, this::verticalAlignment);
  //     UIParsing.apply(children, "horizontal-alignment", HorizontalAlignment::parse, this::horizontalAlignment);
  //     UIParsing.apply(children, "allow-overflow", UIParsing::parseBool, this::allowOverflow);
  // }

  /// Recursively find the child with the given [id] in the
  /// hierarchy below this component
  C? childById<C extends Component>(String id) {
    var iter = children.reversed.iterator;

    while (iter.moveNext()) {
      var child = iter.current;
      if (child.id == id) {
        if (child is! C) {
          throw UnimplementedError("No model exception :(");
          // throw new IncompatibleUIModelException(
          //         "Expected child with id '" + id + "'"
          //                 + " to be a " + expectedClass.getSimpleName()
          //                 + " but it is a " + child.getClass().getSimpleName()
          // );
        }
        return child;
      } else if (child is ParentComponent) {
        var candidate = child.childById<C>(id);
        if (candidate != null) return candidate;
      }
    }

    return null;
  }

  /// Get the most specific child at the given coordinates
  ///
  /// @param x The x-coordinate to query
  /// @param y The y-coordinate to query
  /// @return The most specific child at the given coordinates,
  /// or {@code null} if there is none
  Component? childAt(int x, int y) {
    var iter = children.reversed.iterator;

    while (iter.moveNext()) {
      var child = iter.current;
      if (child.isInBoundingBox(x.toDouble(), y.toDouble())) {
        if (child is ParentComponent) {
          return child.childAt(x, y);
        } else {
          return child;
        }
      }
    }

    return isInBoundingBox(x.toDouble(), y.toDouble()) ? this : null;
  }

  /// Collect the entire component hierarchy below
  /// this component into [list]
  void collectChildren(List<Component> into) {
    into.add(this);
    for (var child in children) {
      if (child is ParentComponent) {
        child.collectChildren(into);
      } else {
        into.add(child);
      }
    }
  }

  @override
  void updateX(int x) {
    final offset = x - this.x;
    super.updateX(x);

    for (var child in children) {
      child.updateX(child.x + offset);
    }
  }

  @override
  void updateY(int y) {
    final offset = y - this.y;
    super.updateY(y);

    for (var child in children) {
      child.updateY(child.y + offset);
    }
  }

  /// The offset from the origin of this component
  /// at which children can start to be mounted. Accumulates
  /// padding as well as padding from content sizing
  @protected
  Size childMountingOffset() {
    var padding = this.padding.value;
    return Size(padding.left, padding.top);
  }

  /// Inflate [child] into [space] and mount using [layoutFunc] if its
  /// positioning is equal to [Positioning.layout], or according to its
  /// intrinsic positioning otherwise
  @protected
  void mountChild(Component? child, BuildContext context, void Function(Component) layoutFunc) {
    if (child == null) return;

    final positioning = child.positioning.value;
    final componentMargins = child.margins.value;
    final padding = this.padding.value;

    switch (positioning.type) {
      case PositioningType.layout:
        layoutFunc(child);
        break;
      case PositioningType.absolute:
        child.inflate(context);
        child.mount(
          this,
          x + positioning.x + componentMargins.left + padding.left,
          y + positioning.y + componentMargins.top + padding.top,
        );
        break;
      case PositioningType.relative:
        child.inflate(context);
        child.mount(
          this,
          x +
              padding.left +
              componentMargins.left +
              ((positioning.x / 100) * (width - child.fullSize.width - padding.horizontal)).round(),
          y +
              padding.top +
              componentMargins.top +
              ((positioning.y / 100) * (height - child.fullSize.height - padding.vertical)).round(),
        );
        break;
    }
  }

  /// Draw the children of this component along with
  /// their focus outline and tooltip, optionally clipping
  /// them if {@link #allowOverflow} is {@code false}
  ///
  /// @param children The list of children to draw
  @protected
  void drawChildren(
      DrawContext context, int mouseX, int mouseY, double partialTicks, double delta, List<Component> children) {
    // TODO: scissoring
    // if (!allowOverflow) {
    //     var padding = this.padding.value;
    //     ScissorStack.push(this.x + padding.left(), this.y + padding.top(), this.width - padding.horizontal(), this.height - padding.vertical(), matrices);
    // }

    // var focusHandler = this.focusHandler();
    //noinspection ForLoopReplaceableByForEach
    for (int i = 0; i < children.length; i++) {
      final child = children[i];

      // if (!ScissorStack.isVisible(child, matrices)) continue;
      // matrices.translate(0, 0, child.zIndex());

      child.draw(context, mouseX, mouseY, partialTicks, delta);
      // if (focusHandler.lastFocusSource() == FocusSource.KEYBOARD_CYCLE && focusHandler.focused() == child) {
      //     child.drawFocusHighlight(matrices, mouseX, mouseY, partialTicks, delta);
      // }

      // matrices.translate(0, 0, -child.zIndex());
    }

    // if (!allowOverflow) {
    //     ScissorStack.pop();
    // }
  }

  /// Calculate the space for child inflation. If a given axis
  /// is content-sized, return the respective value from {@code thisSpace}
  ///
  /// @param thisSpace The space for layout inflation of this widget
  /// @return The available space for child inflation
  @protected
  BuildContext get childContext {
    final padding = this.padding.value;

    return _buildContext!.copy(
      space: Size(
        horizontalSizing.value.isContent ? _buildContext!.space.width - padding.horizontal : width - padding.horizontal,
        verticalSizing.value.isContent ? _buildContext!.space.height - padding.vertical : height - padding.vertical,
      ),
    );
  }
}

class BuildContext {
  final Window window;
  final TextRenderer textRenderer;
  final Size space;

  BuildContext(this.window, this.textRenderer, this.space);
  BuildContext.ofWindow(this.window, this.textRenderer) : space = Size(window.width, window.height);

  BuildContext copy({Window? window, TextRenderer? textRenderer, Size? space}) =>
      BuildContext(window ?? this.window, textRenderer ?? this.textRenderer, space ?? this.space);

  @override
  int get hashCode => Object.hash(window, textRenderer, space);

  @override
  bool operator ==(Object other) =>
      other is BuildContext && other.window == window && other.textRenderer == textRenderer && other.space == space;
}

enum VerticalAlignment {
  top,
  center,
  bottom;

  int align(int componentWidth, int span) {
    switch (this) {
      case VerticalAlignment.top:
        return 0;
      case VerticalAlignment.center:
        return span ~/ 2 - componentWidth ~/ 2;
      case VerticalAlignment.bottom:
        return span - componentWidth;
    }
  }
}

enum HorizontalAlignment {
  left,
  center,
  right;

  int align(int componentWidth, int span) {
    switch (this) {
      case HorizontalAlignment.left:
        return 0;
      case HorizontalAlignment.center:
        return span ~/ 2 - componentWidth ~/ 2;
      case HorizontalAlignment.right:
        return span - componentWidth;
    }
  }
}

enum CursorStyle {
  none(0),
  pointer(GLFW_ARROW_CURSOR),
  text(GLFW_IBEAM_CURSOR),
  hand(GLFW_HAND_CURSOR),
  move(0x36009);

  final int glfw;
  const CursorStyle(this.glfw);
}

enum FocusSource {
  /// The component has been clicked
  mouseClick,

  /// The component has been selected by
  /// cycling focus via the keyboard
  keyboardCycle
}

enum DismountReason {
  /// The child has been dismounted because the parent's layout
  /// is being inflated
  layoutInflation,

  /// The child has been dismounted because it has been removed
  /// from its parent
  removed
}
