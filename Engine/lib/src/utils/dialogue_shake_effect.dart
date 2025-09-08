import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 对话框震动效果管理器
/// 当检测到对话中包含感叹号时，触发震动动画
class DialogueShakeEffect extends StatefulWidget {
  final Widget child;
  final String dialogue;
  final bool enabled;
  final double intensity;
  final Duration duration;

  const DialogueShakeEffect({
    super.key,
    required this.child,
    required this.dialogue,
    this.enabled = true,
    this.intensity = 3.0,
    this.duration = const Duration(milliseconds: 500),
  });

  @override
  State<DialogueShakeEffect> createState() => _DialogueShakeEffectState();
}

class _DialogueShakeEffectState extends State<DialogueShakeEffect>
    with TickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  bool _shouldShake = false;

  @override
  void initState() {
    super.initState();
    _initializeShakeAnimation();
    _checkForExclamation();
  }

  @override
  void didUpdateWidget(DialogueShakeEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 如果对话内容发生变化，重新检查是否需要震动
    if (widget.dialogue != oldWidget.dialogue) {
      _checkForExclamation();
    }
  }

  void _initializeShakeAnimation() {
    _shakeController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _shakeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticOut,
    ));
  }

  void _checkForExclamation() {
    if (!widget.enabled) {
      _shouldShake = false;
      return;
    }

    // 检测中英文感叹号
    final hasExclamation = widget.dialogue.contains('!') || 
                          widget.dialogue.contains('！');
    
    if (hasExclamation != _shouldShake) {
      setState(() {
        _shouldShake = hasExclamation;
      });
      
      if (_shouldShake) {
        _triggerShake();
      }
    }
  }

  void _triggerShake() {
    if (_shakeController.isAnimating) {
      _shakeController.reset();
    }
    _shakeController.forward();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShake) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        final shakeValue = _shakeAnimation.value;
        final shake = widget.intensity * 
                      math.sin(shakeValue * math.pi * 12) * 
                      (1.0 - shakeValue);

        return Transform.translate(
          offset: Offset(shake, 0),
          child: widget.child,
        );
      },
    );
  }
}

/// 震动效果的工具方法类
class ShakeEffectUtils {
  /// 检测文本中是否包含感叹号（中英文）
  static bool containsExclamation(String text) {
    return text.contains('!') || text.contains('！');
  }

  /// 创建震动变换矩阵
  static Matrix4 createShakeTransform(double progress, double intensity) {
    final shake = intensity * math.sin(progress * math.pi * 12) * (1.0 - progress);
    return Matrix4.translationValues(shake, 0.0, 0.0);
  }

  /// 获取震动偏移量
  static Offset getShakeOffset(double progress, double intensity) {
    final shake = intensity * math.sin(progress * math.pi * 12) * (1.0 - progress);
    return Offset(shake, 0);
  }
}

/// 简化版本的震动Widget，可以直接包装任何组件
class SimpleShakeWrapper extends StatefulWidget {
  final Widget child;
  final bool trigger;
  final double intensity;
  final Duration duration;
  final VoidCallback? onShakeComplete;

  const SimpleShakeWrapper({
    super.key,
    required this.child,
    required this.trigger,
    this.intensity = 3.0,
    this.duration = const Duration(milliseconds: 500),
    this.onShakeComplete,
  });

  @override
  State<SimpleShakeWrapper> createState() => _SimpleShakeWrapperState();
}

class _SimpleShakeWrapperState extends State<SimpleShakeWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _lastTrigger = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _animation.addStatusListener((status) {
      if (status == AnimationStatus.completed && widget.onShakeComplete != null) {
        widget.onShakeComplete!();
      }
    });

    _lastTrigger = widget.trigger;
  }

  @override
  void didUpdateWidget(SimpleShakeWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 检测trigger从false变为true时触发震动
    if (!_lastTrigger && widget.trigger) {
      _controller.reset();
      _controller.forward();
    }
    _lastTrigger = widget.trigger;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final offset = ShakeEffectUtils.getShakeOffset(
          _animation.value, 
          widget.intensity
        );
        
        return Transform.translate(
          offset: offset,
          child: widget.child,
        );
      },
    );
  }
}