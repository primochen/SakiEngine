import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/asset_manager.dart';

class AnimationKeyframe {
  final String type; // 'ease' or 'linear'
  final double duration;
  final Map<String, double> properties;
  
  AnimationKeyframe({
    required this.type,
    required this.duration,
    required this.properties,
  });
}

class AnimationDefinition {
  final String name;
  final List<AnimationKeyframe> keyframes;
  
  AnimationDefinition({
    required this.name,
    required this.keyframes,
  });
}

class AnimationManager {
  static final Map<String, AnimationDefinition> _animations = {};
  static bool _isLoaded = false;

  static Future<void> loadAnimations() async {
    if (_isLoaded) return;
    
    try {
      final content = await AssetManager().loadString('GameScript/configs/animation.sks');
      _parseAnimations(content);
      _isLoaded = true;
    } catch (e) {
      print('[AnimationManager] 无法加载动画文件: $e');
    }
  }

  static void _parseAnimations(String content) {
    final lines = content.split('\n');
    String? currentAnimationName;
    List<AnimationKeyframe> currentKeyframes = [];
    
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('//')) continue;
      
      if (!trimmed.startsWith('ease') && !trimmed.startsWith('linear')) {
        // 这是动画名称
        if (currentAnimationName != null && currentKeyframes.isNotEmpty) {
          _animations[currentAnimationName] = AnimationDefinition(
            name: currentAnimationName,
            keyframes: List.from(currentKeyframes),
          );
        }
        currentAnimationName = trimmed;
        currentKeyframes.clear();
      } else {
        // 这是关键帧定义
        final keyframe = _parseKeyframe(trimmed);
        if (keyframe != null) {
          currentKeyframes.add(keyframe);
        }
      }
    }
    
    // 处理最后一个动画
    if (currentAnimationName != null && currentKeyframes.isNotEmpty) {
      _animations[currentAnimationName] = AnimationDefinition(
        name: currentAnimationName,
        keyframes: List.from(currentKeyframes),
      );
    }
  }

  static AnimationKeyframe? _parseKeyframe(String line) {
    final parts = line.split(' ');
    if (parts.length < 3) return null;
    
    final type = parts[0]; // 'ease' or 'linear'
    final duration = double.tryParse(parts[1]);
    if (duration == null) return null;
    
    final properties = <String, double>{};
    
    // 解析属性变化 如: ycenter-0.5, xcenter+0.1
    for (int i = 2; i < parts.length; i++) {
      final prop = parts[i];
      final match = RegExp(r'(\w+)([+-])(\d*\.?\d+)').firstMatch(prop);
      if (match != null) {
        final propName = match.group(1)!;
        final operator = match.group(2)!;
        final value = double.parse(match.group(3)!);
        properties[propName] = operator == '+' ? value : -value;
      }
    }
    
    return AnimationKeyframe(
      type: type,
      duration: duration,
      properties: properties,
    );
  }

  static AnimationDefinition? getAnimation(String name) {
    return _animations[name];
  }

  static bool hasAnimation(String name) {
    return _animations.containsKey(name);
  }

  static List<String> getAnimationNames() {
    return _animations.keys.toList();
  }
}

class CharacterAnimationController {
  final String characterId;
  final VoidCallback? onComplete;
  final void Function(Map<String, double>)? onAnimationUpdate;
  
  AnimationController? _controller;
  Animation<double>? _animation;
  Map<String, double> _baseProperties = {};
  Map<String, double> _currentProperties = {};
  
  CharacterAnimationController({
    required this.characterId,
    this.onComplete,
    this.onAnimationUpdate,
  });

  /// 播放角色动画
  Future<void> playAnimation(
    String animationName,
    TickerProvider vsync,
    Map<String, double> baseProperties, {
    int? repeatCount,
  }) async {
    final animDef = AnimationManager.getAnimation(animationName);
    if (animDef == null) {
      print('[CharacterAnimationController] 动画不存在: $animationName');
      onComplete?.call();
      return;
    }

    print('[CharacterAnimationController] 开始播放动画: $animationName, repeat: ${repeatCount ?? "无限"}');
    _baseProperties = Map.from(baseProperties);
    _currentProperties = Map.from(baseProperties);
    
    // 根据repeatCount决定播放次数
    if (repeatCount == null) {
      // 无限循环播放
      await _playInfiniteLoop(animDef.keyframes, vsync);
    } else if (repeatCount > 0) {
      // 循环播放指定次数
      for (int i = 0; i < repeatCount; i++) {
        await _playKeyframes(animDef.keyframes, vsync);
        // 重置位置以便下一次循环
        _currentProperties = Map.from(_baseProperties);
        onAnimationUpdate?.call(Map.from(_currentProperties));
      }
      // 播放完所有循环后，自动添加平滑复原到基础位置
      await _playReturnToBaseAnimation(vsync);
    } else {
      // repeatCount为0，播放一次
      await _playKeyframes(animDef.keyframes, vsync);
      // 自动添加平滑复原到基础位置
      await _playReturnToBaseAnimation(vsync);
    }
    
    print('[CharacterAnimationController] 动画播放完成: $animationName');
    onComplete?.call();
  }

