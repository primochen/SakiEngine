import 'package:flutter/material.dart';
import 'package:flutter_avif/flutter_avif.dart';

/// 智能图像小部件 - 自动处理AVIF和其他格式
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
    // 检查文件扩展名
    if (assetPath.toLowerCase().endsWith('.avif')) {
      return AvifImage.asset(
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
}