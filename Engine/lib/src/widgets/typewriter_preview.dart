import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/utils/scaling_manager.dart';

class TypewriterPreview extends StatefulWidget {
  final double charsPerSecond;
  final bool skipPunctuationDelay;
  final SakiEngineConfig config;
  final double scale;

  const TypewriterPreview({
    super.key,
    required this.charsPerSecond,
    required this.skipPunctuationDelay,
    required this.config,
    required this.scale,
  });

  @override
  State<TypewriterPreview> createState() => _TypewriterPreviewState();
}

class _TypewriterPreviewState extends State<TypewriterPreview>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<int> _charAnimation;
  
  final String _previewText = "平凡的天才展现自己的才能，真正的天才让人忘记才能。";
  
  @override
  void initState() {
    super.initState();
    _initAnimation();
    _startAnimation();
  }

  void _initAnimation() {
    _animationController = AnimationController(
      duration: Duration(
        milliseconds: widget.charsPerSecond >= 200.0 
          ? 100 // 瞬间显示时的最小持续时间
          : (_previewText.length * 1000 / widget.charsPerSecond).round(),
      ),
      vsync: this,
    );

    _charAnimation = IntTween(
      begin: 0,
      end: _previewText.length,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: widget.charsPerSecond >= 200.0 ? Curves.easeInOut : Curves.linear,
    ));
  }

  void _startAnimation() {
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // 动画完成后等待1秒再重新开始
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            _animationController.reset();
            _animationController.forward();
          }
        });
      }
    });
    
    _animationController.forward();
  }

  @override
  void didUpdateWidget(TypewriterPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.charsPerSecond != widget.charsPerSecond ||
        oldWidget.skipPunctuationDelay != widget.skipPunctuationDelay) {
      _animationController.dispose();
      _initAnimation();
      _startAnimation();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _getVisibleText(int charCount) {
    if (charCount <= 0) return '';
    if (charCount >= _previewText.length) return _previewText;
    
    String visibleText = _previewText.substring(0, charCount);
    
    // 如果启用标点符号延迟效果，在标点符号处添加适当的停顿感
    if (!widget.skipPunctuationDelay && charCount < _previewText.length) {
      final currentChar = _previewText[charCount - 1];
      if (RegExp(r'[。！？；，、]').hasMatch(currentChar)) {
        // 在标点符号后添加一个光标闪烁效果来模拟停顿
        return visibleText;
      }
    }
    
    return visibleText;
  }

  @override
  Widget build(BuildContext context) {
    final textScale = context.scaleFor(ComponentType.text);
    
    return Container(
      padding: EdgeInsets.all(12 * widget.scale),
      margin: EdgeInsets.only(top: 12 * widget.scale),
      decoration: BoxDecoration(
        color: widget.config.themeColors.surface.withOpacity(0.3),
        border: Border.all(
          color: widget.config.themeColors.primary.withOpacity(0.2),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(0 * widget.scale),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.preview,
                color: widget.config.themeColors.primary.withOpacity(0.7),
                size: 16 * widget.scale,
              ),
              SizedBox(width: 8 * widget.scale),
              Text(
                '实时预览',
                style: widget.config.dialogueTextStyle.copyWith(
                  fontSize: widget.config.dialogueTextStyle.fontSize! * textScale * 0.55,
                  color: widget.config.themeColors.primary.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 8 * widget.scale),
          Container(
            width: double.infinity,
            constraints: BoxConstraints(minHeight: 60 * widget.scale),
            padding: EdgeInsets.all(8 * widget.scale),
            decoration: BoxDecoration(
              color: widget.config.themeColors.background.withOpacity(0.5),
              borderRadius: BorderRadius.circular(2 * widget.scale),
            ),
            child: AnimatedBuilder(
              animation: _charAnimation,
              builder: (context, child) {
                final visibleText = _getVisibleText(_charAnimation.value);
                final showCursor = _charAnimation.value < _previewText.length;
                
                return RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: visibleText,
                        style: widget.config.dialogueTextStyle.copyWith(
                          fontSize: widget.config.dialogueTextStyle.fontSize! * textScale * 0.5,
                          color: widget.config.themeColors.onSurface,
                          height: 1.4,
                        ),
                      ),
                      if (showCursor && widget.charsPerSecond < 200.0)
                        TextSpan(
                          text: '|',
                          style: widget.config.dialogueTextStyle.copyWith(
                            fontSize: widget.config.dialogueTextStyle.fontSize! * textScale * 0.5,
                            color: widget.config.themeColors.primary,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}