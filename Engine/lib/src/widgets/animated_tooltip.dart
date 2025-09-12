import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';

class AnimatedTooltip extends StatelessWidget {
  final String text;
  final double scale;
  final SakiEngineConfig config;
  final GlobalKey menuKey;
  final int buttonIndex;

  const AnimatedTooltip({
    super.key,
    required this.text,
    required this.scale,
    required this.config,
    required this.menuKey,
    required this.buttonIndex,
  });

  @override
  Widget build(BuildContext context) {
    // 更新按钮尺寸参数以匹配新的正方形按钮
    const double buttonSize = 48.0; // 正方形按钮尺寸
    const double buttonVerticalMargin = 4.0; // 按钮上下边距
    
    // 计算每个按钮单元的总高度(按钮 + 上下边距)
    final buttonUnitHeight = (buttonSize + buttonVerticalMargin * 2) * scale;
    
    // 计算气泡的垂直位置：菜单顶部偏移 + 按钮索引 * 单元高度 + 按钮中心位置
    double topOffset = 20 * scale + (buttonIndex * buttonUnitHeight) + (buttonSize * scale / 2) - 15 * scale;

    return Positioned(
      left: (20 + 60) * scale,
      top: topOffset,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 200),
        tween: Tween(begin: 0.0, end: 1.0),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset((1.0 - value) * -10 * scale, 0), // 轻微滑入
            child: Transform.scale(
              scale: 0.8 + (0.2 * value), // 从80%缩放到100%
              alignment: Alignment.centerLeft,
              child: Opacity(
                opacity: value.clamp(0.0, 1.0),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16 * scale,
                    vertical: 10 * scale,
                  ),
                  decoration: BoxDecoration(
                    color: config.themeColors.background.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(config.baseWindowBorder > 0 
                        ? config.baseWindowBorder * scale 
                        : 0 * scale),
                    border: Border.all(
                      color: config.themeColors.primary.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: (0.25 * value).clamp(0.0, 1.0)),
                        blurRadius: 12 * scale * value,
                        offset: Offset(-2 * scale, 2 * scale),
                      ),
                      BoxShadow(
                        color: config.themeColors.primary.withValues(alpha: (0.1 * value).clamp(0.0, 1.0)),
                        blurRadius: 6 * scale * value,
                        offset: Offset(0, 0),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 4 * scale,
                        height: 20 * scale,
                        decoration: BoxDecoration(
                          color: config.themeColors.primary.withValues(alpha: (0.6 * value).clamp(0.0, 1.0)),
                          borderRadius: BorderRadius.circular(2 * scale),
                        ),
                      ),
                      SizedBox(width: 12 * scale),
                      Text(
                        text,
                        style: config.quickMenuTextStyle.copyWith(
                          fontSize: config.quickMenuTextStyle.fontSize! * scale * 1.1,
                          color: config.themeColors.primary.withValues(alpha: (0.9 * value).clamp(0.0, 1.0)),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}