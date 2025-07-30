import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';

class QuickMenu extends StatefulWidget {
  final VoidCallback onReview;
  final VoidCallback onBack;

  const QuickMenu({
    super.key,
    required this.onReview,
    required this.onBack,
  });

  @override
  State<QuickMenu> createState() => _QuickMenuState();
}

class _QuickMenuState extends State<QuickMenu> {
  bool _isAnyButtonHovered = false;

  @override
  Widget build(BuildContext context) {
    final config = SakiEngineConfig();
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final scaleFactor = size.width / 1920;

    return Positioned(
      left: 20 * scaleFactor,
      top: 20 * scaleFactor,
      child: Container(
        decoration: BoxDecoration(
          color: config.themeColors.background.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8 * scaleFactor),
          border: Border.all(
            color: config.themeColors.primary.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8 * scaleFactor,
              offset: Offset(0, 4 * scaleFactor),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _QuickMenuButton(
              text: '回顾',
              icon: Icons.auto_stories_outlined,
              onPressed: widget.onReview,
              scaleFactor: scaleFactor,
              config: config,
              isAnyButtonHovered: _isAnyButtonHovered,
              onHover: (hovering) => setState(() => _isAnyButtonHovered = hovering),
            ),
            Container(
              height: 1,
              margin: EdgeInsets.symmetric(horizontal: 8 * scaleFactor),
              color: config.themeColors.primary.withValues(alpha: 0.2),
            ),
            _QuickMenuButton(
              text: '返回',
              icon: Icons.arrow_back_rounded,
              onPressed: widget.onBack,
              scaleFactor: scaleFactor,
              config: config,
              isAnyButtonHovered: _isAnyButtonHovered,
              onHover: (hovering) => setState(() => _isAnyButtonHovered = hovering),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickMenuButton extends StatefulWidget {
  final String text;
  final IconData icon;
  final VoidCallback onPressed;
  final double scaleFactor;
  final SakiEngineConfig config;
  final bool isAnyButtonHovered;
  final Function(bool) onHover;

  const _QuickMenuButton({
    required this.text,
    required this.icon,
    required this.onPressed,
    required this.scaleFactor,
    required this.config,
    this.isAnyButtonHovered = false,
    required this.onHover,
  });

  @override
  State<_QuickMenuButton> createState() => _QuickMenuButtonState();
}

class _QuickMenuButtonState extends State<_QuickMenuButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final scaleFactor = widget.scaleFactor;
    final config = widget.config;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onPressed,
        onHover: (hovering) {
          setState(() => _isHovered = hovering);
          widget.onHover(hovering);
        },
        hoverColor: config.themeColors.primary.withValues(alpha: 0.1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: 16 * scaleFactor,
            vertical: 12 * scaleFactor,
          ),
          decoration: BoxDecoration(
            color: _isHovered 
                ? config.themeColors.primary.withValues(alpha: 0.05)
                : Colors.transparent,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                color: config.themeColors.primary.withValues(alpha: 0.8),
                size: config.quickMenuTextStyle.fontSize! * scaleFactor * 1.3,
              ),
              if (widget.isAnyButtonHovered) ...[
                SizedBox(width: 8 * scaleFactor),
                Text(
                  widget.text,
                  style: config.quickMenuTextStyle.copyWith(
                    fontSize: config.quickMenuTextStyle.fontSize! * scaleFactor,
                    color: config.themeColors.primary.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
