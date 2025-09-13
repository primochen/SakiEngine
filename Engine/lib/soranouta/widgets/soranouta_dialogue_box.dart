import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/utils/scaling_manager.dart';
import 'package:sakiengine/src/utils/settings_manager.dart';
import 'package:sakiengine/src/widgets/typewriter_animation_manager.dart';
import 'package:sakiengine/src/utils/dialogue_progression_manager.dart';
import 'package:sakiengine/src/utils/dialogue_shake_effect.dart';
import 'package:sakiengine/src/utils/read_text_tracker.dart';
import 'package:sakiengine/src/widgets/read_status_indicator.dart';
import 'soranouta_dialogue_content.dart';
import 'soranouta_speaker_widget.dart';

class SoranoUtaDialogueBox extends StatefulWidget {
  final String? speaker;
  final String dialogue;
  final DialogueProgressionManager? progressionManager;
  final bool isFastForwarding; // 新增：快进状态
  final int scriptIndex; // 新增：脚本索引，用于已读状态检查

  const SoranoUtaDialogueBox({
    super.key,
    this.speaker,
    required this.dialogue,
    this.progressionManager,
    this.isFastForwarding = false, // 新增：默认不快进
    required this.scriptIndex, // 新增：必需的脚本索引
  });

  @override
  State<SoranoUtaDialogueBox> createState() => _SoranoUtaDialogueBoxState();
}

