import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:sakiengine/src/config/asset_manager.dart';
import 'package:sakiengine/src/config/config_models.dart';
import 'package:sakiengine/src/game/game_manager.dart';
import 'package:sakiengine/src/utils/binary_serializer.dart';
import 'package:sakiengine/src/screens/save_load_screen.dart';
import 'package:sakiengine/src/sks_parser/sks_ast.dart';
import 'package:sakiengine/src/widgets/choice_menu.dart';
import 'package:sakiengine/src/widgets/dialogue_box.dart';
import 'package:sakiengine/src/widgets/quick_menu.dart';
import 'package:sakiengine/src/screens/review_screen.dart';
import 'package:sakiengine/src/screens/main_menu_screen.dart';
import 'package:sakiengine/src/widgets/common/exit_confirmation_dialog.dart';
import 'package:sakiengine/src/widgets/confirm_dialog.dart';
import 'package:sakiengine/src/widgets/common/notification_overlay.dart';
import 'package:sakiengine/src/utils/image_loader.dart';
import 'package:sakiengine/src/widgets/nvl_screen.dart';
import 'package:sakiengine/src/utils/scaling_manager.dart';
import 'package:sakiengine/src/widgets/common/black_screen_transition.dart';
import 'package:sakiengine/src/widgets/settings_screen.dart';
import 'package:sakiengine/src/utils/dialogue_progression_manager.dart';
import 'package:sakiengine/src/rendering/color_background_renderer.dart';
import 'package:sakiengine/src/effects/scene_filter.dart';
import 'package:sakiengine/src/config/project_info_manager.dart';
import 'package:sakiengine/src/utils/character_layer_parser.dart';
import 'package:sakiengine/soranouta/widgets/soranouta_dialogue_box.dart';
import 'package:sakiengine/src/rendering/scene_layer.dart';
import 'package:sakiengine/src/widgets/developer_panel.dart';
import 'package:sakiengine/src/utils/character_auto_distribution.dart';
import 'package:sakiengine/src/widgets/expression_selector_dialog.dart';
import 'package:sakiengine/src/utils/expression_selector_manager.dart';

class GamePlayScreen extends StatefulWidget {
  final SaveSlot? saveSlotToLoad;
  final VoidCallback? onReturnToMenu;
  final Function(SaveSlot)? onLoadGame;

  const GamePlayScreen({
    super.key,
    this.saveSlotToLoad,
    this.onReturnToMenu,
    this.onLoadGame,
  });

