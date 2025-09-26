import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:sakiengine/src/config/asset_manager.dart';
import 'package:sakiengine/src/utils/character_layer_parser.dart';
import 'package:sakiengine/src/utils/image_loader.dart';

/// GPU 合成结果，包含所有需要在 GPU 上绘制的图层
class GpuCompositeResult {
  GpuCompositeResult({
    required List<ui.Image> layers,
    required this.width,
    required this.height,
  }) : layers = UnmodifiableListView<ui.Image>(layers);

  /// 参与绘制的所有图层（已经解码为 GPU 纹理）
  final UnmodifiableListView<ui.Image> layers;

  /// 合成画布宽度（像素）
  final int width;

  /// 合成画布高度（像素）
  final int height;

  /// 释放所有图层资源
  void dispose() {
    for (final image in layers) {
      image.dispose();
    }
  }
}

/// GPU 合成条目，包含缓存键、虚拟路径以及合成结果
class GpuCompositeEntry {
  const GpuCompositeEntry({
    required this.cacheKey,
    required this.virtualPath,
    required this.result,
  });

  final String cacheKey;
  final String virtualPath;
  final GpuCompositeResult result;
}

/// GPU加速图像合成器
/// 
/// 主要优化：
/// 1. 使用GPU Fragment Shader进行图像混合
/// 2. 批量处理多张图像
/// 3. 异步并行解码
/// 4. 智能内存管理
class GpuImageCompositor {
  static final GpuImageCompositor _instance = GpuImageCompositor._internal();
  factory GpuImageCompositor() => _instance;
  GpuImageCompositor._internal();

  /// 内存缓存
  final Map<String, GpuCompositeEntry> _entryCache = <String, GpuCompositeEntry>{};
  final Map<String, String> _pathToCacheKey = <String, String>{};
  final Map<String, Future<GpuCompositeEntry?>> _compositingTasks =
      <String, Future<GpuCompositeEntry?>>{};
  
  /// GPU加速可用性检查
  bool _gpuAvailable = false;
  bool _checkedGpuAvailability = false;

  /// 检查GPU加速可用性
  Future<void> _checkGpuAvailability() async {
    if (_checkedGpuAvailability) return;
    
    try {
      // 简单的GPU可用性检测
      _gpuAvailable = true; // 默认启用优化合成模式
      _checkedGpuAvailability = true;
      
      if (kDebugMode) {
        print('[GpuImageCompositor] 🚀 优化合成模式已启用');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[GpuImageCompositor] ⚠️ 回退到标准CPU模式: $e');
      }
      _gpuAvailable = false;
      _checkedGpuAvailability = true;
    }
  }

  /// 生成缓存键
  String _generateCacheKey(String resourceId, String pose, String expression) {
    return '${resourceId}_${pose}_$expression';
  }

  /// 生成虚拟缓存路径
  String _generateVirtualPath(String cacheKey) {
    return '/gpu_cache/cg_cache/$cacheKey.png';
  }

  /// 获取合成图像路径（主接口）
  Future<String?> getCompositeImagePath({
    required String resourceId,
    required String pose,
    required String expression,
  }) async {
    final entry = await _getOrCreateEntry(
      resourceId: resourceId,
      pose: pose,
      expression: expression,
    );

    return entry?.virtualPath;
  }

  /// 获取 GPU 合成结果（仅包含内存中的图层数据）
  Future<GpuCompositeResult?> getCompositeResult({
    required String resourceId,
    required String pose,
    required String expression,
  }) async {
    final entry = await _getOrCreateEntry(
      resourceId: resourceId,
      pose: pose,
      expression: expression,
    );
    return entry?.result;
  }

  /// 获取完整的合成条目（带虚拟路径）
  Future<GpuCompositeEntry?> getCompositeEntry({
    required String resourceId,
    required String pose,
    required String expression,
  }) {
    return _getOrCreateEntry(
      resourceId: resourceId,
      pose: pose,
      expression: expression,
    );
  }

  /// 读取已缓存的 GPU 合成结果
  GpuCompositeResult? getCachedResult(String keyOrPath) {
    final cacheKey = keyOrPath.startsWith('/gpu_cache/')
        ? _pathToCacheKey[keyOrPath]
        : keyOrPath;
    if (cacheKey == null) return null;
    return _entryCache[cacheKey]?.result;
  }

  /// 获取（或创建）完整的合成条目
  Future<GpuCompositeEntry?> _getOrCreateEntry({
    required String resourceId,
    required String pose,
    required String expression,
  }) async {
    final cacheKey = _generateCacheKey(resourceId, pose, expression);

    // 命中缓存
    final cachedEntry = _entryCache[cacheKey];
    if (cachedEntry != null) {
      return cachedEntry;
    }

    // 是否已有并发任务
    final existingTask = _compositingTasks[cacheKey];
    if (existingTask != null) {
      return await existingTask;
    }

    final compositionTask =
        _performOptimizedComposition(resourceId, pose, expression, cacheKey);
    _compositingTasks[cacheKey] = compositionTask;

    try {
      final entry = await compositionTask;
      return entry;
    } finally {
      _compositingTasks.remove(cacheKey);
    }
  }

