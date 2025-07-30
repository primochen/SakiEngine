import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';

class ConfirmDialog extends StatelessWidget {
  final String title;
  final String content;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.content,
    required this.onConfirm,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final config = SakiEngineConfig();
    final mediaQuery = MediaQuery.of(context);
    final scale = mediaQuery.size.width / config.logicalWidth;
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;

    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(), // 点击背景关闭
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                config.themeColors.primaryDark.withValues(alpha: 0.2),
                config.themeColors.primaryDark.withValues(alpha: 0.2),
              ],
            ),
          ),
          child: GestureDetector(
            onTap: () {}, // 防止点击内容区域时关闭
            child: Center(
              child: Container(
                width: screenWidth * 0.3,
                height: screenHeight * 0.3,
                decoration: BoxDecoration(
                  color: config.themeColors.background.withValues(alpha: 0.95),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20 * scale,
                      offset: Offset(0, 8 * scale),
                    ),
                  ],
                ),
                padding: EdgeInsets.all(24 * scale),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.left,
                      style: config.dialogueTextStyle.copyWith(
                        fontSize: config.dialogueTextStyle.fontSize! * 1.2,
                        fontWeight: FontWeight.bold,
                        color: config.themeColors.primary,
                      ),
                    ),
                    SizedBox(height: 16 * scale),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          content,
                          textAlign: TextAlign.left,
                          style: config.dialogueTextStyle.copyWith(
                            color: config.themeColors.onSurface,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 24 * scale),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        _buildButton(
                          context, 
                          '取消', 
                          Icons.close_rounded,
                          () {
                            Navigator.of(context).pop();
                            onCancel?.call();
                          },
                          scale,
                          config,
                          isNegative: true,
                        ),
                        SizedBox(width: 16 * scale),
                        _buildButton(
                          context, 
                          '确定', 
                          Icons.check_rounded,
                          () {
                            Navigator.of(context).pop();
                            onConfirm();
                          },
                          scale,
                          config,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton(
    BuildContext context, 
    String text, 
    IconData icon,
    VoidCallback onPressed, 
    double scale,
    SakiEngineConfig config,
    {bool isNegative = false}
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 16 * scale,
            vertical: 8 * scale,
          ),
          decoration: BoxDecoration(
            color: isNegative 
              ? config.themeColors.background.withValues(alpha: 0.6)
              : config.themeColors.primary.withValues(alpha: 0.1),
            border: Border.all(
              color: isNegative 
                ? config.themeColors.onSurfaceVariant.withValues(alpha: 0.3)
                : config.themeColors.primary.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isNegative 
                  ? config.themeColors.onSurfaceVariant 
                  : config.themeColors.primary,
                size: config.dialogueTextStyle.fontSize! * scale * 1.2,
              ),
              SizedBox(width: 8 * scale),
              Text(
                text,
                style: config.dialogueTextStyle.copyWith(
                  color: isNegative 
                    ? config.themeColors.onSurfaceVariant 
                    : config.themeColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}