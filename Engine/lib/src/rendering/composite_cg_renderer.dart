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
      
      // 检查是否已经有完成的路径
      if (_completedPaths.containsKey(cacheKey)) {
        final compositeImagePath = _completedPaths[cacheKey]!;
        
        return CompositeCgDisplay(
          key: ValueKey('composite_display_${characterState.resourceId}'),
          imagePath: compositeImagePath,
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
          }
          return path;
        });
      }
      
      return FutureBuilder<String?>(
        key: ValueKey(widgetKey),
        future: _futureCache[cacheKey],
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // 加载中时不显示任何内容，让背景或其他内容显示
            return const SizedBox.shrink();
          }
          
          if (!snapshot.hasData || snapshot.data == null) {
            return const SizedBox.shrink();
          }

          final compositeImagePath = snapshot.data!;

          return CompositeCgDisplay(
            key: ValueKey('composite_display_${characterState.resourceId}'),
            imagePath: compositeImagePath,
            isFadingOut: characterState.isFadingOut,
          );
        },
      );
    }).toList();
  }
  
  /// 预显示常见的差分变化，确保后续切换不是"第一次"
  static Future<void> _preDisplayCommonVariations(String resourceId, String pose) async {
    // 预显示常见的数字差分：1, 2, 3, 4, 5
    final commonExpressions = ['1', '2', '3', '4', '5'];
    
    print('[CompositeCgRenderer] 开始预显示差分: $resourceId, $pose');
    
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
            print('[CompositeCgRenderer] 预显示完成: $cacheKey -> $path');
          }
          return path;
        }).catchError((error) {
          // 忽略不存在的差分错误
          print('[CompositeCgRenderer] 预显示失败（可能不存在）: $cacheKey');
          return null;
        });
      }
    }
  }
  
  /// 清理缓存
  static void clearCache() {
    _futureCache.clear();
    _completedPaths.clear();
    _preDisplayedCgs.clear();
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