class _SoranoUtaDialogueBoxState extends State<SoranoUtaDialogueBox>
    with TickerProviderStateMixin {
  bool _isHovered = false;
  bool _isDialogueComplete = false;
  double _dialogOpacity = SettingsManager.defaultDialogOpacity;
  bool _isRead = false;

  // 打字机动画管理器
  late TypewriterAnimationManager _typewriterController;
  final bool _enableTypewriter = true;
  bool _enableSpeakerAnimation = true;

  // 文本淡入动画控制器
  late AnimationController _textFadeController;
  late Animation<double> _textFadeAnimation;

  // 说话人擦除动画控制器
  late AnimationController _speakerWipeController;
  late Animation<double> _speakerWipeAnimation;

  // 等待键入字符闪烁动画控制器
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;
  
  // 用于获取对话框位置的GlobalKey
  final GlobalKey _dialogueKey = GlobalKey();
  OverlayEntry? _overlayEntry;

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

    // 检查已读状态
    _isRead = ReadTextTracker.instance.isRead(
      widget.speaker,
      widget.dialogue,
      widget.scriptIndex,
    );

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

    // 启动说话人动画

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
      // 设置打字机的快进模式
      _typewriterController.setFastForwardMode(widget.isFastForwarding);
      
      // 快进模式下跳过淡入动画
      if (widget.isFastForwarding) {
        _textFadeController.value = 1.0; // 直接设为完成状态
      } else {
        _textFadeController.forward();
      }
      
      if (widget.speaker != null &&
          widget.speaker!.isNotEmpty &&
          _enableSpeakerAnimation) {
        _speakerWipeController.forward();
      }
      if (_enableTypewriter) {
        _typewriterController.startTyping(widget.dialogue);
      }
      
      // 创建overlay
      _updateOverlay();
    });
  }

  @override
  void dispose() {
    _removeOverlay();
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

  void _createOverlay() {
    if (!_isRead || _overlayEntry != null) return;
    
    _overlayEntry = OverlayEntry(
      builder: (context) => _buildReadStatusOverlay(),
    );
    
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _updateOverlay() {
    if (_isRead) {
      if (_overlayEntry == null) {
        _createOverlay();
      } else {
        _overlayEntry!.markNeedsBuild();
      }
    } else {
      _removeOverlay();
    }
  }

  Widget _buildReadStatusOverlay() {
    final RenderBox? renderBox = _dialogueKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      print('SoranoUta: RenderBox is null');
      return const SizedBox.shrink();
    }
    
    final position = renderBox.localToGlobal(Offset.zero);
    final config = SakiEngineConfig();
    final uiScale = context.scaleFor(ComponentType.ui);
    final textScale = context.scaleFor(ComponentType.text);
    
    print('SoranoUta 对话框位置: dx=${position.dx}, dy=${position.dy}');
    
    // 计算旋转后的标签尺寸以正确对齐中心点
    final labelWidth = 36.0 * uiScale + 18.0 * 2 * uiScale; // 大约的文本宽度 + padding
    final labelHeight = 14.0 * textScale + 4.0 * 2 * uiScale; // 文本高度 + padding
    
    // 旋转45度后，需要考虑对角线长度来计算中心偏移
    final diagonal = (labelWidth + labelHeight) / 2;
    final centerOffsetX = diagonal * 0.5; // 调整系数
    final centerOffsetY = diagonal * 0.3;
    
    final finalLeft = position.dx - centerOffsetX;
    final finalTop = position.dy - centerOffsetY;
    
    print('SoranoUta 标签位置: left=$finalLeft, top=$finalTop');
    
    return Positioned(
      left: finalLeft,
      top: finalTop,
      child: Transform.rotate(
        angle: -45 * 3.14159 / 180,
        child: Material( // 添加Material包装去除黄色双横线
          color: Colors.transparent,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 18.0 * uiScale,
              vertical: 4.0 * uiScale,
            ),
            decoration: BoxDecoration(
              color: config.themeColors.primary.withOpacity(0.8),
            ),
            child: Text(
              '已读',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.0 * textScale,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.none, // 明确去除装饰线
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(SoranoUtaDialogueBox oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 如果推进管理器发生变化，重新注册打字机
    if (widget.progressionManager != oldWidget.progressionManager) {
      oldWidget.progressionManager?.registerTypewriter(null);
      widget.progressionManager?.registerTypewriter(_typewriterController);
    }
    
    // 如果快进状态发生变化，更新打字机快进模式
    if (widget.isFastForwarding != oldWidget.isFastForwarding) {
      _typewriterController.setFastForwardMode(widget.isFastForwarding);
      // 快进模式下跳过文本淡入动画
      if (widget.isFastForwarding) {
        _textFadeController.value = 1.0; // 直接设为完成状态
      }
    }

    // 如果说话人发生变化，重新开始说话人擦除动画
    if (widget.speaker != oldWidget.speaker) {
      // 启动说话人动画
      if (widget.speaker != null &&
          widget.speaker!.isNotEmpty &&
          _enableSpeakerAnimation) {
        _speakerWipeController.reset();
        _speakerWipeController.forward();
      }
    }

    // 如果对话内容或脚本索引发生变化，重新检查已读状态并开始文本淡入和打字机动画
    if (widget.dialogue != oldWidget.dialogue || widget.scriptIndex != oldWidget.scriptIndex) {
      // 重新检查已读状态
      _isRead = ReadTextTracker.instance.isRead(
        widget.speaker,
        widget.dialogue,
        widget.scriptIndex,
      );
      
      // 快进模式下跳过淡入动画
      if (widget.isFastForwarding) {
        _textFadeController.value = 1.0; // 直接设为完成状态
      } else {
        _textFadeController.reset();
        _textFadeController.forward();
      }
      
      if (_enableTypewriter) {
        _typewriterController.startTyping(widget.dialogue);
      }
      
      // 更新overlay
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateOverlay();
      });
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
      color: SettingsManager().currentDarkMode ? Colors.black : Colors.white,
      letterSpacing: 0.5,
      fontFamily: 'ChillJinshuSongPro_Soft',
      backgroundColor: SettingsManager().currentDarkMode ? Colors.white : Colors.black,
      height: 1.1,
    );

    return Container(
      child: DialogueShakeEffect(
        dialogue: widget.dialogue,
        enabled: true,
        intensity: 4.0 * uiScale,
        duration: const Duration(milliseconds: 600),
        child: Stack(
          children: [
            // 主对话框内容
            SoranoutaDialogueContent(
            speaker: widget.speaker,
            dialogue: widget.dialogue,
            dialogueStyle: dialogueStyle,
            screenSize: screenSize,
            uiScale: uiScale,
            textScale: textScale,
            isHovered: _isHovered,
            isDialogueComplete: _isDialogueComplete,
            dialogOpacity: _dialogOpacity,
            onTap: _handleTap,
            onHoverChanged: (hovered) => setState(() => _isHovered = hovered),
            config: config,
            enableTypewriter: _enableTypewriter,
            typewriterController: _typewriterController,
            textFadeAnimation: _textFadeAnimation,
            blinkAnimation: _blinkAnimation,
            isRead: _isRead,
            readStatusOverlay: null,
            dialogueKey: _dialogueKey, // 传递key给内部组件
          ),
          
          // 说话人显示组件
          SoranoutaSpeakerWidget(
            speaker: widget.speaker,
            speakerStyle: speakerStyle,
            screenWidth: screenSize.width,
            screenHeight: screenSize.height,
            uiScale: uiScale,
            speakerXPos: config.soranoutaSpeakerXPos,
            speakerYPos: config.soranoutaSpeakerYPos,
            enableAnimation: _enableSpeakerAnimation,
            wipeAnimation: _speakerWipeAnimation,
          ),
        ],
        ),
      ),
    );
  }
}
