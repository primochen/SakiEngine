import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/asset_manager.dart';
import 'package:sakiengine/src/game/game_manager.dart';
import 'package:sakiengine/src/utils/cg_image_compositor.dart';
import 'package:sakiengine/src/utils/gpu_image_compositor.dart';
import 'package:sakiengine/src/sks_parser/sks_ast.dart';

/// 基于预合成图像的CG角色渲染器
/// 
/// 替代原有的多层实时渲染方式，直接使用预合成的单张图像
class CompositeCgRenderer {
  // GPU加速合成器实例
  static final GpuImageCompositor _gpuCompositor = GpuImageCompositor();
  static final CgImageCompositor _legacyCompositor = CgImageCompositor();
  
  // 性能优化开关
  static bool _useGpuAcceleration = true;
  
  // 缓存Future，避免重复创建导致的loading状态
  static final Map<String, Future<String?>> _futureCache = {};
  // 缓存已完成的合成路径
  static final Map<String, String> _completedPaths = {};
  
  // 预显示差分的状态跟踪
  static final Set<String> _preDisplayedCgs = <String>{};
  
  // 当前显示的图像状态缓存（用于无缝切换）
  static final Map<String, String> _currentDisplayedImages = {};
  
  // 预加载完成的图像缓存（关键：确保没有"第一次加载"）
  static final Map<String, ui.Image> _preloadedImages = {};

  // GPU 纹理缓存与状态
  static final Map<String, Future<GpuCompositeEntry?>> _gpuFutureCache = {};
  static final Map<String, GpuCompositeResult> _gpuCompletedResults = {};
  static final Map<String, GpuCompositeResult> _gpuPreloadedResults = {};
  static final Map<String, String> _currentDisplayedGpuKeys = {};

  static final Map<String, Future<ui.Image?>> _gpuFlattenTasks = {};

  // 着色器支持
  static ui.FragmentProgram? _dissolveProgram;
  static Future<void> _ensureDissolveProgram() async {
    if (_dissolveProgram != null) return;
    try {
      final program = await ui.FragmentProgram.fromAsset('assets/shaders/dissolve.frag');
      _dissolveProgram = program;
    } catch (e) {
      if (kDebugMode) {
        print('[CompositeCgRenderer] Failed to load dissolve shader: $e');
      }
    }
  }

  /// 供后台预合成逻辑注册缓存结果，避免首次切换差分时重新加载
  static Future<void> cachePrecomposedResult({
    required String resourceId,
    required String pose,
    required String expression,
    String? compositePath,
    GpuCompositeEntry? gpuEntry,
  }) async {
    final cacheKey = '${resourceId}_${pose}_${expression}';

    if (gpuEntry != null) {
      _gpuCompletedResults[cacheKey] = gpuEntry.result;
      _gpuPreloadedResults[cacheKey] = gpuEntry.result;
      _gpuFutureCache[cacheKey] = Future.value(gpuEntry);

      final virtualPath = gpuEntry.virtualPath;
      _completedPaths[cacheKey] = virtualPath;
      _futureCache[cacheKey] = Future.value(virtualPath);

      final flattenTask = _gpuFlattenTasks[cacheKey] ??=
          _flattenGpuResultToImage(gpuEntry.result);
      final flattenedImage = await flattenTask;
      if (flattenedImage != null) {
        final previous = _preloadedImages[cacheKey];
        if (previous != null && previous != flattenedImage) {
          previous.dispose();
        }
        _preloadedImages[cacheKey] = flattenedImage;
      } else {
        _gpuFlattenTasks.remove(cacheKey);
      }
    }

    if (compositePath != null) {
      _completedPaths[cacheKey] = compositePath;
      _futureCache[cacheKey] = Future.value(compositePath);
    }
  }

  // 预热是否已经开始
  static bool _preWarmingStarted = false;
  
  static List<Widget> buildCgCharacters(
    BuildContext context,
    Map<String, CharacterState> cgCharacters,
    GameManager gameManager,
    {bool skipAnimations = false}
  ) {
    _ensureDissolveProgram();
    // 确保预热已开始（只执行一次）
    if (!_preWarmingStarted) {
      _preWarmingStarted = true;
      // 异步开始预热，不阻塞UI
      _startGlobalPreWarming();
    }
    
    if (cgCharacters.isEmpty) return [];
    
    // 按resourceId分组，保留最新的角色状态
    final Map<String, MapEntry<String, CharacterState>> charactersByResourceId = {};
    
    for (final entry in cgCharacters.entries) {
      final resourceId = entry.value.resourceId;
      charactersByResourceId[resourceId] = entry;
    }
    
    return charactersByResourceId.values.map<Widget>((entry) {
      if (_useGpuAcceleration) {
        return _buildGpuCharacterWidget(
          context: context,
          entry: entry,
          skipAnimations: skipAnimations,
        );
      }

      return _buildCpuCharacterWidget(
        context: context,
        entry: entry,
        skipAnimations: skipAnimations,
      );
    }).toList();
  }
  
