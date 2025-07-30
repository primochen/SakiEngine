import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sakiengine/src/game/game_manager.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';

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
    final screenSize = MediaQuery.of(context).size;
    final config = SakiEngineConfig();
    final scaleX = screenSize.width / config.logicalWidth;
    final scaleY = screenSize.height / config.logicalHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.escape): const _CloseIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _CloseIntent: _CloseAction(widget.onClose),
        },
        child: Focus(
          autofocus: true,
          child: GestureDetector(
            onTap: widget.onClose, // 点击背景关闭
            child: _buildContent(scale, config, screenSize),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(double scale, SakiEngineConfig config, Size screenSize) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            config.themeColors.primaryDark.withValues(alpha: 0.5),
            config.themeColors.primaryDark.withValues(alpha: 0.5),
          ],
        ),
      ),
      child: GestureDetector(
        onTap: () {}, // 防止点击内容区域时也关闭
        child: Center(
          child: Container(
            width: screenSize.width * 0.85,
            height: screenSize.height * 0.8,
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
            child: Column(
              children: [
                // 标题栏
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: 32 * scale,
                    vertical: 20 * scale,
                  ),
                  decoration: BoxDecoration(
                    color: config.themeColors.primary.withValues(alpha: 0.1),
                    border: Border(
                      bottom: BorderSide(
                        color: config.themeColors.primary.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '回忆录',
                        style: config.reviewTitleTextStyle.copyWith(
                          fontSize: config.reviewTitleTextStyle.fontSize! * scale * _titleSizeRatio,
                          color: config.themeColors.primary,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const Spacer(),
                      _buildCloseButton(scale, config),
                    ],
                  ),
                ),
                
                // 对话历史列表
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 32 * scale, vertical: 16 * scale),
                    child: widget.dialogueHistory.isEmpty
                        ? _buildEmptyState(scale, config)
                        : _buildDialogueList(scale, config),
                  ),
                ),
                
                // 底部装饰
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 12 * scale),
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
                        fontSize: config.reviewTitleTextStyle.fontSize! * scale * _bottomTextSizeRatio,
                        color: config.themeColors.primary.withValues(alpha: 0.7),
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(double scale, SakiEngineConfig config) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80 * scale,
            height: 80 * scale,
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
              size: 36 * scale,
              color: config.themeColors.primary.withValues(alpha: 0.6),
            ),
          ),
          SizedBox(height: 24 * scale),
          Text(
            '回忆的书页还是空白的',
            style: config.reviewTitleTextStyle.copyWith(
              fontSize: config.reviewTitleTextStyle.fontSize! * scale * _emptyMainTextSizeRatio,
              color: config.themeColors.primary.withValues(alpha: 0.7),
              fontStyle: FontStyle.italic,
            ),
          ),
          SizedBox(height: 8 * scale),
          Text(
            '开始对话来创造美好的回忆吧',
            style: config.reviewTitleTextStyle.copyWith(
              fontSize: config.reviewTitleTextStyle.fontSize! * scale * _emptySubTextSizeRatio,
              color: config.themeColors.primary.withValues(alpha: 0.5),
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogueList(double scale, SakiEngineConfig config) {
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: false,
      thickness: 6 * scale,
      radius: Radius.circular(3 * scale),
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.zero,
        itemCount: widget.dialogueHistory.length,
        itemBuilder: (context, index) {
          final entry = widget.dialogueHistory[index];
          return _buildDialogueEntry(entry, index, scale, config);
        },
      ),
    );
  }

  Widget _buildDialogueEntry(
    DialogueHistoryEntry entry,
    int index,
    double scale,
    SakiEngineConfig config,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 2 * scale),
      padding: EdgeInsets.symmetric(
        horizontal: 20 * scale,
        vertical: 12 * scale,
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
              if (entry.speaker != null) ...[
                Text(
                  entry.speaker!,
                  style: config.reviewTitleTextStyle.copyWith(
                    fontSize: config.reviewTitleTextStyle.fontSize! * scale * _speakerSizeRatio,
                    fontWeight: FontWeight.w500,
                    color: config.themeColors.primary,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(width: 12 * scale),
              ],
              Text(
                '${index + 1}',
                style: config.reviewTitleTextStyle.copyWith(
                  fontSize: config.reviewTitleTextStyle.fontSize! * scale * _indexSizeRatio,
                  color: config.themeColors.primary.withValues(alpha: 0.5),
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.normal,
                ),
              ),
              const Spacer(),
              // 跳转按钮
              if (widget.onJumpToEntry != null)
                _buildJumpButton(entry, scale, config),
              SizedBox(width: 12 * scale),
              Text(
                _formatTimestamp(entry.timestamp),
                style: config.reviewTitleTextStyle.copyWith(
                  fontSize: config.reviewTitleTextStyle.fontSize! * scale * _timestampSizeRatio,
                  color: config.themeColors.primary.withValues(alpha: 0.4),
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
          SizedBox(height: 6 * scale),
          
          // 对话内容
          Container(
            padding: EdgeInsets.only(left: entry.speaker != null ? 0 : 16 * scale),
            child: Text(
              entry.dialogue,
              style: config.reviewTitleTextStyle.copyWith(
                fontSize: config.reviewTitleTextStyle.fontSize! * scale * _dialogueSizeRatio,
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

  Widget _buildJumpButton(DialogueHistoryEntry entry, double scale, SakiEngineConfig config) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          widget.onJumpToEntry?.call(entry);
        },
        borderRadius: BorderRadius.circular(12 * scale),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 4 * scale),
          child: Text(
            '跳转',
            style: config.reviewTitleTextStyle.copyWith(
              fontSize: config.reviewTitleTextStyle.fontSize! * scale * _jumpButtonSizeRatio,
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

  Widget _buildCloseButton(double scale, SakiEngineConfig config) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onClose,
        borderRadius: BorderRadius.circular(20 * scale),
        child: Container(
          width: 36 * scale,
          height: 36 * scale,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: config.themeColors.primary.withValues(alpha: 0.1),
            border: Border.all(
              color: config.themeColors.primary.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.close,
            color: config.themeColors.primary.withValues(alpha: 0.8),
            size: 20 * scale,
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

// 定义关闭意图和动作
class _CloseIntent extends Intent {
  const _CloseIntent();
}

class _CloseAction extends Action<_CloseIntent> {
  final VoidCallback onClose;

  _CloseAction(this.onClose);

  @override
  Object? invoke(_CloseIntent intent) {
    onClose();
    return null;
  }
}