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
  double _shakeIntensity = 0.0; // 当前震动强度
  late AnimationController _intensityController;
  late Animation<double> _intensityAnimation;

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
    // 震动频率控制器（按需启动）
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 42), // ~24Hz
      vsync: this,
    );

    _shakeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_shakeController);

    // 强度控制器（控制震动衰减）
    _intensityController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _intensityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _intensityController,
      curve: Curves.easeOut,
    ));

    // 监听强度动画完成事件
    _intensityController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // 震动结束时停止高频震动动画
        _shakeController.stop();
      }
    });
  }

  void _checkForExclamation() {
    if (!widget.enabled) {
      return;
    }

    // 检测中英文感叹号
    final hasExclamation = widget.dialogue.contains('!') || 
                          widget.dialogue.contains('！');
    
    // 如果发现感叹号，启动震动效果
    if (hasExclamation) {
      _startShakeEffect();
    }
  }

  void _startShakeEffect() {
    // 启动高频震动动画
    _shakeController.repeat();
    
    // 重置并启动强度衰减动画
    _intensityController.reset();
    _intensityController.forward();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _intensityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_shakeAnimation, _intensityAnimation]),
      builder: (context, child) {
        // 计算当前的震动偏移
        final shakeValue = math.sin(_shakeAnimation.value * 2 * math.pi);
        final currentIntensity = widget.intensity * _intensityAnimation.value;
        final shake = currentIntensity * shakeValue;

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