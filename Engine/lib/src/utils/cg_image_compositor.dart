import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:sakiengine/src/config/asset_manager.dart';
import 'package:sakiengine/src/utils/character_layer_parser.dart';
import 'package:sakiengine/src/utils/image_loader.dart';

/// CG图像合成器 - 负责将多层图像合成为单张图像并内存缓存
/// 
/// 功能：
/// - 将CG的所有差分图层（背景、表情、帽子等）合成为单张图像
/// - 智能内存缓存管理，避免重复合成
/// - 跨平台兼容，包括Web版本
class CgImageCompositor {
  static final CgImageCompositor _instance = CgImageCompositor._internal();
  factory CgImageCompositor() => _instance;
  CgImageCompositor._internal();

  /// 内存缓存：缓存键 -> 合成图像的字节数据
  final Map<String, Uint8List> _imageCache = {};
  
  /// 内存缓存：缓存键 -> 合成图像路径（虚拟路径，用于兼容现有API）
  final Map<String, String> _compositePathCache = {};
  
  /// 正在合成的任务，避免重复合成
  final Map<String, Future<String?>> _compositingTasks = {};

  /// 生成缓存键
  String _generateCacheKey(String resourceId, String pose, String expression) {
    return '${resourceId}_${pose}_$expression';
  }

  /// 生成虚拟缓存路径 - 用于兼容现有API
  String _generateVirtualPath(String cacheKey) {
    return '/memory_cache/cg_cache/$cacheKey.png';
  }

  /// 获取或生成合成CG图像的路径
  /// 
  /// 返回合成图像的虚拟路径，如果合成失败则返回null
  /// 实际图像数据存储在内存中，通过getImageBytes方法获取
  Future<String?> getCompositeImagePath({
    required String resourceId,
    required String pose,
    required String expression,
  }) async {
    final cacheKey = _generateCacheKey(resourceId, pose, expression);
    
    // 检查内存缓存
    if (_compositePathCache.containsKey(cacheKey) && _imageCache.containsKey(cacheKey)) {
      return _compositePathCache[cacheKey];
    }

    // 检查是否已经在合成中
    if (_compositingTasks.containsKey(cacheKey)) {
      return await _compositingTasks[cacheKey];
    }

    // 开始新的合成任务
    final compositeTask = _performComposition(resourceId, pose, expression, cacheKey);
    _compositingTasks[cacheKey] = compositeTask;

    try {
      final result = await compositeTask;
      return result;
    } finally {
      // 清除合成任务记录
      _compositingTasks.remove(cacheKey);
    }
  }

  /// 获取缓存的图像字节数据
  /// 
  /// 根据路径或缓存键获取图像的字节数据
  Uint8List? getImageBytes(String pathOrKey) {
    // 如果是虚拟路径，提取缓存键
    if (pathOrKey.startsWith('/memory_cache/cg_cache/')) {
      final filename = pathOrKey.split('/').last;
      final cacheKey = filename.replaceAll('.png', '');
      return _imageCache[cacheKey];
    }
    
    // 直接作为缓存键查找
    return _imageCache[pathOrKey];
  }

