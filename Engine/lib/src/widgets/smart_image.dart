import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_avif/flutter_avif.dart';

/// 智能图像小部件 - 自动处理AVIF、WebP和其他格式
/// 
/// 特性:
/// - 自动识别图像格式
/// - WebP优先策略 (完美透明通道 + 优化文件大小)
/// - AVIF智能回退 (WebP > PNG > AVIF)
/// - 透明通道保护处理
class SmartImage extends StatelessWidget {
  final String assetPath;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final Widget? errorWidget;

  const SmartImage.asset(
    this.assetPath, {
    super.key,
    this.fit,
    this.width,
    this.height,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final lowercasePath = assetPath.toLowerCase();
    
    // 检查文件扩展名
    if (lowercasePath.endsWith('.avif')) {
      return _buildAvifImageWithFallback();
    } else if (lowercasePath.endsWith('.webp')) {
      // WebP有完美的透明通道支持，直接使用
      return Image.asset(
        assetPath,
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
        
        // 如果找到了更好的格式，使用标准Image.asset
        if (bestPath != null && bestPath != assetPath) {
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
        
        // 否则使用AVIF，但添加透明背景处理
        return Container(
          width: width,
          height: height,
          decoration: const BoxDecoration(
            color: Colors.transparent,
          ),
          child: AvifImage.asset(
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
  
  /// 检查资源文件是否存在
  Future<bool> _assetExists(String assetPath) async {
    try {
      await rootBundle.load(assetPath);
      return true;
    } catch (e) {
      return false;
    }
  }
}