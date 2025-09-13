import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/config_models.dart';
import 'package:sakiengine/src/game/game_manager.dart';
import 'package:sakiengine/src/screens/game_play_screen.dart';
import 'package:sakiengine/src/screens/review_screen.dart';
import 'package:sakiengine/src/screens/save_load_screen.dart';
import 'package:sakiengine/src/sks_parser/sks_ast.dart';
import 'package:sakiengine/src/utils/binary_serializer.dart';
import 'package:sakiengine/src/utils/dialogue_progression_manager.dart';
import 'package:sakiengine/src/utils/expression_selector_manager.dart';
import 'package:sakiengine/src/utils/scaling_manager.dart';
import 'package:sakiengine/src/widgets/choice_menu.dart';
import 'package:sakiengine/src/widgets/common/notification_overlay.dart';
import 'package:sakiengine/src/widgets/common/right_click_ui_manager.dart';
import 'package:sakiengine/src/widgets/debug_panel_dialog.dart';
import 'package:sakiengine/src/widgets/developer_panel.dart';
import 'package:sakiengine/src/widgets/expression_selector_dialog.dart';
import 'package:sakiengine/src/widgets/common/common_indicator.dart';
import 'package:sakiengine/src/widgets/nvl_screen.dart';
import 'package:sakiengine/src/widgets/quick_menu.dart';
import 'package:sakiengine/src/widgets/settings_screen.dart';

/// 游戏UI层组件
/// 包含所有游戏中的UI元素，支持右键隐藏
class GameUILayer extends StatefulWidget {
  final GameState gameState;
  final GameManager gameManager;
  final DialogueProgressionManager dialogueProgressionManager;
  final String currentScript;
  final GlobalKey nvlScreenKey;
  
  // 状态管理
  final bool showReviewOverlay;
  final bool showSaveOverlay;
  final bool showLoadOverlay;
  final bool showSettings;
  final bool showDeveloperPanel;
  final bool showDebugPanel;
  final bool showExpressionSelector;
  final bool isShowingMenu;
  
  // 回调函数
  final VoidCallback onToggleReview;
  final VoidCallback onToggleSave;
  final VoidCallback onToggleLoad;
  final VoidCallback onToggleSettings;
  final VoidCallback onToggleDeveloperPanel;
  final VoidCallback onToggleDebugPanel;
  final VoidCallback onToggleExpressionSelector;
  final VoidCallback onHandleQuickMenuBack;
  final VoidCallback onHandlePreviousDialogue;
  final VoidCallback? onSkipRead; // 新增：跳过已读文本回调
  final Function(DialogueHistoryEntry) onJumpToHistoryEntry;
  final Function(SaveSlot)? onLoadGame;
  final VoidCallback onProgressDialogue;
  
  // 表情选择器管理器
  final ExpressionSelectorManager? expressionSelectorManager;
  
  // 对话框创建函数
  final Widget Function({Key? key, String? speaker, String? speakerAlias, required String dialogue, required bool isFastForwarding, required int scriptIndex}) createDialogueBox;
  
  // 通知显示回调
  final Function(String) showNotificationMessage;

  const GameUILayer({
    super.key,
    required this.gameState,
    required this.gameManager,
    required this.dialogueProgressionManager,
    required this.currentScript,
    required this.nvlScreenKey,
    required this.showReviewOverlay,
    required this.showSaveOverlay,
    required this.showLoadOverlay,
    required this.showSettings,
    required this.showDeveloperPanel,
    required this.showDebugPanel,
    required this.showExpressionSelector,
    required this.isShowingMenu,
    required this.onToggleReview,
    required this.onToggleSave,
    required this.onToggleLoad,
    required this.onToggleSettings,
    required this.onToggleDeveloperPanel,
    required this.onToggleDebugPanel,
    required this.onToggleExpressionSelector,
    required this.onHandleQuickMenuBack,
    required this.onHandlePreviousDialogue,
    this.onSkipRead, // 新增：跳过已读文本回调（可选）
    required this.onJumpToHistoryEntry,
    required this.onLoadGame,
    required this.onProgressDialogue,
    required this.expressionSelectorManager,
    required this.createDialogueBox,
    required this.showNotificationMessage,
  });

  @override
  State<GameUILayer> createState() => _GameUILayerState();
}

class _GameUILayerState extends State<GameUILayer> {
  final _notificationOverlayKey = GlobalKey<NotificationOverlayState>();

