import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/utils/scaling_manager.dart';
import 'package:sakiengine/src/utils/settings_manager.dart';
import 'package:sakiengine/src/utils/smart_asset_image.dart';
import 'package:sakiengine/src/widgets/typewriter_animation_manager.dart';
import 'package:sakiengine/src/utils/dialogue_progression_manager.dart';
import 'package:sakiengine/src/widgets/dialogue_next_arrow.dart';

class SoranoUtaDialogueBox extends StatefulWidget {
  final String? speaker;
  final String dialogue;
  final DialogueProgressionManager? progressionManager;

  const SoranoUtaDialogueBox({
    super.key,
    this.speaker,
    required this.dialogue,
    this.progressionManager,
  });

  @override
  State<SoranoUtaDialogueBox> createState() => _SoranoUtaDialogueBoxState();
}

class _SoranoUtaDialogueBoxState extends State<SoranoUtaDialogueBox>
    with TickerProviderStateMixin {
  bool _isHovered = false;
  bool _isDialogueComplete = false;
  double _dialogOpacity = SettingsManager.defaultDialogOpacity;

  // 打字机动画管理器
  late TypewriterAnimationManager _typewriterController;
  bool _enableTypewriter = true;
  bool _enableSpeakerAnimation = true;

  // 文本淡入动画控制器
  late AnimationController _textFadeController;
  late Animation<double> _textFadeAnimation;

  // 说话人擦除动画控制器
  late AnimationController _speakerWipeController;
  late Animation<double> _speakerWipeAnimation;
  String? _currentSpeaker;

  // 等待键入字符闪烁动画控制器
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  void _onSettingsChanged() {
    if (mounted) {
      setState(() {
        _dialogOpacity = SettingsManager().currentDialogOpacity;
        _enableSpeakerAnimation = SettingsManager().currentSpeakerAnimation;
      });
    }
  }

  @override
  void initState() {
    super.initState();

    // 初始化打字机动画管理器
    _typewriterController = TypewriterAnimationManager();
    _typewriterController.initialize(this);
    _typewriterController.addListener(_onTypewriterStateChanged);

    // 注册打字机到推进管理器
    widget.progressionManager?.registerTypewriter(_typewriterController);

    // 初始化文本淡入动画
    _textFadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _textFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textFadeController,
      curve: Curves.easeInOut,
    ));

    // 初始化说话人擦除动画
    _speakerWipeController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _speakerWipeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _speakerWipeController,
      curve: Curves.easeOutQuart,
    ));

    _currentSpeaker = widget.speaker;

    // 初始化等待键入字符闪烁动画
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _blinkAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_blinkController);

    _blinkController.repeat(reverse: true);

    // 监听设置变化
    SettingsManager().addListener(_onSettingsChanged);

    // 加载设置
    _loadSettings();

    // 开始文本淡入和打字机动画
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _textFadeController.forward();
      if (widget.speaker != null &&
          widget.speaker!.isNotEmpty &&
          _enableSpeakerAnimation) {
        _speakerWipeController.forward();
      }
      if (_enableTypewriter) {
        _typewriterController.startTyping(widget.dialogue);
      }
    });
  }

  @override
  void dispose() {
    // 从推进管理器注销打字机
    widget.progressionManager?.registerTypewriter(null);
    SettingsManager().removeListener(_onSettingsChanged);
    _typewriterController.removeListener(_onTypewriterStateChanged);
    _typewriterController.dispose();
    _textFadeController.dispose();
    _speakerWipeController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SoranoUtaDialogueBox oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 如果推进管理器发生变化，重新注册打字机
    if (widget.progressionManager != oldWidget.progressionManager) {
      oldWidget.progressionManager?.registerTypewriter(null);
      widget.progressionManager?.registerTypewriter(_typewriterController);
    }

    // 如果说话人发生变化，重新开始说话人擦除动画
    if (widget.speaker != oldWidget.speaker) {
      _currentSpeaker = widget.speaker;
      if (widget.speaker != null &&
          widget.speaker!.isNotEmpty &&
          _enableSpeakerAnimation) {
        _speakerWipeController.reset();
        _speakerWipeController.forward();
      }
    }

    // 如果对话内容发生变化，重新开始文本淡入和打字机动画
    if (widget.dialogue != oldWidget.dialogue) {
      _textFadeController.reset();
      _textFadeController.forward();
      if (_enableTypewriter) {
        _typewriterController.startTyping(widget.dialogue);
      }
    }
  }

  void _onTypewriterStateChanged() {
    if (mounted) {
      setState(() {
        _isDialogueComplete = _typewriterController.isCompleted;
      });
    }
  }

  Future<void> _loadSettings() async {
    final settings = SettingsManager();
    final opacity = await settings.getDialogOpacity();
    _enableSpeakerAnimation = await settings.getSpeakerAnimation();

    if (mounted) {
      setState(() {
        _dialogOpacity = opacity;
      });
    }
  }

  void _handleTap() {
    // 使用推进管理器统一处理对话推进
    widget.progressionManager?.progressDialogue();
  }

  bool _isTextOverflowing(
      BuildContext context, String text, TextStyle style, double maxWidth) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: null,
    )..layout(maxWidth: maxWidth);

    return textPainter.height > maxWidth;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final config = SakiEngineConfig();
    final uiScale = context.scaleFor(ComponentType.ui);
    final textScale = context.scaleFor(ComponentType.text);

    final dialogueStyle = config.dialogueTextStyle.copyWith(
      fontSize: config.dialogueTextStyle.fontSize! * textScale,
      color: config.themeColors.onSurface,
      height: 1.6,
      letterSpacing: 0.3,
      fontFamily: 'SourceHanSansCN',
    );

    final speakerStyle = config.speakerTextStyle.copyWith(
      fontSize: config.speakerTextStyle.fontSize! * textScale,
      color: Colors.white,
      letterSpacing: 0.5,
      fontFamily: 'ChillJinshuSongPro_Soft',
      backgroundColor: Colors.black,
      height: 1.1,
    );

    return Stack(
      children: [
        // 对话框（独立控件）
        GestureDetector(
          onTap: _handleTap,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: MouseRegion(
              onEnter: (_) => setState(() => _isHovered = true),
              onExit: (_) => setState(() => _isHovered = false),
              child: Container(
                width: screenSize.width * 0.85,
                height: screenSize.height * 0.35 / 1.5,
                margin: EdgeInsets.all(16.0 * uiScale),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                      config.baseWindowBorder > 0
                          ? config.baseWindowBorder * uiScale
                          : 0 * uiScale),
                  border: Border.all(
                    color: config.themeColors.primary
                        .withOpacity(_isHovered ? 0.4 : 0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 12 * uiScale,
                      offset: Offset(0, 4 * uiScale),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                      config.baseWindowBorder > 0
                          ? config.baseWindowBorder * uiScale
                          : 0 * uiScale),
                  child: Stack(
                    children: [
                      // 底层：纯色背景
                      Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: config.themeColors.background
                            .withOpacity(_dialogOpacity),
                      ),
                      // 中层：背景图片
                      if (config.baseWindowBackground != null &&
                          config.baseWindowBackground!.isNotEmpty)
                        Positioned.fill(
                          child: Opacity(
                            opacity: config.baseWindowBackgroundAlpha *
                                _dialogOpacity,
                            child: ColorFiltered(
                              colorFilter: ColorFilter.mode(
                                Colors.transparent,
                                config.baseWindowBackgroundBlendMode,
                              ),
                              child: FittedBox(
                                fit: BoxFit.none,
                                alignment: Alignment(
                                  (config.dialogueBackgroundXAlign - 0.5) * 2,
                                  (config.dialogueBackgroundYAlign - 0.5) * 2,
                                ),
                                child: Transform.scale(
                                  scale: config.dialogueBackgroundScale,
                                  child: SmartAssetImage(
                                    assetName: config.baseWindowBackground!,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      // 上层：半透明控件
                      Container(
                        color: config.themeColors.background
                            .withOpacity(config.baseWindowAlpha * 0.3),
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: 16.0 * uiScale + config.soranoUtaTextXPos,
                            right: 16.0 * uiScale,
                            top: 16.0 * uiScale + config.soranoUtaTextYPos,
                            bottom: 16.0 * uiScale,
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              // 检查文本是否溢出
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  setState(() {
                                    _isDialogueComplete = !_isTextOverflowing(
                                        context,
                                        widget.dialogue,
                                        dialogueStyle,
                                        constraints.maxWidth - 32 * uiScale);
                                  });
                                }
                              });

                              return SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    FadeTransition(
                                      opacity: _textFadeAnimation,
                                      child: RichText(
                                        text: TextSpan(
                                          children: [
                                            TextSpan(
                                              text: _enableTypewriter
                                                  ? _typewriterController
                                                      .displayedText
                                                  : widget.dialogue,
                                              style: dialogueStyle,
                                            ),
                                            if (_isDialogueComplete)
                                              WidgetSpan(
                                                alignment:
                                                    PlaceholderAlignment.middle,
                                                child: Padding(
                                                  padding: EdgeInsets.only(
                                                      left: uiScale),
                                                  child: widget.speaker !=
                                                              null &&
                                                          widget.speaker!
                                                              .isNotEmpty
                                                      ? Padding(
                                                          padding:
                                                              EdgeInsets.only(
                                                                  bottom: 15 *
                                                                      uiScale),
                                                          child:
                                                              AnimatedBuilder(
                                                            animation:
                                                                _blinkAnimation,
                                                            builder: (context,
                                                                child) {
                                                              return Opacity(
                                                                opacity:
                                                                    _blinkAnimation
                                                                        .value,
                                                                child: Text(
                                                                  '_',
                                                                  style: dialogueStyle
                                                                      .copyWith(
                                                                    color: config
                                                                        .themeColors
                                                                        .primary,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    height: 1.0,
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                        )
                                                      : Padding(
                                                          padding:
                                                              EdgeInsets.only(
                                                                  bottom: 7 *
                                                                      uiScale),
                                                          child:
                                                              DialogueNextArrow(
                                                            visible:
                                                                _isDialogueComplete,
                                                            fontSize:
                                                                dialogueStyle
                                                                    .fontSize!,
                                                            color: config
                                                                .themeColors
                                                                .primary
                                                                .withOpacity(
                                                                    0.7),
                                                          ),
                                                        ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // 说话人黑色矩形（独立控件，在对话框之上）
        Positioned(
          left: (screenSize.width * 0.85) * config.soranoutaSpeakerXPos +
              16 * uiScale,
          bottom: 16 * uiScale +
              (screenSize.height * 0.35 / 1.5) *
                  (1.0 - config.soranoutaSpeakerYPos),
          child: FractionalTranslation(
            translation: const Offset(0.0, 0.5),
            child: Opacity(
              opacity: (widget.speaker != null && widget.speaker!.isNotEmpty)
                  ? 1.0
                  : 0.0,
              child: _enableSpeakerAnimation
                  ? AnimatedBuilder(
                      animation: _speakerWipeAnimation,
                      builder: (context, child) {
                        return ClipRect(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            widthFactor: (widget.speaker != null &&
                                    widget.speaker!.isNotEmpty)
                                ? _speakerWipeAnimation.value
                                : 0.0,
                            child: Text(
                              widget.speaker ?? ' ',
                              style: speakerStyle,
                              textHeightBehavior: const TextHeightBehavior(
                                applyHeightToFirstAscent: false,
                                applyHeightToLastDescent: false,
                              ),
                            ),
                          ),
                        );
                      },
                    )
                  : Text(
                      widget.speaker ?? ' ',
                      style: speakerStyle,
                      textHeightBehavior: const TextHeightBehavior(
                        applyHeightToFirstAscent: false,
                        applyHeightToLastDescent: false,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
