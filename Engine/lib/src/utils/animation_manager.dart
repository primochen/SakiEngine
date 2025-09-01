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
  
  AnimationController? _controller;
  Animation<double>? _animation;
  Map<String, double> _baseProperties = {};
  Map<String, double> _currentProperties = {};
  
  CharacterAnimationController({
    required this.characterId,
    this.onComplete,
  });

  Future<void> playAnimation(
    String animationName,
    TickerProvider vsync,
    Map<String, double> baseProperties,
  ) async {
    final animDef = AnimationManager.getAnimation(animationName);
    if (animDef == null) {
      print('[CharacterAnimationController] 动画不存在: $animationName');
      onComplete?.call();
      return;
    }

    _baseProperties = Map.from(baseProperties);
    _currentProperties = Map.from(baseProperties);
    
    await _playKeyframes(animDef.keyframes, vsync);
    onComplete?.call();
  }

  Future<void> _playKeyframes(List<AnimationKeyframe> keyframes, TickerProvider vsync) async {
    for (final keyframe in keyframes) {
      await _playKeyframe(keyframe, vsync);
    }
  }

  Future<void> _playKeyframe(AnimationKeyframe keyframe, TickerProvider vsync) async {
    _controller?.dispose();
    _controller = AnimationController(
      duration: Duration(milliseconds: (keyframe.duration * 1000).round()),
      vsync: vsync,
    );

    final startProperties = Map<String, double>.from(_currentProperties);
    final endProperties = Map<String, double>.from(_currentProperties);
    
    // 计算结束属性值
    for (final entry in keyframe.properties.entries) {
      final propName = entry.key;
      final offset = entry.value;
      endProperties[propName] = (_baseProperties[propName] ?? 0.0) + offset;
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
      for (final propName in keyframe.properties.keys) {
        final startValue = startProperties[propName] ?? 0.0;
        final endValue = endProperties[propName] ?? 0.0;
        _currentProperties[propName] = startValue + (endValue - startValue) * progress;
      }
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