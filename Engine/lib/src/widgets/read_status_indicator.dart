import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';

/// 已读状态指示器
/// 
/// 显示一个小的"已读"标记，放在对话框的左上角
class ReadStatusIndicator extends StatelessWidget {
  final bool isRead;
  final double uiScale;
  final double textScale;

  const ReadStatusIndicator({
    super.key,
    required this.isRead,
    required this.uiScale,
    required this.textScale,
  });

  @override
  Widget build(BuildContext context) {
    if (!isRead) {
      return const SizedBox.shrink();
    }

    final config = SakiEngineConfig();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 6.0 * uiScale,
        vertical: 2.0 * uiScale,
      ),
      decoration: BoxDecoration(
        color: config.themeColors.primary.withOpacity(0.8),
        borderRadius: BorderRadius.circular(4.0 * uiScale),
      ),
      child: Text(
        '已读',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10.0 * textScale,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}