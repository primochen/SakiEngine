import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/asset_manager.dart';
import 'package:sakiengine/src/utils/image_loader.dart';

/// 转场效果类型枚举
enum TransitionType {
  fade,  // 黑屏淡入淡出 (原有效果)
  diss,  // 直接图片渐变过渡
  wipe,  // 擦除效果 (未来扩展)
  slide, // 滑动效果 (未来扩展)
}

/// 转场效果管理器
class SceneTransitionEffectManager {
  static SceneTransitionEffectManager? _instance;
  static SceneTransitionEffectManager get instance => 
      _instance ??= SceneTransitionEffectManager._();
  
  SceneTransitionEffectManager._();
  
  OverlayEntry? _overlayEntry;
  bool _isTransitioning = false;
  
  /// 执行场景转场
  /// [context] 用于创建覆盖层的上下文
  /// [transitionType] 转场类型
  /// [onMidTransition] 在转场中点执行的回调（切换场景时机）
  /// [duration] 转场时长
  /// [oldBackground] 旧背景名称（用于diss效果）
  /// [newBackground] 新背景名称（用于diss效果）
  Future<void> transition({
    required BuildContext context,
    required TransitionType transitionType,
    required VoidCallback onMidTransition,
    Duration duration = const Duration(milliseconds: 800),
    String? oldBackground,
    String? newBackground,
  }) async {
    print('[SceneTransition] 请求${transitionType.name}转场，当前状态: isTransitioning=$_isTransitioning');
    if (_isTransitioning) return;
    
    _isTransitioning = true;
    print('[SceneTransition] 开始${transitionType.name}转场，时长: ${duration.inMilliseconds}ms');
    
    final completer = Completer<void>();
    
    // 根据转场类型创建不同的覆盖层
    Widget transitionWidget;
    switch (transitionType) {
      case TransitionType.fade:
        transitionWidget = _FadeTransitionOverlay(
          duration: duration,
          onMidTransition: onMidTransition,
          onComplete: () {
            print('[SceneTransition] fade转场完成，移除覆盖层');
            _removeOverlay();
            _isTransitioning = false;
            completer.complete();
          },
        );
        break;
      case TransitionType.diss:
        transitionWidget = _DissTransitionOverlay(
          duration: duration,
          onMidTransition: onMidTransition,
          onComplete: () {
            print('[SceneTransition] diss转场完成，移除覆盖层');
            _removeOverlay();
            _isTransitioning = false;
            completer.complete();
          },
          oldBackgroundName: oldBackground,
          newBackgroundName: newBackground,
        );
        break;
      default:
        // 默认使用fade效果
        transitionWidget = _FadeTransitionOverlay(
          duration: duration,
          onMidTransition: onMidTransition,
          onComplete: () {
            print('[SceneTransition] 默认fade转场完成，移除覆盖层');
            _removeOverlay();
            _isTransitioning = false;
            completer.complete();
          },
        );
    }
    
    // 创建覆盖层
    _overlayEntry = OverlayEntry(
      builder: (context) => transitionWidget,
    );
    
    // 插入覆盖层
    print('[SceneTransition] 插入${transitionType.name}转场覆盖层');
    Overlay.of(context).insert(_overlayEntry!);
    
    return completer.future;
  }
  
  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
  
  bool get isTransitioning => _isTransitioning;
}

/// 黑屏淡入淡出转场覆盖层（原有效果）
class _FadeTransitionOverlay extends StatefulWidget {
  final Duration duration;
  final VoidCallback onMidTransition;
  final VoidCallback onComplete;
  
  const _FadeTransitionOverlay({
    required this.duration,
    required this.onMidTransition,
    required this.onComplete,
  });
  
  @override
  State<_FadeTransitionOverlay> createState() => _FadeTransitionOverlayState();
}

class _FadeTransitionOverlayState extends State<_FadeTransitionOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeOutAnimation;
  late Animation<double> _fadeInAnimation;
  bool _midTransitionExecuted = false;
  
  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    
    // 前半段：淡出到黑屏 (0 -> 1)
    _fadeOutAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
    ));
    
    // 后半段：从黑屏淡入 (1 -> 0)
    _fadeInAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 1.0, curve: Curves.easeInOut),
    ));
    
    _controller.addListener(_onAnimationUpdate);
    _controller.addStatusListener(_onAnimationStatus);
    
    // 开始动画
    _controller.forward();
  }
  
  void _onAnimationUpdate() {
    // 在动画中点执行场景切换
    if (!_midTransitionExecuted && _controller.value >= 0.5) {
      _midTransitionExecuted = true;
      print('[FadeTransition] 到达转场中点，执行回调');
      widget.onMidTransition();
    }
  }
  
  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onComplete();
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // 计算当前黑屏不透明度
        double opacity;
        if (_controller.value <= 0.5) {
          // 前半段：淡出到黑屏
          opacity = _fadeOutAnimation.value;
        } else {
          // 后半段：从黑屏淡入
          opacity = _fadeInAnimation.value;
        }
        
        return Material(
          color: Colors.black.withOpacity(opacity),
          child: const SizedBox(
            width: double.infinity,
            height: double.infinity,
          ),
        );
      },
    );
  }
}

