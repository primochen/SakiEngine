import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_avif/flutter_avif.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';

/// 图像加载器 - 支持多种图像格式包括AVIF和WebP
/// 
/// 支持的格式:
/// - WebP: 原生支持，完美透明通道，文件大小优化
/// - PNG: 原生支持，完美透明通道
/// - AVIF: 通过flutter_avif插件支持，透明通道有限制
/// - JPG/JPEG: 原生支持，无透明通道
/// 
/// 智能回退策略 (针对AVIF):
/// 1. WebP版本 (最优选择)
/// 2. PNG版本 (可靠的透明通道)  
/// 3. AVIF原文件 (最后选择)
class ImageLoader {
  /// 从资源路径加载图像
  static Future<ui.Image?> loadImage(String assetPath) async {
    try {
      final lowercasePath = assetPath.toLowerCase();
      
      // 检查文件扩展名
      if (lowercasePath.endsWith('.avif')) {
        return await _loadAvifImageWithFallback(assetPath);
      } else if (lowercasePath.endsWith('.webp')) {
        // WebP有很好的透明通道支持，优先使用
        return await _loadStandardImage(assetPath);
      } else {
        return await _loadStandardImage(assetPath);
      }
    } catch (e) {
      print('加载图像失败 $assetPath: $e');
      return null;
    }
  }
  
  /// 加载AVIF图像并提供回退机制
  static Future<ui.Image?> _loadAvifImageWithFallback(String assetPath) async {
    final config = SakiEngineConfig();
    
    // 根据配置决定优先级：WebP > PNG > AVIF
    if (config.preferWebpOverAvif || config.preferPngOverAvif) {
      // 先尝试WebP版本（如果启用）
      if (config.preferWebpOverAvif) {
        final webpPath = assetPath.replaceAll(RegExp(r'\.avif$', caseSensitive: false), '.webp');
        try {
          final webpImage = await _loadStandardImage(webpPath);
          if (webpImage != null) {
            print('使用WebP替代AVIF: $webpPath');
            return webpImage;
          }
        } catch (e) {
          // WebP不存在，继续尝试PNG
        }
      }
      
      // 再尝试PNG版本（如果启用）
      if (config.preferPngOverAvif) {
        final pngPath = assetPath.replaceAll(RegExp(r'\.avif$', caseSensitive: false), '.png');
        try {
          final pngImage = await _loadStandardImage(pngPath);
          if (pngImage != null) {
            print('使用PNG替代AVIF: $pngPath');
            return pngImage;
          }
        } catch (e) {
          // PNG不存在，最后使用AVIF
        }
      }
    }
    
    return await _loadAvifImage(assetPath);
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