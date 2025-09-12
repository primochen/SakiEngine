import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/utils/scaling_manager.dart';
import 'package:sakiengine/src/utils/settings_manager.dart';
import 'package:sakiengine/src/widgets/animated_tooltip.dart';

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
  final GlobalKey _menuKey = GlobalKey();
  
  // 自动隐藏相关状态
  bool _isAutoHideEnabled = false;
  bool _isMenuHidden = false;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  
  // 常量
  static const Duration _animationDuration = Duration(milliseconds: 200);

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
    
    // 初始状态：如果开启自动隐藏，则隐藏菜单
    if (_isAutoHideEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _hideMenu();
      });
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    SettingsManager().removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _loadAutoHideSetting() async {
    final enabled = await SettingsManager().getAutoHideQuickMenu();
    if (mounted) {
      final wasEnabled = _isAutoHideEnabled;
      setState(() {
        _isAutoHideEnabled = enabled;
      });
      
      // 设置变化时的处理
      if (enabled && !wasEnabled) {
        // 刚开启自动隐藏
        _hideMenu();
      } else if (!enabled && wasEnabled) {
        // 刚关闭自动隐藏
        if (_isMenuHidden) {
          _showMenu();
        }
      }
    }
  }

  void _onSettingsChanged() {
    _loadAutoHideSetting();
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
  }

  void _onTriggerAreaEnter() {
    if (_isAutoHideEnabled && _isMenuHidden) {
      _showMenu();
    }
  }

  void _onTriggerAreaExit() {
    if (_isAutoHideEnabled && !_isMenuHidden) {
      _hideMenu();
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = SakiEngineConfig();
    final scale = context.scaleFor(ComponentType.menu);
    final screenSize = MediaQuery.of(context).size;

    return Stack(
      children: [
        // 触发区域 - 窗口高度的一半，放在最底层
        Positioned(
          left: 0,
          top: 0,
          child: MouseRegion(
            onEnter: (_) => _onTriggerAreaEnter(),
            onExit: (_) => _onTriggerAreaExit(),
            child: Container(
              // 快捷菜单是竖排，所以触发区域是窗口高度的一半
              width: 100 * scale, // 左边缘触发区域
              height: screenSize.height * 0.5, // 窗口高度的一半
              color: Colors.transparent,
            ),
          ),
        ),
        
        // 实际的快捷菜单 - 放在触发区域之上，但确保不完全遮挡触发区域
        Positioned(
          left: 20 * scale,
          top: 20 * scale,
          child: MouseRegion(
            onEnter: (_) => _onTriggerAreaEnter(), // 菜单本身也能触发显示
            onExit: (_) {
              // 只有当鼠标完全离开整个左侧区域时才隐藏
              // 这里不立即隐藏，让外层的MouseRegion处理
            },
            child: AnimatedBuilder(
              animation: _slideAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                    _slideAnimation.value.dx * 120 * scale, // 根据缩放调整偏移
                    _slideAnimation.value.dy,
                  ),
                  child: Container(
                    key: _menuKey,
                    decoration: BoxDecoration(
                      color: config.themeColors.background.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(config.baseWindowBorder > 0 
                          ? config.baseWindowBorder * scale 
                          : 0 * scale),
                      border: Border.all(
                        color: config.themeColors.primary.withValues(alpha: 0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
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
                );
              },
            ),
          ),
        ),
        
        if (_hoveredButtonText != null && _hoveredButtonIndex != null)
          AnimatedTooltip(
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
      width: 40 * scale,
      margin: EdgeInsets.symmetric(horizontal: 8 * scale),
      child: Divider(
        height: 0,
        thickness: 1.5 * scale,
        color: config.themeColors.primary.withValues(alpha: 0.6),
      ),
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

class _QuickMenuButtonState extends State<_QuickMenuButton> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
    
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.1, // 轻微旋转
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    final config = widget.config;
    
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 48 * scale,
        height: 48 * scale,
        margin: EdgeInsets.symmetric(horizontal: 2 * scale, vertical: 4 * scale),
        child: InkWell(
          onTap: widget.onPressed,
          onHover: (hovering) {
            setState(() => _isHovered = hovering);
            widget.onHover(hovering, widget.text);
            
            if (hovering) {
              _animationController.forward();
            } else {
              _animationController.reverse();
            }
          },
          hoverColor: config.themeColors.primary.withValues(alpha: 0.1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48 * scale,
            height: 48 * scale,
            decoration: BoxDecoration(
              color: _isHovered 
                  ? config.themeColors.primary.withValues(alpha: 0.05)
                  : Colors.transparent,
            ),
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Center(
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Transform.rotate(
                      angle: _rotationAnimation.value,
                      child: Icon(
                        widget.icon,
                        color: config.themeColors.primary,
                        size: config.quickMenuTextStyle.fontSize! * scale * 1.3,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

