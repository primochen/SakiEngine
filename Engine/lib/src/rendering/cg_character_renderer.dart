import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/asset_manager.dart';
import 'package:sakiengine/src/config/config_models.dart';
import 'package:sakiengine/src/game/game_manager.dart';
import 'package:sakiengine/src/utils/character_layer_parser.dart';
import 'package:sakiengine/src/utils/image_loader.dart';

/// CG角色渲染器，负责处理CG模式下的角色显示
class CgCharacterRenderer {
  static List<Widget> buildCgCharacters(
    BuildContext context, 
    Map<String, CharacterState> cgCharacters, 
    Map<String, PoseConfig> poseConfigs, 
    Set<String> everShownCharacters
  ) {
    //print('[CgCharacterRenderer] 构建CG角色，数量: ${cgCharacters.length}');
    if (cgCharacters.isEmpty) return [];
    
    // 按resourceId分组，保留最新的角色状态
    final Map<String, MapEntry<String, CharacterState>> charactersByResourceId = {};
    
    for (final entry in cgCharacters.entries) {
      final resourceId = entry.value.resourceId;
      //print('[CgCharacterRenderer] 处理CG角色: ${entry.key}, resourceId: $resourceId, pose: ${entry.value.pose}, expression: ${entry.value.expression}');
      // 总是保留最新的状态（覆盖之前的）
      charactersByResourceId[resourceId] = entry;
    }
    
    return charactersByResourceId.values.map((entry) {
      final characterId = entry.key;
      final characterState = entry.value;

      // 使用resourceId作为key，确保唯一性
      final widgetKey = 'cg_${characterState.resourceId}';
      
      return FutureBuilder<List<CharacterLayerInfo>>(
        key: ValueKey(widgetKey), // 使用resourceId作为key
        future: CharacterLayerParser.parseCharacterLayers(
          resourceId: characterState.resourceId,
          pose: characterState.pose ?? 'pose1',
          expression: characterState.expression ?? 'happy',
        ),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox.shrink();
          }

          final layerInfos = snapshot.data!;

          // 根据解析结果创建图层组件，使用resourceId和图层类型作为key，保持差分动画
          final layers = layerInfos.map((layerInfo) {
            return CgCharacterLayer(
              key: ValueKey('cg_${characterState.resourceId}-${layerInfo.layerType}'),
              assetName: layerInfo.assetName,
              isFadingOut: characterState.isFadingOut,
            );
          }).toList();

          // CG角色直接返回层叠的图层，不使用pose配置的位置，而是铺满整个屏幕
          return Stack(
            fit: StackFit.expand, // 铺满整个屏幕
            children: layers,
          );
        },
      );
    }).toList();
  }
}

/// CG角色图层组件，以铺满屏幕的方式渲染图像
class CgCharacterLayer extends StatefulWidget {
  final String assetName;
  final bool isFadingOut;
  final VoidCallback? onFadeOutComplete;
  
  const CgCharacterLayer({
    super.key, 
    required this.assetName,
    this.isFadingOut = false,
    this.onFadeOutComplete,
  });

  @override
  State<CgCharacterLayer> createState() => _CgCharacterLayerState();
}

class _CgCharacterLayerState extends State<CgCharacterLayer>
    with SingleTickerProviderStateMixin {
  ui.Image? _currentImage;
  ui.Image? _previousImage;

  late final AnimationController _controller;
  late final Animation<double> _animation;

  static ui.FragmentProgram? _dissolveProgram;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);

    _loadImage();
    _loadShader();
  }

  Future<void> _loadShader() async {
    if (_dissolveProgram == null) {
      try {
        final program = await ui.FragmentProgram.fromAsset('assets/shaders/dissolve.frag');
        _dissolveProgram = program;
      } catch (e) {
        print('Error loading shader: $e');
      }
    }
  }

  @override
  void didUpdateWidget(covariant CgCharacterLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 检查是否开始淡出
    if (!oldWidget.isFadingOut && widget.isFadingOut) {
      // 开始淡出动画
      _controller.reverse().then((_) {
        // 淡出完成，通知回调
        widget.onFadeOutComplete?.call();
      });
      return;
    }
    
    if (oldWidget.assetName != widget.assetName) {
      _previousImage = _currentImage;
      _loadImage().then((_) {
        if (mounted) {
          _controller.forward(from: 0.0);
        }
      });
    }
  }

  Future<void> _loadImage() async {
    final assetPath = await AssetManager().findAsset(widget.assetName);
    if (assetPath != null && mounted) {
      final image = await ImageLoader.loadImage(assetPath);
      if (mounted && image != null) {
        setState(() {
          _currentImage = image;
        });
        
        // 始终触发动画
        _controller.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _currentImage?.dispose();
    _previousImage?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentImage == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            // CG图像使用与scene相同的BoxFit.cover方式铺满屏幕，保持比例
            return ClipRect(
              child: FadeTransition(
                opacity: _animation,
                child: RawImage(
                  image: _currentImage!,
                  fit: BoxFit.cover, // 像scene一样使用cover方式
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  filterQuality: FilterQuality.high,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// CG图层的溶解绘制器，专门为铺满屏幕的CG渲染优化
class CgDissolvePainter extends CustomPainter {
  final ui.FragmentProgram program;
  final double progress;
  final ui.Image imageFrom;
  final ui.Image imageTo;

  CgDissolvePainter({
    required this.program,
    required this.progress,
    required this.imageFrom,
    required this.imageTo,
  });

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    try {
      // 如果没有之前的图片（首次显示），从透明开始
      if (imageFrom == imageTo) {
        // 首次显示：简单的透明度渐变，并铺满整个画布
        final paint = ui.Paint()
          ..color = Colors.white.withOpacity(progress)
          ..isAntiAlias = true
          ..filterQuality = FilterQuality.high;
        
        // 像scene背景一样填充整个区域
        canvas.drawImageRect(
          imageTo,
          ui.Rect.fromLTWH(0, 0, imageTo.width.toDouble(), imageTo.height.toDouble()),
          ui.Rect.fromLTWH(0, 0, size.width, size.height),
          paint,
        );
        return;
      }

      // 差分切换：使用dissolve效果
      final shader = program.fragmentShader();
      shader
        ..setFloat(0, progress)
        ..setFloat(1, size.width)
        ..setFloat(2, size.height)
        ..setFloat(3, imageFrom.width.toDouble())
        ..setFloat(4, imageFrom.height.toDouble())
        ..setFloat(5, imageTo.width.toDouble())
        ..setFloat(6, imageTo.height.toDouble())
        ..setImageSampler(0, imageFrom)
        ..setImageSampler(1, imageTo);

      final paint = ui.Paint()
        ..shader = shader
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high;
      canvas.drawRect(ui.Rect.fromLTWH(0, 0, size.width, size.height), paint);
    } catch (e) {
      print("Error painting CG dissolve shader: $e");
    }
  }

  @override
  bool shouldRepaint(covariant CgDissolvePainter oldDelegate) {
    return progress != oldDelegate.progress ||
        imageFrom != oldDelegate.imageFrom ||
        imageTo != oldDelegate.imageTo;
  }
}