  static Widget _buildCpuCharacterWidget({
    required BuildContext context,
    required MapEntry<String, CharacterState> entry,
    required bool skipAnimations,
  }) {
    final characterState = entry.value;
    final displayKey = entry.key;

    assert(() {
      print('[CompositeCgRenderer] [CPU] 构建CG: key=$displayKey res=${characterState.resourceId} pose=${characterState.pose} exp=${characterState.expression} skip=$skipAnimations');
      return true;
    }());

    final widgetKey = 'composite_cg_$displayKey';
    final cacheKey = '${characterState.resourceId}_${characterState.pose ?? 'pose1'}_${characterState.expression ?? 'happy'}';

    final resourceBaseId = '${characterState.resourceId}_${characterState.pose ?? 'pose1'}';
    if (!_preDisplayedCgs.contains(resourceBaseId)) {
      _preDisplayedCgs.add(resourceBaseId);
      _preDisplayCommonVariations(characterState.resourceId, characterState.pose ?? 'pose1');
    }

    final currentImagePath = _currentDisplayedImages[displayKey];
    final bool isFirstAppearance = currentImagePath == null && !skipAnimations;

    if (_preloadedImages.containsKey(cacheKey)) {
      final preloadedImage = _preloadedImages[cacheKey]!;
      _currentDisplayedImages[displayKey] = cacheKey;

      assert(() {
        if (currentImagePath == null) {
          print('[CompositeCgRenderer] [CPU] 使用预加载图像首次显示 key=$displayKey cache=$cacheKey');
        }
        return true;
      }());

      return _FirstCgFadeWrapper(
        fadeKey: displayKey,
        enableFade: isFirstAppearance,
        child: DirectCgDisplay(
          key: ValueKey('direct_display_$displayKey'),
          image: preloadedImage,
          resourceId: characterState.resourceId,
          isFadingOut: characterState.isFadingOut,
          enableFadeIn: !skipAnimations && currentImagePath == null,
          skipAnimation: skipAnimations,
        ),
      );
    }

    if (_completedPaths.containsKey(cacheKey)) {
      final compositeImagePath = _completedPaths[cacheKey]!;
      _currentDisplayedImages[displayKey] = compositeImagePath;

      assert(() {
        if (currentImagePath == null) {
          print('[CompositeCgRenderer] [CPU] 首次显示路径已缓存 key=$displayKey path=$compositeImagePath');
        }
        return true;
      }());

        return _FirstCgFadeWrapper(
          fadeKey: displayKey,
          enableFade: isFirstAppearance,
          child: SeamlessCgDisplay(
            key: ValueKey('seamless_display_$displayKey'),
            newImagePath: compositeImagePath,
            currentImagePath: currentImagePath,
            resourceId: characterState.resourceId,
            dissolveProgram: _dissolveProgram,
            isFadingOut: characterState.isFadingOut,
            skipAnimation: skipAnimations,
          ),
        );
    }

    if (!_futureCache.containsKey(cacheKey)) {
      _futureCache[cacheKey] = _loadAndCacheImage(
        resourceId: characterState.resourceId,
        pose: characterState.pose ?? 'pose1',
        expression: characterState.expression ?? 'happy',
        cacheKey: cacheKey,
        displayKey: displayKey,
      );
    }

    return FutureBuilder<String?>(
      key: ValueKey(widgetKey),
      future: _futureCache[cacheKey],
      builder: (context, snapshot) {
        final shouldShowCurrent = currentImagePath != null;
        final hasNewImage = snapshot.hasData && snapshot.data != null;

        if (snapshot.connectionState == ConnectionState.waiting) {
          if (shouldShowCurrent) {
            return SeamlessCgDisplay(
              key: ValueKey('seamless_display_$displayKey'),
              newImagePath: null,
              currentImagePath: currentImagePath,
              resourceId: characterState.resourceId,
              dissolveProgram: _dissolveProgram,
              isFadingOut: characterState.isFadingOut,
              skipAnimation: skipAnimations,
            );
          }
          return Container(
            key: ValueKey('loading_placeholder_$displayKey'),
            width: double.infinity,
            height: double.infinity,
          );
        }

        if (!hasNewImage) {
          if (shouldShowCurrent) {
            return SeamlessCgDisplay(
              key: ValueKey('seamless_display_$displayKey'),
              newImagePath: null,
              currentImagePath: currentImagePath,
              resourceId: characterState.resourceId,
              dissolveProgram: _dissolveProgram,
              isFadingOut: characterState.isFadingOut,
              skipAnimation: skipAnimations,
            );
          }
          return Container(
            key: ValueKey('error_placeholder_$displayKey'),
            width: double.infinity,
            height: double.infinity,
          );
        }

        final compositeImagePath = snapshot.data!;
        _currentDisplayedImages[displayKey] = compositeImagePath;

        assert(() {
          if (currentImagePath == null) {
            print('[CompositeCgRenderer] [CPU] Future首次完成 key=$displayKey path=$compositeImagePath');
          }
          return true;
        }());

        return _FirstCgFadeWrapper(
          fadeKey: displayKey,
          enableFade: isFirstAppearance,
          child: SeamlessCgDisplay(
            key: ValueKey('seamless_display_$displayKey'),
            newImagePath: compositeImagePath,
            currentImagePath: currentImagePath,
            resourceId: characterState.resourceId,
            dissolveProgram: _dissolveProgram,
            isFadingOut: characterState.isFadingOut,
            skipAnimation: skipAnimations,
          ),
        );
      },
    );
  }

