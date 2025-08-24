import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/game/game_manager.dart';
import 'package:sakiengine/src/utils/scaling_manager.dart';

class NvlScreen extends StatefulWidget {
  final List<NvlDialogue> nvlDialogues;
  final VoidCallback onTap;

  const NvlScreen({
    super.key,
    required this.nvlDialogues,
    required this.onTap,
  });

  @override
  State<NvlScreen> createState() => _NvlScreenState();
}

class _NvlScreenState extends State<NvlScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  final ScrollController _scrollController = ScrollController();

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = SakiEngineConfig();
    final textScale = context.scaleFor(ComponentType.text);
    final uiScale = context.scaleFor(ComponentType.ui);

    return GestureDetector(
      onTap: widget.onTap,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          // 半透明黑色遮罩
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: config.nvlLeft * uiScale,    // 使用配置文件参数
                right: config.nvlRight * uiScale,  // 使用配置文件参数
                top: config.nvlTop * uiScale,      // 使用配置文件参数
                bottom: config.nvlBottom * uiScale, // 使用配置文件参数
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, // 整个容器也左对齐
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, // 改为左对齐
                        children: widget.nvlDialogues.map((dialogue) {
                          return _buildNvlDialogue(dialogue, config, textScale, uiScale);
                        }).toList(),
                      ),
                    ),
                  ),
                  // 移除提示文本
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNvlDialogue(NvlDialogue dialogue, SakiEngineConfig config, double textScale, double uiScale) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16 * uiScale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dialogue.speaker != null) ...[
            Text(
              dialogue.speaker!,
              style: config.speakerTextStyle.copyWith(
                fontSize: config.speakerTextStyle.fontSize! * textScale,
                color: config.themeColors.primary,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 8 * uiScale),
          ],
          Text(
            dialogue.dialogue,
            style: config.dialogueTextStyle.copyWith(
              fontSize: config.dialogueTextStyle.fontSize! * textScale,
              color: Colors.white,
              height: 1.6,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}