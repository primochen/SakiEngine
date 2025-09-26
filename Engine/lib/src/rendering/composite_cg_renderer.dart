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
  
  static List<Widget> buildCgCharacters(
    BuildContext context,
    Map<String, CharacterState> cgCharacters,
    GameManager gameManager,
  ) {
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
        _futureCache[cacheKey] = CgImageCompositor().getCompositeImagePath(
          resourceId: characterState.resourceId,
          pose: characterState.pose ?? 'pose1',
          expression: characterState.expression ?? 'happy',
        ).then((path) {
          // 缓存完成的路径
          if (path != null) {
            _completedPaths[cacheKey] = path;
            // 更新当前显示的图像
            _currentDisplayedImages[characterState.resourceId] = path;
          }
          return path;
        });
      }
      
      return FutureBuilder<String?>(
        key: ValueKey(widgetKey),
        future: _futureCache[cacheKey],
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // 加载中时如果有当前图像，继续显示当前图像而不是空白
            if (currentImagePath != null) {
              return SeamlessCgDisplay(
                key: ValueKey('seamless_display_${characterState.resourceId}'),
                newImagePath: null, // 正在加载
                currentImagePath: currentImagePath,
                resourceId: characterState.resourceId,
                isFadingOut: characterState.isFadingOut,
              );
            }
            // 如果没有当前图像，返回透明占位符而不是完全空白
            return const SizedBox.expand();
          }
          
          if (!snapshot.hasData || snapshot.data == null) {
            // 如果加载失败但有当前图像，继续显示当前图像
            if (currentImagePath != null) {
              return SeamlessCgDisplay(
                key: ValueKey('seamless_display_${characterState.resourceId}'),
                newImagePath: null,
                currentImagePath: currentImagePath,
                resourceId: characterState.resourceId,
                isFadingOut: characterState.isFadingOut,
              );
            }
            return const SizedBox.shrink();
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
  
  /// 预显示常见的差分变化，确保后续切换不是"第一次"
  static Future<void> _preDisplayCommonVariations(String resourceId, String pose) async {
    // 扩大预热范围，包含更多常见差分
    final commonExpressions = ['happy', 'sad', 'angry', 'surprised', 'confused', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    
    for (final expression in commonExpressions) {
      final cacheKey = '${resourceId}_${pose}_$expression';
      
      // 如果还没有缓存这个差分，就预先加载
      if (!_futureCache.containsKey(cacheKey)) {
        _futureCache[cacheKey] = CgImageCompositor().getCompositeImagePath(
          resourceId: resourceId,
          pose: pose,
          expression: expression,
        ).then((path) {
          // 缓存完成的路径
          if (path != null) {
            _completedPaths[cacheKey] = path;
            // 预设为当前显示图像，以便后续快速切换
            if (!_currentDisplayedImages.containsKey(resourceId)) {
              _currentDisplayedImages[resourceId] = path;
            }
          }
          return path;
        }).catchError((error) {
          // 忽略不存在的差分错误
          return null;
        });
      }
    }
    
    // 额外预热其他常见姿势的表情
    final otherPoses = pose == 'pose1' ? ['pose2'] : ['pose1'];
    for (final otherPose in otherPoses) {
      for (final expression in ['happy', '1', '2', '3']) { // 最常用的几个表情
        final cacheKey = '${resourceId}_${otherPose}_$expression';
        
        if (!_futureCache.containsKey(cacheKey)) {
          _futureCache[cacheKey] = CgImageCompositor().getCompositeImagePath(
            resourceId: resourceId,
            pose: otherPose,
            expression: expression,
          ).then((path) {
            if (path != null) {
              _completedPaths[cacheKey] = path;
            }
            return path;
          }).catchError((error) => null);
        }
      }
    }
  }
  
  /// 清理缓存
  static void clearCache() {
    _futureCache.clear();
    _completedPaths.clear();
    _preDisplayedCgs.clear();
    _currentDisplayedImages.clear();
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
  ui.Image? _currentImage;
  ui.Image? _newImage;
  
  late AnimationController _fadeController;
  late AnimationController _transitionController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _transitionAnimation;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _transitionController = AnimationController(
      duration: const Duration(milliseconds: 150), // 快速过渡避免黑屏
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    
    _transitionAnimation = CurvedAnimation(
      parent: _transitionController,
      curve: Curves.easeInOut,
    );

    // 加载当前图像
    if (widget.currentImagePath != null) {
      _loadCurrentImage();
    }
    
    // 加载新图像
    if (widget.newImagePath != null) {
      _loadNewImage();
    }
  }

  @override
  void didUpdateWidget(SeamlessCgDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 如果新图像路径改变了，加载新图像
    if (widget.newImagePath != oldWidget.newImagePath && widget.newImagePath != null) {
      _loadNewImage();
    }
    
    // 如果当前图像路径改变了，更新当前图像
    if (widget.currentImagePath != oldWidget.currentImagePath) {
      if (widget.currentImagePath != null) {
        _loadCurrentImage();
      }
    }
  }

  Future<void> _loadCurrentImage() async {
    if (widget.currentImagePath == null) return;
    
    try {
      final file = File(widget.currentImagePath!);
      if (!await file.exists()) return;

      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      
      if (mounted) {
        setState(() {
          _currentImage?.dispose();
          _currentImage = frame.image;
        });
        
        // 如果没有新图像正在加载，开始淡入当前图像
        if (widget.newImagePath == null) {
          _fadeController.forward();
        }
      }
    } catch (e) {
      // 静默处理错误
    }
  }

  Future<void> _loadNewImage() async {
    if (widget.newImagePath == null) return;
    
    try {
      final file = File(widget.newImagePath!);
      if (!await file.exists()) return;

      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      
      if (mounted) {
        setState(() {
          _newImage?.dispose();
          _newImage = frame.image;
        });
        
        // 开始过渡动画：从当前图像过渡到新图像
        _performTransition();
      }
    } catch (e) {
      // 静默处理错误
    }
  }

  void _performTransition() {
    if (_newImage != null) {
      // 重置过渡动画并开始
      _transitionController.reset();
      _transitionController.forward().then((_) {
        // 过渡完成后，新图像变为当前图像
        if (mounted) {
          setState(() {
            _currentImage?.dispose();
            _currentImage = _newImage;
            _newImage = null;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _transitionController.dispose();
    _currentImage?.dispose();
    _newImage?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentImage == null && _newImage == null) {
      return const SizedBox.expand();
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_fadeAnimation, _transitionAnimation]),
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: SeamlessCgPainter(
                currentImage: _currentImage,
                newImage: _newImage,
                fadeOpacity: _fadeAnimation.value,
                transitionOpacity: _transitionAnimation.value,
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