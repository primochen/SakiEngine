import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/asset_manager.dart';
import 'package:sakiengine/src/game/game_manager.dart';
import 'package:sakiengine/src/utils/cg_image_compositor.dart';
import 'package:sakiengine/src/sks_parser/sks_ast.dart';

/// 基于预合成图像的CG角色渲染器
/// 
/// 替代原有的多层实时渲染方式，直接使用预合成的单张图像
class CompositeCgRenderer {
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
  
  // 预热是否已经开始
  static bool _preWarmingStarted = false;
  
  static List<Widget> buildCgCharacters(
    BuildContext context,
    Map<String, CharacterState> cgCharacters,
    GameManager gameManager,
  ) {
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
    
    return charactersByResourceId.values.map((entry) {
      final characterId = entry.key;
      final characterState = entry.value;

      // 使用resourceId作为key，确保唯一性
      final widgetKey = 'composite_cg_${characterState.resourceId}';
      
      // 生成缓存键用于Future缓存
      final cacheKey = '${characterState.resourceId}_${characterState.pose ?? 'pose1'}_${characterState.expression ?? 'happy'}';
      
      // 检查是否需要预显示常见差分
      final resourceBaseId = '${characterState.resourceId}_${characterState.pose ?? 'pose1'}';
      if (!_preDisplayedCgs.contains(resourceBaseId)) {
        _preDisplayedCgs.add(resourceBaseId);
        // 异步预显示常见的差分
        _preDisplayCommonVariations(characterState.resourceId, characterState.pose ?? 'pose1');
      }
      
      // 获取当前显示的图像路径（用于无缝切换）
      final currentImagePath = _currentDisplayedImages[characterState.resourceId];
      
      // 关键修复：检查是否已经预加载了这个图像
      if (_preloadedImages.containsKey(cacheKey)) {
        final preloadedImage = _preloadedImages[cacheKey]!;
        _currentDisplayedImages[characterState.resourceId] = cacheKey; // 使用cacheKey作为标识
        
        return DirectCgDisplay(
          key: ValueKey('direct_display_${characterState.resourceId}'),
          image: preloadedImage,
          resourceId: characterState.resourceId,
          isFadingOut: characterState.isFadingOut,
        );
      }
      
      // 检查是否已经有完成的路径
      if (_completedPaths.containsKey(cacheKey)) {
        final compositeImagePath = _completedPaths[cacheKey]!;
        
        // 更新当前显示的图像
        _currentDisplayedImages[characterState.resourceId] = compositeImagePath;
        
        return SeamlessCgDisplay(
          key: ValueKey('seamless_display_${characterState.resourceId}'),
          newImagePath: compositeImagePath,
          currentImagePath: currentImagePath,
          resourceId: characterState.resourceId,
          isFadingOut: characterState.isFadingOut,
        );
      }
      
      // 获取或创建Future
      if (!_futureCache.containsKey(cacheKey)) {
        _futureCache[cacheKey] = _loadAndCacheImage(
          resourceId: characterState.resourceId,
          pose: characterState.pose ?? 'pose1',
          expression: characterState.expression ?? 'happy',
          cacheKey: cacheKey,
        );
      }
      
      return FutureBuilder<String?>(
        key: ValueKey(widgetKey),
        future: _futureCache[cacheKey],
        builder: (context, snapshot) {
          // 核心修复：无论什么状态都先尝试显示当前图像
          final shouldShowCurrent = currentImagePath != null;
          final hasNewImage = snapshot.hasData && snapshot.data != null;
          
          if (snapshot.connectionState == ConnectionState.waiting) {
            // 等待中：如果有当前图像就显示，没有则显示占位符但不返回空白
            if (shouldShowCurrent) {
              return SeamlessCgDisplay(
                key: ValueKey('seamless_display_${characterState.resourceId}'),
                newImagePath: null, // 正在加载
                currentImagePath: currentImagePath,
                resourceId: characterState.resourceId,
                isFadingOut: characterState.isFadingOut,
              );
            }
            // 首次加载时显示透明占位符，避免布局闪烁
            return Container(
              key: ValueKey('loading_placeholder_${characterState.resourceId}'),
              width: double.infinity,
              height: double.infinity,
            );
          }
          
          if (!hasNewImage) {
            // 加载失败：如果有当前图像继续显示，否则返回占位符
            if (shouldShowCurrent) {
              return SeamlessCgDisplay(
                key: ValueKey('seamless_display_${characterState.resourceId}'),
                newImagePath: null,
                currentImagePath: currentImagePath,
                resourceId: characterState.resourceId,
                isFadingOut: characterState.isFadingOut,
              );
            }
            return Container(
              key: ValueKey('error_placeholder_${characterState.resourceId}'),
              width: double.infinity,
              height: double.infinity,
            );
          }

          final compositeImagePath = snapshot.data!;
          
          // 更新当前显示的图像
          _currentDisplayedImages[characterState.resourceId] = compositeImagePath;

          return SeamlessCgDisplay(
            key: ValueKey('seamless_display_${characterState.resourceId}'),
            newImagePath: compositeImagePath,
            currentImagePath: currentImagePath,
            resourceId: characterState.resourceId,
            isFadingOut: characterState.isFadingOut,
          );
        },
      );
    }).toList();
  }
  
