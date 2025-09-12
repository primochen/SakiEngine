import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/utils/scaling_manager.dart';
import 'package:sakiengine/src/utils/settings_manager.dart';

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

class _QuickMenuState extends State<QuickMenu> 
    with TickerProviderStateMixin {
  String? _hoveredButtonText;
  int? _hoveredButtonIndex;
  GlobalKey _menuKey = GlobalKey();
  
  // 自动隐藏相关状态
  bool _isAutoHideEnabled = false;
  bool _isMenuHidden = false;
  Timer? _autoHideTimer;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  
  // 常量
  static const Duration _autoHideDelay = Duration(milliseconds: 500);
  static const Duration _animationDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    
    // 初始化滑动动画
    _slideController = AnimationController(
      duration: _animationDuration,
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.8, 0), // 向左滑出80%
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    ));
    
    // 加载设置并监听变化
    _loadAutoHideSetting();
    SettingsManager().addListener(_onSettingsChanged);
    
    // 启动自动隐藏计时器
    _resetAutoHideTimer();
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    _slideController.dispose();
    SettingsManager().removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _loadAutoHideSetting() async {
    final enabled = await SettingsManager().getAutoHideQuickMenu();
    if (mounted) {
      setState(() {
        _isAutoHideEnabled = enabled;
      });
      if (enabled) {
        _resetAutoHideTimer();
      } else {
        _autoHideTimer?.cancel();
        if (_isMenuHidden) {
          _showMenu();
        }
      }
    }
  }

  void _onSettingsChanged() {
    _loadAutoHideSetting();
  }

  void _resetAutoHideTimer() {
    if (!_isAutoHideEnabled) return;
    
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(_autoHideDelay, () {
      if (mounted && !_isMenuHidden) {
        _hideMenu();
      }
    });
  }

  void _hideMenu() {
    if (!_isAutoHideEnabled || _isMenuHidden) return;
    
    setState(() {
      _isMenuHidden = true;
    });
    _slideController.forward();
  }

  void _showMenu() {
    if (!_isMenuHidden) return;
    
    setState(() {
      _isMenuHidden = false;
    });
    _slideController.reverse();
    _resetAutoHideTimer();
  }

  void _onMenuInteraction() {
    if (_isAutoHideEnabled) {
      if (_isMenuHidden) {
        _showMenu();
      } else {
        // 菜单已显示，重置计时器
        _resetAutoHideTimer();
      }
    }
  }

  void _onMenuExit() {
    if (_isAutoHideEnabled && !_isMenuHidden) {
      _resetAutoHideTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = SakiEngineConfig();
    final scale = context.scaleFor(ComponentType.menu);

    return Stack(
      children: [
        // 固定的触发区域 - 始终在左上角，用于隐藏状态下触发显示
        Positioned(
          left: 0,
          top: 0,
          child: MouseRegion(
            onEnter: (_) {
              if (_isAutoHideEnabled && _isMenuHidden) {
                _showMenu();
              }
            },
            child: Container(
              width: 60 * scale, // 触发区域宽度
              height: 200 * scale, // 触发区域高度，覆盖菜单可能的高度
              color: Colors.transparent,
            ),
          ),
        ),
        
        // 实际的快捷菜单
        Positioned(
          left: 20 * scale,
          top: 20 * scale,
          child: AnimatedBuilder(
            animation: _slideAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  _slideAnimation.value.dx * 120 * scale, // 根据缩放调整偏移
                  _slideAnimation.value.dy,
                ),
                child: MouseRegion(
                  onEnter: (_) => _onMenuInteraction(),
                  onExit: (_) => _onMenuExit(),
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
                          onPressed: () {
                            _onMenuInteraction();
                            widget.onSave();
                          },
                          scale: scale,
                          config: config,
                          onHover: (hovering, text) => setState(() {
                            if (hovering) _onMenuInteraction();
                            _hoveredButtonText = hovering ? text : null;
                            _hoveredButtonIndex = hovering ? 0 : null;
                          }),
                        ),
                        _buildDivider(scale, config),
                        _QuickMenuButton(
                          text: '读档',
                          icon: Icons.folder_open_outlined,
                          onPressed: () {
                            _onMenuInteraction();
                            widget.onLoad();
                          },
                          scale: scale,
                          config: config,
                          onHover: (hovering, text) => setState(() {
                            if (hovering) _onMenuInteraction();
                            _hoveredButtonText = hovering ? text : null;
                            _hoveredButtonIndex = hovering ? 1 : null;
                          }),
                        ),
                        _buildDivider(scale, config),
                        _QuickMenuButton(
                          text: '回顾',
                          icon: Icons.auto_stories_outlined,
                          onPressed: () {
                            _onMenuInteraction();
                            widget.onReview();
                          },
                          scale: scale,
                          config: config,
                          onHover: (hovering, text) => setState(() {
                            if (hovering) _onMenuInteraction();
                            _hoveredButtonText = hovering ? text : null;
                            _hoveredButtonIndex = hovering ? 2 : null;
                          }),
                        ),
                        _buildDivider(scale, config),
                        _QuickMenuButton(
                          text: '回退',
                          icon: Icons.undo_outlined,
                          onPressed: () {
                            _onMenuInteraction();
                            widget.onPreviousDialogue();
                          },
                          scale: scale,
                          config: config,
                          onHover: (hovering, text) => setState(() {
                            if (hovering) _onMenuInteraction();
                            _hoveredButtonText = hovering ? text : null;
                            _hoveredButtonIndex = hovering ? 3 : null;
                          }),
                        ),
                        _buildDivider(scale, config),
                        _QuickMenuButton(
                          text: '设置',
                          icon: Icons.settings_outlined,
                          onPressed: () {
                            _onMenuInteraction();
                            widget.onSettings();
                          },
                          scale: scale,
                          config: config,
                          onHover: (hovering, text) => setState(() {
                            if (hovering) _onMenuInteraction();
                            _hoveredButtonText = hovering ? text : null;
                            _hoveredButtonIndex = hovering ? 4 : null;
                          }),
                        ),
                        _buildDivider(scale, config),
                        _QuickMenuButton(
                          text: '返回',
                          icon: Icons.arrow_back_rounded,
                          onPressed: () {
                            _onMenuInteraction();
                            widget.onBack();
                          },
                          scale: scale,
                          config: config,
                          onHover: (hovering, text) => setState(() {
                            if (hovering) _onMenuInteraction();
                            _hoveredButtonText = hovering ? text : null;
                            _hoveredButtonIndex = hovering ? 5 : null;
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
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