  static Widget _buildGpuCharacterWidget({
    required BuildContext context,
    required MapEntry<String, CharacterState> entry,
    required bool skipAnimations,
  }) {
    final characterState = entry.value;
    final displayKey = entry.key;

    assert(() {
      print('[CompositeCgRenderer] [GPU] 构建CG: key=$displayKey res=${characterState.resourceId} pose=${characterState.pose} exp=${characterState.expression} skip=$skipAnimations');
      return true;
    }());
    final cacheKey = '${characterState.resourceId}_${characterState.pose ?? 'pose1'}_${characterState.expression ?? 'happy'}';

    final resourceBaseId = '${characterState.resourceId}_${characterState.pose ?? 'pose1'}';
    if (!_preDisplayedCgs.contains(resourceBaseId)) {
      _preDisplayedCgs.add(resourceBaseId);
      _preDisplayCommonVariations(characterState.resourceId, characterState.pose ?? 'pose1');
    }

    final currentKey = _currentDisplayedGpuKeys[displayKey];
    final currentResult = _resolveGpuResult(currentKey);
    final bool isFirstAppearance = currentKey == null && !skipAnimations;

    if (_preloadedImages.containsKey(cacheKey)) {
      final preloadedImage = _preloadedImages[cacheKey]!;
      _currentDisplayedGpuKeys[displayKey] = cacheKey;

      assert(() {
        if (currentKey == null) {
          print('[CompositeCgRenderer] [GPU] 使用预加载图像首次显示 key=$displayKey cache=$cacheKey');
        }
        return true;
      }());

      return _FirstCgFadeWrapper(
        fadeKey: 'gpu_$displayKey',
        enableFade: isFirstAppearance,
        child: DirectCgDisplay(
          key: ValueKey('direct_display_gpu_$displayKey'),
          image: preloadedImage,
          resourceId: characterState.resourceId,
          isFadingOut: characterState.isFadingOut,
          enableFadeIn: !skipAnimations && currentKey == null,
          skipAnimation: skipAnimations,
        ),
      );
    }

    if (_gpuPreloadedResults.containsKey(cacheKey)) {
      final preloadedResult = _gpuPreloadedResults[cacheKey]!;
      _currentDisplayedGpuKeys[displayKey] = cacheKey;

      return _FirstCgFadeWrapper(
        fadeKey: 'gpu_$displayKey',
        enableFade: isFirstAppearance,
        child: GpuDirectCgDisplay(
          key: ValueKey('gpu_direct_$displayKey'),
          result: preloadedResult,
          resourceId: characterState.resourceId,
          isFadingOut: characterState.isFadingOut,
          skipAnimation: skipAnimations,
          enableFadeIn: !skipAnimations && currentKey == null,
        ),
      );
    }

    if (_gpuCompletedResults.containsKey(cacheKey)) {
      final completedResult = _gpuCompletedResults[cacheKey]!;
      _currentDisplayedGpuKeys[displayKey] = cacheKey;

      if (currentResult == null && !skipAnimations) {
        assert(() {
          print('[CompositeCgRenderer] [GPU] 首次显示缓存结果，启用淡入 key=$displayKey cache=$cacheKey');
          return true;
        }());
        return _FirstCgFadeWrapper(
          fadeKey: 'gpu_$displayKey',
          enableFade: true,
          child: GpuDirectCgDisplay(
            key: ValueKey('gpu_direct_initial_$displayKey'),
            result: completedResult,
            resourceId: characterState.resourceId,
            isFadingOut: characterState.isFadingOut,
            skipAnimation: skipAnimations,
            enableFadeIn: true,
          ),
        );
      }

      assert(() {
        if (currentResult == null) {
          print('[CompositeCgRenderer] [GPU] 首次显示但跳过淡入（skip=$skipAnimations） key=$displayKey cache=$cacheKey');
        }
        return true;
      }());

      return _FirstCgFadeWrapper(
        fadeKey: 'gpu_$displayKey',
        enableFade: isFirstAppearance,
        child: GpuSeamlessCgDisplay(
          key: ValueKey('gpu_seamless_$displayKey'),
          newResult: completedResult,
          currentResult: currentResult,
          resourceId: characterState.resourceId,
          isFadingOut: characterState.isFadingOut,
          skipAnimation: skipAnimations,
        ),
      );
    }

    if (!_gpuFutureCache.containsKey(cacheKey)) {
      _gpuFutureCache[cacheKey] = _gpuCompositor
          .getCompositeEntry(
        resourceId: characterState.resourceId,
        pose: characterState.pose ?? 'pose1',
        expression: characterState.expression ?? 'happy',
      )
          .then((entry) {
        if (entry != null) {
          _gpuCompletedResults[cacheKey] = entry.result;
          _gpuPreloadedResults[cacheKey] = entry.result;
        }
        return entry;
      });
    }

    return FutureBuilder<GpuCompositeEntry?>(
      key: ValueKey('gpu_future_$displayKey'),
      future: _gpuFutureCache[cacheKey],
      builder: (context, snapshot) {
        final entryData = snapshot.data;
        final newResult = entryData?.result;

        final hasNewResult = snapshot.hasData && newResult != null;

        if (snapshot.connectionState == ConnectionState.waiting) {
          if (currentResult != null) {
            return GpuSeamlessCgDisplay(
              key: ValueKey('gpu_seamless_$displayKey'),
              newResult: null,
              currentResult: currentResult,
              resourceId: characterState.resourceId,
              isFadingOut: characterState.isFadingOut,
              skipAnimation: skipAnimations,
            );
          }
          return Container(
            key: ValueKey('gpu_loading_$displayKey'),
            width: double.infinity,
            height: double.infinity,
          );
        }

        if (!hasNewResult) {
          if (currentResult != null) {
            return GpuSeamlessCgDisplay(
              key: ValueKey('gpu_seamless_${characterState.resourceId}'),
              newResult: null,
              currentResult: currentResult,
              resourceId: characterState.resourceId,
              isFadingOut: characterState.isFadingOut,
              skipAnimation: skipAnimations,
            );
          }
          return Container(
            key: ValueKey('gpu_error_${characterState.resourceId}'),
            width: double.infinity,
            height: double.infinity,
          );
        }

        _gpuCompletedResults[cacheKey] = newResult;
        _gpuPreloadedResults[cacheKey] = newResult;
        _currentDisplayedGpuKeys[displayKey] = cacheKey;

        return GpuSeamlessCgDisplay(
          key: ValueKey('gpu_seamless_$displayKey'),
          newResult: newResult,
          currentResult: currentResult,
          resourceId: characterState.resourceId,
          isFadingOut: characterState.isFadingOut,
          skipAnimation: skipAnimations,
        );
      },
    );
  }

  static GpuCompositeResult? _resolveGpuResult(String? cacheKey) {
    if (cacheKey == null) return null;
    return _gpuCompletedResults[cacheKey] ??
        _gpuPreloadedResults[cacheKey] ??
        _gpuCompositor.getCachedResult(cacheKey);
  }

  static Future<ui.Image?> _flattenGpuResultToImage(
    GpuCompositeResult result,
  ) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final width = result.width.toDouble();
      final height = result.height.toDouble();

      final targetRect = ui.Rect.fromLTWH(0, 0, width, height);
      final paint = ui.Paint()
        ..isAntiAlias = false
        ..filterQuality = ui.FilterQuality.none;

      for (var layerIndex = 0; layerIndex < result.layers.length; layerIndex++) {
        final layer = result.layers[layerIndex];
        final srcRect = ui.Rect.fromLTWH(
          0,
          0,
          layer.width.toDouble(),
          layer.height.toDouble(),
        );
        paint.blendMode = layerIndex == 0 ? ui.BlendMode.src : ui.BlendMode.srcOver;
        canvas.drawImageRect(layer, srcRect, targetRect, paint);
      }

