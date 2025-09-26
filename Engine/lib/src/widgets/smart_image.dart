import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_avif/flutter_avif.dart';
import 'package:sakiengine/src/widgets/animated_webp_image.dart';
import 'package:sakiengine/src/utils/cg_image_compositor.dart';

/// 智能图像小部件 - 自动处理AVIF、WebP和其他格式
/// 
/// 特性:
/// - 自动识别图像格式
/// - WebP动图支持 (默认播放一次，可通过loop参数控制循环)
/// - WebP优先策略 (完美透明通道 + 优化文件大小)
/// - AVIF智能回退 (WebP > PNG > AVIF)
/// - 透明通道保护处理
class SmartImage extends StatelessWidget {
  final String assetPath;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final Widget? errorWidget;
  final bool? loop; // 新增：控制WebP动图是否循环播放
  final VoidCallback? onAnimationComplete; // 新增：动画完成回调

  const SmartImage.asset(
    this.assetPath, {
    super.key,
    this.fit,
    this.width,
    this.height,
    this.errorWidget,
    this.loop,
    this.onAnimationComplete, // 新增
  });

  @override
  Widget build(BuildContext context) {
    final lowercasePath = assetPath.toLowerCase();
    
    // 检查是否为内存缓存路径
    if (_isMemoryCachePath(assetPath)) {
      return _buildMemoryCacheImage();
    }
    
    final isFilePath = _isFileSystemPath(assetPath);
    
    // 检查文件扩展名
    if (lowercasePath.endsWith('.avif')) {
      return _buildAvifImageWithFallback();
    } else if (lowercasePath.endsWith('.webp')) {
      // WebP支持动画，使用专门的动图组件，默认不循环
      if (isFilePath) {
        // 文件系统路径：对于WebP文件，直接使用Image.file，因为AnimatedWebPImage没有.file构造器
        return Image.file(
          File(assetPath),
          fit: fit ?? BoxFit.contain,
          width: width,
          height: height,
          errorBuilder: errorWidget != null 
            ? (context, error, stackTrace) => errorWidget!
            : null,
        );
      } else {
        return AnimatedWebPImage.asset(
          assetPath,
          fit: fit ?? BoxFit.contain,
          width: width,
          height: height,
          errorWidget: errorWidget,
          autoPlay: true,
          loop: loop ?? false, // 默认不循环
          onAnimationComplete: onAnimationComplete, // 传递动画完成回调
        );
      }
    } else {
      if (isFilePath) {
        return Image.file(
          File(assetPath),
          fit: fit ?? BoxFit.contain,
          width: width,
          height: height,
          errorBuilder: errorWidget != null 
            ? (context, error, stackTrace) => errorWidget!
            : null,
        );
      } else {
        return Image.asset(
          assetPath,
          fit: fit ?? BoxFit.contain,
          width: width,
          height: height,
          errorBuilder: errorWidget != null 
            ? (context, error, stackTrace) => errorWidget!
            : null,
        );
      }
    }
  }
  
