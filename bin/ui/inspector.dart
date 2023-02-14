import 'dart:math';

import '../color.dart';
import '../text/text.dart';
import '../text/text_renderer.dart';
import 'component.dart';
import 'insets.dart';

abstract class Inspector {
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
    context.primitiveRenderer.rect(x.toDouble() - insets.left, y.toDouble() - insets.top,
        width.toDouble() + insets.horizontal, insets.top.toDouble(), color, context.projection);
    context.primitiveRenderer.rect(x.toDouble() - insets.left, y.toDouble() + height,
        width.toDouble() + insets.horizontal, insets.bottom.toDouble(), color, context.projection);

    context.primitiveRenderer.rect(
        x.toDouble() - insets.left, y.toDouble(), insets.left.toDouble(), height.toDouble(), color, context.projection);
    context.primitiveRenderer.rect(
        x.toDouble() + width, y.toDouble(), insets.right.toDouble(), height.toDouble(), color, context.projection);
  }

  /// Draw the element inspector for the given tree, detailing the position,
  /// bounding box, margins and padding of each component
  ///
  /// @param matrices    The transformation matrix stack
  /// @param root        The root component of the hierarchy to draw
  /// @param mouseX      The x-coordinate of the mouse pointer
  /// @param mouseY      The y-coordinate of the mouse pointer
  /// @param onlyHovered Whether to only draw the inspector for the hovered widget
  static void drawInspector(DrawContext context, ParentComponent root, double mouseX, double mouseY, bool onlyHovered) {
    // RenderSystem.disableDepthTest();
    // var client = MinecraftClient.getInstance();
    // var textRenderer = client.textRenderer;

    final children = <Component>[];
    if (!onlyHovered) {
      root.collectChildren(children);
    } else if (root.childAt(mouseX.toInt(), mouseY.toInt()) != null) {
      children.add(root.childAt(mouseX.toInt(), mouseY.toInt())!);
    }

    for (var child in children) {
      // if (child is ParentComponent) {
      //   drawInsets(context, child.x, child.y, child.width, child.height, child.padding.value.inverted,
      //       Color.ofArgb(0xA70CECDD));
      // }

      final margins = child.margins.value;
      drawInsets(context, child.x, child.y, child.width, child.height, margins, Color.ofArgb(0xA7FFF338));

      context.primitiveRenderer.roundedRect(child.x.toDouble(), child.y.toDouble(), child.width.toDouble(),
          child.height.toDouble(), 5, Color.ofArgb(0xFF3AB0FF), context.projection,
          outlineThickness: 1);

      if (onlyHovered) {
        final nameText = Text.string("${child.runtimeType}${child.id == null ? "" : " '${child.id}'"}")
          ..shape(context.font);

        final descriptor = Text([
          StyledString(
              "${child.x},${child.y} (${child.width},${child.height}) <${child.margins.value.top},${child.margins.value.bottom},${child.margins.value.left},${child.margins.value.right}>"),
          if (child is ParentComponent)
            StyledString(
                " <${child.padding.value.top},${child.padding.value.bottom},${child.padding.value.left},${child.padding.value.right}>"),
        ])
          ..shape(context.font);

        int inspectorX = child.x + 1;
        int inspectorY = child.y + child.height + child.margins.value.bottom + 1;
        int inspectorHeight = nameText.height + descriptor.height + 10;

        if (inspectorY > context.renderContext.window.height - inspectorHeight) {
          inspectorY -= child.fullSize.height + inspectorHeight + 1;
          if (inspectorY < 0) inspectorY = 1;
          if (child is ParentComponent) {
            inspectorX += child.padding.value.left;
            inspectorY += child.padding.value.top;
          }
        }

        int width = max(
              (nameText.width ~/ 64) * context.font.defaultFont.size,
              (descriptor.width ~/ 64) * context.font.defaultFont.size,
            ) +
            25;
        context.primitiveRenderer.roundedRect(inspectorX.toDouble(), inspectorY.toDouble(), width + 3,
            inspectorHeight.toDouble(), 5, Color.ofArgb(0xA7000000), context.projection);
        context.primitiveRenderer.roundedRect(inspectorX.toDouble(), inspectorY.toDouble(), width + 3,
            inspectorHeight.toDouble(), 5, Color.ofArgb(0xA7000000), context.projection,
            outlineThickness: 1);

        drawText(inspectorX + 2, inspectorY + 3, 1, nameText, context.renderContext.findProgram("text"),
            context.projection, Color.white.asVector().rgb);
        drawText(inspectorX + 2, inspectorY + nameText.height + 3, 1, descriptor,
            context.renderContext.findProgram("text"), context.projection, Color.white.asVector().rgb);
      }
    }

    // RenderSystem.enableDepthTest();
  }
}