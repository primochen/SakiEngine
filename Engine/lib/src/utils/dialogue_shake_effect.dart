import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 对话框震动效果管理器
/// 当检测到对话中包含感叹号时，触发GAL风格震动（2-3次快速抖动带衰减）
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
    this.duration = const Duration(milliseconds: 100), // 更快的动画速度
  });

  @override
  State<DialogueShakeEffect> createState() => _DialogueShakeEffectState();
}

class _DialogueShakeEffectState extends State<DialogueShakeEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

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
    // GAL风格震动控制器 - 短时间内完成2-3次抖动
    _shakeController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _shakeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_shakeController);
  }

  void _checkForExclamation() {
    if (!widget.enabled) {
      return;
    }

    // 检测中英文感叹号
    final hasExclamation = widget.dialogue.contains('!') || 
                          widget.dialogue.contains('！');
    
    // 如果发现感叹号，触发GAL风格震动
    if (hasExclamation) {
      _triggerShake();
    }
  }

  void _triggerShake() {
    // 重置并启动震动动画
    _shakeController.reset();
    _shakeController.forward();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        final progress = _shakeAnimation.value;
        
        double intensity;
        double offsetY = 0.0;
        double scaleX = 1.0;
        double scaleY = 1.0;
        
        if (progress < 0.4) {
          // 主要撞击：果冻变形 + 轻微向上弹
          final t = progress / 0.4;
          final easedT = Curves.easeInOut.transform(t);
          intensity = 1.0;
          
          // 轻微向上弹跳
          offsetY = -widget.intensity * 0.8 * math.sin(easedT * math.pi) * intensity;
          
          // 果冻变形效果
          scaleX = 1.0 + widget.intensity * 0.05 * math.sin(easedT * math.pi) * intensity;
          scaleY = 1.0 - widget.intensity * 0.04 * math.sin(easedT * math.pi) * intensity;
          
        } else if (progress < 0.65) {
          // 余震衰减：微小的果冻余震
          final t = (progress - 0.4) / 0.25;
          final decay = math.exp(-t * 2);
          intensity = 0.25 * decay;
          
          // 微小的余震变形
          final aftershock = math.sin(t * math.pi * 1.5);
          scaleX = 1.0 + widget.intensity * 0.015 * aftershock * intensity;
          scaleY = 1.0 - widget.intensity * 0.01 * aftershock * intensity;
          
        } else {
          // 二次弹跳：像果冻掉到案板上的轻微反弹
          final t = (progress - 0.65) / 0.35;
          final bounceT = Curves.easeOut.transform(t);
          intensity = 0.3 * (1.0 - t); // 快速衰减
          final easedT = Curves.easeInOut.transform(t);
          // 轻微的二次弹跳
          final bounce = math.sin(bounceT * math.pi);
          offsetY = -widget.intensity * 0.8 * math.sin(easedT * math.pi) * intensity;
          
          // 轻微的二次变形
          scaleX = 1.0 + widget.intensity * 0.03 * bounce * intensity;
          scaleY = 1.0 - widget.intensity * 0.02 * bounce * intensity;
          
          // 最后阶段平滑到静止
          if (t > 0.7) {
            final fadeOut = (1.0 - t) / 0.3;
            offsetY *= fadeOut;
            scaleX = 1.0 + (scaleX - 1.0) * fadeOut;
            scaleY = 1.0 + (scaleY - 1.0) * fadeOut;
          }
        }

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..translate(0.0, offsetY, 0.0)
            ..scale(scaleX, scaleY, 1.0),
          child: widget.child,
        );
      },
    );
  }
}

/// GAL风格果冻震动效果的工具方法类
class ShakeEffectUtils {
  /// 检测文本中是否包含感叹号（中英文）
  static bool containsExclamation(String text) {
    return text.contains('!') || text.contains('！');
  }

  /// 创建纯粹的果冻撞击变形效果矩阵
  static Matrix4 createShakeTransform(double progress, double intensity) {
    double shakeIntensity;
    double offsetY = 0.0;
    double scaleX = 1.0;
    double scaleY = 1.0;
    
    if (progress < 0.6) {
      // 主要撞击变形
      final t = progress / 0.6;
      final easedT = Curves.easeInOut.transform(t);
      shakeIntensity = 1.0;
      
      offsetY = -intensity * 0.8 * math.sin(easedT * math.pi) * shakeIntensity;
      scaleX = 1.0 + intensity * 0.05 * math.sin(easedT * math.pi) * shakeIntensity;
      scaleY = 1.0 - intensity * 0.04 * math.sin(easedT * math.pi) * shakeIntensity;
      
    } else {
      // 果冻余震衰减
      final t = (progress - 0.6) / 0.4;
      final decay = math.exp(-t * 4);
      final easedDecay = Curves.easeOut.transform(decay);
      shakeIntensity = 0.3 * easedDecay;
      
      final aftershock = math.sin(t * math.pi * 3);
      scaleX = 1.0 + intensity * 0.02 * aftershock * shakeIntensity;
      scaleY = 1.0 - intensity * 0.015 * aftershock * shakeIntensity;
      
      // 接近静止时平滑过渡
      if (shakeIntensity < 0.01) {
        scaleX = 1.0 + (scaleX - 1.0) * (shakeIntensity / 0.01);
        scaleY = 1.0 + (scaleY - 1.0) * (shakeIntensity / 0.01);
      }
    }
    
    return Matrix4.identity()
      ..translate(0.0, offsetY, 0.0)
      ..scale(scaleX, scaleY, 1.0);
  }

  /// 获取纯粹的果冻撞击效果偏移量
  static Offset getShakeOffset(double progress, double intensity) {
    double offsetY = 0.0;
    
    if (progress < 0.6) {
      // 主要撞击，轻微向上弹跳
      final t = progress / 0.6;
      final easedT = Curves.easeInOut.transform(t);
      
      offsetY = -intensity * 0.8 * math.sin(easedT * math.pi);
    }
    // 衰减阶段不需要位移，只有变形
    
    return Offset(0, offsetY);
  }
}

/// 简化版本的GAL震动Widget，可以直接包装任何组件
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
    this.duration = const Duration(milliseconds: 150),
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
    ).animate(_controller);

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
    
    // 检测trigger从false变为true时触发GAL震动
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
        final transform = ShakeEffectUtils.createShakeTransform(
          _animation.value, 
          widget.intensity
        );
        
        return Transform(
          alignment: Alignment.center,
          transform: transform,
          child: widget.child,
        );
      },
    );
  }
}