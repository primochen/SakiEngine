import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/utils/settings_manager.dart';

/// 对话框中提示下一句话的箭头组件
class DialogueNextArrow extends StatefulWidget {
  final bool visible;
  final double fontSize;
  final Color? color;
  
  const DialogueNextArrow({
    super.key,
    required this.visible,
    required this.fontSize,
    this.color,
  });

  @override
  State<DialogueNextArrow> createState() => _DialogueNextArrowState();
}

class _DialogueNextArrowState extends State<DialogueNextArrow>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500), // 加快到1.5秒
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) {
      return const SizedBox.shrink();
    }

    final config = SakiEngineConfig();
    // 深色模式下使用亮色，浅色模式下使用深色
    final defaultColor = SettingsManager().currentDarkMode 
        ? Colors.white.withValues(alpha: 0.8)  // 深色模式用白色
        : config.themeColors.primary.withValues(alpha: 0.7);  // 浅色模式用主题色
    final effectiveColor = widget.color ?? defaultColor;
    final size = widget.fontSize*1.6;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        // 使用正弦波确保首尾帧平滑相接
        final breathOffset = sin(_animationController.value * 2.0 * pi) * 4.0; // 左右移动4像素
        
        return Transform.translate(
          offset: Offset(breathOffset, 0),
          child: Icon(
            Icons.keyboard_arrow_right_rounded,
            color: effectiveColor,
            size: size,
          ),
        );
      },
    );
  }
}