  /// 批量GPU合成（性能优化核心）
  Future<List<String?>> batchCompose(List<Map<String, String>> requests) async {
    await _checkGpuAvailability();

    final startTime = DateTime.now();

    try {
      final tasks = requests.map((request) {
        final resourceId = request['resourceId']!;
        final pose = request['pose'] ?? 'pose1';
        final expression = request['expression'] ?? 'happy';
        return _getOrCreateEntry(
          resourceId: resourceId,
          pose: pose,
          expression: expression,
        );
      }).toList();

      final entries = await Future.wait(tasks, eagerError: false);

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      if (kDebugMode) {
        print('[GpuImageCompositor] ⚡ 批量准备 ${requests.length} 组图层耗时: ${duration}ms');
      }

      return entries.map((entry) => entry?.virtualPath).toList();
    } catch (e) {
      if (kDebugMode) {
        print('[GpuImageCompositor] ❌ 批量处理失败: $e');
      }
      return List<String?>.filled(requests.length, null);
    }
  }

  /// 执行优化合成，准备 GPU 渲染所需的图层
  Future<GpuCompositeEntry?> _performOptimizedComposition(
    String resourceId,
    String pose,
    String expression,
    String cacheKey,
  ) async {
    final startTime = DateTime.now();
    
    try {
      await _checkGpuAvailability();

      // 解析图层信息
      final layerInfos = await CharacterLayerParser.parseCharacterLayers(
        resourceId: resourceId,
        pose: pose,
        expression: expression,
      );

      if (layerInfos.isEmpty) return null;

      // 并行加载所有图层
      final layerLoadTasks = layerInfos.map((layerInfo) => 
          _loadLayerImageAsync(layerInfo.assetName)).toList();
      
      final layerImages = await Future.wait(layerLoadTasks);
      final validImages =
          layerImages.whereType<ui.Image>().toList(growable: false);

      if (validImages.isEmpty) {
        return null;
      }

      final loadTime = DateTime.now().difference(startTime).inMilliseconds;

      final width = validImages.first.width;
      final height = validImages.first.height;

      final result = GpuCompositeResult(
        layers: validImages,
        width: width,
        height: height,
      );

      final virtualPath = _generateVirtualPath(cacheKey);
      final entry = GpuCompositeEntry(
        cacheKey: cacheKey,
        virtualPath: virtualPath,
        result: result,
      );

      _entryCache[cacheKey] = entry;
      _pathToCacheKey[virtualPath] = cacheKey;

      final totalTime = DateTime.now().difference(startTime).inMilliseconds;

      if (kDebugMode) {
        print('[GpuImageCompositor] ⚡ 准备 GPU 图层 $cacheKey: 加载${loadTime}ms，总耗时${totalTime}ms');
      }

      return entry;

    } catch (e) {
      final errorTime = DateTime.now().difference(startTime).inMilliseconds;
      if (kDebugMode) {
        print('[GpuImageCompositor] ❌ 合成失败 ($errorTime ms): $e');
      }
      return null;
    }
  }

  /// 异步加载图层图像
  Future<ui.Image?> _loadLayerImageAsync(String assetName) async {
    try {
      final assetPath = await AssetManager().findAsset(assetName);
      if (assetPath == null) return null;
      
      return await ImageLoader.loadImage(assetPath);
    } catch (e) {
      return null;
    }
  }

  /// 获取缓存图像字节
  Uint8List? getImageBytes(String pathOrKey) {
    // GPU 渲染路径不再返回 CPU 合成的二进制数据
    return null;
  }

  /// 清理缓存
  Future<void> clearCache() async {
    for (final entry in _entryCache.values) {
      entry.result.dispose();
    }
    _entryCache.clear();
    _pathToCacheKey.clear();
    _compositingTasks.clear();
    
    if (kDebugMode) {
      print('[GpuImageCompositor] 🧹 优化缓存已清理');
    }
  }

  /// 获取缓存统计
  Map<String, dynamic> getCacheStats() {
    final totalLayers = _entryCache.values.fold<int>(
      0,
      (previousValue, entry) => previousValue + entry.result.layers.length,
    );

    return {
      'cache_type': 'gpu_layers',
      'gpu_available': _gpuAvailable,
      'cached_entries': _entryCache.length,
      'total_layers': totalLayers,
      'active_tasks': _compositingTasks.length,
    };
  }

  /// 预热优化器（可选调用）
  Future<void> warmUpGpu() async {
    await _checkGpuAvailability();
    if (kDebugMode) {
      print('[GpuImageCompositor] 🔥 优化器预热${_gpuAvailable ? "成功" : "失败"}');
    }
  }
}