  /// 检查是否有弹窗显示
  bool get _hasOverlayOpen {
    return widget.isShowingMenu ||
        widget.showSaveOverlay ||
        widget.showLoadOverlay ||
        widget.showReviewOverlay ||
        widget.showSettings ||
        widget.showDeveloperPanel ||
        widget.showDebugPanel ||
        widget.showExpressionSelector;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 对话框 - 使用 AnimatedSwitcher 为对话框切换添加过渡动画
        HideableUI(
          child: AnimatedSwitcher(
            duration: widget.gameState.isFastForwarding 
                ? Duration.zero // 快进模式下跳过动画
                : const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              // 快进模式下跳过滑动动画，直接显示
              if (widget.gameState.isFastForwarding) {
                return child;
              }
              
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOut,
                  )),
                  child: child,
                ),
              );
            },
            child: widget.gameState.dialogue != null && !widget.gameState.isNvlMode
                ? widget.createDialogueBox(
                    key: const ValueKey('normal_dialogue'),
                    speaker: widget.gameState.speaker,
                    speakerAlias: widget.gameState.speakerAlias, // 传递角色简写
                    dialogue: widget.gameState.dialogue!,
                    isFastForwarding: widget.gameState.isFastForwarding, // 传递快进状态
                    scriptIndex: widget.gameManager.currentScriptIndex, // 传递脚本索引
                  )
                : const SizedBox.shrink(key: ValueKey('no_dialogue')),
          ),
        ),
        
        // 选择菜单
        if (widget.gameState.currentNode is MenuNode)
          HideableUI(
            child: ChoiceMenu(
              menuNode: widget.gameState.currentNode as MenuNode,
              onChoiceSelected: (String targetLabel) {
                widget.gameManager.jumpToLabel(targetLabel);
              },
              isFastForwarding: widget.gameState.isFastForwarding, // 传递快进状态
            ),
          ),
        
        // NVL 模式覆盖层 - 使用 AnimatedSwitcher 添加过渡动画
        HideableUI(
          child: AnimatedSwitcher(
            duration: widget.gameState.isFastForwarding 
                ? Duration.zero // 快进模式下跳过动画
                : const Duration(milliseconds: 400),
            transitionBuilder: (Widget child, Animation<double> animation) {
              // 快进模式下跳过淡入淡出动画，直接显示
              if (widget.gameState.isFastForwarding) {
                return child;
              }
              
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            child: widget.gameState.isNvlMode
                ? NvlScreen(
                    key: widget.nvlScreenKey,
                    nvlDialogues: widget.gameState.nvlDialogues,
                    isMovieMode: widget.gameState.isNvlMovieMode,
                    progressionManager: widget.dialogueProgressionManager,
                    isFastForwarding: widget.gameState.isFastForwarding, // 传递快进状态
                  )
                : const SizedBox.shrink(key: ValueKey('no_nvl')),
          ),
        ),
        
        // 快捷菜单
        HideableUI(
          child: QuickMenu(
            onSave: widget.onToggleSave,
            onLoad: widget.onToggleLoad,
            onReview: widget.onToggleReview,
            onSettings: widget.onToggleSettings,
            onBack: widget.onHandleQuickMenuBack,
            onPreviousDialogue: widget.onHandlePreviousDialogue,
            onSkipRead: widget.onSkipRead, // 新增：传递跳过已读文本回调
          ),
        ),
        
        // 快进指示器 - 垂直居中
        if (widget.gameState.isFastForwarding)
          Positioned(
            left: 20 * context.scaleFor(ComponentType.menu),
            top: 0,
            bottom: 0,
            child: Center(
              child: HideableUI(
                child: CommonIndicator(
                  isVisible: widget.gameState.isFastForwarding,
                  icon: Icons.fast_forward_rounded, // 使用圆滑的图标
                  text: '正在快进......',
                ),
              ),
            ),
          ),
        
        // 回顾界面
        if (widget.showReviewOverlay)
          HideableUI(
            child: ReviewOverlay(
              dialogueHistory: widget.gameManager.getDialogueHistory(),
              onClose: widget.onToggleReview,
              onJumpToEntry: widget.onJumpToHistoryEntry,
            ),
          ),
        
        // 存档界面
        if (widget.showSaveOverlay)
          HideableUI(
            child: SaveLoadScreen(
              mode: SaveLoadMode.save,
              gameManager: widget.gameManager,
              onClose: widget.onToggleSave,
            ),
          ),
        
        // 读档界面
        if (widget.showLoadOverlay)
          HideableUI(
            child: SaveLoadScreen(
              mode: SaveLoadMode.load,
              onClose: widget.onToggleLoad,
              onLoadSlot: widget.onLoadGame ?? (saveSlot) {
                // 如果没有回调，使用传统的导航方式（兼容性）
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => GamePlayScreen(saveSlotToLoad: saveSlot),
                  ),
                  (route) => false,
                );
              },
            ),
          ),
        
        // 设置界面
        if (widget.showSettings)
          HideableUI(
            child: SettingsScreen(
              onClose: widget.onToggleSettings,
            ),
          ),
        
        // 开发者面板 (仅Debug模式)
        if (kDebugMode && widget.showDeveloperPanel)
          HideableUI(
            child: DeveloperPanel(
              onClose: widget.onToggleDeveloperPanel,
              gameManager: widget.gameManager,
              onReload: () => widget.gameManager.hotReload(widget.currentScript),
            ),
          ),
        
        // 调试面板 (发行版也可用，方便玩家复制日志)
        if (widget.showDebugPanel)
          HideableUI(
            child: DebugPanelDialog(
              onClose: widget.onToggleDebugPanel,
            ),
          ),
        
        // 表情选择器 (仅Debug模式)
        if (kDebugMode && widget.showExpressionSelector)
          HideableUI(
            child: Builder(
              builder: (context) {
                final speakerInfo = widget.expressionSelectorManager?.getCurrentSpeakerInfo();
                if (speakerInfo == null) {
                  return const SizedBox.shrink();
                }
                return ExpressionSelectorDialog(
                  characterId: speakerInfo.characterId,
                  characterName: speakerInfo.speakerName,
                  currentPose: speakerInfo.currentPose,
                  currentExpression: speakerInfo.currentExpression,
                  currentDialogue: widget.gameManager.currentDialogueText,
                  onSelectionChanged: (pose, expression) {
                    widget.expressionSelectorManager?.handleExpressionSelectionChanged(
                      speakerInfo.characterId,
                      pose,
                      expression,
                    );
                  },
                  onClose: widget.onToggleExpressionSelector,
                );
              },
            ),
          ),
        
        // 通知覆盖层
        HideableUI(
          child: NotificationOverlay(
            key: _notificationOverlayKey,
            scale: context.scaleFor(ComponentType.ui),
          ),
        ),
      ],
    );
  }

  /// 显示通知消息
  void showNotification(String message) {
    _notificationOverlayKey.currentState?.show(message);
  }
}