      final picture = recorder.endRecording();
      final image = await picture.toImage(result.width, result.height);
      picture.dispose();
      return image;
    } catch (_) {
      return null;
    }
  }
  
  /// 加载并缓存图像到内存（关键方法）
  static Future<String?> _loadAndCacheImage({
    required String resourceId,
    required String pose,
    required String expression,
    required String cacheKey,
    required String displayKey,
  }) async {
    try {
      print('[CompositeCgRenderer] 开始加载: $cacheKey');
      
      if (_useGpuAcceleration) {
        final entry = await _gpuCompositor.getCompositeEntry(
          resourceId: resourceId,
          pose: pose,
          expression: expression,
        );

        if (entry == null) {
          print('[CompositeCgRenderer] 合成失败: $cacheKey');
          return null;
        }

        _gpuCompletedResults[cacheKey] = entry.result;
        _gpuPreloadedResults[cacheKey] = entry.result;
        return entry.virtualPath;
      }

      // 先获取合成图像路径 - 使用传统合成器
      final compositeImagePath = await _legacyCompositor.getCompositeImagePath(
        resourceId: resourceId,
        pose: pose,
        expression: expression,
      );
      
      print('[CompositeCgRenderer] 合成路径: $compositeImagePath');
      
      if (compositeImagePath != null) {
        // 缓存完成的路径
        _completedPaths[cacheKey] = compositeImagePath;
        
        final imageBytes = _legacyCompositor.getImageBytes(compositeImagePath);
        print('[CompositeCgRenderer] 内存缓存存在: ${imageBytes != null}');
        
        if (imageBytes != null) {
          // 将字节数据转换为ui.Image
          final codec = await ui.instantiateImageCodec(imageBytes);
          final frame = await codec.getNextFrame();
          
          // 缓存到内存，确保下次访问时没有"第一次加载"
          _preloadedImages[cacheKey] = frame.image;
          print('[CompositeCgRenderer] 成功缓存到内存: $cacheKey, 总缓存数: ${_preloadedImages.length}');
        } else {
          print('[CompositeCgRenderer] 内存缓存中无数据: $compositeImagePath');
        }
        
        // 更新当前显示的图像
        _currentDisplayedImages[displayKey] = compositeImagePath;
      } else {
        print('[CompositeCgRenderer] 合成失败: $cacheKey');
      }
      
      return compositeImagePath;
    } catch (e) {
      print('[CompositeCgRenderer] 加载异常: $cacheKey - $e');
      return null;
    }
  }
  
  /// 全局预热 - 在游戏启动时预热所有常见CG组合
  static void _startGlobalPreWarming() {
    print('[CompositeCgRenderer] 🚀 全局预热已禁用，采用动态预热策略');
  }
  
  /// 检查CG组合是否存在
  static Future<bool> _checkCgCombinationExists(String resourceId, String pose, String expression) async {
    try {
      final compositeImagePath = _useGpuAcceleration 
          ? await _gpuCompositor.getCompositeImagePath(
              resourceId: resourceId,
              pose: pose,
              expression: expression,
            )
          : await _legacyCompositor.getCompositeImagePath(
              resourceId: resourceId,
              pose: pose,
              expression: expression,
            );
      return compositeImagePath != null;
    } catch (e) {
      return false;
    }
  }
  
  /// 预显示常见的差分变化，确保后续切换不是"第一次"
  static Future<void> _preDisplayCommonVariations(String resourceId, String pose) async {
    print('[CompositeCgRenderer] 开始预热角色: $resourceId $pose');
    
    // 从游戏管理器获取脚本信息来预热实际使用的差分
    // 这里简化为仅预热当前组合，因为完整的脚本分析在游戏启动时已完成
    print('[CompositeCgRenderer] 脚本分析预热已在游戏启动时完成');
  }
  
  /// 清理缓存
  static void clearCache() {
    _futureCache.clear();
    _completedPaths.clear();
    _preDisplayedCgs.clear();
    _currentDisplayedImages.clear();
    _gpuFutureCache.clear();
    _gpuCompletedResults.clear();
    _gpuPreloadedResults.clear();
    _currentDisplayedGpuKeys.clear();
    _gpuFlattenTasks.clear();
    
    // 释放预加载的图像内存
    for (final image in _preloadedImages.values) {
      try {
        image.dispose();
      } catch (e) {
        // 静默处理
      }
    }
    _preloadedImages.clear();
    
    // 重置预热标志，允许重新预热
    _preWarmingStarted = false;
  }
  
  /// 设置GPU加速开关
  static void setGpuAcceleration(bool enabled) {
    _useGpuAcceleration = enabled;
    if (enabled) {
      print('[CompositeCgRenderer] 🚀 GPU加速已启用');
    } else {
      print('[CompositeCgRenderer] 🔄 已切换到传统CPU合成器');
    }
  }
  
  /// 获取当前GPU加速状态
  static bool get isGpuAccelerationEnabled => _useGpuAcceleration;
}

/// GPU 直接显示控件（使用 GPU 图层实时合成）
class GpuDirectCgDisplay extends StatefulWidget {
  final GpuCompositeResult result;
  final String resourceId;
  final bool isFadingOut;
  final bool skipAnimation;
  final bool enableFadeIn;

  const GpuDirectCgDisplay({
    super.key,
    required this.result,
    required this.resourceId,
    this.isFadingOut = false,
    this.skipAnimation = false,
    this.enableFadeIn = false,
  });

  @override
  State<GpuDirectCgDisplay> createState() => _GpuDirectCgDisplayState();
}

class _GpuDirectCgDisplayState extends State<GpuDirectCgDisplay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    final bool shouldFadeIn = widget.enableFadeIn && !widget.isFadingOut && !widget.skipAnimation;
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
      value: widget.isFadingOut ? 0.0 : (shouldFadeIn ? 0.0 : 1.0),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    if (!widget.isFadingOut && !widget.skipAnimation) {
      if (shouldFadeIn) {
        _fadeController.forward();
      } else if (_fadeController.value < 1.0) {
        _fadeController.forward();
      }
    }
  }

  @override
  void didUpdateWidget(covariant GpuDirectCgDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.result != oldWidget.result) {
      if (widget.skipAnimation) {
        _fadeController.value = widget.isFadingOut ? 0.0 : 1.0;
      } else {
        final bool shouldFadeIn = widget.enableFadeIn && !widget.isFadingOut;
        _fadeController.forward(from: shouldFadeIn ? 0.0 : 0.0);
      }
    }

    if (!oldWidget.isFadingOut && widget.isFadingOut) {
      if (widget.skipAnimation) {
        _fadeController.value = 0.0;
      } else {
        _fadeController.reverse();
      }
    } else if (oldWidget.isFadingOut && !widget.isFadingOut) {
      if (widget.skipAnimation) {
        _fadeController.value = 1.0;
      } else {
        _fadeController.forward();
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: GpuCompositePainter(
                result: widget.result,
                opacity: _fadeAnimation.value,
              ),
            );
          },
        );
      },
    );
  }
}

/// GPU 无缝切换控件，支持在两组图层之间进行平滑过渡
class GpuSeamlessCgDisplay extends StatefulWidget {
  final GpuCompositeResult? newResult;
  final GpuCompositeResult? currentResult;
  final String resourceId;
  final bool isFadingOut;
  final bool skipAnimation;

  const GpuSeamlessCgDisplay({
    super.key,
    this.newResult,
    this.currentResult,
    required this.resourceId,
    this.isFadingOut = false,
    this.skipAnimation = false,
  });

  @override
  State<GpuSeamlessCgDisplay> createState() => _GpuSeamlessCgDisplayState();
}

