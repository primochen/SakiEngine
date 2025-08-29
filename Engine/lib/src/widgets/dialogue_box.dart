import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/utils/scaling_manager.dart';
import 'package:sakiengine/src/utils/settings_manager.dart';
import 'package:sakiengine/src/utils/smart_asset_image.dart';
import 'package:sakiengine/src/widgets/typewriter_animation_manager.dart';
import 'package:sakiengine/src/utils/dialogue_progression_manager.dart';
import 'package:sakiengine/src/widgets/dialogue_next_arrow.dart';

class DialogueBox extends StatefulWidget {
  final String? speaker;
  final String dialogue;
  final DialogueProgressionManager? progressionManager;

  const DialogueBox({
    super.key,
    this.speaker,
    required this.dialogue,
    this.progressionManager,
  });

  @override
  State<DialogueBox> createState() => _DialogueBoxState();
}

class _DialogueBoxState extends State<DialogueBox> with TickerProviderStateMixin {
  bool _isHovered = false;
  bool _isDialogueComplete = false;
  double _dialogOpacity = SettingsManager.defaultDialogOpacity;
  
  // 打字机动画管理器
  late TypewriterAnimationManager _typewriterController;
  bool _enableTypewriter = true;
  
  // 文本淡入动画控制器
  late AnimationController _textFadeController;
  late Animation<double> _textFadeAnimation;
  
  void _onSettingsChanged() {
    if (mounted) {
      setState(() {
        _dialogOpacity = SettingsManager().currentDialogOpacity;
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

    // 监听设置变化
    SettingsManager().addListener(_onSettingsChanged);
    
    // 加载设置
    _loadSettings();
    
    // 开始文本淡入和打字机动画
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _textFadeController.forward();
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
    super.dispose();
  }

  @override
  void didUpdateWidget(DialogueBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 如果推进管理器发生变化，重新注册打字机
    if (widget.progressionManager != oldWidget.progressionManager) {
      oldWidget.progressionManager?.registerTypewriter(null);
      widget.progressionManager?.registerTypewriter(_typewriterController);
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
    // 可以添加打字机开关设置
    // final enableTypewriter = await settings.getEnableTypewriter();
    
    if (mounted) {
      setState(() {
        _dialogOpacity = opacity;
        // _enableTypewriter = enableTypewriter;
      });
    }
  }

  void _handleTap() {
    // 使用推进管理器统一处理对话推进
    widget.progressionManager?.progressDialogue();
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
    );

    return GestureDetector(
      onTap: _handleTap,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: Container(
            width: screenSize.width * 0.85,
            height: screenSize.height * 0.25,
            margin: EdgeInsets.all(16.0 * uiScale),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(config.baseWindowBorder > 0 
                  ? config.baseWindowBorder * uiScale 
                  : 0 * uiScale),
              border: Border.all(
                color: config.themeColors.primary.withOpacity(_isHovered ? 0.4 : 0.2),
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
              borderRadius: BorderRadius.circular(config.baseWindowBorder > 0 
                  ? config.baseWindowBorder * uiScale 
                  : 0 * uiScale),
              child: Stack(
                children: [
                  // 底层：纯色背景
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: config.themeColors.background,
                  ),
                  // 中层：背景图片
                  if (config.baseWindowBackground != null && config.baseWindowBackground!.isNotEmpty)
                    Positioned.fill(
                      child: Opacity(
                        opacity: config.baseWindowBackgroundAlpha,
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
                    color: config.themeColors.background.withOpacity(config.baseWindowAlpha * _dialogOpacity),
                    child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题栏
                Container(
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
                  child: Text(
                    widget.speaker ?? '', // 如果 speaker 为 null，则显示空字符串
                    style: config.speakerTextStyle.copyWith(
                      fontSize: config.speakerTextStyle.fontSize! * textScale,
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
                        if (mounted) {
                          setState(() {
                            _isDialogueComplete = !_isTextOverflowing(
                              context, 
                              widget.dialogue, 
                              dialogueStyle, 
                              constraints.maxWidth - 32 * uiScale
                            );
                          });
                        }
                      });

                      return SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.all(16.0 * uiScale),
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
                                           ? _typewriterController.displayedText 
                                           : widget.dialogue,
                                         style: dialogueStyle,
                                       ),
                                       if (_isDialogueComplete)
                                         WidgetSpan(
                                           alignment: PlaceholderAlignment.middle,
                                           child: Padding(
                                             padding: EdgeInsets.only(left: uiScale),
                                             child: DialogueNextArrow(
                                               visible: _isDialogueComplete,
                                               fontSize: dialogueStyle.fontSize!,
                                               color: config.themeColors.primary.withOpacity(0.7),
                                             ),
                                           ),
                                         ),
                                     ],
                                   ),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
