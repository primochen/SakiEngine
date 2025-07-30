import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/skr_parser/skr_ast.dart';

class ChoiceMenu extends StatelessWidget {
  final MenuNode menuNode;
  final Function(String) onChoiceSelected;

  const ChoiceMenu({
    super.key,
    required this.menuNode,
    required this.onChoiceSelected,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final config = SakiEngineConfig();
    final scaleX = screenSize.width / config.logicalWidth;
    final scaleY = screenSize.height / config.logicalHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: menuNode.choices
            .map(
              (choice) => Padding(
                padding: EdgeInsets.symmetric(vertical: 12 * scale),
                child: _ChoiceButton(
                  text: choice.text,
                  onPressed: () => onChoiceSelected(choice.targetLabel),
                  scale: scale,
                  config: config,
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ChoiceButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final double scale;
  final SakiEngineConfig config;

  const _ChoiceButton({
    required this.text,
    required this.onPressed,
    required this.scale,
    required this.config,
  });

  @override
  State<_ChoiceButton> createState() => _ChoiceButtonState();
}

class _ChoiceButtonState extends State<_ChoiceButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onPressed,
        onHover: (hovering) {
          setState(() => _isHovered = hovering);
        },
        child: Container(
          width: MediaQuery.of(context).size.width * 0.5,
          padding: EdgeInsets.symmetric(
            horizontal: 24 * widget.scale,
            vertical: 16 * widget.scale,
          ),
          decoration: BoxDecoration(
            color: _isHovered 
              ? HSLColor.fromColor(widget.config.themeColors.background)
                  .withLightness((HSLColor.fromColor(widget.config.themeColors.background).lightness - 0.1).clamp(0.0, 1.0))
                  .toColor().withValues(alpha: 0.9)
              : widget.config.themeColors.background.withValues(alpha: 0.9),
            border: Border.all(
              color: widget.config.themeColors.primary.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Text(
            widget.text,
            textAlign: TextAlign.center,
            style: widget.config.choiceTextStyle.copyWith(
              fontSize: widget.config.choiceTextStyle.fontSize! * widget.scale,
              color: widget.config.themeColors.primary,
              fontWeight: _isHovered ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
} 