  @override
  State<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends State<GamePlayScreen> with TickerProviderStateMixin {
  late final GameManager _gameManager;
  late final DialogueProgressionManager _dialogueProgressionManager;
  final _notificationOverlayKey = GlobalKey<NotificationOverlayState>();
  String _currentScript = 'start'; 
  bool _showReviewOverlay = false;
  bool _showSaveOverlay = false;
  bool _showLoadOverlay = false;
  bool _showSettings = false;
  bool _isShowingMenu = false;
  bool _showDeveloperPanel = false; // 开发者面板显示状态
  bool _showExpressionSelector = false; // 表情选择器显示状态
  HotKey? _reloadHotKey;
  HotKey? _developerPanelHotKey; // Shift+D快捷键
  ExpressionSelectorManager? _expressionSelectorManager; // 表情选择器管理器
  String? _projectName;
  final GlobalKey _nvlScreenKey = GlobalKey();
  
  // 跟踪上一次的NVL状态，用于检测转场
  bool _previousIsNvlMode = false;
  bool _previousIsNvlMovieMode = false;

  @override
  void initState() {
    super.initState();
    _gameManager = GameManager(
      onReturn: _returnToMainMenu,
    );
    
    // 初始化对话推进管理器
    _dialogueProgressionManager = DialogueProgressionManager(
      gameManager: _gameManager,
    );

    // 获取项目名称
    _loadProjectName();

    // 注册系统级热键 Shift+R
    _setupHotkey();
    
    // 初始化表情选择器管理器（仅在Debug模式下）
    if (kDebugMode) {
      _setupExpressionSelectorManager();
    }

    if (widget.saveSlotToLoad != null) {
      _currentScript = widget.saveSlotToLoad!.currentScript;
      //print('🎮 读取存档: currentScript = $_currentScript');
      //print('🎮 存档中的scriptIndex = ${widget.saveSlotToLoad!.snapshot.scriptIndex}');
      _gameManager.restoreFromSnapshot(
          _currentScript, widget.saveSlotToLoad!.snapshot, shouldReExecute: false);
      
      // 延迟显示读档成功通知，确保UI已经构建完成
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showNotificationMessage('读档成功');
        // 设置context用于转场效果
        _gameManager.setContext(context, this as TickerProvider);
      });
    } else {
      _gameManager.startGame(_currentScript);
      // 延迟设置context，确保组件已mounted
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _gameManager.setContext(context, this as TickerProvider);
      });
    }
  }

  Future<void> _loadProjectName() async {
    try {
      _projectName = await ProjectInfoManager().getAppName();
      if (mounted) setState(() {});
    } catch (e) {
      _projectName = 'SakiEngine';
    }
  }

  void _returnToMainMenu() {
    // 停止所有音效，保留音乐
    _gameManager.stopAllSounds();
    
    if (mounted && widget.onReturnToMenu != null) {
      widget.onReturnToMenu!();
    } else if (mounted) {
      // 兼容性后退方案：使用传统的页面导航
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => MainMenuScreen(
            onNewGame: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const GamePlayScreen()),
            ),
            onLoadGame: () => setState(() => _showLoadOverlay = true),
          ),
        ),
        (Route<dynamic> route) => false,
      );
    }
  }

  Future<void> _initializeModule() async {
    // 移除模块系统 - 直接加载项目名称即可
  }

  Widget _createDialogueBox({
    Key? key,
    String? speaker,
    required String dialogue,
  }) {
    // 根据项目名称选择对话框
    if (_projectName == 'SoraNoUta') {
      return SoranoUtaDialogueBox(
        key: key,
        speaker: speaker,
        dialogue: dialogue,
        progressionManager: _dialogueProgressionManager,
      );
    }
    
    // 默认对话框
    return DialogueBox(
      key: key,
      speaker: speaker,
      dialogue: dialogue,
      progressionManager: _dialogueProgressionManager,
    );
  }

  void _handleQuickMenuBack() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ConfirmDialog(
          title: '返回主菜单',
          content: '确定要返回主菜单吗？未保存的游戏进度将会丢失。',
          onConfirm: _returnToMainMenu,
        );
      },
    );
  }

  void _handlePreviousDialogue() {
    final history = _gameManager.getDialogueHistory();
    
    // 如果当前显示选项，回到最后一句对话（选项出现前的对话）
    if (_isShowingMenu) {
      if (history.isNotEmpty) {
        final lastEntry = history.last;
        _jumpToHistoryEntryQuiet(lastEntry);
      }
    } 
    // 如果没有选项，正常回到上一句
    else if (history.length >= 2) {
      final previousEntry = history[history.length - 2];
      _jumpToHistoryEntryQuiet(previousEntry);
    }
  }

  @override
  void dispose() {
    // 取消注册系统热键
    if (_reloadHotKey != null) {
      hotKeyManager.unregister(_reloadHotKey!);
    }
    // 取消注册开发者面板热键
    if (_developerPanelHotKey != null) {
      hotKeyManager.unregister(_developerPanelHotKey!);
    }
    // 清理表情选择器管理器
    _expressionSelectorManager?.dispose();
    
    _gameManager.dispose();
    super.dispose();
  }

  // 设置系统级热键
  Future<void> _setupHotkey() async {
    _reloadHotKey = HotKey(
      key: PhysicalKeyboardKey.keyR,
      modifiers: [HotKeyModifier.shift],
      scope: HotKeyScope.inapp, // 先使用应用内热键，避免权限问题
    );
    
    try {
      await hotKeyManager.register(
        _reloadHotKey!,
        keyDownHandler: (hotKey) {
          print('热键触发: ${hotKey.toJson()}');
          if (mounted) {
            _handleHotReload();
          }
        },
      );
      print('快捷键 Shift+R 注册成功');
    } catch (e) {
      print('快捷键注册失败: $e');
      // 如果系统级热键失败，尝试应用内热键
      _reloadHotKey = HotKey(
        key: PhysicalKeyboardKey.keyR,
        modifiers: [HotKeyModifier.shift],
        scope: HotKeyScope.inapp,
      );
      try {
        await hotKeyManager.register(
          _reloadHotKey!,
          keyDownHandler: (hotKey) {
            print('应用内热键触发: ${hotKey.toJson()}');
            if (mounted) {
              _handleHotReload();
            }
          },
        );
        print('应用内快捷键 Shift+R 注册成功');
      } catch (e2) {
        print('应用内快捷键注册也失败: $e2');
      }
    }

    // 注册开发者面板快捷键 Shift+D (仅在Debug模式下)
    if (kDebugMode) {
      _developerPanelHotKey = HotKey(
        key: PhysicalKeyboardKey.keyD,
        modifiers: [HotKeyModifier.shift],
        scope: HotKeyScope.inapp,
      );
      
      try {
        await hotKeyManager.register(
          _developerPanelHotKey!,
          keyDownHandler: (hotKey) {
            print('开发者面板热键触发: ${hotKey.toJson()}');
            if (mounted) {
              setState(() {
                _showDeveloperPanel = !_showDeveloperPanel;
              });
            }
          },
        );
        print('快捷键 Shift+D 注册成功 (开发者面板)');
      } catch (e) {
        print('开发者面板快捷键注册失败: $e');
      }
    }

    // 添加箭头键支持（替代滚轮）
    try {
      final nextHotKey = HotKey(
        key: PhysicalKeyboardKey.arrowDown,
        scope: HotKeyScope.inapp,
      );
      
      final prevHotKey = HotKey(
        key: PhysicalKeyboardKey.arrowUp,
        scope: HotKeyScope.inapp,
      );

      await hotKeyManager.register(
        nextHotKey,
        keyDownHandler: (hotKey) {
          //print('🎮 下箭头键 - 前进剧情');
          if (mounted && !_isShowingMenu) {
            _dialogueProgressionManager.progressDialogue();
          }
        },
      );

      await hotKeyManager.register(
        prevHotKey,
        keyDownHandler: (hotKey) {
          //print('🎮 上箭头键 - 回滚剧情');
          if (mounted) {
            _handlePreviousDialogue();
          }
        },
      );
      
      print('箭头键快捷键注册成功');
    } catch (e) {
      print('箭头键快捷键注册失败: $e');
    }
  }

  // 设置表情选择器管理器（Debug模式下的表情选择功能）
  void _setupExpressionSelectorManager() {
    _expressionSelectorManager = ExpressionSelectorManager(
      gameManager: _gameManager,
      showNotificationCallback: _showNotificationMessage,
      triggerReloadCallback: _handleHotReload,
      getCurrentGameState: () {
        // 获取当前游戏状态
        return _gameManager.currentState;
      },
      setExpressionSelectorVisibility: (show) {
        if (mounted) {
          // 检查是否可以显示表情选择器
          final canShow = show && _expressionSelectorManager!.canShowExpressionSelector(
            showSaveOverlay: _showSaveOverlay,
            showLoadOverlay: _showLoadOverlay,
            showReviewOverlay: _showReviewOverlay,
            showSettings: _showSettings,
            showDeveloperPanel: _showDeveloperPanel,
            isShowingMenu: _isShowingMenu,
          );
          
          setState(() {
            _showExpressionSelector = canShow;
          });
          
          _expressionSelectorManager!.setExpressionSelectorVisible(canShow);
        }
      },
    );
    
    _expressionSelectorManager!.initialize();
  }

  // 显示通知消息
  void _showNotificationMessage(String message) {
    _notificationOverlayKey.currentState?.show(message);
  }

  Future<void> _handleHotReload() async {
    await _gameManager.hotReload(_currentScript);
    _showNotificationMessage('重载完成');
  }

  Future<void> _jumpToHistoryEntry(DialogueHistoryEntry entry) async {
    setState(() => _showReviewOverlay = false);
    await _gameManager.jumpToHistoryEntry(entry, _currentScript);
    _showNotificationMessage('跳转成功');
  }

  Future<void> _jumpToHistoryEntryQuiet(DialogueHistoryEntry entry) async {
    await _gameManager.jumpToHistoryEntry(entry, _currentScript);
  }

  Future<bool> _onWillPop() async {
    return await ExitConfirmationDialog.showExitConfirmation(context, hasProgress: true);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (!didPop) {
          final shouldExit = await _onWillPop();
          if (shouldExit && mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Focus(
        autofocus: false,
        child: Scaffold(
          body: StreamBuilder<GameState>(
          stream: _gameManager.gameStateStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final gameState = snapshot.data!;
            
            // 检测从电影模式退出，播放退出动画
            if (_previousIsNvlMode && _previousIsNvlMovieMode && 
                (!gameState.isNvlMode || !gameState.isNvlMovieMode)) {
              // 即将从电影模式退出，播放黑边退出动画
              final state = _nvlScreenKey.currentState as NvlScreenController?;
              state?.playMovieModeExitAnimation();
            }
            
            // 更新状态跟踪
            _previousIsNvlMode = gameState.isNvlMode;
            _previousIsNvlMovieMode = gameState.isNvlMovieMode;
            
            // 更新选项显示状态
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _isShowingMenu = gameState.currentNode is MenuNode;
                });
              }
            });
            
            return Listener(
              onPointerSignal: (pointerSignal) {
                // 检查是否有弹窗或菜单显示
                final hasOverlayOpen = _isShowingMenu || 
                    _showSaveOverlay || 
                    _showLoadOverlay || 
                    _showReviewOverlay ||
                    _showSettings ||
                    _showDeveloperPanel || // 添加开发者面板检查
                    _showExpressionSelector; // 添加表情选择器检查
                
                // 处理标准的PointerScrollEvent（鼠标滚轮）
                if (pointerSignal is PointerScrollEvent) {
                  // 向上滚动: 前进剧情
                  if (pointerSignal.scrollDelta.dy < 0) {
                    if (!hasOverlayOpen) {
                      _dialogueProgressionManager.progressDialogue();
                    }
                  }
                  // 向下滚动: 回滚剧情
                  else if (pointerSignal.scrollDelta.dy > 0) {
                    if (!hasOverlayOpen) {
                      _handlePreviousDialogue();
                    }
                  }
                }
                // 处理macOS触控板事件
                else if (pointerSignal.toString().contains('Scroll')) {
                  // 触控板滚动事件，推进剧情
                  if (!hasOverlayOpen) {
                    _dialogueProgressionManager.progressDialogue();
                  }
                }
              },
              child: Stack(
              children: [
                GestureDetector(
                  onTap: (gameState.currentNode is MenuNode || _showDeveloperPanel) ? null : () {
                    _dialogueProgressionManager.progressDialogue();
                  },
                  child: _buildSceneWithFilter(gameState),
                ),
                // NVL 模式覆盖层 - 使用 AnimatedSwitcher 添加过渡动画
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400), // 从800ms加快到400ms
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    // 电影模式和普通旁白模式都只使用淡入淡出，不再有上移动画
                    return FadeTransition(
                      opacity: animation,
                      child: child,
                    );
                  },
                  child: gameState.isNvlMode
                      ? NvlScreen(
                          key: _nvlScreenKey,
                          nvlDialogues: gameState.nvlDialogues,
                          isMovieMode: gameState.isNvlMovieMode,
                          progressionManager: _dialogueProgressionManager,
                        )
                      : const SizedBox.shrink(key: ValueKey('no_nvl')),
                ),
                QuickMenu(
                  onSave: () => setState(() => _showSaveOverlay = true),
                  onLoad: () => setState(() => _showLoadOverlay = true),
                  onReview: () => setState(() => _showReviewOverlay = true),
                  onSettings: () => setState(() => _showSettings = true),
                  onBack: _handleQuickMenuBack,
                  onPreviousDialogue: _handlePreviousDialogue,
                ),
                if (_showReviewOverlay)
                  ReviewOverlay(
                    dialogueHistory: _gameManager.getDialogueHistory(),
                    onClose: () => setState(() => _showReviewOverlay = false),
                    onJumpToEntry: _jumpToHistoryEntry,
                  ),
                if (_showSaveOverlay)
                  SaveLoadScreen(
                    mode: SaveLoadMode.save,
                    gameManager: _gameManager,
                    onClose: () => setState(() => _showSaveOverlay = false),
                  ),
                if (_showLoadOverlay)
                  SaveLoadScreen(
                    mode: SaveLoadMode.load,
                    onClose: () => setState(() => _showLoadOverlay = false),
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
                if (_showSettings)
                  SettingsScreen(
                    onClose: () => setState(() => _showSettings = false),
                  ),
                // 开发者面板 (仅Debug模式)
                if (kDebugMode && _showDeveloperPanel)
                  DeveloperPanel(
                    onClose: () => setState(() => _showDeveloperPanel = false),
                    gameManager: _gameManager,
                    onReload: () => _gameManager.hotReload(_currentScript),
                  ),
                // 表情选择器 (仅Debug模式)
                if (kDebugMode && _showExpressionSelector)
                  Builder(
                    builder: (context) {
                      final speakerInfo = _expressionSelectorManager?.getCurrentSpeakerInfo();
                      if (speakerInfo == null) {
                        return const SizedBox.shrink();
                      }
                      return ExpressionSelectorDialog(
                        characterId: speakerInfo.characterId,
                        characterName: speakerInfo.speakerName,
                        currentPose: speakerInfo.currentPose,
                        currentExpression: speakerInfo.currentExpression,
                        onSelectionChanged: (pose, expression) {
                          _expressionSelectorManager?.handleExpressionSelectionChanged(
                            speakerInfo.characterId,
                            pose,
                            expression,
                          );
                        },
                        onClose: () => setState(() => _showExpressionSelector = false),
                      );
                    },
                  ),
                NotificationOverlay(
                  key: _notificationOverlayKey,
                  scale: context.scaleFor(ComponentType.ui),
                ),
              ],
            ),
            );
          },
        ),
        ),
      ),
    );
  }

  // 淡出动画完成后移除角色
  void _removeCharacterAfterFadeOut(String characterId) {
    _gameManager.removeCharacterAfterFadeOut(characterId);
  }

  Widget _buildSceneWithFilter(GameState gameState) {
    return Stack(
      children: [
        if (gameState.background != null)
          _buildBackground(gameState.background!, gameState.sceneFilter, gameState.sceneLayers, gameState.sceneAnimationProperties),
        ..._buildCharacters(context, gameState.characters, _gameManager.poseConfigs, gameState.everShownCharacters),
        // 使用 AnimatedSwitcher 为对话框切换添加过渡动画
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
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
          child: gameState.dialogue != null && !gameState.isNvlMode
              ? _createDialogueBox(
                  key: const ValueKey('normal_dialogue'),
                  speaker: gameState.speaker,
                  dialogue: gameState.dialogue!,
                )
              : const SizedBox.shrink(key: ValueKey('no_dialogue')),
        ),
        if (gameState.currentNode is MenuNode)
          ChoiceMenu(
            menuNode: gameState.currentNode as MenuNode,
            onChoiceSelected: (String targetLabel) {
              _gameManager.jumpToLabel(targetLabel);
            },
          ),
      ],
    );
  }

  /// 构建背景Widget - 支持图片背景和十六进制颜色背景，以及多图层场景和动画
  Widget _buildBackground(String background, [SceneFilter? sceneFilter, List<String>? sceneLayers, Map<String, double>? animationProperties]) {
    Widget backgroundWidget;
    
    // 如果有多图层数据，使用多图层渲染器
    if (sceneLayers != null && sceneLayers.isNotEmpty) {
      final layers = sceneLayers.map((layerString) => SceneLayer.fromString(layerString))
          .where((layer) => layer != null)
          .cast<SceneLayer>()
          .toList();
      
      if (layers.isNotEmpty) {
        backgroundWidget = MultiLayerRenderer.buildMultiLayerScene(
          layers: layers,
          screenSize: MediaQuery.of(context).size,
        );
      } else {
        backgroundWidget = Container(color: Colors.black);
      }
    } else {
      // 单图层模式（原有逻辑）
      // 检查是否为十六进制颜色格式
      if (ColorBackgroundRenderer.isValidHexColor(background)) {
        backgroundWidget = ColorBackgroundRenderer.createColorBackgroundWidget(background);
      } else {
        // 处理图片背景
        backgroundWidget = FutureBuilder<String?>(
          key: ValueKey('bg_$background'), // 添加key避免重建
          future: AssetManager().findAsset('backgrounds/${background.replaceAll(' ', '-')}'),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              return Image.asset(
                snapshot.data!,
                key: ValueKey(snapshot.data!), // 为图片添加key
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  // 如果是同步加载（已缓存），直接显示
                  if (wasSynchronouslyLoaded ?? false) {
                    return child;
                  }
                  // 异步加载时，只在完全加载后显示，避免闪烁
                  return frame != null ? child : Container(color: Colors.black);
                },
              );
            }
            return Container(color: Colors.black);
          },
        );
      }
    }
    
    // 始终应用动画变换以避免Widget结构变化导致的闪烁
    backgroundWidget = Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..translate(
          ((animationProperties?['xcenter'] ?? 0.0)) * MediaQuery.of(context).size.width,
          ((animationProperties?['ycenter'] ?? 0.0)) * MediaQuery.of(context).size.height,
        )
        ..scale((animationProperties?['scale'] ?? 1.0))
        ..rotateZ((animationProperties?['rotation'] ?? 0.0)),
      child: Opacity(
        opacity: ((animationProperties?['alpha'] ?? 1.0)).clamp(0.0, 1.0),
        child: backgroundWidget,
      ),
    );
    
    // 应用场景滤镜
    if (sceneFilter != null) {
      backgroundWidget = _FilteredBackground(
        filter: sceneFilter,
        child: backgroundWidget,
      );
    }
    
    return backgroundWidget;
  }

  List<Widget> _buildCharacters(BuildContext context, Map<String, CharacterState> characters, Map<String, PoseConfig> poseConfigs, Set<String> everShownCharacters) {
    // 应用自动分布逻辑
    final characterOrder = characters.keys.toList();
    final distributedPoseConfigs = CharacterAutoDistribution.calculateAutoDistribution(
      characters,
      poseConfigs,
      characterOrder,
    );
    
    // 按resourceId分组，保留最新的角色状态
    final Map<String, MapEntry<String, CharacterState>> charactersByResourceId = {};
    
    for (final entry in characters.entries) {
      final resourceId = entry.value.resourceId;
      // 总是保留最新的状态（覆盖之前的）
      charactersByResourceId[resourceId] = entry;
    }
    
    return charactersByResourceId.values.map((entry) {
      final characterId = entry.key;
      final characterState = entry.value;
      // 使用分布后的pose配置
      // 优先查找角色专属的自动分布配置，如果没有则使用原始配置
      final autoDistributedPoseId = '${characterId}_auto_distributed';
      final poseConfig = distributedPoseConfigs[autoDistributedPoseId] ?? 
                        distributedPoseConfigs[characterState.positionId] ?? 
                        PoseConfig(id: 'default');

      // 使用resourceId作为key，确保唯一性
      final widgetKey = '${characterState.resourceId}';
      final cacheKey = '$characterId:${characterState.resourceId}:${characterState.pose ?? 'pose1'}:${characterState.expression ?? 'happy'}';
      
      return FutureBuilder<List<CharacterLayerInfo>>(
        key: ValueKey(widgetKey), // 使用resourceId作为key
        future: CharacterLayerParser.parseCharacterLayers(
          resourceId: characterState.resourceId,
          pose: characterState.pose ?? 'pose1',
          expression: characterState.expression ?? 'happy',
        ),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox.shrink();
          }

          final layerInfos = snapshot.data!;

          // 根据解析结果创建图层组件，使用resourceId和图层类型作为key，保持差分动画
          final layers = layerInfos.map((layerInfo) {
            return _CharacterLayer(
              key: ValueKey('${characterState.resourceId}-${layerInfo.layerType}'),
              assetName: layerInfo.assetName,
              isFadingOut: characterState.isFadingOut,
              onFadeOutComplete: characterState.isFadingOut ? () {
                // 淡出完成，从角色列表中移除该角色
                _removeCharacterAfterFadeOut(characterId);
              } : null,
            );
          }).toList();
          
          final characterStack = Stack(children: layers);
          
          Widget finalWidget = characterStack;
          
          // 获取动画属性
          final animProps = characterState.animationProperties;
          double finalXCenter = poseConfig.xcenter;
          double finalYCenter = poseConfig.ycenter;
          double finalScale = poseConfig.scale;
          double alpha = 1.0;
          
          if (animProps != null) {
            finalXCenter = animProps['xcenter'] ?? finalXCenter;
            finalYCenter = animProps['ycenter'] ?? finalYCenter;
            finalScale = animProps['scale'] ?? finalScale;
            alpha = animProps['alpha'] ?? alpha;
          }
          
          if (finalScale > 0) {
            finalWidget = SizedBox(
              height: MediaQuery.of(context).size.height * finalScale,
              child: characterStack,
            );
          }
          
          // 应用透明度
          if (alpha < 1.0) {
            finalWidget = Opacity(
              opacity: alpha,
              child: finalWidget,
            );
          }

          return Positioned(
            key: ValueKey('positioned-$widgetKey'), // 使用resourceId作为key
            left: finalXCenter * MediaQuery.of(context).size.width,
            top: finalYCenter * MediaQuery.of(context).size.height,
            child: FractionalTranslation(
              translation: _anchorToTranslation(poseConfig.anchor),
              child: finalWidget,
            ),
          );
        },
      );
    }).toList();
  }

  Offset _anchorToTranslation(String anchor) {
    switch (anchor) {
      case 'topCenter': return const Offset(-0.5, 0);
      case 'bottomCenter': return const Offset(-0.5, -1.0);
      case 'centerLeft': return const Offset(0, -0.5);
      case 'centerRight': return const Offset(-1.0, -0.5);
      case 'center':
      default:
        return const Offset(-0.5, -0.5);
    }
  }
}

