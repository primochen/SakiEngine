import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/asset_manager.dart';
import 'package:sakiengine/src/utils/image_loader.dart';

/// 转场效果预热管理器
/// 在游戏启动时预热转场效果，避免首次使用时卡顿
class TransitionPrewarmingManager {
  static TransitionPrewarmingManager? _instance;
  static TransitionPrewarmingManager get instance => 
      _instance ??= TransitionPrewarmingManager._();
  
  TransitionPrewarmingManager._();
  
  bool _isPrewarming = false;
  bool _isPrewarmed = false;
  
  /// 执行预热
  /// 创建纯黑色遮罩，在遮罩下预热主菜单和转场效果
  Future<void> prewarm(BuildContext context) async {
    if (_isPrewarming || _isPrewarmed) return;
    
    _isPrewarming = true;
    print('[TransitionPrewarming] 开始预热转场效果');
    
    final completer = Completer<void>();
    
    // 创建预热覆盖层
    final overlayEntry = OverlayEntry(
      builder: (context) => _PrewarmingOverlay(
        onComplete: () {
          _isPrewarming = false;
          _isPrewarmed = true;
          print('[TransitionPrewarming] 预热完成');
          completer.complete();
        },
      ),
    );
    
    // 插入覆盖层
    Overlay.of(context).insert(overlayEntry);
    
    // 等待预热完成后移除覆盖层
    await completer.future;
    overlayEntry.remove();
  }
  
  bool get isPrewarmed => _isPrewarmed;
}

/// 预热覆盖层
/// 创建纯黑色遮罩，持续100ms然后淡出
class _PrewarmingOverlay extends StatefulWidget {
  final VoidCallback onComplete;
  
  const _PrewarmingOverlay({
    required this.onComplete,
  });
  
  @override
  State<_PrewarmingOverlay> createState() => _PrewarmingOverlayState();
}

class _PrewarmingOverlayState extends State<_PrewarmingOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeOutAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200), // 总时长200ms
      vsync: this,
    );
    
    // 淡出动画：从不透明到透明
    _fadeOutAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOut), // 后半段淡出
    ));
    
    _controller.addStatusListener(_onAnimationStatus);
    
    // 开始预热流程
    _startPrewarming();
  }
  
  Future<void> _startPrewarming() async {
    // 预热dissolve着色器
    await _prewarmDissolveShader();
    
    // 预热图片加载
    await _prewarmImageLoading();
    
    // 等待100ms保持黑屏
    await Future.delayed(const Duration(milliseconds: 100));
    
    // 开始淡出动画
    if (mounted) {
      _controller.forward();
    }
  }
  
  /// 预热dissolve着色器
  Future<void> _prewarmDissolveShader() async {
    try {
      print('[TransitionPrewarming] 预热dissolve着色器');
      await ui.FragmentProgram.fromAsset('assets/shaders/dissolve.frag');
    } catch (e) {
      print('[TransitionPrewarming] 着色器预热失败: $e');
    }
  }
  
  /// 预热图片加载流程
  Future<void> _prewarmImageLoading() async {
    try {
      print('[TransitionPrewarming] 预热图片加载流程');
      
      // 尝试加载一个默认背景来预热图片加载管道
      final assetManager = AssetManager();
      
      // 查找可能存在的背景图片进行预热
      const testBackgrounds = ['school', 'sky', 'bg-school', 'chapter0'];
      
      for (final bgName in testBackgrounds) {
        final assetPath = await assetManager.findAsset(bgName);
        if (assetPath != null) {
          print('[TransitionPrewarming] 找到预热背景: $bgName');
          final image = await ImageLoader.loadImage(assetPath);
          // 立即释放图片内存，我们只是想预热加载流程
          image?.dispose();
          break;
        }
      }
    } catch (e) {
      print('[TransitionPrewarming] 图片加载预热失败: $e');
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
        // 计算黑屏不透明度
        double opacity;
        if (_controller.value <= 0.5) {
          // 前半段：保持完全不透明
          opacity = 1.0;
        } else {
          // 后半段：淡出
          opacity = _fadeOutAnimation.value;
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