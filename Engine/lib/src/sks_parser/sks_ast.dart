import 'package:flutter/material.dart';

// Base class for all AST nodes.
abstract class SksNode {}

// Represents the entire screen.
class ScreenNode extends SksNode {
  final String name;
  final List<SksNode> children;

  ScreenNode(this.name, this.children);
}

// Represents a solid color background.
class AddNode extends SksNode {
  final String color; // Expecting format like #RRGGBB

  AddNode(this.color);
}

// Represents a text label.
class TextNode extends SksNode {
  final String text;
  final String? font;
  final String? color;
  final double? size;
  final double? left;
  final double? right;
  final double? top;
  final double? bottom;

  TextNode({
    required this.text,
    this.font,
    this.color,
    this.size,
    this.left,
    this.right,
    this.top,
    this.bottom,
  });
}

// Represents a horizontal layout container.
class HBoxNode extends SksNode {
  final List<SksNode> children;
  final double? left;
  final double? right;
  final double? top;
  final double? bottom;
  final double? spacing;

  HBoxNode({
    required this.children,
    this.left,
    this.right,
    this.top,
    this.bottom,
    this.spacing,
  });
}

// Represents a text button.
class TextButtonNode extends SksNode {
  final String text;
  final String action;
  final TextStyle? style;

  TextButtonNode({
    required this.text,
    required this.action,
    this.style,
  });
} 