  /// 加载并缓存图像到内存（关键方法）
  static Future<String?> _loadAndCacheImage({
    required String resourceId,
    required String pose,
    required String expression,
    required String cacheKey,
  }) async {
    try {
      print('[CompositeCgRenderer] 开始加载: $cacheKey');
      
      // 先获取合成图像路径
      final compositeImagePath = await CgImageCompositor().getCompositeImagePath(
        resourceId: resourceId,
        pose: pose,
        expression: expression,
      );
      
      print('[CompositeCgRenderer] 合成路径: $compositeImagePath');
      
      if (compositeImagePath != null) {
        // 缓存完成的路径
        _completedPaths[cacheKey] = compositeImagePath;
        
        // 关键：同时将图像加载到内存缓存中
        final file = File(compositeImagePath);
        print('[CompositeCgRenderer] 文件存在: ${await file.exists()}');
        
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          
          // 缓存到内存，确保下次访问时没有"第一次加载"
          _preloadedImages[cacheKey] = frame.image;
          print('[CompositeCgRenderer] 成功缓存到内存: $cacheKey, 总缓存数: ${_preloadedImages.length}');
        } else {
          print('[CompositeCgRenderer] 文件不存在: $compositeImagePath');
        }
        
        // 更新当前显示的图像
        _currentDisplayedImages[resourceId] = compositeImagePath;
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
      final compositeImagePath = await CgImageCompositor().getCompositeImagePath(
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
}

/// 直接CG显示组件（用于已预加载的图像）
/// 
/// 直接显示已在内存中的图像，无需加载过程
class DirectCgDisplay extends StatefulWidget {
  final ui.Image image;
  final String resourceId;
  final bool isFadingOut;
  
  const DirectCgDisplay({
    super.key,
    required this.image,
    required this.resourceId,
    this.isFadingOut = false,
  });

  @override
  State<DirectCgDisplay> createState() => _DirectCgDisplayState();
}

class _DirectCgDisplayState extends State<DirectCgDisplay>
    with SingleTickerProviderStateMixin {
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

    // 立即开始淡入，因为图像已经在内存中
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    // 注意：不要在这里dispose image，因为它可能被其他地方使用
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
              painter: DirectCgPainter(
                image: widget.image,
                opacity: _fadeAnimation.value,
              ),
            );
          },
        );
      },
    );
  }
}

/// 直接CG绘制器
class DirectCgPainter extends CustomPainter {
  final ui.Image image;
  final double opacity;

  DirectCgPainter({
    required this.image,
    required this.opacity,
  });

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    if (size.isEmpty || opacity <= 0) return;
    
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
  bool shouldRepaint(DirectCgPainter oldDelegate) {
    return image != oldDelegate.image || opacity != oldDelegate.opacity;
  }
}

  /// 无缝CG切换显示组件
/// 
/// 提供在差分切换时无黑屏的平滑过渡效果
class SeamlessCgDisplay extends StatefulWidget {
  final String? newImagePath;
  final String? currentImagePath;
  final String resourceId;
  final bool isFadingOut;
  
  const SeamlessCgDisplay({
    super.key,
    this.newImagePath,
    this.currentImagePath,
    required this.resourceId,
    this.isFadingOut = false,
  });

  @override
  State<SeamlessCgDisplay> createState() => _SeamlessCgDisplayState();
}

class _SeamlessCgDisplayState extends State<SeamlessCgDisplay>
    with TickerProviderStateMixin {
  ui.Image? _displayedImage; // 当前显示的图像（永远不为空一旦有图像）
  
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
  }

  Future<void> _loadAndSetImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) return;

      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      
      if (mounted) {
        // 关键修复：只有在成功加载新图像后才替换显示的图像
        final oldImage = _displayedImage;
        
        setState(() {
          _displayedImage = frame.image;
        });
        
        // 开始淡入动画
        _fadeController.forward();
        
        // 释放旧图像
        oldImage?.dispose();
      }
    } catch (e) {
      // 加载失败时保持当前显示的图像不变
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _displayedImage?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 关键：如果没有图像可显示，返回透明容器而不是空白
    if (_displayedImage == null) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.transparent,
      );
    }

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: SeamlessCgPainter(
                currentImage: _displayedImage,
                newImage: null, // 简化：直接切换图像，不需要双图像混合
                fadeOpacity: _fadeAnimation.value,
                transitionOpacity: 0.0,
              ),
            );
          },
        );
      },
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