class _CharacterLayer extends StatefulWidget {
  final String assetName;
  final bool isFadingOut;
  final VoidCallback? onFadeOutComplete;
  
  const _CharacterLayer({
    super.key, 
    required this.assetName,
    this.isFadingOut = false,
    this.onFadeOutComplete,
  });

  @override
  State<_CharacterLayer> createState() => _CharacterLayerState();
}

class _CharacterLayerState extends State<_CharacterLayer>
    with SingleTickerProviderStateMixin {
  ui.Image? _currentImage;
  ui.Image? _previousImage;

  late final AnimationController _controller;
  late final Animation<double> _animation;

  static ui.FragmentProgram? _dissolveProgram;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);

    _loadImage();
    _loadShader();
  }

  Future<void> _loadShader() async {
    if (_dissolveProgram == null) {
      try {
        final program = await ui.FragmentProgram.fromAsset('assets/shaders/dissolve.frag');
        _dissolveProgram = program;
      } catch (e) {
        print('Error loading shader: $e');
      }
    }
  }

  @override
  void didUpdateWidget(covariant _CharacterLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 检查是否开始淡出
    if (!oldWidget.isFadingOut && widget.isFadingOut) {
      // 开始淡出动画
      _controller.reverse().then((_) {
        // 淡出完成，通知回调
        widget.onFadeOutComplete?.call();
      });
      return;
    }
    
    if (oldWidget.assetName != widget.assetName) {
      _previousImage = _currentImage;
      _loadImage().then((_) {
        if (mounted) {
          _controller.forward(from: 0.0);
        }
      });
    }
  }

  Future<void> _loadImage() async {
    final assetPath = await AssetManager().findAsset(widget.assetName);
    if (assetPath != null && mounted) {
      final image = await ImageLoader.loadImage(assetPath);
      if (mounted && image != null) {
        setState(() {
          _currentImage = image;
        });
        
        // 始终触发动画
        _controller.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _currentImage?.dispose();
    _previousImage?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentImage == null || _dissolveProgram == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final imageSize = Size(_currentImage!.width.toDouble(), _currentImage!.height.toDouble());
            
            // 确定绘制尺寸
            Size paintSize;
            if (!constraints.hasBoundedHeight) {
              paintSize = imageSize;
            } else {
              final imageAspectRatio = imageSize.width / imageSize.height;
              final paintHeight = constraints.maxHeight;
              final paintWidth = paintHeight * imageAspectRatio;
              paintSize = Size(paintWidth, paintHeight);
            }
            
            return CustomPaint(
              size: paintSize,
              painter: _DissolvePainter(
                program: _dissolveProgram!,
                progress: _animation.value,
                imageFrom: _previousImage ?? _currentImage!, // 没有previousImage时用当前图片，shader会处理透明
                imageTo: _currentImage!,
              ),
            );
          },
        );
      },
    );
  }
}

