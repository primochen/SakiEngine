import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/widgets/read_status_indicator.dart';

/// 对话框标题栏组件
/// 
/// 显示说话者的名称和已读标记
class DialogueSpeakerHeader extends StatelessWidget {
  final String? speaker;
  final double uiScale;
  final double textScale;
  final bool isRead; // 新增：已读状态

  const DialogueSpeakerHeader({
    super.key,
    required this.speaker,
    required this.uiScale,
    required this.textScale,
    required this.isRead,
  });

  @override
  Widget build(BuildContext context) {
    final config = SakiEngineConfig();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 16 * uiScale,
        vertical: 12 * uiScale,
      ),
      decoration: BoxDecoration(
        color: config.themeColors.primary.withOpacity(0.05),
        border: Border(
          bottom: BorderSide(
            color: config.themeColors.primary.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // 已读标记放在左侧
          ReadStatusIndicator(
            isRead: isRead,
            uiScale: uiScale,
            textScale: textScale,
          ),
          if (isRead) SizedBox(width: 8 * uiScale), // 如果有已读标记，添加间距
          // 说话者名称
          Expanded(
            child: Text(
              speaker ?? '',
              style: config.speakerTextStyle.copyWith(
                fontSize: config.speakerTextStyle.fontSize! * textScale,
                color: config.themeColors.primary,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}