class _GpuSeamlessCgDisplayState extends State<GpuSeamlessCgDisplay>
    with TickerProviderStateMixin {
  late final AnimationController _transitionController;
  late final Animation<double> _transitionAnimation;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  GpuCompositeResult? _currentResult;
  GpuCompositeResult? _incomingResult;

  @override
  void initState() {
    super.initState();

    _transitionController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
      value: 1.0,
    );
    _transitionAnimation = CurvedAnimation(
      parent: _transitionController,
      curve: Curves.easeInOut,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
      value: widget.isFadingOut ? 0.0 : 1.0,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _currentResult = widget.currentResult ?? widget.newResult;
    if (widget.skipAnimation) {
      _currentResult = widget.newResult ?? widget.currentResult;
      _incomingResult = null;
      _transitionController.value = 1.0;
      _fadeController.value = widget.isFadingOut ? 0.0 : 1.0;
    } else {
      if (widget.newResult != null && widget.newResult != widget.currentResult) {
        _startTransition(widget.newResult!);
      }

      if (widget.isFadingOut) {
        _fadeController.reverse(from: 1.0);
      }
    }

    _transitionController.addStatusListener(_handleTransitionStatus);
  }

  void _handleTransitionStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _incomingResult != null) {
      _currentResult = _incomingResult;
      _incomingResult = null;
      setState(() {});
    }
  }

  void _startTransition(GpuCompositeResult nextResult) {
    _incomingResult = nextResult;
    _transitionController
      ..value = 0.0
      ..forward();
  }

  @override
  void didUpdateWidget(covariant GpuSeamlessCgDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newResult = widget.newResult;
    if (newResult != null &&
        newResult != _incomingResult &&
        newResult != _currentResult) {
      if (widget.skipAnimation) {
        _currentResult = newResult;
        _incomingResult = null;
        _transitionController.value = 1.0;
        setState(() {});
      } else {
        _startTransition(newResult);
      }
    } else if (newResult == null && widget.currentResult != null &&
        widget.currentResult != _currentResult) {
      _currentResult = widget.currentResult;
      _incomingResult = null;
      _transitionController.value = 1.0;
      setState(() {});
    }

    if (!oldWidget.isFadingOut && widget.isFadingOut) {
      if (widget.skipAnimation) {
        _fadeController.value = 0.0;
      } else {
        _fadeController.reverse();
      }
    } else if (oldWidget.isFadingOut && !widget.isFadingOut) {
      if (widget.skipAnimation) {
        _fadeController.value = 1.0;
      } else {
        _fadeController.forward();
      }
    }
  }

  @override
  void dispose() {
    _transitionController.removeStatusListener(_handleTransitionStatus);
    _transitionController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentResult == null && _incomingResult == null) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.transparent,
      );
    }

    final listenable = Listenable.merge(<Listenable>[
      _transitionController,
      _fadeController,
    ]);

    return AnimatedBuilder(
      animation: listenable,
      builder: (context, child) {
        final transitionValue = _incomingResult == null
            ? 0.0
            : _transitionAnimation.value.clamp(0.0, 1.0);
        final fadeValue = _fadeAnimation.value.clamp(0.0, 1.0);

        final currentOpacity = _incomingResult != null
            ? (1.0 - transitionValue) * fadeValue
            : fadeValue;
        final newOpacity = _incomingResult != null
            ? transitionValue * fadeValue
            : 0.0;

        return LayoutBuilder(
          builder: (context, constraints) {
            return CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: GpuSeamlessCgPainter(
                currentResult: _currentResult,
                newResult: _incomingResult,
                currentOpacity: currentOpacity,
                newOpacity: newOpacity,
              ),
            );
          },
        );
      },
    );
  }
}

class GpuCompositePainter extends CustomPainter {
  final GpuCompositeResult result;
  final double opacity;

  GpuCompositePainter({
    required this.result,
    required this.opacity,
  });

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    _drawCompositeResult(canvas, size, result, opacity);
  }

  @override
  bool shouldRepaint(GpuCompositePainter oldDelegate) {
    return result != oldDelegate.result || opacity != oldDelegate.opacity;
  }
}

class GpuSeamlessCgPainter extends CustomPainter {
  final GpuCompositeResult? currentResult;
  final GpuCompositeResult? newResult;
  final double currentOpacity;
  final double newOpacity;

  GpuSeamlessCgPainter({
    required this.currentResult,
    required this.newResult,
    required this.currentOpacity,
    required this.newOpacity,
  });

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    if (size.isEmpty) return;

    if (currentResult != null && currentOpacity > 0) {
      _drawCompositeResult(canvas, size, currentResult!, currentOpacity);
    }
    if (newResult != null && newOpacity > 0) {
      _drawCompositeResult(canvas, size, newResult!, newOpacity);
    }
  }

  @override
  bool shouldRepaint(GpuSeamlessCgPainter oldDelegate) {
    return currentResult != oldDelegate.currentResult ||
        newResult != oldDelegate.newResult ||
        currentOpacity != oldDelegate.currentOpacity ||
        newOpacity != oldDelegate.newOpacity;
  }
}

/// 直接CG显示组件（用于已预加载的图像）
///
/// 会在同一角色的差分切换时使用溶解效果过渡
class DirectCgDisplay extends StatefulWidget {
  final ui.Image image;
  final String resourceId;
  final bool isFadingOut;
  final bool enableFadeIn;
  final bool skipAnimation;

  const DirectCgDisplay({
    super.key,
    required this.image,
    required this.resourceId,
    this.isFadingOut = false,
    this.enableFadeIn = false,
    this.skipAnimation = false,
  });

  @override
  State<DirectCgDisplay> createState() => _DirectCgDisplayState();
}

class _DirectCgDisplayState extends State<DirectCgDisplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progress;

  ui.Image? _currentImage;
  ui.Image? _previousImage;
  bool _hasShownOnce = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _currentImage = widget.image;
    assert(() {
      print('[DirectCgDisplay] init for ${widget.resourceId} enableFadeIn=${widget.enableFadeIn} skip=${widget.skipAnimation}');
      return true;
    }());
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_controller.isAnimating) {
        _previousImage = null;
        _hasShownOnce = true;
      }
    });

    if (widget.skipAnimation) {
      _controller.value = 1.0;
      _hasShownOnce = true;
    } else {
      _controller.forward();
    }
    CompositeCgRenderer._ensureDissolveProgram().then((_) {
      if (mounted && CompositeCgRenderer._dissolveProgram != null) {
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(covariant DirectCgDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);

    final imageChanged = widget.image != _currentImage;
    final fadingChanged = widget.isFadingOut != oldWidget.isFadingOut;

    if (imageChanged) {
      _previousImage = _currentImage;
      _currentImage = widget.image;
      assert(() {
        print('[DirectCgDisplay] imageChanged for ${widget.resourceId} enableFadeIn=${widget.enableFadeIn}');
        return true;
      }());
      if (widget.skipAnimation) {
        _controller.value = 1.0;
        _previousImage = null;
        _hasShownOnce = true;
      } else {
        _controller.forward(from: 0.0);
      }
    } else if (fadingChanged) {
      if (widget.isFadingOut) {
        // 淡出时不参与差分溶解
        _previousImage = null;
      }
      if (widget.skipAnimation) {
        _controller.value = widget.isFadingOut ? 0.0 : 1.0;
        _previousImage = null;
        _hasShownOnce = true;
      } else {
        _controller.forward(from: 0.0);
      }
    } else if (widget.skipAnimation && !_hasShownOnce) {
      _controller.value = 1.0;
      _previousImage = null;
      _hasShownOnce = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _currentImage;
    if (image == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _progress,
      builder: (context, child) {
        final dissolveProgram = CompositeCgRenderer._dissolveProgram;
        final bool shaderAvailable = dissolveProgram != null;
        final bool hasPrevious = _previousImage != null && !widget.isFadingOut;
        final progressValue = _progress.value.clamp(0.0, 1.0);
        double overallAlpha;
        if (widget.isFadingOut) {
          overallAlpha = 1.0 - progressValue;
        } else if (widget.enableFadeIn && !_hasShownOnce) {
          overallAlpha = progressValue;
        } else {
          overallAlpha = 1.0;
        }
        assert(() {
          if (!_hasShownOnce && widget.enableFadeIn) {
            print('[DirectCgDisplay] progress=${progressValue.toStringAsFixed(2)} alpha=${overallAlpha.toStringAsFixed(2)}');
          }
          return true;
        }());
        if (widget.skipAnimation) {
          overallAlpha = widget.isFadingOut ? 0.0 : 1.0;
        }
        overallAlpha = overallAlpha.clamp(0.0, 1.0);
        final ui.Image fromImage = hasPrevious ? _previousImage! : image;
        final double dissolveProgress = hasPrevious ? progressValue : 1.0;
        if (shaderAvailable) {
          return LayoutBuilder(
            builder: (context, constraints) {
              return CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: _DissolveShaderPainter(
                  program: dissolveProgram!,
                  progress: dissolveProgress,
                  fromImage: fromImage,
                  toImage: image,
                  opacity: overallAlpha,
                ),
              );
            },
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            return CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: DirectCgPainter(
                currentImage: image,
                previousImage: _previousImage,
                progress: progressValue,
                isFadingOut: widget.isFadingOut,
                enableFadeIn: widget.enableFadeIn && !_hasShownOnce,
              ),
            );
          },
        );
      },
    );
  }
}