  /// 构建AVIF图像，支持WebP和PNG回退
  Widget _buildAvifImageWithFallback() {
    // 优先级：WebP > PNG > AVIF
    final webpPath = assetPath.replaceAll(RegExp(r'\.avif$', caseSensitive: false), '.webp');
    final pngPath = assetPath.replaceAll(RegExp(r'\.avif$', caseSensitive: false), '.png');
    
    return FutureBuilder<String?>(
      future: _findBestImageFormat(webpPath, pngPath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        
        final bestPath = snapshot.data;
        
        // 如果找到了更好的格式，使用对应的组件
        if (bestPath != null && bestPath != assetPath) {
          final isBestPathFile = _isFileSystemPath(bestPath);
          if (bestPath.toLowerCase().endsWith('.webp')) {
            // 使用WebP动图组件，默认不循环
            if (isBestPathFile) {
              // 文件系统路径：直接使用Image.file
              return Image.file(
                File(bestPath),
                fit: fit ?? BoxFit.contain,
                width: width,
                height: height,
                errorBuilder: errorWidget != null 
                  ? (context, error, stackTrace) => errorWidget!
                  : null,
              );
            } else {
              return AnimatedWebPImage.asset(
                bestPath,
                fit: fit ?? BoxFit.contain,
                width: width,
                height: height,
                errorWidget: errorWidget,
                autoPlay: true,
                loop: loop ?? false, // 默认不循环
              );
            }
          } else {
            // 使用标准Image组件
            if (isBestPathFile) {
              return Image.file(
                File(bestPath),
                fit: fit ?? BoxFit.contain,
                width: width,
                height: height,
                errorBuilder: errorWidget != null 
                  ? (context, error, stackTrace) => errorWidget!
                  : null,
              );
            } else {
              return Image.asset(
                bestPath,
                fit: fit ?? BoxFit.contain,
                width: width,
                height: height,
                errorBuilder: errorWidget != null 
                  ? (context, error, stackTrace) => errorWidget!
                  : null,
              );
            }
          }
        }
        
        // 否则使用AVIF，但添加透明背景处理
        final isOriginalFile = _isFileSystemPath(assetPath);
        return Container(
          width: width,
          height: height,
          decoration: const BoxDecoration(
            color: Colors.transparent,
          ),
          child: isOriginalFile ? 
            AvifImage.file(
              File(assetPath),
              fit: fit ?? BoxFit.contain,
              isAntiAlias: true,
              filterQuality: FilterQuality.high,
              errorBuilder: errorWidget != null 
                ? (context, error, stackTrace) => errorWidget!
                : null,
            ) :
            AvifImage.asset(
              assetPath,
              fit: fit ?? BoxFit.contain,
              isAntiAlias: true,
              filterQuality: FilterQuality.high,
              errorBuilder: errorWidget != null 
                ? (context, error, stackTrace) => errorWidget!
                : null,
            ),
        );
      },
    );
  }
  
  /// 查找最佳的图像格式 (WebP > PNG > null)
  Future<String?> _findBestImageFormat(String webpPath, String pngPath) async {
    // 首先尝试WebP
    if (await _assetExists(webpPath)) {
      return webpPath;
    }
    
    // 然后尝试PNG
    if (await _assetExists(pngPath)) {
      return pngPath;
    }
    
    // 都不存在，返回null使用原始AVIF
    return null;
  }
  
  /// 判断是否为文件系统路径（debug模式下的绝对路径）
  bool _isFileSystemPath(String path) {
    // 排除内存缓存路径
    if (_isMemoryCachePath(path)) {
      return false;
    }
    // 检查是否为绝对路径：Unix风格 (/) 或 Windows风格 (C:)
    return path.startsWith('/') || (path.length > 2 && path[1] == ':');
  }
  
  /// 判断是否为内存缓存路径
  bool _isMemoryCachePath(String path) {
    return path.startsWith('/memory_cache/cg_cache/');
  }
  
  /// 构建内存缓存图像
  Widget _buildMemoryCacheImage() {
    print('[SmartImage] 🐛 尝试从内存缓存加载: $assetPath');
    
    final imageBytes = CgImageCompositor().getImageBytes(assetPath);
    
    if (imageBytes == null) {
      print('[SmartImage] ❌ 内存缓存中未找到图像数据: $assetPath');
      // 如果内存中没有找到图像数据，显示错误或占位符
      return errorWidget ?? Container(
        width: width,
        height: height,
        color: Colors.grey.withValues(alpha: 0.3),
        child: const Center(
          child: Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    }
    
    print('[SmartImage] ✅ 找到内存缓存图像: $assetPath (${imageBytes.length} bytes)');
    
    return Image.memory(
      imageBytes,
      fit: fit ?? BoxFit.contain,
      width: width,
      height: height,
      errorBuilder: errorWidget != null 
        ? (context, error, stackTrace) {
            print('[SmartImage] ❌ Image.memory加载失败: $error');
            return errorWidget!;
          }
        : (context, error, stackTrace) {
            print('[SmartImage] ❌ Image.memory加载失败: $error');
            return Container(
              width: width,
              height: height,
              color: Colors.red.withValues(alpha: 0.3),
              child: const Center(
                child: Icon(Icons.error, color: Colors.red),
              ),
            );
          },
    );
  }
  
  /// 检查资源文件是否存在
  Future<bool> _assetExists(String assetPath) async {
    try {
      if (_isFileSystemPath(assetPath)) {
        // 文件系统路径，检查文件是否存在
        return await File(assetPath).exists();
      } else {
        // Bundle资源路径
        await rootBundle.load(assetPath);
        return true;
      }
    } catch (e) {
      return false;
    }
  }
}