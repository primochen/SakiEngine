import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/utils/scaling_manager.dart';
import 'dart:math';

class TypewriterPreview extends StatefulWidget {
  final double charsPerSecond;
  final bool skipPunctuationDelay;
  final SakiEngineConfig config;
  final double scale;
  final String? previewText; // 新增：预选的展示文本

  const TypewriterPreview({
    super.key,
    required this.charsPerSecond,
    required this.skipPunctuationDelay,
    required this.config,
    required this.scale,
    this.previewText, // 可选参数
  });

  @override
  State<TypewriterPreview> createState() => _TypewriterPreviewState();
  
  // 静态方法：获取随机文本，供外部使用
  static String getRandomPreviewText() {
    final random = Random();
    return _previewTexts[random.nextInt(_previewTexts.length)];
  }
  
  // 预设的示例文本列表
  static const List<String> _previewTexts = [
    "平凡的天才展现自己的才能，真正的天才让人忘记才能。",
    "人什么的，大半都是幻影一般的东西，真正重要的人和物只有一点点。所以，我只相信重要的东西。",
    "对于真正空虚的人来说，幸福圆满的故事只会沉重得让人窒息。",
    "决定绘画价值的不是作者，而是观众。",
    "努力不会辜负人。说到底，努力的总量就和命运的恩惠没有任何关系。",
    "几乎所有人都会意识到自己并不是什么特别的存在。",
    "高喊着虚无缥缈的口号行动，只能迎来虚妄的结局。",
    "世上能够将美视为纯粹的“美”去爱的人非常少见，这世间满是瞎眼的废物。",
  ];
}

class _TypewriterPreviewState extends State<TypewriterPreview>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<int> _charAnimation;
  
  late String _currentPreviewText;
  
  @override
  void initState() {
    super.initState();
    // 使用传入的文本，如果没有则随机选择
    _currentPreviewText = widget.previewText ?? TypewriterPreview.getRandomPreviewText();
    _initAnimation();
    _startAnimation();
  }

  void _initAnimation() {
    _animationController = AnimationController(
      duration: Duration(
        milliseconds: widget.charsPerSecond >= 200.0 
          ? 100 // 瞬间显示时的最小持续时间
          : (_currentPreviewText.length * 1000 / widget.charsPerSecond).round(),
      ),
      vsync: this,
    );

    _charAnimation = IntTween(
      begin: 0,
      end: _currentPreviewText.length,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: widget.charsPerSecond >= 200.0 ? Curves.easeInOut : Curves.linear,
    ));
  }

  void _startAnimation() {
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // 动画完成后等待1秒再重新开始，但不更换文本
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
      _initAnimation(); // 使用当前已选择的文本重新初始化
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
    if (charCount >= _currentPreviewText.length) return _currentPreviewText;
    
    String visibleText = _currentPreviewText.substring(0, charCount);
    
    // 如果启用标点符号延迟效果，在标点符号处添加适当的停顿感
    if (!widget.skipPunctuationDelay && charCount < _currentPreviewText.length) {
      final currentChar = _currentPreviewText[charCount - 1];
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
                final showCursor = _charAnimation.value < _currentPreviewText.length;
                
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