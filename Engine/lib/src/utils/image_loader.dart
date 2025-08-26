import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_avif/flutter_avif.dart';

/// 图像加载器 - 支持多种图像格式包括AVIF
class ImageLoader {
  /// 从资源路径加载图像
  static Future<ui.Image?> loadImage(String assetPath) async {
    try {
      // 检查文件扩展名
      if (assetPath.toLowerCase().endsWith('.avif')) {
        return await _loadAvifImage(assetPath);
      } else {
        return await _loadStandardImage(assetPath);
      }
    } catch (e) {
      print('加载图像失败 $assetPath: $e');
      return null;
    }
  }

  /// 加载AVIF图像
  static Future<ui.Image?> _loadAvifImage(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      final frames = await decodeAvif(data.buffer.asUint8List());
      
      if (frames.isNotEmpty) {
        // 返回第一帧（静态图像或动画第一帧）
        return frames.first.image;
      }
      
      return null;
    } catch (e) {
      print('加载AVIF图像失败 $assetPath: $e');
      return null;
    }
  }

  /// 加载标准图像格式
  static Future<ui.Image?> _loadStandardImage(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      print('加载标准图像失败 $assetPath: $e');
      return null;
    }
  }
}