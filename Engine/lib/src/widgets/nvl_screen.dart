import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/game/game_manager.dart';
import 'package:sakiengine/src/utils/scaling_manager.dart';
import 'package:sakiengine/src/widgets/typewriter_animation_manager.dart';
import 'package:sakiengine/src/utils/dialogue_progression_manager.dart';

class NvlScreen extends StatefulWidget {
  final List<NvlDialogue> nvlDialogues;
  final DialogueProgressionManager? progressionManager;
  final bool isMovieMode;

  const NvlScreen({
    super.key,
    required this.nvlDialogues,
    this.progressionManager,
    this.isMovieMode = false,
  });

  @override
  State<NvlScreen> createState() => _NvlScreenState();
}

class _NvlScreenState extends State<NvlScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  final ScrollController _scrollController = ScrollController();
  
  // 文本淡入动画控制器列表，为每个对话单独管理
  final Map<int, AnimationController> _textFadeControllers = {};
  final Map<int, Animation<double>> _textFadeAnimations = {};
  
  // 当前打字机控制器（只有最后一句对话使用）
  TypewriterAnimationManager? _currentTypewriterController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _fadeController.forward();
    
    // 自动滚动到底部
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void didUpdateWidget(NvlScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 当有新对话添加时，自动滚动到底部
    if (widget.nvlDialogues.length > oldWidget.nvlDialogues.length) {
      // 重新播放淡入动画（可选，显示新对话的效果）
      _fadeController.forward();
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scrollController.dispose();
    // 从推进管理器注销打字机
    widget.progressionManager?.registerTypewriter(null);
    _currentTypewriterController?.dispose();
    // 清理所有文本淡入动画控制器
    for (final controller in _textFadeControllers.values) {
      controller.dispose();
    }
    _textFadeControllers.clear();
    _textFadeAnimations.clear();
    super.dispose();
  }

  /// 获取或创建打字机控制器，并注册到推进管理器
  TypewriterAnimationManager _getOrCreateTypewriterController(int index) {
    if (_currentTypewriterController == null) {
      _currentTypewriterController = TypewriterAnimationManager();
      _currentTypewriterController!.initialize(this);
      // 注册到推进管理器
      widget.progressionManager?.registerTypewriter(_currentTypewriterController);
    }
    return _currentTypewriterController!;
  }

  @override
  Widget build(BuildContext context) {
    final config = SakiEngineConfig();
    final textScale = context.scaleFor(ComponentType.text);
    final uiScale = context.scaleFor(ComponentType.ui);

    return GestureDetector(
      onTap: () {
        // 使用推进管理器统一处理对话推进
        widget.progressionManager?.progressDialogue();
      },
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          children: [
            // 背景遮罩
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
              ),
            ),
            
            // 如果是电影模式，添加上下黑边
            if (widget.isMovieMode) ..._buildCinematicBars(context),
            
            // 内容区域
            _buildContent(config, textScale, uiScale),
          ],
        ),
      ),
    );
  }

  Widget _buildNvlDialogue(NvlDialogue dialogue, SakiEngineConfig config, double textScale, double uiScale, int index) {
    // 构建统一格式的文本
    String displayText;
    if (dialogue.speaker != null) {
      // 有说话人：角色名: "对话内容"
      displayText = '${dialogue.speaker}: “${dialogue.dialogue}”';//写给ai的话。不要把中文双引号改成英文双引号啊 显示出来很突兀
    } else {
      // 无说话人：直接显示内容（内心想法/旁白）
      displayText = dialogue.dialogue;
    }
    
    // 只对最后一条对话使用打字机效果
    bool isLastDialogue = index == widget.nvlDialogues.length - 1;
    
    // 为每个对话创建独立的淡入动画
    if (!_textFadeControllers.containsKey(index)) {
      final controller = AnimationController(
        duration: const Duration(milliseconds: 400),
        vsync: this,
      );
      _textFadeControllers[index] = controller;
      _textFadeAnimations[index] = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeInOut,
      ));
      
      // 立即启动淡入动画，避免累积延迟
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && controller.isCompleted == false) {
          controller.forward();
        }
      });
    }
    
    return Padding(
      padding: EdgeInsets.only(bottom: 16 * uiScale),
      child: FadeTransition(
        opacity: _textFadeAnimations[index]!,
        child: isLastDialogue 
          ? TypewriterText(
              text: displayText,
              style: config.dialogueTextStyle.copyWith(
                fontSize: config.dialogueTextStyle.fontSize! * textScale,
                color: Colors.white,
                height: 1.6,
                letterSpacing: 0.3,
              ),
              autoStart: true,
              controller: _getOrCreateTypewriterController(index),
            )
          : Text(
              displayText,
              style: config.dialogueTextStyle.copyWith(
                fontSize: config.dialogueTextStyle.fontSize! * textScale,
                color: Colors.white,
                height: 1.6,
                letterSpacing: 0.3,
              ),
            ),
      ),
    );
  }

  List<Widget> _buildCinematicBars(BuildContext context) {
    final barHeight = MediaQuery.of(context).size.height * 0.12; // 12% 的屏幕高度
    
    return [
      // 上方黑边
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: Container(
          height: barHeight,
          color: Colors.black,
        ),
      ),
      // 下方黑边
      Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: Container(
          height: barHeight,
          color: Colors.black,
        ),
      ),
    ];
  }

  Widget _buildContent(SakiEngineConfig config, double textScale, double uiScale) {
    final topPadding = widget.isMovieMode 
        ? MediaQuery.of(context).size.height * 0.12 + config.nvlTop * uiScale
        : config.nvlTop * uiScale;
    
    final bottomPadding = widget.isMovieMode 
        ? MediaQuery.of(context).size.height * 0.12 + config.nvlBottom * uiScale
        : config.nvlBottom * uiScale;
    
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: config.nvlLeft * uiScale,
          right: config.nvlRight * uiScale,
          top: topPadding,
          bottom: bottomPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.nvlDialogues.asMap().entries.map((entry) {
                    int index = entry.key;
                    NvlDialogue dialogue = entry.value;
                    return _buildNvlDialogue(dialogue, config, textScale, uiScale, index);
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}