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
  /// 预热dissolve着色器和图片加载流程
  Future<void> prewarm(BuildContext context) async {
    if (_isPrewarming || _isPrewarmed) return;
    
    _isPrewarming = true;
    //print('[TransitionPrewarming] 开始转场预热');
    
    try {
      // 预热dissolve着色器
      await _prewarmDissolveShader();
      
      // 预热图片加载流程
      await _prewarmImageLoading();
      
      _isPrewarmed = true;
      //print('[TransitionPrewarming] 转场预热完成');
    } catch (e) {
      //print('[TransitionPrewarming] 转场预热失败: $e');
    } finally {
      _isPrewarming = false;
    }
  }
  
  /// 预热dissolve着色器
  Future<void> _prewarmDissolveShader() async {
    try {
      //print('[TransitionPrewarming] 预热dissolve着色器');
      await ui.FragmentProgram.fromAsset('assets/shaders/dissolve.frag');
    } catch (e) {
      //print('[TransitionPrewarming] 着色器预热失败: $e');
    }
  }
  
  /// 预热图片加载流程
  Future<void> _prewarmImageLoading() async {
    try {
      //print('[TransitionPrewarming] 预热图片加载流程');
      
      // 尝试加载一个默认背景来预热图片加载管道
      final assetManager = AssetManager();
      
      // 查找可能存在的背景图片进行预热
      const testBackgrounds = ['school', 'sky', 'bg-school', 'chapter0'];
      
      for (final bgName in testBackgrounds) {
        final assetPath = await assetManager.findAsset(bgName);
        if (assetPath != null) {
          //print('[TransitionPrewarming] 找到预热背景: $bgName');
          final image = await ImageLoader.loadImage(assetPath);
          // 立即释放图片内存，我们只是想预热加载流程
          image?.dispose();
          break;
        }
      }
    } catch (e) {
      //print('[TransitionPrewarming] 图片加载预热失败: $e');
    }
  }
  
  bool get isPrewarmed => _isPrewarmed;
}

