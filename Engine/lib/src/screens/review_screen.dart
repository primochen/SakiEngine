import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sakiengine/src/game/game_manager.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/utils/scaling_manager.dart';
import 'package:sakiengine/src/widgets/common/close_button.dart';
import 'package:sakiengine/src/widgets/common/overlay_scaffold.dart';

class ReviewOverlay extends StatefulWidget {
  final List<DialogueHistoryEntry> dialogueHistory;
  final VoidCallback onClose;
  final Function(DialogueHistoryEntry)? onJumpToEntry;

  const ReviewOverlay({
    super.key,
    required this.dialogueHistory,
    required this.onClose,
    this.onJumpToEntry,
  });

  @override
  State<ReviewOverlay> createState() => _ReviewOverlayState();
}

class _ReviewOverlayState extends State<ReviewOverlay> {
  final ScrollController _scrollController = ScrollController();
  
  // 字体大小百分比 (相对于标题字体大小)
  static const double _titleSizeRatio = 1.0;              // 标题: 100%
  static const double _speakerSizeRatio = 0.56;           // 说话人: 56%
  static const double _dialogueSizeRatio = 0.5;           // 对话内容: 50%
  static const double _indexSizeRatio = 0.44;             // 序号: 44%
  static const double _timestampSizeRatio = 0.39;         // 时间戳: 39%
  static const double _jumpButtonSizeRatio = 0.39;        // 跳转按钮: 39%
  static const double _emptyMainTextSizeRatio = 0.61;     // 空状态主文字: 61%
  static const double _emptySubTextSizeRatio = 0.5;       // 空状态副文字: 50%
  static const double _bottomTextSizeRatio = 0.44;        // 底部统计: 44%

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = SakiEngineConfig();
    final uiScale = context.scaleFor(ComponentType.ui);
    final textScale = context.scaleFor(ComponentType.text);

    return OverlayScaffold(
      title: '对话记录',
      onClose: widget.onClose,
      content: Container(
        padding: EdgeInsets.symmetric(horizontal: 32 * uiScale, vertical: 16 * uiScale),
        child: widget.dialogueHistory.isEmpty
            ? _buildEmptyState(uiScale, textScale, config)
            : _buildDialogueList(uiScale, textScale, config),
      ),
      footer: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 12 * uiScale),
        decoration: BoxDecoration(
          color: config.themeColors.primary.withValues(alpha: 0.05),
          border: Border(
            top: BorderSide(
              color: config.themeColors.primary.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
        ),
        child: Center(
          child: Text(
            '${widget.dialogueHistory.length} 段回忆',
            style: config.reviewTitleTextStyle.copyWith(
              fontSize: config.reviewTitleTextStyle.fontSize! * textScale * _bottomTextSizeRatio,
              color: config.themeColors.primary.withValues(alpha: 0.7),
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(double uiScale, double textScale, SakiEngineConfig config) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80 * uiScale,
            height: 80 * uiScale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: config.themeColors.primary.withValues(alpha: 0.1),
              border: Border.all(
                color: config.themeColors.primary.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.auto_stories_outlined,
              size: 36 * uiScale,
              color: config.themeColors.primary.withValues(alpha: 0.6),
            ),
          ),
          SizedBox(height: 24 * uiScale),
          Text(
            '回忆的书页还是空白的',
            style: config.reviewTitleTextStyle.copyWith(
              fontSize: config.reviewTitleTextStyle.fontSize! * textScale * _emptyMainTextSizeRatio,
              color: config.themeColors.primary.withValues(alpha: 0.7),
              fontStyle: FontStyle.italic,
            ),
          ),
          SizedBox(height: 8 * uiScale),
          Text(
            '开始对话来创造美好的回忆吧',
            style: config.reviewTitleTextStyle.copyWith(
              fontSize: config.reviewTitleTextStyle.fontSize! * textScale * _emptySubTextSizeRatio,
              color: config.themeColors.primary.withValues(alpha: 0.5),
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogueList(double uiScale, double textScale, SakiEngineConfig config) {
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: false,
      thickness: 6 * uiScale,
      radius: Radius.circular(3 * uiScale),
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.zero,
        itemCount: widget.dialogueHistory.length,
        itemBuilder: (context, index) {
          final entry = widget.dialogueHistory[index];
          return _buildDialogueEntry(entry, index, uiScale, textScale, config);
        },
      ),
    );
  }

  Widget _buildDialogueEntry(
    DialogueHistoryEntry entry,
    int index,
    double uiScale,
    double textScale,
    SakiEngineConfig config,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 2 * uiScale),
      padding: EdgeInsets.symmetric(
        horizontal: 20 * uiScale,
        vertical: 12 * uiScale,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: config.themeColors.primary.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 说话人和序号
          Row(
            children: [
              if (entry.speaker != null && entry.speaker!.isNotEmpty) ...[
                Text(
                  entry.speaker!,
                  style: config.reviewTitleTextStyle.copyWith(
                    fontSize: config.reviewTitleTextStyle.fontSize! * textScale * _speakerSizeRatio,
                    fontWeight: FontWeight.w500,
                    color: config.themeColors.primary,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(width: 12 * uiScale),
              ],
              Text(
                '${index + 1}',
                style: config.reviewTitleTextStyle.copyWith(
                  fontSize: config.reviewTitleTextStyle.fontSize! * textScale * _indexSizeRatio,
                  color: config.themeColors.primary.withValues(alpha: 0.5),
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.normal,
                ),
              ),
              const Spacer(),
              // 跳转按钮
              if (widget.onJumpToEntry != null)
                _buildJumpButton(entry, uiScale, textScale, config),
              SizedBox(width: 12 * uiScale),
              Text(
                _formatTimestamp(entry.timestamp),
                style: config.reviewTitleTextStyle.copyWith(
                  fontSize: config.reviewTitleTextStyle.fontSize! * textScale * _timestampSizeRatio,
                  color: config.themeColors.primary.withValues(alpha: 0.4),
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
          SizedBox(height: 6 * uiScale),
          
          // 对话内容
          Container(
            padding: EdgeInsets.only(left: entry.speaker != null ? 0 : 16 * uiScale),
            child: Text(
              entry.dialogue,
              style: config.reviewTitleTextStyle.copyWith(
                fontSize: config.reviewTitleTextStyle.fontSize! * textScale * _dialogueSizeRatio,
                color: config.themeColors.onSurface,
                height: 1.6,
                letterSpacing: 0.3,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJumpButton(DialogueHistoryEntry entry, double uiScale, double textScale, SakiEngineConfig config) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          widget.onJumpToEntry?.call(entry);
        },
        borderRadius: BorderRadius.circular(12 * uiScale),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 8 * uiScale, vertical: 4 * uiScale),
          child: Text(
            '跳转',
            style: config.reviewTitleTextStyle.copyWith(
              fontSize: config.reviewTitleTextStyle.fontSize! * textScale * _jumpButtonSizeRatio,
              color: config.themeColors.primary.withValues(alpha: 0.7),
              decoration: TextDecoration.underline,
              decorationColor: config.themeColors.primary.withValues(alpha: 0.5),
              fontWeight: FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}小时前';
    } else {
      return '${timestamp.month}/${timestamp.day} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}
