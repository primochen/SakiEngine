import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sakiengine/src/config/asset_manager.dart';
import 'package:sakiengine/src/config/config_models.dart';
import 'package:sakiengine/src/game/game_manager.dart';
import 'package:sakiengine/src/utils/image_loader.dart';
import 'package:sakiengine/src/utils/cg_image_compositor.dart';
import 'package:sakiengine/src/rendering/color_background_renderer.dart';
import 'package:sakiengine/src/utils/character_layer_parser.dart';
import 'package:sakiengine/src/utils/character_auto_distribution.dart';
import 'package:sakiengine/src/utils/expression_offset_manager.dart'; // 新增：导入差分偏移管理器

/// 游戏渲染器 - 统一的背景和角色绘制逻辑
/// 同时供游戏界面和截图生成器使用，确保完全一致的渲染效果
class GameRenderer {
  
  /// 在Canvas上绘制背景（支持动画）
  static Future<void> drawBackground(
    Canvas canvas, 
    String? backgroundName, 
    Size canvasSize, {
    Map<String, double>? animationProperties,
  }) async {
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
      ColorBackgroundRenderer.drawColorBackground(canvas, backgroundName, canvasSize, animationProperties: animationProperties);
      return;
    }

    try {
      String? backgroundPath;
      
      // 检查是否为内存缓存路径
      if (CgImageCompositor().isCachePath(backgroundName)) {
        print('[GameRenderer] 🐛 检测到内存缓存背景路径: $backgroundName');
        backgroundPath = backgroundName; // 直接使用内存缓存路径
      } else {
        // 常规资源路径处理
        backgroundPath = await AssetManager().findAsset('backgrounds/${backgroundName.replaceAll(' ', '-')}');
      }
      
      if (backgroundPath == null) {
        print('[GameRenderer] ❌ 背景路径未找到: $backgroundName');
        return;
      }
      
      print('[GameRenderer] 🐛 尝试加载背景图像: $backgroundPath');
      
      // 使用新的图像加载器加载背景图片
      final backgroundImage = await ImageLoader.loadImage(backgroundPath);
      if (backgroundImage == null) {
        print('[GameRenderer] ❌ 背景图像加载失败: $backgroundPath');
        return;
      }
      
      print('[GameRenderer] ✅ 背景图像加载成功: ${backgroundImage.width}x${backgroundImage.height}');
      
      // 使用与游戏界面相同的填充逻辑 (BoxFit.cover)，支持动画
      _drawImageWithBoxFitCover(canvas, backgroundImage, canvasSize, animationProperties: animationProperties);
    } catch (e) {
      print('[GameRenderer] ❌ 绘制背景失败: $e');
    }
  }
  
  /// 在Canvas上绘制所有角色
  static Future<void> drawCharacters(
    Canvas canvas,
    Map<String, CharacterState> characters,
    Map<String, PoseConfig> poseConfigs,
    Size canvasSize,
  ) async {
    // 应用自动分布逻辑
    final characterOrder = characters.keys.toList();
    final distributedPoseConfigs = CharacterAutoDistribution.calculateAutoDistribution(
      characters,
      poseConfigs,
      characterOrder,
    );
    
    for (final entry in characters.entries) {
      final characterId = entry.key;
      final characterState = entry.value;
      await drawSingleCharacter(canvas, characterId, characterState, distributedPoseConfigs, canvasSize);
    }
  }
  
  /// 在Canvas上绘制所有CG角色（铺满屏幕）
  static Future<void> drawCgCharacters(
    Canvas canvas,
    Map<String, CharacterState> cgCharacters,
    Map<String, PoseConfig> poseConfigs,
    Size canvasSize,
  ) async {
    if (cgCharacters.isEmpty) return;
    
    // 按resourceId分组，保留最新的角色状态（复用CgCharacterRenderer的逻辑）
    final Map<String, MapEntry<String, CharacterState>> charactersByResourceId = {};
    
    for (final entry in cgCharacters.entries) {
      final resourceId = entry.value.resourceId;
      // 总是保留最新的状态（覆盖之前的）
      charactersByResourceId[resourceId] = entry;
    }
    
    // 绘制每个CG角色
    for (final entry in charactersByResourceId.values) {
      final characterId = entry.key;
      final characterState = entry.value;
      await drawSingleCgCharacter(canvas, characterId, characterState, canvasSize);
    }
  }
  
  /// 在Canvas上绘制单个CG角色（铺满屏幕）
  static Future<void> drawSingleCgCharacter(
    Canvas canvas,
    String characterId,
    CharacterState characterState,
    Size canvasSize,
  ) async {
    try {
      // 使用异步图层解析器（复用普通角色的逻辑）
      final layerInfos = await CharacterLayerParser.parseCharacterLayers(
        resourceId: characterState.resourceId,
        pose: characterState.pose ?? 'pose1',
        expression: characterState.expression ?? 'happy',
      );
      
      // 按层级顺序绘制所有图层，使用BoxFit.cover效果铺满画布
      for (final layerInfo in layerInfos) {
        final image = await _loadCharacterImage(layerInfo.assetName);
        if (image != null) {
          _drawCgCharacterLayer(canvas, image, canvasSize, characterState.animationProperties);
        }
      }
    } catch (e) {
      print('绘制CG角色 $characterId 失败: $e');
    }
  }
  
  /// 绘制CG角色图层（使用BoxFit.cover效果铺满画布）
  static void _drawCgCharacterLayer(
    Canvas canvas, 
    ui.Image image, 
    Size canvasSize,
    Map<String, double>? animationProperties,
  ) {
    // 计算BoxFit.cover的绘制参数
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
    
    // 应用动画属性（如果有的话）
    final alpha = animationProperties?['alpha'] ?? 1.0;
    final paint = Paint()
      ..filterQuality = FilterQuality.high
      ..isAntiAlias = true
      ..color = Color.fromRGBO(255, 255, 255, alpha);
    
    // 如果有其他动画变换，应用它们
    if (animationProperties != null && animationProperties.isNotEmpty) {
      canvas.save();
      
      // 计算变换中心点
      final centerX = canvasSize.width / 2;
      final centerY = canvasSize.height / 2;
      
      // 应用平移
      final xOffset = (animationProperties['xcenter'] ?? 0.0) * canvasSize.width;
      final yOffset = (animationProperties['ycenter'] ?? 0.0) * canvasSize.height;
      canvas.translate(centerX + xOffset, centerY + yOffset);
      
      // 应用旋转
      final rotation = animationProperties['rotation'] ?? 0.0;
      if (rotation != 0.0) {
        canvas.rotate(rotation);
      }
      
      // 应用缩放
      final scale = animationProperties['scale'] ?? 1.0;
      if (scale != 1.0) {
        canvas.scale(scale);
      }
      
      // 移回中心点
      canvas.translate(-centerX, -centerY);
      
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(offsetX, offsetY, scaledWidth, scaledHeight),
        paint,
      );
      
      canvas.restore();
    } else {
      // 无动画时直接绘制
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(offsetX, offsetY, scaledWidth, scaledHeight),
        paint,
      );
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
      // 优先查找角色专属的自动分布配置，如果没有则使用原始配置
      final autoDistributedPoseId = '${characterId}_auto_distributed';
      final poseConfig = poseConfigs[autoDistributedPoseId] ?? 
                        poseConfigs[characterState.positionId] ?? 
                        PoseConfig(id: 'default');
      
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
      
      // 计算角色的绘制参数，包含动画属性
      final renderParams = _calculateCharacterRenderParams(
        poseConfig, 
        canvasSize,
        sampleImage,
        characterState.animationProperties,
      );
      
      // 按层级顺序绘制所有图层，为表情图层应用偏移
      for (int i = 0; i < layerImages.length; i++) {
        final layerInfo = layerInfos[i];
        final layerImage = layerImages[i];
        
        // 获取差分偏移（仅对表情图层有效）
        final (xOffset, yOffset, alpha, scale) = ExpressionOffsetManager().getExpressionOffset(
          characterId: characterState.resourceId,
          pose: characterState.pose ?? 'pose1',
          layerType: layerInfo.layerType,
        );
        
        // 应用偏移和缩放到渲染参数
        final adjustedParams = _applyExpressionOffset(renderParams, xOffset, yOffset, scale);
        
        _drawCharacterLayer(canvas, layerImage, adjustedParams, alpha);
      }
    } catch (e) {
      print('绘制角色 $characterId 失败: $e');
    }
  }
  
  /// 应用差分偏移和缩放到角色渲染参数
  /// [params] 原始渲染参数
  /// [xOffset] 横向偏移（归一化值，相对于角色宽度）
  /// [yOffset] 纵向偏移（归一化值，相对于角色高度）
  /// [scale] 缩放比例（1.0为原始大小）
  static CharacterRenderParams _applyExpressionOffset(
    CharacterRenderParams params,
    double xOffset,
    double yOffset,
    double scale,
  ) {
    // 先应用缩放（如果有的话）
    double finalWidth = params.width * scale;
    double finalHeight = params.height * scale;
    
    // 计算像素偏移量（基于缩放后的尺寸）
    final pixelXOffset = finalWidth * xOffset;
    final pixelYOffset = finalHeight * yOffset;
    
    return CharacterRenderParams(
      x: params.x + pixelXOffset,
      y: params.y + pixelYOffset,
      width: finalWidth,
      height: finalHeight,
      alpha: params.alpha,
    );
  }

  /// 计算角色渲染参数（复用游戏界面的 _buildCharacters 逻辑）
  static CharacterRenderParams _calculateCharacterRenderParams(
    PoseConfig poseConfig,
    Size canvasSize,
    ui.Image sampleImage,
    Map<String, double>? animationProperties,
  ) {
    // 从pose配置获取基础属性
    double baseXCenter = poseConfig.xcenter;
    double baseYCenter = poseConfig.ycenter;
    double baseScale = poseConfig.scale;
    double alpha = 1.0;
    
    // 如果有动画属性，应用动画偏移
    if (animationProperties != null) {
      baseXCenter = animationProperties['xcenter'] ?? baseXCenter;
      baseYCenter = animationProperties['ycenter'] ?? baseYCenter;
      baseScale = animationProperties['scale'] ?? baseScale;
      alpha = animationProperties['alpha'] ?? alpha;
    }
    
    // 计算位置（复用 Positioned 的逻辑）
    final centerX = baseXCenter * canvasSize.width;
    final centerY = baseYCenter * canvasSize.height;
    
    // 计算约束高度（复用 SizedBox 的逻辑）
    double? constraintHeight;
    if (baseScale > 0) {
      constraintHeight = canvasSize.height * baseScale;
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
      alpha: alpha,
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
  static void _drawCharacterLayer(Canvas canvas, ui.Image image, CharacterRenderParams params, [double? expressionAlpha]) {
    final finalAlpha = expressionAlpha ?? params.alpha;
    final paint = Paint()
      ..filterQuality = FilterQuality.high
      ..isAntiAlias = true
      ..color = Color.fromRGBO(255, 255, 255, finalAlpha);
    
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(params.x, params.y, params.width, params.height),
      paint,
    );
  }
  
  /// 使用 BoxFit.cover 逻辑绘制图片
  static void _drawImageWithBoxFitCover(Canvas canvas, ui.Image image, Size canvasSize, {Map<String, double>? animationProperties}) {
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
    
    // 应用动画属性
    if (animationProperties != null && animationProperties.isNotEmpty) {
      canvas.save();
      
      // 计算变换中心点
      final centerX = canvasSize.width / 2;
      final centerY = canvasSize.height / 2;
      
      // 应用平移
      final xOffset = (animationProperties['xcenter'] ?? 0.0) * canvasSize.width;
      final yOffset = (animationProperties['ycenter'] ?? 0.0) * canvasSize.height;
      canvas.translate(centerX + xOffset, centerY + yOffset);
      
      // 应用旋转
      final rotation = animationProperties['rotation'] ?? 0.0;
      if (rotation != 0.0) {
        canvas.rotate(rotation);
      }
      
      // 应用缩放
      final scale = animationProperties['scale'] ?? 1.0;
      if (scale != 1.0) {
        canvas.scale(scale);
      }
      
      // 移回中心点
      canvas.translate(-centerX, -centerY);
      
      // 设置透明度
      final alpha = animationProperties['alpha'] ?? 1.0;
      final paint = Paint()..color = Color.fromRGBO(255, 255, 255, alpha);
      
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(offsetX, offsetY, scaledWidth, scaledHeight),
        paint,
      );
      
      canvas.restore();
    } else {
      // 无动画时使用原来的绘制方式
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(offsetX, offsetY, scaledWidth, scaledHeight),
        Paint(),
      );
    }
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
  final double alpha;
  
  CharacterRenderParams({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.alpha = 1.0,
  });
}
