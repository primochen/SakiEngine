import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/utils/scaling_manager.dart';

/// 快进状态指示器
/// 
/// 在快捷菜单下方显示快进状态的指示器
class FastForwardIndicator extends StatefulWidget {
  final bool isFastForwarding;
  final Duration animationDuration;
  
  const FastForwardIndicator({
    super.key,
    required this.isFastForwarding,
    this.animationDuration = const Duration(milliseconds: 300),
  });
  
  @override
  State<FastForwardIndicator> createState() => _FastForwardIndicatorState();
}

class _FastForwardIndicatorState extends State<FastForwardIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    // 根据初始状态设置动画
    if (widget.isFastForwarding) {
      _animationController.forward();
      _startPulseAnimation();
    }
  }
  
  @override
  void didUpdateWidget(FastForwardIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.isFastForwarding != widget.isFastForwarding) {
      if (widget.isFastForwarding) {
        _animationController.forward();
        _startPulseAnimation();
      } else {
        _animationController.reverse();
      }
    }
  }
  
  void _startPulseAnimation() {
    // 快进时不使用脉冲动画，保持稳定显示
    if (widget.isFastForwarding) {
      _animationController.stop();
      _animationController.value = 1.0; // 保持完全显示
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final config = SakiEngineConfig();
    final scale = context.scaleFor(ComponentType.menu);
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        // 快进时始终显示，不快进时淡出
        if (!widget.isFastForwarding && _opacityAnimation.value <= 0.0) {
          return const SizedBox.shrink();
        }
        
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: widget.isFastForwarding ? 1.0 : _opacityAnimation.value,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 12 * scale, 
                vertical: 8 * scale
              ),
              decoration: BoxDecoration(
                color: config.themeColors.background.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(
                  config.baseWindowBorder > 0 
                      ? config.baseWindowBorder * scale 
                      : 0 * scale
                ),
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.fast_forward,
                    color: config.themeColors.primary,
                    size: 18 * scale,
                  ),
                  SizedBox(width: 6 * scale),
                  Text(
                    '正在快进......',
                    style: config.quickMenuTextStyle.copyWith(
                      color: config.themeColors.primary,
                      fontSize: config.quickMenuTextStyle.fontSize! * scale,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}