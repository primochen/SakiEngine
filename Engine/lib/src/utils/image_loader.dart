import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_avif/flutter_avif.dart';
import 'package:path/path.dart' as p;
import 'package:sakiengine/src/config/asset_manager.dart';
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
  /// 获取游戏路径，从dart-define或环境变量获取
  static String get _debugRoot {
    const fromDefine = String.fromEnvironment('SAKI_GAME_PATH', defaultValue: '');
    if (fromDefine.isNotEmpty) return fromDefine;
    
    final fromEnv = Platform.environment['SAKI_GAME_PATH'];
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    
    return '';
  }

  /// 获取游戏路径，优先使用环境变量，如果没有则从assets读取default_game.txt
  static Future<String> _getGamePath() async {
    // 如果环境变量已设置，直接使用
    if (_debugRoot.isNotEmpty) {
      return _debugRoot;
    }
    
    try {
      // 从assets读取default_game.txt
      final assetContent = await rootBundle.loadString('assets/default_game.txt');
      final defaultGame = assetContent.trim();
      
      if (defaultGame.isEmpty) {
        throw Exception('default_game.txt is empty');
      }
      
      final gamePath = p.join(Directory.current.path, 'Game', defaultGame);
      return gamePath;
    } catch (e) {
      throw Exception('Failed to load default_game.txt from assets: $e');
    }
  }

  /// 从资源路径加载图像
  static Future<ui.Image?> loadImage(String assetPath) async {
    try {
      final lowercasePath = assetPath.toLowerCase();
      
      // 在debug模式下，优先从外部文件系统加载
      if (kDebugMode) {
        final externalImage = await _loadExternalImage(assetPath);
        if (externalImage != null) {
          return externalImage;
        }
        // 如果外部文件加载失败，回退到assets加载
        print('外部图像加载失败，回退到assets: $assetPath');
      }
      
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
        final pngPath = assetPath.replaceAll(RegExp(r'\.avif$', caseSensitive: false), '.webp');
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
      Uint8List bytes;
      
      // 在debug模式下，优先从外部文件系统获取数据
      if (kDebugMode) {
        final gamePath = await _getGamePath();
        if (gamePath.isNotEmpty) {
          final relativePath = assetPath.startsWith('assets/')
              ? assetPath.substring('assets/'.length)
              : assetPath;
          final fileSystemPath = p.normalize(p.join(gamePath, relativePath));
          final file = File(fileSystemPath);
          
          if (await file.exists()) {
            bytes = await file.readAsBytes();
            if (kDebugMode) {
              print('从外部文件加载AVIF: $fileSystemPath');
            }
          } else {
            // 回退到assets
            final data = await rootBundle.load(assetPath);
            bytes = data.buffer.asUint8List();
          }
        } else {
          final data = await rootBundle.load(assetPath);
          bytes = data.buffer.asUint8List();
        }
      } else {
        final data = await rootBundle.load(assetPath);
        bytes = data.buffer.asUint8List();
      }
      
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

  /// 从外部文件系统加载图像（debug模式）
  static Future<ui.Image?> _loadExternalImage(String assetPath) async {
    try {
      final gamePath = await _getGamePath();
      if (gamePath.isEmpty) {
        return null;
      }
      
      // 移除 'assets/' 前缀（如果存在）
      final relativePath = assetPath.startsWith('assets/') 
          ? assetPath.substring('assets/'.length) 
          : assetPath;
      
      final fileSystemPath = p.normalize(p.join(gamePath, relativePath));
      final file = File(fileSystemPath);
      
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        if (kDebugMode) {
          print('从外部文件加载图像: $fileSystemPath');
        }
        return frame.image;
      }
      
      // 如果直接路径不存在，尝试使用AssetManager的查找逻辑
      final fileName = p.basenameWithoutExtension(relativePath);
      final foundAssetPath = await AssetManager().findAsset(fileName);
      
      if (foundAssetPath != null) {
        final foundRelativePath = foundAssetPath.startsWith('assets/')
            ? foundAssetPath.substring('assets/'.length)
            : foundAssetPath;
        final foundFileSystemPath = p.normalize(p.join(gamePath, foundRelativePath));
        final foundFile = File(foundFileSystemPath);
        
        if (await foundFile.exists()) {
          final bytes = await foundFile.readAsBytes();
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          if (kDebugMode) {
            print('通过AssetManager从外部文件加载图像: $foundFileSystemPath');
          }
          return frame.image;
        }
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('从外部文件系统加载图像失败 $assetPath: $e');
      }
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