/// 使用预合成图像的交叉淡入淡出绘制器
class DirectCgPainter extends CustomPainter {
  final ui.Image currentImage;
  final ui.Image? previousImage;
  final double progress;
  final bool isFadingOut;
  final bool enableFadeIn;

  DirectCgPainter({
    required this.currentImage,
    required this.previousImage,
    required this.progress,
    required this.isFadingOut,
    required this.enableFadeIn,
  });

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    if (size.isEmpty) return;

    final clampedProgress = progress.clamp(0.0, 1.0);
    final hasPrevious = previousImage != null;

    if (hasPrevious && !isFadingOut) {
      canvas.saveLayer(null, ui.Paint());
      _drawImage(canvas, size, previousImage!, 1.0 - clampedProgress);
      _drawImage(canvas, size, currentImage, clampedProgress);
      canvas.restore();
      return;
    }

    final opacity = isFadingOut
        ? 1.0 - clampedProgress
        : (enableFadeIn ? clampedProgress : 1.0);
    _drawImage(canvas, size, currentImage, opacity);
  }

  void _drawImage(
    ui.Canvas canvas,
    ui.Size size,
    ui.Image image,
    double opacity,
  ) {
    if (opacity <= 0) return;

    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;
    final scale = math.max(scaleX, scaleY);

    final targetWidth = imageSize.width * scale;
    final targetHeight = imageSize.height * scale;
    final offsetX = (size.width - targetWidth) / 2;
    final offsetY = (size.height - targetHeight) / 2;

    final targetRect = ui.Rect.fromLTWH(offsetX, offsetY, targetWidth, targetHeight);

    final paint = ui.Paint()
      ..color = ui.Color.fromRGBO(255, 255, 255, opacity.clamp(0.0, 1.0))
      ..isAntiAlias = true
      ..filterQuality = ui.FilterQuality.high;

    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      targetRect,
      paint,
    );
  }

  @override
  bool shouldRepaint(DirectCgPainter oldDelegate) {
    return currentImage != oldDelegate.currentImage ||
        previousImage != oldDelegate.previousImage ||
        progress != oldDelegate.progress ||
        isFadingOut != oldDelegate.isFadingOut ||
        enableFadeIn != oldDelegate.enableFadeIn;
  }
}

  /// 无缝CG切换显示组件
/// 
/// 提供在差分切换时无黑屏的平滑过渡效果
class SeamlessCgDisplay extends StatefulWidget {
  final String? newImagePath;
  final String? currentImagePath;
  final String resourceId;
  final ui.FragmentProgram? dissolveProgram;
  final bool isFadingOut;
  final bool skipAnimation;
  
  const SeamlessCgDisplay({
    super.key,
    this.newImagePath,
    this.currentImagePath,
    required this.resourceId,
    this.dissolveProgram,
    this.isFadingOut = false,
    this.skipAnimation = false,
  });

  @override
  State<SeamlessCgDisplay> createState() => _SeamlessCgDisplayState();
}