/// 图片直接渐变转场覆盖层（使用dissolve着色器效果）
class _DissTransitionOverlay extends StatefulWidget {
  final Duration duration;
  final VoidCallback onMidTransition;
  final VoidCallback onComplete;
  final String? oldBackgroundName;
  final String? newBackgroundName;
  
  const _DissTransitionOverlay({
    required this.duration,
    required this.onMidTransition,
    required this.onComplete,
    this.oldBackgroundName,
    this.newBackgroundName,
  });
  
  @override
  State<_DissTransitionOverlay> createState() => _DissTransitionOverlayState();
}

class _DissTransitionOverlayState extends State<_DissTransitionOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _dissAnimation;
  bool _midTransitionExecuted = false;
  
  ui.Image? _oldImage;
  ui.Image? _newImage;
  static ui.FragmentProgram? _dissolveProgram;
  
  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    
    // 溶解动画：从旧背景溶解到新背景 (0 -> 1)
    _dissAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    
    _controller.addListener(_onAnimationUpdate);
    _controller.addStatusListener(_onAnimationStatus);
    
    // 加载图片和着色器
    _loadImages();
    _loadShader();
  }
  
  Future<void> _loadShader() async {
    if (_dissolveProgram == null) {
      try {
        final program = await ui.FragmentProgram.fromAsset('assets/shaders/dissolve.frag');
        _dissolveProgram = program;
      } catch (e) {
        print('Error loading dissolve shader: $e');
      }
    }
  }
  
  Future<void> _loadImages() async {
    bool shouldStartAnimation = true;
    
    // 加载旧背景图片
    if (widget.oldBackgroundName != null) {
      final oldAssetPath = await AssetManager().findAsset(widget.oldBackgroundName!);
      if (oldAssetPath != null && mounted) {
        final oldImage = await ImageLoader.loadImage(oldAssetPath);
        if (mounted && oldImage != null) {
          setState(() {
            _oldImage = oldImage;
          });
        }
      }
    }
    
    // 加载新背景图片
    if (widget.newBackgroundName != null) {
      final newAssetPath = await AssetManager().findAsset(widget.newBackgroundName!);
      if (newAssetPath != null && mounted) {
        final newImage = await ImageLoader.loadImage(newAssetPath);
        if (mounted && newImage != null) {
          setState(() {
            _newImage = newImage;
          });
        } else {
          print('[DissTransition] 警告: 新背景图片加载失败: ${widget.newBackgroundName}');
          shouldStartAnimation = true; // 即使图片加载失败也要开始动画
        }
      } else {
        print('[DissTransition] 警告: 找不到新背景资源: ${widget.newBackgroundName}');
        shouldStartAnimation = true; // 即使找不到资源也要开始动画
      }
    }
    
    // 无论图片是否加载成功，都要开始动画，避免转场卡住
    if (shouldStartAnimation) {
      _controller.forward();
    }
  }
  
  void _onAnimationUpdate() {
    // 在动画中点执行场景切换
    if (!_midTransitionExecuted && _controller.value >= 0.5) {
      _midTransitionExecuted = true;
      print('[DissTransition] 到达转场中点，执行回调');
      widget.onMidTransition();
    }
  }
  
  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onComplete();
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    _oldImage?.dispose();
    _newImage?.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _dissAnimation,
      builder: (context, child) {
        // 如果没有图片，使用黑色遮罩进行渐变过渡
        if (_oldImage == null && _newImage == null) {
          return Material(
            color: Colors.black.withOpacity(
              _dissAnimation.value > 0.5 
                ? 2.0 * (1.0 - _dissAnimation.value) 
                : 2.0 * _dissAnimation.value
            ),
            child: const SizedBox(
              width: double.infinity,
              height: double.infinity,
            ),
          );
        }
        
        // 使用Flutter原生的图片渐变
        return Stack(
          fit: StackFit.expand,
          children: [
            // 旧背景，逐渐淡出
            if (_oldImage != null)
              Opacity(
                opacity: 1.0 - _dissAnimation.value,
                child: RawImage(
                  image: _oldImage!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            // 新背景，逐渐淡入（如果没有新图片，就不显示）
            if (_newImage != null)
              Opacity(
                opacity: _dissAnimation.value,
                child: RawImage(
                  image: _newImage!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
          ],
        );
      },
    );
  }
}


/// 转场类型解析工具
class TransitionTypeParser {
  static TransitionType parseTransitionType(String transitionString) {
    switch (transitionString.toLowerCase().trim()) {
      case 'fade':
        return TransitionType.fade;
      case 'diss':
      case 'dissolve':
        return TransitionType.diss;
      case 'wipe':
        return TransitionType.wipe;
      case 'slide':
        return TransitionType.slide;
      default:
        return TransitionType.fade; // 默认使用fade
    }
  }
}