  /// 执行实际的图像合成
  Future<String?> _performComposition(String resourceId, String pose, String expression, String cacheKey) async {
    try {
      if (kIsWeb) {
        if (kDebugMode) {
          print('[CgImageCompositor] Skip CPU composition on Web for $cacheKey');
        }
        return null;
      }
      // 检查内存缓存
      if (_imageCache.containsKey(cacheKey)) {
        final virtualPath = _generateVirtualPath(cacheKey);
        _compositePathCache[cacheKey] = virtualPath;
        return virtualPath;
      }

      // 解析角色图层
      final layerInfos = await CharacterLayerParser.parseCharacterLayers(
        resourceId: resourceId,
        pose: pose,
        expression: expression,
      );

      if (layerInfos.isEmpty) {
        return null;
      }

      // 加载所有图层图像
      final layerImages = <ui.Image>[];
      for (final layerInfo in layerInfos) {
        final image = await _loadLayerImage(layerInfo.assetName);
        if (image == null) {
          return null;
        }
        layerImages.add(image);
      }

      if (layerImages.isEmpty) {
        return null;
      }

      // 合成图像
      final compositeImage = await _compositeImages(layerImages);
      if (compositeImage == null) {
        return null;
      }

      // 保存合成图像到内存缓存
      final success = await _saveCompositeToMemory(compositeImage, cacheKey);
      if (!success) {
        return null;
      }

      // 生成虚拟路径并更新缓存
      final virtualPath = _generateVirtualPath(cacheKey);
      _compositePathCache[cacheKey] = virtualPath;
      
      // 清理资源
      for (final image in layerImages) {
        image.dispose();
      }
      compositeImage.dispose();

      return virtualPath;

    } catch (e) {
      if (kDebugMode) {
        print('[CgImageCompositor] Composition failed: $e');
      }
      return null;
    }
  }

  /// 加载单个图层图像
  Future<ui.Image?> _loadLayerImage(String assetName) async {
    try {
      final assetPath = await AssetManager().findAsset(assetName);
      if (assetPath == null) {
        return null;
      }
      
      return await ImageLoader.loadImage(assetPath);
    } catch (e) {
      return null;
    }
  }

  /// 合成多个图层为单张图像
  Future<ui.Image?> _compositeImages(List<ui.Image> layerImages) async {
    try {
      if (layerImages.isEmpty) return null;
      
      // 使用第一张图片的尺寸作为画布尺寸
      final baseImage = layerImages.first;
      final canvasWidth = baseImage.width;
      final canvasHeight = baseImage.height;

      // 创建合成画布
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final canvasRect = ui.Rect.fromLTWH(0, 0, canvasWidth.toDouble(), canvasHeight.toDouble());

      // 依次绘制所有图层
      for (final image in layerImages) {
        final paint = ui.Paint()
          ..isAntiAlias = true
          ..filterQuality = ui.FilterQuality.high;
        
        // 按原始尺寸绘制（假设所有图层尺寸相同）
        final srcRect = ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
        canvas.drawImageRect(image, srcRect, canvasRect, paint);
      }

      // 完成绘制并转换为图像
      final picture = recorder.endRecording();
      final compositeImage = await picture.toImage(canvasWidth, canvasHeight);
      picture.dispose();

      return compositeImage;
    } catch (e) {
      return null;
    }
  }

  /// 保存合成图像到内存缓存
  Future<bool> _saveCompositeToMemory(ui.Image image, String cacheKey) async {
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        return false;
      }

      final bytes = byteData.buffer.asUint8List();
      _imageCache[cacheKey] = bytes;
      
      if (kDebugMode) {
        print('[CgImageCompositor] Memory cache saved: $cacheKey (${bytes.length} bytes)');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('[CgImageCompositor] Failed to save composite image: $e');
      }
      return false;
    }
  }

  /// 清理缓存
  Future<void> clearCache() async {
    try {
      _imageCache.clear();
      _compositePathCache.clear();
      _compositingTasks.clear();
      
      if (kDebugMode) {
        print('[CgImageCompositor] Memory cache cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[CgImageCompositor] Failed to clear cache: $e');
      }
    }
  }

  /// 获取缓存统计信息
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      int totalSize = 0;
      
      // 计算内存中所有图像的总大小
      for (final bytes in _imageCache.values) {
        totalSize += bytes.length;
      }
      
      return {
        'cache_type': 'memory',
        'cached_images': _imageCache.length,
        'total_size': totalSize,
        'path_cache_count': _compositePathCache.length,
        'compositing_tasks': _compositingTasks.length,
      };
    } catch (e) {
      return {
        'error': e.toString(),
      };
    }
  }
}