  /// 播放回到基础位置的平滑动画
  Future<void> _playReturnToBaseAnimation(TickerProvider vsync) async {
    // 检查当前属性是否与基础属性不同
    bool needsReturn = false;
    for (final key in _currentProperties.keys) {
      if ((_currentProperties[key] ?? 0.0) != (_baseProperties[key] ?? 0.0)) {
        needsReturn = true;
        break;
      }
    }
    
    if (!needsReturn) return;
    
    // 创建回到基础位置的关键帧（0.3秒平滑过渡）
    final returnKeyframe = AnimationKeyframe(
      type: 'ease',
      duration: 0.3,
      properties: {}, // 空属性表示回到基础值
    );
    
    await _playKeyframe(returnKeyframe, vsync, isReturnAnimation: true);
  }

  /// 无限循环播放动画
  Future<void> _playInfiniteLoop(List<AnimationKeyframe> keyframes, TickerProvider vsync) async {
    // 注意：这里实际上不是真正的无限循环，因为那会阻塞UI
    // 我们播放一次后就停止，让游戏管理器决定是否继续
    // 真正的无限循环需要在游戏管理器层面处理
    await _playKeyframes(keyframes, vsync);
    
    // 重置位置以便可能的下一次循环
    _currentProperties = Map.from(_baseProperties);
    onAnimationUpdate?.call(Map.from(_currentProperties));
    
    // 对于无限循环，我们不添加复原动画，保持在基础位置
  }

  Future<void> _playKeyframes(List<AnimationKeyframe> keyframes, TickerProvider vsync) async {
    for (final keyframe in keyframes) {
      await _playKeyframe(keyframe, vsync);
    }
  }

  Future<void> _playKeyframe(AnimationKeyframe keyframe, TickerProvider vsync, {bool isReturnAnimation = false}) async {
    _controller?.dispose();
    _controller = AnimationController(
      duration: Duration(milliseconds: (keyframe.duration * 1000).round()),
      vsync: vsync,
    );

    final startProperties = Map<String, double>.from(_currentProperties);
    final endProperties = Map<String, double>.from(_currentProperties);
    
    if (isReturnAnimation) {
      // 复原动画：回到基础属性值
      for (final key in _currentProperties.keys) {
        endProperties[key] = _baseProperties[key] ?? 0.0;
      }
    } else {
      // 正常动画：计算结束属性值
      for (final entry in keyframe.properties.entries) {
        final propName = entry.key;
        final offset = entry.value;
        endProperties[propName] = (_baseProperties[propName] ?? 0.0) + offset;
      }
    }

    // 创建动画
    late final CurvedAnimation curvedAnimation;
    if (keyframe.type == 'ease') {
      curvedAnimation = CurvedAnimation(
        parent: _controller!,
        curve: Curves.easeInOut,
      );
    } else {
      curvedAnimation = CurvedAnimation(
        parent: _controller!,
        curve: Curves.linear,
      );
    }

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation);
    
    _animation!.addListener(() {
      final progress = _animation!.value;
      
      if (isReturnAnimation) {
        // 复原动画：插值到基础位置
        for (final propName in _currentProperties.keys) {
          final startValue = startProperties[propName] ?? 0.0;
          final endValue = endProperties[propName] ?? 0.0;
          _currentProperties[propName] = startValue + (endValue - startValue) * progress;
        }
      } else {
        // 正常动画：使用关键帧定义的属性
        for (final propName in keyframe.properties.keys) {
          final startValue = startProperties[propName] ?? 0.0;
          final endValue = endProperties[propName] ?? 0.0;
          _currentProperties[propName] = startValue + (endValue - startValue) * progress;
        }
      }
      
      // 调用实时更新回调
      onAnimationUpdate?.call(Map.from(_currentProperties));
    });

    final completer = Completer<void>();
    _controller!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        completer.complete();
      }
    });

    await _controller!.forward();
    await completer.future;
  }

  Map<String, double> get currentProperties => Map.from(_currentProperties);

  void dispose() {
    _controller?.dispose();
  }
}