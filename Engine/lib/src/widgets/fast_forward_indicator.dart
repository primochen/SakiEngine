import 'package:flutter/material.dart';

/// 快进状态指示器
/// 
/// 在屏幕右上角显示快进状态的小图标
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
  late Animation<double> _pulseAnimation;
  
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
    
    // 脉搏动画，快进时持续播放
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
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
    if (widget.isFastForwarding) {
      _animationController.repeat(reverse: true);
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 60,
      right: 20,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          if (!widget.isFastForwarding && _opacityAnimation.value <= 0.0) {
            return const SizedBox.shrink();
          }
          
          return Transform.scale(
            scale: _scaleAnimation.value * 
                   (widget.isFastForwarding ? _pulseAnimation.value : 1.0),
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.fast_forward,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '快进',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.5),
                            offset: const Offset(1, 1),
                            blurRadius: 2,
                          ),
                        ],
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