class _SeamlessCgDisplayState extends State<SeamlessCgDisplay>
    with TickerProviderStateMixin {
  ui.Image? _currentImage;
  ui.Image? _previousImage;
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    // 优先加载当前图像或新图像
    final imageToLoad = widget.newImagePath ?? widget.currentImagePath;
    if (imageToLoad != null) {
      _loadAndSetImage(imageToLoad);
    }

    _fadeController.addStatusListener(_handleFadeStatus);
    if (widget.dissolveProgram == null) {
      CompositeCgRenderer._ensureDissolveProgram().then((_) {
        if (mounted && CompositeCgRenderer._dissolveProgram != null) {
          setState(() {});
        }
      });
    }
    if (widget.skipAnimation) {
      _fadeController.value = widget.isFadingOut ? 0.0 : 1.0;
    }
  }

  @override
  void didUpdateWidget(SeamlessCgDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 如果有新图像路径，加载它
    if (widget.newImagePath != null && 
        widget.newImagePath != oldWidget.newImagePath) {
      _loadAndSetImage(widget.newImagePath!);
    }
    // 如果没有新图像但有当前图像，且当前图像变了，加载当前图像
    else if (widget.newImagePath == null && 
             widget.currentImagePath != null &&
             widget.currentImagePath != oldWidget.currentImagePath) {
      _loadAndSetImage(widget.currentImagePath!);
    }

    if (widget.skipAnimation) {
      _fadeController.value = widget.isFadingOut ? 0.0 : 1.0;
      if (_previousImage != null) {
        _previousImage = null;
      }
    }
  }

  Future<void> _loadAndSetImage(String imagePath) async {
    try {
      // 修复：优先从内存缓存获取图像数据
      final imageBytes =
          CompositeCgRenderer._legacyCompositor.getImageBytes(imagePath);
      if (imageBytes != null) {
        final codec = await ui.instantiateImageCodec(imageBytes);
        final frame = await codec.getNextFrame();
        
        if (mounted) {
          final oldImage = _currentImage;
          
          setState(() {
            _previousImage = oldImage;
            _currentImage = frame.image;
          });
          
          if (widget.skipAnimation) {
            _fadeController.value = widget.isFadingOut ? 0.0 : 1.0;
            _previousImage = null;
          } else {
            _fadeController.forward(from: 0.0);
          }
        }
        return;
      }
      
      // 降级到文件系统（兼容性处理）
      final file = File(imagePath);
      if (!await file.exists()) return;

      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      
      if (mounted) {
        final oldImage = _currentImage;
        
        setState(() {
          _previousImage = oldImage;
          _currentImage = frame.image;
        });
        
        if (widget.skipAnimation) {
          _fadeController.value = widget.isFadingOut ? 0.0 : 1.0;
          _previousImage = null;
        } else {
          _fadeController.forward(from: 0.0);
        }
      }
    } catch (e) {
      // 加载失败时保持当前显示的图像不变
    }
  }

  @override
  void dispose() {
    _fadeController.removeStatusListener(_handleFadeStatus);
    _fadeController.dispose();
    _previousImage = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 关键：如果没有图像可显示，返回透明容器而不是空白
    if (_currentImage == null) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.transparent,
      );
    }

    final dissolveProgram =
        widget.dissolveProgram ?? CompositeCgRenderer._dissolveProgram;
    final bool shaderAvailable = dissolveProgram != null;
    final bool skipping = widget.skipAnimation;
    final double animationValue = skipping
        ? (widget.isFadingOut ? 0.0 : 1.0)
        : _fadeAnimation.value.clamp(0.0, 1.0);
    final bool hasPrevious = !skipping && _previousImage != null && !widget.isFadingOut;
    double overallAlpha;
    if (widget.isFadingOut) {
      overallAlpha = skipping ? 0.0 : 1.0 - animationValue;
    } else {
      overallAlpha = 1.0;
    }
    overallAlpha = overallAlpha.clamp(0.0, 1.0);
    final ui.Image fromImage = hasPrevious ? _previousImage! : _currentImage!;
    final double dissolveProgress = hasPrevious ? animationValue : 1.0;

    if (shaderAvailable) {
      return AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return LayoutBuilder(
            builder: (context, constraints) {
              return CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: _DissolveShaderPainter(
                  program: dissolveProgram!,
                  progress: dissolveProgress,
                  fromImage: fromImage,
                  toImage: _currentImage!,
                  opacity: overallAlpha,
                ),
              );
            },
          );
        },
      );
    }

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        final double painterOpacity = widget.skipAnimation
            ? (widget.isFadingOut ? 0.0 : 1.0)
            : _fadeAnimation.value;
        return LayoutBuilder(
          builder: (context, constraints) {
            return CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: SeamlessCgPainter(
                currentImage: _currentImage,
                newImage: null,
                fadeOpacity: painterOpacity,
                transitionOpacity: 0.0,
              ),
            );
          },
        );
      },
    );
  }

  void _handleFadeStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _previousImage = null;
    }
  }
}

class _FirstCgFadeWrapper extends StatefulWidget {
  final String fadeKey;
  final Widget child;
  final bool enableFade;

  const _FirstCgFadeWrapper({
    required this.fadeKey,
    required this.child,
    required this.enableFade,
  });

  @override
  State<_FirstCgFadeWrapper> createState() => _FirstCgFadeWrapperState();
}

class _FirstCgFadeWrapperState extends State<_FirstCgFadeWrapper>
    with SingleTickerProviderStateMixin {
  static final Set<String> _fadedKeys = <String>{};
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late bool _shouldFade;

  @override
  void initState() {
    super.initState();
    _shouldFade = widget.enableFade && !_fadedKeys.contains(widget.fadeKey);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: _shouldFade ? 0.0 : 1.0,
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    if (_shouldFade) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _FirstCgFadeWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fadeKey != widget.fadeKey) {
      final bool shouldFadeNow = widget.enableFade && !_fadedKeys.contains(widget.fadeKey);
      if (shouldFadeNow) {
        _controller.value = 0.0;
        _controller.forward();
        _shouldFade = true;
      } else {
        _controller.value = 1.0;
        _shouldFade = false;
      }
    }
  }

  @override
  void dispose() {
    if (_shouldFade) {
      _fadedKeys.add(widget.fadeKey);
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldFade) {
      return widget.child;
    }
    return FadeTransition(
      opacity: _opacity,
      child: widget.child,
    );
  }
}

/// 合成CG显示组件
class CompositeCgDisplay extends StatefulWidget {
  final String imagePath;
  final bool isFadingOut;
  
  const CompositeCgDisplay({
    super.key,
    required this.imagePath,
    this.isFadingOut = false,
  });

  @override
  State<CompositeCgDisplay> createState() => _CompositeCgDisplayState();
}

class _CompositeCgDisplayState extends State<CompositeCgDisplay>
    with SingleTickerProviderStateMixin {
  
  ui.Image? _image;
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant CompositeCgDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 检查是否开始淡出
    if (!oldWidget.isFadingOut && widget.isFadingOut) {
      _controller.reverse();
      return;
    }
    
    // 检查图像路径是否改变
    if (oldWidget.imagePath != widget.imagePath) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    try {
      final file = File(widget.imagePath);
      if (!await file.exists()) {
        return;
      }

      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      
      if (mounted) {
        setState(() {
          _image?.dispose(); // 释放旧图像
          _image = frame.image;
        });
        
        // 开始淡入动画
        _controller.forward();
      }
    } catch (e) {
      // 静默处理错误
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_image == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: CompositeCgPainter(
                image: _image!,
                opacity: _fadeAnimation.value,
              ),
            );
          },
        );
      },
    );
  }
}

class _DissolveShaderPainter extends CustomPainter {
  final ui.FragmentProgram program;
  final double progress;
  final ui.Image fromImage;
  final ui.Image toImage;
  final double opacity;

  _DissolveShaderPainter({
    required this.program,
    required this.progress,
    required this.fromImage,
    required this.toImage,
    required this.opacity,
  });

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    if (size.isEmpty) return;

    final targetRect = _calculateCoverRect(size, toImage.width, toImage.height);

    final shader = program.fragmentShader();
    shader
      ..setFloat(0, progress.clamp(0.0, 1.0))
      ..setFloat(1, targetRect.width)
      ..setFloat(2, targetRect.height)
      ..setFloat(3, fromImage.width.toDouble())
      ..setFloat(4, fromImage.height.toDouble())
      ..setFloat(5, toImage.width.toDouble())
      ..setFloat(6, toImage.height.toDouble())
      ..setFloat(7, targetRect.left)
      ..setFloat(8, targetRect.top)
      ..setFloat(9, opacity.clamp(0.0, 1.0));

    shader
      ..setImageSampler(0, fromImage)
      ..setImageSampler(1, toImage);

