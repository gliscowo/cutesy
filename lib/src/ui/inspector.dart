import 'dart:math';

import 'package:diamond_gl/diamond_gl.dart';

import '../context.dart';
import '../text/text.dart';
import 'insets.dart';
import 'widget.dart';

abstract class Inspector {
  static const _textSize = 20.0;

  /// Draw the area around the given rectangle which
  /// the given insets describe
  ///
  /// @param matrices The transformation matrix stack
  /// @param x        The x-coordinate of top-left corner of the rectangle
  /// @param y        The y-coordinate of top-left corner of the rectangle
  /// @param width    The width of the rectangle
  /// @param height   The height of the rectangle
  /// @param insets   The insets to draw around the rectangle
  /// @param color    The color to draw the inset area with
  static void drawInsets(DrawContext context, int x, int y, int width, int height, Insets insets, Color color) {
    context.primitives.rect(x.toDouble() - insets.left, y.toDouble() - insets.top, width.toDouble() + insets.horizontal,
        insets.top.toDouble(), color, context.projection);
    context.primitives.rect(x.toDouble() - insets.left, y.toDouble() + height, width.toDouble() + insets.horizontal,
        insets.bottom.toDouble(), color, context.projection);

    context.primitives.rect(
        x.toDouble() - insets.left, y.toDouble(), insets.left.toDouble(), height.toDouble(), color, context.projection);
    context.primitives.rect(
        x.toDouble() + width, y.toDouble(), insets.right.toDouble(), height.toDouble(), color, context.projection);
  }

  /// Draw the element inspector for the given tree, detailing the position,
  /// bounding box, margins and padding of each widget
  ///
  /// @param matrices    The transformation matrix stack
  /// @param root        The root widget of the hierarchy to draw
  /// @param mouseX      The x-coordinate of the mouse pointer
  /// @param mouseY      The y-coordinate of the mouse pointer
  /// @param onlyHovered Whether to only draw the inspector for the hovered widget
  static void drawInspector(DrawContext context, ParentWidget root, double mouseX, double mouseY, bool onlyHovered) {
    final children = <Widget>[];
    if (!onlyHovered) {
      root.collectDescendants(children);
    } else if (root.childAt(mouseX.toInt(), mouseY.toInt()) != null) {
      children.add(root.childAt(mouseX.toInt(), mouseY.toInt())!);
    }

    for (var child in children) {
      if (child is ParentWidget) {
        drawInsets(context, child.x, child.y, child.width, child.height, child.padding.value.inverted,
            Color.ofArgb(0xA70CECDD));
      }

      final margins = child.margins.value;
      drawInsets(context, child.x, child.y, child.width, child.height, margins, Color.ofArgb(0xA7FFF338));

      context.primitives.roundedRect(child.x.toDouble(), child.y.toDouble(), child.width.toDouble(),
          child.height.toDouble(), 2, Color.ofArgb(0xFF3AB0FF), context.projection,
          outlineThickness: 1);

      if (onlyHovered) {
        final nameText = Text.string("${child.runtimeType}${child.id == null ? "" : " '${child.id}'"}");

        final descriptor = Text([
          StyledString(
            "${child.x},${child.y} (${child.width},${child.height}) <${child.margins.value.top},${child.margins.value.bottom},${child.margins.value.left},${child.margins.value.right}>",
          ),
          if (child is ParentWidget)
            StyledString(
              " <${child.padding.value.top},${child.padding.value.bottom},${child.padding.value.left},${child.padding.value.right}>",
            ),
        ]);

        final nameSize = context.textRenderer.sizeOf(nameText, _textSize);
        final descriptorSize = context.textRenderer.sizeOf(descriptor, _textSize);

        int inspectorX = child.x + 1;
        int inspectorY = child.y + child.height + child.margins.value.bottom + 1;
        int inspectorHeight = nameSize.height + descriptorSize.height + 10;

        if (inspectorY > context.renderContext.window.height - inspectorHeight) {
          inspectorY -= child.fullSize.height + inspectorHeight + 1;
          if (inspectorY < 0) inspectorY = 1;
          if (child is ParentWidget) {
            inspectorX += child.padding.value.left;
            inspectorY += child.padding.value.top;
          }
        }

        int width = max(nameSize.width, descriptorSize.width);
        context.primitives.roundedRect(inspectorX.toDouble(), inspectorY.toDouble(), width + 6,
            inspectorHeight.toDouble(), 5, Color.ofArgb(0xA7000000), context.projection);
        context.primitives.roundedRect(inspectorX.toDouble(), inspectorY.toDouble(), width + 6,
            inspectorHeight.toDouble(), 5, Color.ofArgb(0xA7000000), context.projection,
            outlineThickness: 1);

        context.textRenderer.drawText(inspectorX + 3, inspectorY + 3, nameText, _textSize, context.projection);
        context.textRenderer
            .drawText(inspectorX + 3, inspectorY + nameSize.height + 5, descriptor, _textSize, context.projection);
      }
    }
  }
}
