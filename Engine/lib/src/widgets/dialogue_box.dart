import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';

class DialogueBox extends StatefulWidget {
  final String? speaker;
  final String dialogue;
  final VoidCallback? onNext;

  const DialogueBox({
    super.key,
    this.speaker,
    required this.dialogue,
    this.onNext,
  });

  @override
  State<DialogueBox> createState() => _DialogueBoxState();
}

class _DialogueBoxState extends State<DialogueBox> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isDialogueComplete = false;
  late AnimationController _animationController;
  late Animation<double> _blinkAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _blinkAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  bool _isTextOverflowing(BuildContext context, String text, TextStyle style, double maxWidth) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: null,
    )..layout(maxWidth: maxWidth);

    return textPainter.height > maxWidth;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final config = SakiEngineConfig();
    final scaleX = screenSize.width / config.logicalWidth;
    final scaleY = screenSize.height / config.logicalHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final dialogueStyle = config.dialogueTextStyle.copyWith(
      fontSize: config.dialogueTextStyle.fontSize! * scale * 0.9,
      color: config.themeColors.onSurface,
      height: 1.6,
      letterSpacing: 0.3,
    );

    return GestureDetector(
      onTap: widget.onNext,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: Container(
            width: screenSize.width * 0.85,
            height: screenSize.height * 0.25,
            margin: EdgeInsets.all(16.0 * scale),
            decoration: BoxDecoration(
              color: config.themeColors.background.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(8 * scale),
              border: Border.all(
                color: config.themeColors.primary.withValues(alpha: _isHovered ? 0.4 : 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12 * scale,
                  offset: Offset(0, 4 * scale),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题栏
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: 16 * scale,
                    vertical: 12 * scale,
                  ),
                  decoration: BoxDecoration(
                    color: config.themeColors.primary.withValues(alpha: 0.05),
                    border: Border(
                      bottom: BorderSide(
                        color: config.themeColors.primary.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Text(
                    widget.speaker ?? '', // 如果 speaker 为 null，则显示空字符串
                    style: config.speakerTextStyle.copyWith(
                      fontSize: config.speakerTextStyle.fontSize! * scale * 0.9,
                      color: config.themeColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                
                // 对话内容
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // 检查文本是否溢出
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        setState(() {
                          _isDialogueComplete = !_isTextOverflowing(
                            context, 
                            widget.dialogue, 
                            dialogueStyle, 
                            constraints.maxWidth - 32 * scale
                          );
                        });
                      });

                      return SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.all(16.0 * scale),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                               RichText(
                                 text: TextSpan(
                                   children: [
                                     TextSpan(
                                       text: widget.dialogue,
                                       style: dialogueStyle,
                                     ),
                                     if (_isDialogueComplete)
                                       WidgetSpan(
                                         alignment: PlaceholderAlignment.middle,
                                         child: Padding(
                                           padding: EdgeInsets.only(left:scale),
                                           child: AnimatedBuilder(
                                             animation: _blinkAnimation,
                                             builder: (context, child) {
                                               return Opacity(
                                                 opacity: _blinkAnimation.value,
                                                 child: Icon(
                                                   Icons.keyboard_arrow_right_rounded,
                                                   color: config.themeColors.primary.withValues(alpha: 0.7),
                                                   size: dialogueStyle.fontSize! * 2,
                                                 ),
                                               );
                                             },
                                           ),
                                         ),
                                       ),
                                   ],
                                 ),
                               ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 