    final paint = ui.Paint()..shader = shader;

    canvas.drawRect(targetRect, paint);
  }

  @override
  bool shouldRepaint(covariant _DissolveShaderPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        fromImage != oldDelegate.fromImage ||
        toImage != oldDelegate.toImage ||
        program != oldDelegate.program ||
        opacity != oldDelegate.opacity;
  }
}

/// 无缝CG切换绘制器
/// 
/// 支持两个图像之间的平滑过渡，避免黑屏
class SeamlessCgPainter extends CustomPainter {
  final ui.Image? currentImage;
  final ui.Image? newImage;
  final double fadeOpacity;
  final double transitionOpacity;

  SeamlessCgPainter({
    this.currentImage,
    this.newImage,
    required this.fadeOpacity,
    required this.transitionOpacity,
  });

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    if (size.isEmpty) return;
    
    try {
      // 如果正在过渡，绘制两个图像的混合
      if (newImage != null && currentImage != null && transitionOpacity > 0) {
        // 绘制当前图像（透明度递减）
        _drawImageWithOpacity(canvas, size, currentImage!, 1.0 - transitionOpacity);
        
        // 绘制新图像（透明度递增）
        _drawImageWithOpacity(canvas, size, newImage!, transitionOpacity);
      }
      // 只有当前图像
      else if (currentImage != null) {
        _drawImageWithOpacity(canvas, size, currentImage!, fadeOpacity);
      }
      // 只有新图像
      else if (newImage != null) {
        _drawImageWithOpacity(canvas, size, newImage!, fadeOpacity);
      }
      
    } catch (e) {
      // 静默处理绘制错误
    }
  }

  void _drawImageWithOpacity(ui.Canvas canvas, ui.Size size, ui.Image image, double opacity) {
    if (opacity <= 0) return;
    
    try {
      // 计算BoxFit.cover的缩放和定位
      final imageSize = Size(image.width.toDouble(), image.height.toDouble());
      
      // 计算缩放比例（cover模式取较大的缩放比例）
      final scaleX = size.width / imageSize.width;
      final scaleY = size.height / imageSize.height;
      final scale = scaleX > scaleY ? scaleX : scaleY;
      
      // 计算缩放后的尺寸
      final scaledWidth = imageSize.width * scale;
      final scaledHeight = imageSize.height * scale;
      
      // 计算居中偏移
      final offsetX = (size.width - scaledWidth) / 2;
      final offsetY = (size.height - scaledHeight) / 2;
      
      // 创建目标矩形
      final targetRect = ui.Rect.fromLTWH(offsetX, offsetY, scaledWidth, scaledHeight);
      
      // 创建画笔，设置透明度
      final paint = ui.Paint()
        ..color = Color.fromRGBO(255, 255, 255, opacity.clamp(0.0, 1.0))
        ..isAntiAlias = true
        ..filterQuality = ui.FilterQuality.high;
      
      // 绘制图像
      canvas.drawImageRect(
        image,
        ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        targetRect,
        paint,
      );
      
    } catch (e) {
      // 静默处理绘制错误
    }
  }

  @override
  bool shouldRepaint(SeamlessCgPainter oldDelegate) {
    return currentImage != oldDelegate.currentImage ||
           newImage != oldDelegate.newImage ||
           fadeOpacity != oldDelegate.fadeOpacity ||
           transitionOpacity != oldDelegate.transitionOpacity;
  }
}

/// 合成CG图像的绘制器
class CompositeCgPainter extends CustomPainter {
  final ui.Image image;
  final double opacity;

  CompositeCgPainter({
    required this.image,
    required this.opacity,
  });

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    try {
      // 计算BoxFit.cover的缩放和定位
      final imageSize = Size(image.width.toDouble(), image.height.toDouble());
      
      // 计算缩放比例（cover模式取较大的缩放比例）
      final scaleX = size.width / imageSize.width;
      final scaleY = size.height / imageSize.height;
      final scale = scaleX > scaleY ? scaleX : scaleY;
      
      // 计算缩放后的尺寸
      final scaledWidth = imageSize.width * scale;
      final scaledHeight = imageSize.height * scale;
      
      // 计算居中偏移
      final offsetX = (size.width - scaledWidth) / 2;
      final offsetY = (size.height - scaledHeight) / 2;
      
      // 创建目标矩形
      final targetRect = ui.Rect.fromLTWH(offsetX, offsetY, scaledWidth, scaledHeight);
      
      // 创建画笔，设置透明度
      final paint = ui.Paint()
        ..color = Color.fromRGBO(255, 255, 255, opacity)
        ..isAntiAlias = true
        ..filterQuality = ui.FilterQuality.high;
      
      // 绘制图像
      canvas.drawImageRect(
        image,
        ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        targetRect,
        paint,
      );
      
    } catch (e) {
      // 静默处理绘制错误
    }
  }

  @override
  bool shouldRepaint(covariant CompositeCgPainter oldDelegate) {
    return image != oldDelegate.image || opacity != oldDelegate.opacity;
  }
}

ui.Rect _calculateCoverRect(ui.Size canvasSize, int width, int height) {
  if (canvasSize.isEmpty || width == 0 || height == 0) {
    return ui.Rect.zero;
  }

  final imageWidth = width.toDouble();
  final imageHeight = height.toDouble();
  final scaleX = canvasSize.width / imageWidth;
  final scaleY = canvasSize.height / imageHeight;
  final scale = math.max(scaleX, scaleY);

  final scaledWidth = imageWidth * scale;
  final scaledHeight = imageHeight * scale;
  final offsetX = (canvasSize.width - scaledWidth) / 2;
  final offsetY = (canvasSize.height - scaledHeight) / 2;

  return ui.Rect.fromLTWH(offsetX, offsetY, scaledWidth, scaledHeight);
}

void _drawCompositeResult(
  ui.Canvas canvas,
  ui.Size size,
  GpuCompositeResult result,
  double opacity,
) {
  if (opacity <= 0 || size.isEmpty) return;

  final targetRect = _calculateCoverRect(size, result.width, result.height);
  if (targetRect.isEmpty) return;

  final srcRect = ui.Rect.fromLTWH(
    0,
    0,
    result.width.toDouble(),
    result.height.toDouble(),
  );

  final alpha = opacity.clamp(0.0, 1.0);
  final paint = ui.Paint()
    ..isAntiAlias = true
    ..filterQuality = ui.FilterQuality.high;

  for (var index = 0; index < result.layers.length; index++) {
    final layer = result.layers[index];
    paint
      ..blendMode = index == 0 ? ui.BlendMode.src : ui.BlendMode.srcOver
      ..color = ui.Color.fromRGBO(255, 255, 255, alpha);
    canvas.drawImageRect(layer, srcRect, targetRect, paint);
  }
}
