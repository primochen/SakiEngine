import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:sakiengine/src/rendering/game_renderer.dart';
import 'package:sakiengine/src/game/game_manager.dart';
import 'package:sakiengine/src/config/config_models.dart';
import 'dart:io';

/// 游戏截图生成器
/// 根据当前游戏状态生成16:9的假截图，包含背景和角色，但不显示对话框
class ScreenshotGenerator {
  static const double targetWidth = 640.0;
  static const double targetHeight = 360.0;  // 16:9 比例
  
  /// 生成当前游戏状态的截图
  /// 返回截图的文件路径
  static Future<String?> generateScreenshot(
    GameState gameState, 
    Map<String, PoseConfig> poseConfigs,
    String savesDirectory,
    int slotId,
  ) async {
    try {
      // 创建画布
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, targetWidth, targetHeight));
      const canvasSize = Size(targetWidth, targetHeight);
      
      // 使用统一的渲染器绘制背景
      await GameRenderer.drawBackground(canvas, gameState.background, canvasSize);
      
      // 使用统一的渲染器绘制角色
      await GameRenderer.drawCharacters(canvas, gameState.characters, poseConfigs, canvasSize);
      
      // 完成绘制
      final picture = recorder.endRecording();
      final image = await picture.toImage(targetWidth.toInt(), targetHeight.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) return null;
      
      // 保存截图文件
      final screenshotPath = '$savesDirectory/screenshot_$slotId.png';
      final file = File(screenshotPath);
      await file.writeAsBytes(byteData.buffer.asUint8List());
      
      return screenshotPath;
    } catch (e) {
      print('生成截图失败: $e');
      return null;
    }
  }
  
  /// 删除截图文件
  static Future<void> deleteScreenshot(int slotId, String savesDirectory) async {
    try {
      final screenshotPath = '$savesDirectory/screenshot_$slotId.png';
      final file = File(screenshotPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('删除截图失败: $e');
    }
  }
}