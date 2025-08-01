import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/utils/scaling_manager.dart';

class QuickMenu extends StatefulWidget {
  final VoidCallback onSave;
  final VoidCallback onLoad;
  final VoidCallback onReview;
  final VoidCallback onBack;

  const QuickMenu({
    super.key,
    required this.onSave,
    required this.onLoad,
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
    final scale = context.scaleFor(ComponentType.menu);

    return Positioned(
      left: 20 * scale,
      top: 20 * scale,
      child: Container(
        decoration: BoxDecoration(
          color: config.themeColors.background.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8 * scale),
          border: Border.all(
            color: config.themeColors.primary.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8 * scale,
              offset: Offset(0, 4 * scale),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _QuickMenuButton(
              text: '存档',
              icon: Icons.save_alt_outlined,
              onPressed: widget.onSave,
              scale: scale,
              config: config,
              isAnyButtonHovered: _isAnyButtonHovered,
              onHover: (hovering) => setState(() => _isAnyButtonHovered = hovering),
            ),
            _buildDivider(scale, config),
            _QuickMenuButton(
              text: '读档',
              icon: Icons.folder_open_outlined,
              onPressed: widget.onLoad,
              scale: scale,
              config: config,
              isAnyButtonHovered: _isAnyButtonHovered,
              onHover: (hovering) => setState(() => _isAnyButtonHovered = hovering),
            ),
            _buildDivider(scale, config),
            _QuickMenuButton(
              text: '回顾',
              icon: Icons.auto_stories_outlined,
              onPressed: widget.onReview,
              scale: scale,
              config: config,
              isAnyButtonHovered: _isAnyButtonHovered,
              onHover: (hovering) => setState(() => _isAnyButtonHovered = hovering),
            ),
            _buildDivider(scale, config),
            _QuickMenuButton(
              text: '返回',
              icon: Icons.arrow_back_rounded,
              onPressed: widget.onBack,
              scale: scale,
              config: config,
              isAnyButtonHovered: _isAnyButtonHovered,
              onHover: (hovering) => setState(() => _isAnyButtonHovered = hovering),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(double scale, SakiEngineConfig config) {
    return Container(
      height: 1,
      margin: EdgeInsets.symmetric(horizontal: 8 * scale),
      color: config.themeColors.primary.withOpacity(0.2),
    );
  }
}

class _QuickMenuButton extends StatefulWidget {
  final String text;
  final IconData icon;
  final VoidCallback onPressed;
  final double scale;
  final SakiEngineConfig config;
  final bool isAnyButtonHovered;
  final Function(bool) onHover;

  const _QuickMenuButton({
    required this.text,
    required this.icon,
    required this.onPressed,
    required this.scale,
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
    final scale = widget.scale;
    final config = widget.config;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onPressed,
        onHover: (hovering) {
          setState(() => _isHovered = hovering);
          widget.onHover(hovering);
        },
        hoverColor: config.themeColors.primary.withOpacity(0.1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: 16 * scale,
            vertical: 12 * scale,
          ),
          decoration: BoxDecoration(
            color: _isHovered 
                ? config.themeColors.primary.withOpacity(0.05)
                : Colors.transparent,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                color: config.themeColors.primary.withOpacity(0.8),
                size: config.quickMenuTextStyle.fontSize! * scale * 1.3,
              ),
              if (widget.isAnyButtonHovered) ...[
                SizedBox(width: 8 * scale),
                Text(
                  widget.text,
                  style: config.quickMenuTextStyle.copyWith(
                    fontSize: config.quickMenuTextStyle.fontSize! * scale,
                    color: config.themeColors.primary.withOpacity(0.9),
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
