import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/utils/scaling_manager.dart';

class QuickMenu extends StatefulWidget {
  final VoidCallback onSave;
  final VoidCallback onLoad;
  final VoidCallback onReview;
  final VoidCallback onSettings;
  final VoidCallback onBack;
  final VoidCallback onPreviousDialogue;

  const QuickMenu({
    super.key,
    required this.onSave,
    required this.onLoad,
    required this.onReview,
    required this.onSettings,
    required this.onBack,
    required this.onPreviousDialogue,
  });

  @override
  State<QuickMenu> createState() => _QuickMenuState();
}

class _QuickMenuState extends State<QuickMenu> {
  String? _hoveredButtonText;
  int? _hoveredButtonIndex;
  GlobalKey _menuKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final config = SakiEngineConfig();
    final scale = context.scaleFor(ComponentType.menu);

    return Stack(
      children: [
        Positioned(
          left: 20 * scale,
          top: 20 * scale,
          child: Container(
            key: _menuKey,
            decoration: BoxDecoration(
              color: config.themeColors.background.withOpacity(0.9),
              borderRadius: BorderRadius.circular(config.baseWindowBorder > 0 
                  ? config.baseWindowBorder * scale 
                  : 0 * scale),
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
                  onHover: (hovering, text) => setState(() {
                    _hoveredButtonText = hovering ? text : null;
                    _hoveredButtonIndex = hovering ? 0 : null;
                  }),
                ),
                _buildDivider(scale, config),
                _QuickMenuButton(
                  text: '读档',
                  icon: Icons.folder_open_outlined,
                  onPressed: widget.onLoad,
                  scale: scale,
                  config: config,
                  onHover: (hovering, text) => setState(() {
                    _hoveredButtonText = hovering ? text : null;
                    _hoveredButtonIndex = hovering ? 1 : null;
                  }),
                ),
                _buildDivider(scale, config),
                _QuickMenuButton(
                  text: '回顾',
                  icon: Icons.auto_stories_outlined,
                  onPressed: widget.onReview,
                  scale: scale,
                  config: config,
                  onHover: (hovering, text) => setState(() {
                    _hoveredButtonText = hovering ? text : null;
                    _hoveredButtonIndex = hovering ? 2 : null;
                  }),
                ),
                _buildDivider(scale, config),
                _QuickMenuButton(
                  text: '回退',
                  icon: Icons.undo_outlined,
                  onPressed: widget.onPreviousDialogue,
                  scale: scale,
                  config: config,
                  onHover: (hovering, text) => setState(() {
                    _hoveredButtonText = hovering ? text : null;
                    _hoveredButtonIndex = hovering ? 3 : null;
                  }),
                ),
                _buildDivider(scale, config),
                _QuickMenuButton(
                  text: '设置',
                  icon: Icons.settings_outlined,
                  onPressed: widget.onSettings,
                  scale: scale,
                  config: config,
                  onHover: (hovering, text) => setState(() {
                    _hoveredButtonText = hovering ? text : null;
                    _hoveredButtonIndex = hovering ? 4 : null;
                  }),
                ),
                _buildDivider(scale, config),
                _QuickMenuButton(
                  text: '返回',
                  icon: Icons.arrow_back_rounded,
                  onPressed: widget.onBack,
                  scale: scale,
                  config: config,
                  onHover: (hovering, text) => setState(() {
                    _hoveredButtonText = hovering ? text : null;
                    _hoveredButtonIndex = hovering ? 5 : null;
                  }),
                ),
              ],
            ),
          ),
        ),
        if (_hoveredButtonText != null && _hoveredButtonIndex != null)
          _HoverTooltip(
            text: _hoveredButtonText!,
            scale: scale,
            config: config,
            menuKey: _menuKey,
            buttonIndex: _hoveredButtonIndex!,
          ),
      ],
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
  final Function(bool, String) onHover;

  const _QuickMenuButton({
    required this.text,
    required this.icon,
    required this.onPressed,
    required this.scale,
    required this.config,
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
          widget.onHover(hovering, widget.text);
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
          child: Icon(
            widget.icon,
            color: config.themeColors.primary.withOpacity(0.8),
            size: config.quickMenuTextStyle.fontSize! * scale * 1.3,
          ),
        ),
      ),
    );
  }
}

class _HoverTooltip extends StatelessWidget {
  final String text;
  final double scale;
  final SakiEngineConfig config;
  final GlobalKey menuKey;
  final int buttonIndex;

  const _HoverTooltip({
    required this.text,
    required this.scale,
    required this.config,
    required this.menuKey,
    required this.buttonIndex,
  });

  @override
  Widget build(BuildContext context) {
    const double buttonPadding = 12.0;
    const double dividerHeight = 1.0;
    
    final buttonHeight = (config.quickMenuTextStyle.fontSize! * 1.3) + (buttonPadding * 2);
    double topOffset = 20 * scale + (buttonIndex * (buttonHeight * scale + dividerHeight)) + (buttonHeight * scale / 2) - 15 * scale;

    return Positioned(
      left: (20 + 60) * scale,
      top: topOffset,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 150),
        tween: Tween(begin: 0.0, end: 1.0),
        curve: Curves.easeOutQuart,
        builder: (context, value, child) {
          return Transform.scale(
            scale: 0.8 + (0.2 * value),
            alignment: Alignment.centerLeft,
            child: Opacity(
              opacity: value,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 16 * scale,
                  vertical: 10 * scale,
                ),
                decoration: BoxDecoration(
                  color: config.themeColors.background.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(config.baseWindowBorder > 0 
                      ? config.baseWindowBorder * scale 
                      : 0 * scale),
                  border: Border.all(
                    color: config.themeColors.primary.withOpacity(0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 12 * scale,
                      offset: Offset(-2 * scale, 2 * scale),
                    ),
                    BoxShadow(
                      color: config.themeColors.primary.withOpacity(0.1),
                      blurRadius: 6 * scale,
                      offset: Offset(0, 0),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 4 * scale,
                      height: 20 * scale,
                      decoration: BoxDecoration(
                        color: config.themeColors.primary.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(2 * scale),
                      ),
                    ),
                    SizedBox(width: 12 * scale),
                    Text(
                      text,
                      style: config.quickMenuTextStyle.copyWith(
                        fontSize: config.quickMenuTextStyle.fontSize! * scale * 1.1,
                        color: config.themeColors.primary.withOpacity(0.9),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
