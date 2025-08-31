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
      final bytes = data.buffer.asUint8List();
      
      // 直接使用标准图像解码器，让Flutter自动处理AVIF
      // 这样可以保持与其他格式相同的透明通道处理方式
      try {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        return frame.image;
      } catch (e) {
        // 如果标准解码器失败，再尝试flutter_avif
        print('标准AVIF解码失败，尝试flutter_avif解码器: $e');
        final frames = await decodeAvif(bytes);
        
        if (frames.isNotEmpty) {
          return frames.first.image;
        }
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