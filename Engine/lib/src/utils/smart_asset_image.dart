import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sakiengine/src/config/asset_manager.dart';
import 'package:sakiengine/src/widgets/smart_image.dart';

class SmartAssetImage extends StatelessWidget {
  final String assetName;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final Widget? errorWidget;
  final bool? loop; // 新增：控制WebP动图是否循环播放
  final VoidCallback? onAnimationComplete; // 新增：动画完成回调

  const SmartAssetImage({
    super.key,
    required this.assetName,
    this.fit,
    this.width,
    this.height,
    this.errorWidget,
    this.loop,
    this.onAnimationComplete, // 新增
  });

  @override
  Widget build(BuildContext context) {
    print('[SmartAssetImage] 构建资源图片: $assetName');
    return FutureBuilder<String?>(
      future: AssetManager().findAsset(assetName),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          final assetPath = snapshot.data!;
          print('[SmartAssetImage] 找到资源路径: $assetPath');
          
          if (assetPath.toLowerCase().endsWith('.svg')) {
            print('[SmartAssetImage] 检测到SVG文件，准备渲染');
            // 检查是否是绝对路径（Debug模式）
            if (assetPath.startsWith('/') || assetPath.contains(':')) {
              // 绝对路径：使用SvgPicture.file
              print('[SmartAssetImage] 使用绝对路径加载SVG: $assetPath');
              return SvgPicture.file(
                File(assetPath),
                fit: fit ?? BoxFit.contain,
                width: width,
                height: height,
                colorFilter: null,
                allowDrawingOutsideViewBox: true,
                placeholderBuilder: errorWidget != null 
                  ? (context) => errorWidget!
                  : null,
              );
            } else {
              // 相对路径：使用SvgPicture.asset
              print('[SmartAssetImage] 使用相对路径加载SVG: $assetPath');
              return SvgPicture.asset(
                assetPath,
                fit: fit ?? BoxFit.contain,
                width: width,
                height: height,
                colorFilter: null,
                allowDrawingOutsideViewBox: true,
                placeholderBuilder: errorWidget != null 
                  ? (context) => errorWidget!
                  : null,
              );
            }
          } else {
            print('[SmartAssetImage] 非SVG文件，使用SmartImage: $assetPath');
            return SmartImage.asset(
              assetPath,
              fit: fit,
              width: width,
              height: height,
              errorWidget: errorWidget,
              loop: loop, // 传递loop参数
              onAnimationComplete: onAnimationComplete, // 传递动画完成回调
            );
          }
        } else if (snapshot.hasError) {
          print('Error loading asset $assetName: ${snapshot.error}');
          return errorWidget ?? Container();
        }
        
        print('[SmartAssetImage] 资源未找到或加载中: $assetName');
        return errorWidget ?? Container();
      },
    );
  }
}