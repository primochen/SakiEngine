import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sakiengine/src/config/asset_manager.dart';
import 'package:sakiengine/src/utils/character_layer_parser.dart';
import 'package:sakiengine/src/utils/image_loader.dart';

/// CG图像合成器 - 负责将多层图像合成为单张图像并缓存
/// 
/// 功能：
/// - 将CG的所有差分图层（背景、表情、帽子等）合成为单张图像
/// - 智能缓存管理，避免重复合成
/// - 提供合成图像的路径管理和验证
class CgImageCompositor {
  static final CgImageCompositor _instance = CgImageCompositor._internal();
  factory CgImageCompositor() => _instance;
  CgImageCompositor._internal();

  /// 缓存目录名称
  static const String _cacheDir = '.cg_cache';
  
  /// 内存缓存：缓存键 -> 合成图像路径
  final Map<String, String> _compositePathCache = {};
  
  /// 正在合成的任务，避免重复合成
  final Map<String, Future<String?>> _compositingTasks = {};

  /// 获取缓存根目录
  Future<String> _getCacheRoot() async {
    final gamePath = await _getGamePath();
    return p.join(gamePath, _cacheDir);
  }

  /// 获取游戏路径（复用AssetManager的逻辑）
  Future<String> _getGamePath() async {
    const fromDefine = String.fromEnvironment('SAKI_GAME_PATH', defaultValue: '');
    if (fromDefine.isNotEmpty) return fromDefine;
    
    final fromEnv = Platform.environment['SAKI_GAME_PATH'];
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    
    try {
      // 从assets读取default_game.txt
      final assetContent = await AssetManager().loadString('assets/default_game.txt');
      final defaultGame = assetContent.trim();
      
      if (defaultGame.isEmpty) {
        throw Exception('default_game.txt is empty');
      }
      
      final gamePath = p.join(Directory.current.path, 'Game', defaultGame);
      return gamePath;
    } catch (e) {
      throw Exception('Failed to load default_game.txt: $e');
    }
  }

  /// 生成缓存键
  String _generateCacheKey(String resourceId, String pose, String expression) {
    return '${resourceId}_${pose}_${expression}';
  }

  /// 获取缓存文件路径
  Future<String> _getCacheFilePath(String cacheKey) async {
    final cacheRoot = await _getCacheRoot();
    return p.join(cacheRoot, '$cacheKey.png');
  }

  /// 确保缓存目录存在
  Future<void> _ensureCacheDirectory() async {
    final cacheRoot = await _getCacheRoot();
    final cacheDir = Directory(cacheRoot);
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
      // 缓存目录已创建
    }
  }

  /// 获取或生成合成CG图像的路径
  /// 
  /// 返回合成图像的文件系统路径，如果合成失败则返回null
  Future<String?> getCompositeImagePath({
    required String resourceId,
    required String pose,
    required String expression,
  }) async {
    final cacheKey = _generateCacheKey(resourceId, pose, expression);
    
    // 检查内存缓存
    if (_compositePathCache.containsKey(cacheKey)) {
      final cachedPath = _compositePathCache[cacheKey]!;
      // 验证文件是否仍然存在
      if (await File(cachedPath).exists()) {
        return cachedPath;
      } else {
        // 文件已被删除，清除缓存
        _compositePathCache.remove(cacheKey);
      }
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

  /// 执行实际的图像合成
  Future<String?> _performComposition(String resourceId, String pose, String expression, String cacheKey) async {
    try {
      
      // 确保缓存目录存在
      await _ensureCacheDirectory();
      
      // 获取缓存文件路径
      final cacheFilePath = await _getCacheFilePath(cacheKey);
      
      // 检查磁盘缓存
      if (await File(cacheFilePath).exists()) {
        _compositePathCache[cacheKey] = cacheFilePath;
        return cacheFilePath;
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

      // 保存合成图像到缓存
      final success = await _saveCompositeImage(compositeImage, cacheFilePath);
      if (!success) {
        return null;
      }

      // 更新内存缓存
      _compositePathCache[cacheKey] = cacheFilePath;
      
      // 清理资源
      for (final image in layerImages) {
        image.dispose();
      }
      compositeImage.dispose();

      return cacheFilePath;

    } catch (e) {
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

  /// 保存合成图像到文件
  Future<bool> _saveCompositeImage(ui.Image image, String filePath) async {
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        return false;
      }

      final bytes = byteData.buffer.asUint8List();
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 清理缓存
  Future<void> clearCache() async {
    try {
      final cacheRoot = await _getCacheRoot();
      final cacheDir = Directory(cacheRoot);
      
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
      
      _compositePathCache.clear();
      _compositingTasks.clear();
      
    } catch (e) {
    }
  }

  /// 获取缓存统计信息
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final cacheRoot = await _getCacheRoot();
      final cacheDir = Directory(cacheRoot);
      
      if (!await cacheDir.exists()) {
        return {
          'cache_dir': cacheRoot,
          'exists': false,
          'file_count': 0,
          'total_size': 0,
        };
      }
      
      final files = await cacheDir.list().where((entity) => entity is File).cast<File>().toList();
      int totalSize = 0;
      
      for (final file in files) {
        try {
          final stat = await file.stat();
          totalSize += stat.size;
        } catch (e) {
          // 忽略单个文件的统计错误
        }
      }
      
      return {
        'cache_dir': cacheRoot,
        'exists': true,
        'file_count': files.length,
        'total_size': totalSize,
        'memory_cache_count': _compositePathCache.length,
        'compositing_tasks': _compositingTasks.length,
      };
    } catch (e) {
      return {
        'error': e.toString(),
      };
    }
  }
}