import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sakiengine/src/config/asset_manager.dart';
import 'package:sakiengine/src/config/config_models.dart';
import 'package:sakiengine/src/game/game_manager.dart';
import 'package:sakiengine/src/utils/image_loader.dart';
import 'package:sakiengine/src/rendering/color_background_renderer.dart';
import 'package:sakiengine/src/utils/character_layer_parser.dart';

/// 游戏渲染器 - 统一的背景和角色绘制逻辑
/// 同时供游戏界面和截图生成器使用，确保完全一致的渲染效果
class GameRenderer {
  
  /// 在Canvas上绘制背景
  static Future<void> drawBackground(
    Canvas canvas, 
    String? backgroundName, 
    Size canvasSize,
  ) async {
    if (backgroundName == null) {
      // 没有背景时使用黑色填充
      canvas.drawRect(
        Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
        Paint()..color = Colors.black,
      );
      return;
    }

    // 检查是否为十六进制颜色格式
    if (ColorBackgroundRenderer.isValidHexColor(backgroundName)) {
      ColorBackgroundRenderer.drawColorBackground(canvas, backgroundName, canvasSize);
      return;
    }

    try {
      final backgroundPath = await AssetManager().findAsset('backgrounds/${backgroundName.replaceAll(' ', '-')}');
      if (backgroundPath == null) return;
      
      // 使用新的图像加载器加载背景图片
      final backgroundImage = await ImageLoader.loadImage(backgroundPath);
      if (backgroundImage == null) return;
      
      // 使用与游戏界面相同的填充逻辑 (BoxFit.cover)
      _drawImageWithBoxFitCover(canvas, backgroundImage, canvasSize);
    } catch (e) {
      print('绘制背景失败: $e');
    }
  }
  
  /// 在Canvas上绘制所有角色
  static Future<void> drawCharacters(
    Canvas canvas,
    Map<String, CharacterState> characters,
    Map<String, PoseConfig> poseConfigs,
    Size canvasSize,
  ) async {
    for (final entry in characters.entries) {
      final characterId = entry.key;
      final characterState = entry.value;
      await drawSingleCharacter(canvas, characterId, characterState, poseConfigs, canvasSize);
    }
  }
  
  /// 在Canvas上绘制单个角色
  static Future<void> drawSingleCharacter(
    Canvas canvas,
    String characterId,
    CharacterState characterState,
    Map<String, PoseConfig> poseConfigs,
    Size canvasSize,
  ) async {
    try {
      final poseConfig = poseConfigs[characterState.positionId] ?? PoseConfig(id: 'default');
      
      // 使用新的异步图层解析器
      final layerInfos = await CharacterLayerParser.parseCharacterLayers(
        resourceId: characterState.resourceId,
        pose: characterState.pose ?? 'pose1',
        expression: characterState.expression ?? 'happy',
      );
      
      // 加载所有图层的图片数据
      ui.Image? sampleImage;
      final layerImages = <ui.Image>[];
      
      for (final layerInfo in layerInfos) {
        final imageData = await _loadCharacterImage(layerInfo.assetName);
        if (imageData != null) {
          layerImages.add(imageData);
          sampleImage ??= imageData; // 用第一个成功加载的图片作为尺寸参考
        }
      }
      
      if (sampleImage == null) return;
      
      // 计算角色的绘制参数
      final renderParams = _calculateCharacterRenderParams(
        poseConfig, 
        canvasSize,
        sampleImage,
      );
      
      // 按层级顺序绘制所有图层
      for (int i = 0; i < layerImages.length; i++) {
        _drawCharacterLayer(canvas, layerImages[i], renderParams);
      }
    } catch (e) {
      print('绘制角色 $characterId 失败: $e');
    }
  }
  
  /// 计算角色渲染参数（复用游戏界面的 _buildCharacters 逻辑）
  static CharacterRenderParams _calculateCharacterRenderParams(
    PoseConfig poseConfig,
    Size canvasSize,
    ui.Image sampleImage,
  ) {
    // 计算位置（复用 Positioned 的逻辑）
    final centerX = poseConfig.xcenter * canvasSize.width;
    final centerY = poseConfig.ycenter * canvasSize.height;
    
    // 计算约束高度（复用 SizedBox 的逻辑）
    double? constraintHeight;
    if (poseConfig.scale > 0) {
      constraintHeight = canvasSize.height * poseConfig.scale;
    }
    
    // 计算实际绘制尺寸（复用 _CharacterLayer 的 LayoutBuilder 逻辑）
    final imageSize = Size(sampleImage.width.toDouble(), sampleImage.height.toDouble());
    Size paintSize;
    
    if (constraintHeight != null && constraintHeight > 0) {
      final imageAspectRatio = imageSize.width / imageSize.height;
      final paintHeight = constraintHeight;
      final paintWidth = paintHeight * imageAspectRatio;
      paintSize = Size(paintWidth, paintHeight);
    } else {
      paintSize = imageSize;
    }
    
    // 计算锚点偏移（复用 _anchorToTranslation 逻辑）
    final anchorOffset = _getAnchorOffset(poseConfig.anchor);
    final finalX = centerX + (anchorOffset.dx * paintSize.width);
    final finalY = centerY + (anchorOffset.dy * paintSize.height);
    
    return CharacterRenderParams(
      x: finalX,
      y: finalY,
      width: paintSize.width,
      height: paintSize.height,
    );
  }
  
  /// 获取锚点偏移（复用 _anchorToTranslation 逻辑）
  static Offset _getAnchorOffset(String anchor) {
    switch (anchor) {
      case 'topCenter': return const Offset(-0.5, 0);
      case 'bottomCenter': return const Offset(-0.5, -1.0);
      case 'centerLeft': return const Offset(0, -0.5);
      case 'centerRight': return const Offset(-1.0, -0.5);
      case 'center':
      default:
        return const Offset(-0.5, -0.5);
    }
  }
  
  /// 在Canvas上绘制角色图层
  static void _drawCharacterLayer(Canvas canvas, ui.Image image, CharacterRenderParams params) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(params.x, params.y, params.width, params.height),
      Paint(),
    );
  }
  
  /// 使用 BoxFit.cover 逻辑绘制图片
  static void _drawImageWithBoxFitCover(Canvas canvas, ui.Image image, Size canvasSize) {
    final imageAspectRatio = image.width / image.height;
    final canvasAspectRatio = canvasSize.width / canvasSize.height;
    
    double scaleX, scaleY;
    if (imageAspectRatio > canvasAspectRatio) {
      // 图片更宽，按高度缩放
      scaleY = canvasSize.height / image.height;
      scaleX = scaleY;
    } else {
      // 图片更高，按宽度缩放
      scaleX = canvasSize.width / image.width;
      scaleY = scaleX;
    }
    
    final scaledWidth = image.width * scaleX;
    final scaledHeight = image.height * scaleY;
    final offsetX = (canvasSize.width - scaledWidth) / 2;
    final offsetY = (canvasSize.height - scaledHeight) / 2;
    
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(offsetX, offsetY, scaledWidth, scaledHeight),
      Paint(),
    );
  }
  
  /// 加载角色图片
  static Future<ui.Image?> _loadCharacterImage(String assetName) async {
    try {
      final assetPath = await AssetManager().findAsset(assetName);
      if (assetPath == null) return null;
      
      return await ImageLoader.loadImage(assetPath);
    } catch (e) {
      print('加载角色图片失败 $assetName: $e');
      return null;
    }
  }
}

/// 角色渲染参数
class CharacterRenderParams {
  final double x;
  final double y;
  final double width;
  final double height;
  
  CharacterRenderParams({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}