class _DissolvePainter extends CustomPainter {
  final ui.FragmentProgram program;
  final double progress;
  final ui.Image imageFrom;
  final ui.Image imageTo;

  _DissolvePainter({
    required this.program,
    required this.progress,
    required this.imageFrom,
    required this.imageTo,
  });

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    try {
      // 如果没有之前的图片（首次显示），从透明开始
      if (imageFrom == imageTo) {
        // 首次显示：简单的透明度渐变
        final paint = ui.Paint()
          ..color = Colors.white.withOpacity(progress)
          ..isAntiAlias = true
          ..filterQuality = FilterQuality.high;
        
        canvas.drawImageRect(
          imageTo,
          ui.Rect.fromLTWH(0, 0, imageTo.width.toDouble(), imageTo.height.toDouble()),
          ui.Rect.fromLTWH(0, 0, size.width, size.height),
          paint,
        );
        return;
      }

      // 差分切换：使用dissolve效果
      final shader = program.fragmentShader();
      shader
        ..setFloat(0, progress)
        ..setFloat(1, size.width)
        ..setFloat(2, size.height)
        ..setFloat(3, imageFrom.width.toDouble())
        ..setFloat(4, imageFrom.height.toDouble())
        ..setFloat(5, imageTo.width.toDouble())
        ..setFloat(6, imageTo.height.toDouble())
        ..setImageSampler(0, imageFrom)
        ..setImageSampler(1, imageTo);

      final paint = ui.Paint()
        ..shader = shader
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high;
      canvas.drawRect(ui.Rect.fromLTWH(0, 0, size.width, size.height), paint);
    } catch (e) {
      print("Error painting dissolve shader: $e");
    }
  }

  @override
  bool shouldRepaint(covariant _DissolvePainter oldDelegate) {
    return progress != oldDelegate.progress ||
        imageFrom != oldDelegate.imageFrom ||
        imageTo != oldDelegate.imageTo;
  }
}

class _FilteredBackground extends StatefulWidget {
  final SceneFilter filter;
  final Widget child;
  
  const _FilteredBackground({
    required this.filter,
    required this.child,
  });

  @override
  State<_FilteredBackground> createState() => _FilteredBackgroundState();
}

class _FilteredBackgroundState extends State<_FilteredBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: (widget.filter.duration * 1000).round()),
      vsync: this,
    );
    
    if (widget.filter.animation != AnimationType.none) {
      _animationController.repeat();
    }
  }

  @override
  void didUpdateWidget(_FilteredBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter != widget.filter) {
      _animationController.duration = Duration(milliseconds: (widget.filter.duration * 1000).round());
      if (widget.filter.animation != AnimationType.none) {
        _animationController.repeat();
      } else {
        _animationController.stop();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FilterRenderer.applyFilter(
      child: widget.child,
      filter: widget.filter,
      animationController: _animationController,
    );
  }
}
