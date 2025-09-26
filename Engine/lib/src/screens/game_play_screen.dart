import 'dart:async';
import 'dart:ui' as ui;
import 'dart:io';

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
import 'package:sakiengine/src/widgets/smart_image.dart';
import 'package:sakiengine/src/screens/review_screen.dart';
import 'package:sakiengine/src/screens/main_menu_screen.dart';
import 'package:sakiengine/src/widgets/common/exit_confirmation_dialog.dart';
import 'package:sakiengine/src/rendering/cg_character_renderer.dart';
import 'package:sakiengine/src/rendering/composite_cg_renderer.dart';
import 'package:sakiengine/src/rendering/rendering_system_integration.dart';
import 'package:sakiengine/src/widgets/confirm_dialog.dart';
import 'package:sakiengine/src/widgets/common/notification_overlay.dart';
import 'package:sakiengine/src/utils/image_loader.dart';
import 'package:sakiengine/src/widgets/nvl_screen.dart';
import 'package:sakiengine/src/utils/scaling_manager.dart';
import 'package:sakiengine/src/widgets/common/black_screen_transition.dart';
import 'package:sakiengine/src/widgets/settings_screen.dart';
import 'package:sakiengine/src/utils/dialogue_progression_manager.dart';
import 'package:sakiengine/src/utils/smart_asset_image.dart';
import 'package:sakiengine/src/rendering/color_background_renderer.dart';
import 'package:sakiengine/src/effects/scene_filter.dart';
import 'package:sakiengine/src/config/project_info_manager.dart';
import 'package:sakiengine/src/utils/character_layer_parser.dart';
import 'package:sakiengine/soranouta/widgets/soranouta_dialogue_box.dart';
import 'package:sakiengine/src/rendering/scene_layer.dart';
import 'package:sakiengine/src/widgets/developer_panel.dart';
import 'package:sakiengine/src/widgets/debug_panel_dialog.dart';
import 'package:sakiengine/src/utils/character_auto_distribution.dart';
import 'package:sakiengine/src/widgets/expression_selector_dialog.dart';
import 'package:sakiengine/src/utils/expression_selector_manager.dart';
import 'package:sakiengine/src/utils/expression_offset_manager.dart';
import 'package:sakiengine/src/utils/key_sequence_detector.dart';
import 'package:sakiengine/src/widgets/common/right_click_ui_manager.dart';
import 'package:sakiengine/src/widgets/common/game_ui_layer.dart';
import 'package:sakiengine/src/utils/fast_forward_manager.dart';
import 'package:sakiengine/src/utils/auto_play_manager.dart'; // 新增：自动播放管理器
import 'package:sakiengine/src/utils/read_text_tracker.dart';
import 'package:sakiengine/src/utils/read_text_skip_manager.dart';
import 'package:sakiengine/src/utils/settings_manager.dart';
import 'package:sakiengine/src/widgets/movie_player.dart'; // 新增：视频播放器导入
import 'package:sakiengine/src/utils/dialogue_shake_effect.dart'; // 新增：震动效果导入

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
  final _gameUILayerKey = GlobalKey<GameUILayerState>();
  String _currentScript = 'start'; 
  bool _showReviewOverlay = false;
  bool _showSaveOverlay = false;
  bool _showLoadOverlay = false;
  bool _showSettings = false;
  bool _isShowingMenu = false;
  bool _showDeveloperPanel = false; // 开发者面板显示状态
  bool _showDebugPanel = false; // 调试面板显示状态
  bool _showExpressionSelector = false; // 表情选择器显示状态
  HotKey? _reloadHotKey;
  HotKey? _developerPanelHotKey; // Shift+D快捷键
  KeySequenceDetector? _consoleSequenceDetector; // console序列检测器
  ExpressionSelectorManager? _expressionSelectorManager; // 表情选择器管理器
  FastForwardManager? _fastForwardManager; // 快进管理器
  AutoPlayManager? _autoPlayManager; // 新增：自动播放管理器
  ReadTextSkipManager? _readTextSkipManager; // 已读文本快进管理器
  String? _projectName;
  final GlobalKey _nvlScreenKey = GlobalKey();
  
  // 跟踪上一次的NVL状态，用于检测转场
  bool _previousIsNvlMode = false;
  bool _previousIsNvlMovieMode = false;
  
  // 快进状态
  bool _isFastForwarding = false;
  
  // 自动播放状态
  bool _isAutoPlaying = false;
  
  // 加载淡出动画控制
  late AnimationController _loadingFadeController;
  late Animation<double> _loadingFadeAnimation;
  bool _isInitialLoading = true;

  @override
  void initState() {
    super.initState();
    
    // 初始化加载淡出动画
    _loadingFadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _loadingFadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _loadingFadeController,
      curve: Curves.easeOut,
    ));
    
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
    
    // 初始化console序列检测器（发行版也可用，方便玩家复制日志）
    _setupConsoleSequenceDetector();
    
    // 初始化快进管理器
    _setupFastForwardManager();
    
    // 初始化自动播放管理器
    _setupAutoPlayManager();
    
    // 初始化已读文本跟踪器和已读文本快进管理器
    _setupReadTextTracking();

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
    String? speakerAlias, // 新增：角色简写参数
    required String dialogue,
    required bool isFastForwarding, // 新增快进状态参数
    required int scriptIndex, // 新增脚本索引参数
  }) {
    // 不在这里标记为已读！应该在用户推进对话时才标记
    
    // 根据项目名称选择对话框
    if (_projectName == 'SoraNoUta') {
      return SoranoUtaDialogueBox(
        key: key,
        speaker: speaker,
        speakerAlias: speakerAlias, // 传递角色简写
        dialogue: dialogue,
        progressionManager: _dialogueProgressionManager,
        isFastForwarding: isFastForwarding, // 传递快进状态
        scriptIndex: scriptIndex, // 传递脚本索引
      );
    }
    
    // 默认对话框
    return DialogueBox(
      key: key,
      speaker: speaker,
      dialogue: dialogue,
      progressionManager: _dialogueProgressionManager,
      isFastForwarding: isFastForwarding, // 传递快进状态
      scriptIndex: scriptIndex, // 传递脚本索引
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
    // 清理console序列检测器
    _consoleSequenceDetector?.dispose();
    // 清理快进管理器
    _fastForwardManager?.dispose();
    
    // 清理自动播放管理器
    _autoPlayManager?.dispose();
    
    // 清理已读文本快进管理器
    _readTextSkipManager?.dispose();
    
    // 清理加载淡出动画控制器
    _loadingFadeController.dispose();
    
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
          if (mounted && !_isShowingMenu && _gameManager.currentState.movieFile == null) {
            _dialogueProgressionManager.progressDialogue();
          }
        },
      );

      await hotKeyManager.register(
        prevHotKey,
        keyDownHandler: (hotKey) {
          //print('🎮 上箭头键 - 回滚剧情');
          if (mounted && _gameManager.currentState.movieFile == null) {
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
            showDebugPanel: _showDebugPanel,
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

  // 设置console按键序列检测器（发行版也可用，方便玩家复制日志）
  void _setupConsoleSequenceDetector() {
    // 定义 c-o-n-s-o-l-e 按键序列
    final consoleSequence = [
      LogicalKeyboardKey.keyC,
      LogicalKeyboardKey.keyO,
      LogicalKeyboardKey.keyN,
      LogicalKeyboardKey.keyS,
      LogicalKeyboardKey.keyO,
      LogicalKeyboardKey.keyL,
      LogicalKeyboardKey.keyE,
    ];
    
    _consoleSequenceDetector = KeySequenceDetector(
      sequence: consoleSequence,
      onSequenceComplete: () {
        if (mounted) {
          setState(() {
            _showDebugPanel = !_showDebugPanel;
          });
          _showNotificationMessage('调试面板 ${_showDebugPanel ? '开启' : '关闭'}');
        }
      },
      sequenceTimeout: const Duration(seconds: 3),
    );
    
    _consoleSequenceDetector!.startListening();
    
    print('Console按键序列检测器已启动 (c-o-n-s-o-l-e)');
    print('发行版用户可通过连续按下 c-o-n-s-o-l-e 来打开日志面板复制日志');
  }

  // 设置快进管理器
  void _setupFastForwardManager() {
    _fastForwardManager = FastForwardManager(
      dialogueProgressionManager: _dialogueProgressionManager,
      onFastForwardStateChanged: (isFastForwarding) {
        // 使用post frame callback延迟处理，避免在build期间调用setState
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isFastForwarding = isFastForwarding;
            });
          }
        });
      },
      canFastForward: () {
        // 检查是否有弹窗或菜单显示，如果有则不能快进
        final hasOverlayOpen = _isShowingMenu || 
            _showSaveOverlay || 
            _showLoadOverlay || 
            _showReviewOverlay ||
            _showSettings ||
            _showDeveloperPanel || 
            _showDebugPanel || 
            _showExpressionSelector;
        // 禁用在视频播放时的快进功能
        final isPlayingMovie = _gameManager.currentState.movieFile != null;
        return !hasOverlayOpen && !isPlayingMovie;
      },
      setGameManagerFastForward: (isFastForwarding) {
        // 通知GameManager快进状态变化
        _gameManager.setFastForwardMode(isFastForwarding);
      },
    );
    
    _fastForwardManager!.startListening();
    print('快进管理器已初始化 - 按住Ctrl键可快进对话');
  }
  
  // 设置已读文本跟踪
  void _setupReadTextTracking() async {
    // 初始化已读文本跟踪器
    await ReadTextTracker.instance.initialize();
    
    // 初始化已读文本快进管理器
    _readTextSkipManager = ReadTextSkipManager(
      gameManager: _gameManager,
      dialogueProgressionManager: _dialogueProgressionManager,
      readTextTracker: ReadTextTracker.instance,
      onSkipStateChanged: (isSkipping) {
        // 更新UI状态
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isFastForwarding = isSkipping; // 同步快进状态到UI
            });
          }
        });
      },
      canSkip: () {
        // 检查是否有弹窗或菜单显示，如果有则不能快进
        final hasOverlayOpen = _isShowingMenu || 
            _showSaveOverlay || 
            _showLoadOverlay || 
            _showReviewOverlay ||
            _showSettings ||
            _showDeveloperPanel || 
            _showDebugPanel || 
            _showExpressionSelector;
        // 禁用在视频播放时的快进功能
        final isPlayingMovie = _gameManager.currentState.movieFile != null;
        return !hasOverlayOpen && !isPlayingMovie;
      },
    );
    
    print('已读文本跟踪器已初始化 - 快捷菜单中的快进按钮只会跳过已读文本');
  }

  // 设置自动播放管理器
  void _setupAutoPlayManager() {
    _autoPlayManager = AutoPlayManager(
      dialogueProgressionManager: _dialogueProgressionManager,
      onAutoPlayStateChanged: () {
        // 使用post frame callback延迟处理，避免在build期间调用setState
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isAutoPlaying = _autoPlayManager!.isAutoPlaying;
            });
            // 同步到GameManager
            _gameManager.setAutoPlayMode(_isAutoPlaying);
          }
        });
      },
      canAutoPlay: () {
        // 检查是否有弹窗或菜单显示，如果有则不能自动播放
        final hasOverlayOpen = _isShowingMenu || 
            _showSaveOverlay || 
            _showLoadOverlay || 
            _showReviewOverlay ||
            _showSettings ||
            _showDeveloperPanel || 
            _showDebugPanel || 
            _showExpressionSelector ||
            _isFastForwarding; // 快进时不能自动播放
        // 禁用在视频播放时的自动播放功能
        final isPlayingMovie = _gameManager.currentState.movieFile != null;
        return !hasOverlayOpen && !isPlayingMovie;
      },
    );
    
    print('自动播放管理器已初始化');
  }

  // 处理跳过已读文本
  void _handleSkipReadText() async {
    print('🎯 快进按钮被点击');
    
    // 获取快进模式设置
    final fastForwardMode = await SettingsManager().getFastForwardMode();
    print('🎯 当前快进模式: $fastForwardMode');
    
    if (fastForwardMode == 'force') {
      // 强制快进模式：使用FastForwardManager
      print('🎯 使用强制快进模式 - _fastForwardManager: ${_fastForwardManager?.hashCode}');
      _fastForwardManager?.toggleFastForward();
    } else {
      // 快进已读模式：使用ReadTextSkipManager
      print('🎯 使用快进已读模式 - _readTextSkipManager: ${_readTextSkipManager?.hashCode}');
      _readTextSkipManager?.toggleSkipping();
    }
  }

  // 获取当前有效的快进状态
  bool _getCurrentFastForwardState() {
    // 返回任意一个快进管理器的活动状态
    return (_fastForwardManager?.isFastForwarding ?? false) || 
           (_readTextSkipManager?.isSkipping ?? false);
  }

  // 处理自动播放
  void _handleAutoPlay() {
    print('🎯 自动播放按钮被点击 - _autoPlayManager: ${_autoPlayManager?.hashCode}');
    _autoPlayManager?.toggleAutoPlay();
  }

  // 显示通知消息
  void _showNotificationMessage(String message) {
    // 调用GameUILayer的showNotification方法
    _gameUILayerKey.currentState?.showNotification(message);
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
        autofocus: true, // 确保能接收键盘事件
        onKeyEvent: (node, event) {
          // 处理快进键盘事件
          if (_fastForwardManager != null) {
            final handled = _fastForwardManager!.handleKeyEvent(event);
            if (handled) {
              return KeyEventResult.handled;
            }
          }
          
          // 处理回车和空格键推进剧情
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.enter || 
                event.logicalKey == LogicalKeyboardKey.space) {
              // 检查是否正在播放视频，如果是则不推进剧情
              if (_gameManager.currentState.movieFile == null) {
                _gameManager.next();
                // 通知自动播放管理器有手动推进
                _autoPlayManager?.onManualProgress();
              }
              return KeyEventResult.handled;
            }
          }
          
          return KeyEventResult.ignored;
        },
        child: Scaffold(
          backgroundColor: Colors.black, // 添加黑色背景，这样震动时露出的就是黑色
          body: StreamBuilder<GameState>(
          stream: _gameManager.gameStateStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Container(color: Colors.black);
            }
            final gameState = snapshot.data!;
            
            // 首次加载完成，触发淡出动画
            if (_isInitialLoading) {
              _isInitialLoading = false;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _loadingFadeController.forward();
              });
            }
            
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
            
            // 同步快进状态：如果GameManager停止了快进，同步到FastForwardManager和UI
            if (_isFastForwarding && !gameState.isFastForwarding) {
              // 使用post frame callback延迟处理，避免在build中调用setState
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  // 只需要停止FastForwardManager，不需要再次调用forceStopFastForward
                  // 因为GameManager已经处理了状态更新
                  _fastForwardManager?.stopFastForward();
                  setState(() {
                    _isFastForwarding = false;
                  });
                }
              });
            }
            
            // 更新选项显示状态
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                final newIsShowingMenu = gameState.currentNode is MenuNode;
                if (!_isShowingMenu && newIsShowingMenu) {
                  // 选择菜单出现，强制停止自动播放
                  _autoPlayManager?.forceStopOnBlocking();
                }
                setState(() {
                  _isShowingMenu = newIsShowingMenu;
                });
              }
            });
            
            return RightClickUIManager(
              // 背景层 - 不会被隐藏的内容（场景、角色等）
              backgroundChild: Listener(
                onPointerSignal: (pointerSignal) {
                  // 检查是否有弹窗或菜单显示
                  final hasOverlayOpen = _isShowingMenu || 
                      _showSaveOverlay || 
                      _showLoadOverlay || 
                      _showReviewOverlay ||
                      _showSettings ||
                      _showDeveloperPanel || 
                      _showDebugPanel || 
                      _showExpressionSelector;
                  
                  // 检查是否正在播放视频
                  final isPlayingMovie = gameState.movieFile != null;
                  
                  // 处理标准的PointerScrollEvent（鼠标滚轮）
                  if (pointerSignal is PointerScrollEvent) {
                    // 向上滚动: 前进剧情
                    if (pointerSignal.scrollDelta.dy < 0) {
                      if (!hasOverlayOpen && !isPlayingMovie) {
                        _dialogueProgressionManager.progressDialogue();
                      }
                    }
                    // 向下滚动: 回滚剧情
                    else if (pointerSignal.scrollDelta.dy > 0) {
                      if (!hasOverlayOpen && !isPlayingMovie) {
                        _handlePreviousDialogue();
                      }
                    }
                  }
                  // 处理macOS触控板事件
                  else if (pointerSignal.toString().contains('Scroll')) {
                    // 触控板滚动事件，推进剧情
                    if (!hasOverlayOpen && !isPlayingMovie) {
                      _dialogueProgressionManager.progressDialogue();
                    }
                  }
                },
                child: _buildSceneWithFilter(gameState),
              ),
              // 左键点击回调 - 推进剧情
              onLeftClick: () {
                // 检查是否有弹窗或菜单显示
                final hasOverlayOpen = _isShowingMenu || 
                    _showSaveOverlay || 
                    _showLoadOverlay || 
                    _showReviewOverlay ||
                    _showSettings ||
                    _showDeveloperPanel ||
                    _showDebugPanel ||
                    _showExpressionSelector;
                
                // 检查是否正在播放视频
                final isPlayingMovie = gameState.movieFile != null;
                
                // 只有在没有弹窗且没有播放视频时才推进剧情
                if (!hasOverlayOpen && !isPlayingMovie) {
                  _dialogueProgressionManager.progressDialogue();
                  // 通知自动播放管理器有手动推进
                  _autoPlayManager?.onManualProgress();
                }
              },
              // UI层 - 使用GameUILayer组件
              child: Stack(
                children: [
                  GameUILayer(
                    key: _gameUILayerKey,
                    gameState: gameState,
                    gameManager: _gameManager,
                    dialogueProgressionManager: _dialogueProgressionManager,
                    currentScript: _currentScript,
                    nvlScreenKey: _nvlScreenKey,
                    showReviewOverlay: _showReviewOverlay,
                    showSaveOverlay: _showSaveOverlay,
                    showLoadOverlay: _showLoadOverlay,
                    showSettings: _showSettings,
                    showDeveloperPanel: _showDeveloperPanel,
                    showDebugPanel: _showDebugPanel,
                    showExpressionSelector: _showExpressionSelector,
                    isShowingMenu: _isShowingMenu,
                    onToggleReview: () => setState(() => _showReviewOverlay = !_showReviewOverlay),
                    onToggleSave: () => setState(() => _showSaveOverlay = !_showSaveOverlay),
                    onToggleLoad: () => setState(() => _showLoadOverlay = !_showLoadOverlay),
                    onToggleSettings: () => setState(() => _showSettings = !_showSettings),
                    onToggleDeveloperPanel: () => setState(() => _showDeveloperPanel = !_showDeveloperPanel),
                    onToggleDebugPanel: () => setState(() => _showDebugPanel = !_showDebugPanel),
                    onToggleExpressionSelector: () => setState(() => _showExpressionSelector = !_showExpressionSelector),
                    onHandleQuickMenuBack: _handleQuickMenuBack,
                    onHandlePreviousDialogue: _handlePreviousDialogue,
                    onSkipRead: _handleSkipReadText, // 新增：跳过已读文本回调
                    onAutoPlay: _handleAutoPlay, // 新增：自动播放回调
                    onThemeToggle: () => setState(() {}), // 新增：主题切换回调 - 触发重建以更新UI
                    onJumpToHistoryEntry: _jumpToHistoryEntry,
                    onLoadGame: (saveSlot) {
                      // 在当前GamePlayScreen中恢复存档，而不是创建新实例
                      _currentScript = saveSlot.currentScript;
                      _gameManager.restoreFromSnapshot(
                        saveSlot.currentScript, 
                        saveSlot.snapshot, 
                        shouldReExecute: false
                      );
                      _showNotificationMessage('读档成功');
                    },
                    onProgressDialogue: () => _dialogueProgressionManager.progressDialogue(),
                    expressionSelectorManager: _expressionSelectorManager,
                    createDialogueBox: _createDialogueBox,
                  ),
                  // 加载淡出覆盖层 - 不会被隐藏
                  AnimatedBuilder(
                    animation: _loadingFadeAnimation,
                    builder: (context, child) {
                      if (_loadingFadeAnimation.value <= 0.0) {
                        return const SizedBox.shrink();
                      }
                      return Container(
                        color: Colors.black.withOpacity(_loadingFadeAnimation.value),
                      );
                    },
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
    return SimpleShakeWrapper(
      trigger: gameState.isShaking && (gameState.shakeTarget == 'background' || gameState.shakeTarget == null),
      intensity: gameState.shakeIntensity ?? 8.0,
      duration: Duration(milliseconds: ((gameState.shakeDuration ?? 1.0) * 1000).round()),
      child: Stack(
        children: [
          // 背景层 - 总是渲染背景（如果有的话）
          if (gameState.background != null)
            Builder(
              builder: (context) {
                //print('[GamePlayScreen] 正在渲染背景: ${gameState.background}');
                return _buildBackground(gameState.background!, gameState.sceneFilter, gameState.sceneLayers, gameState.sceneAnimationProperties);
              },
            )
          else
            Builder(
              builder: (context) {
                //print('[GamePlayScreen] 背景为空，不渲染背景层');
                return const SizedBox.shrink();
              },
            ),
          
          // 角色和CG层 - 只有在没有视频时才显示
          if (gameState.movieFile == null) ...[
            ..._buildCharacters(context, gameState.characters, _gameManager.poseConfigs, gameState.everShownCharacters),
            // CG角色渲染，使用新的层叠渲染系统
            // 支持在预合成和层叠渲染间智能切换，优化快进性能
            ...RenderingSystemManager().buildCgCharacters(context, gameState.cgCharacters, _gameManager),
          ],
          
          // 视频播放器 - 最高优先级，如果有视频则覆盖在背景之上
          if (gameState.movieFile != null)
            Positioned.fill(
              child: _buildMoviePlayer(gameState.movieFile!, gameState.movieRepeatCount),
            )
          else
            // 当没有视频时，放置一个透明容器确保视频层被清除
            Positioned.fill(
              child: Container(
                color: Colors.transparent,
                // 添加key确保每次状态变化时重建
                key: const ValueKey('no_movie'),
              ),
            ),
            
          // anime覆盖层 - 最顶层
          if (gameState.animeOverlay != null)
            _buildAnimeOverlay(gameState.animeOverlay!, gameState.animeLoop, keep: gameState.animeKeep),
        ],
      ),
    );
  }

  /// 构建视频播放器
  Widget _buildMoviePlayer(String movieFile, int? repeatCount) {
    return MoviePlayer(
      key: ValueKey('$movieFile-$repeatCount'), // 添加key确保视频切换时正确重建组件，包含repeatCount确保参数变化时重建
      movieFile: movieFile,
      repeatCount: repeatCount, // 新增：传递重复播放次数
      autoPlay: true,
      looping: false,
      onVideoEnd: () {
        // 视频播放结束，继续执行脚本（不使用next()，直接调用内部方法）
        _gameManager.executeScriptAfterMovie();
      },
    );
  }

  /// 构建anime覆盖层 - 全屏显示，支持WebP动图播放
  Widget _buildAnimeOverlay(String animeName, bool loop, {bool keep = false}) {
    return Positioned.fill(
      child: SmartAssetImage(
        assetName: animeName,
        fit: BoxFit.cover, // 和scene一样，贴满屏幕
        loop: loop, // 传递loop参数
        onAnimationComplete: !loop && !keep ? () {
          // 非循环且非keep模式下，动画完成后清除覆盖层
          _clearAnimeOverlay();
        } : null,
        errorWidget: Container(
          color: Colors.transparent,
          child: Center(
            child: Text(
              'Anime not found: $animeName',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      ),
    );
  }

  /// 清除anime覆盖层
  void _clearAnimeOverlay() {
    // 通过GameManager清除anime覆盖层
    _gameManager.clearAnimeOverlay();
  }

  /// 构建背景Widget - 支持图片背景和十六进制颜色背景，以及多图层场景和动画
  Widget _buildBackground(String background, [SceneFilter? sceneFilter, List<String>? sceneLayers, Map<String, double>? animationProperties]) {
    ////print('[_buildBackground] 开始构建背景: $background');
    Widget backgroundWidget;
    
    // 如果有多图层数据，使用多图层渲染器
    if (sceneLayers != null && sceneLayers.isNotEmpty) {
      ////print('[_buildBackground] 使用多图层渲染器');
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
        ////print('[_buildBackground] 多图层为空，使用黑色背景');
        backgroundWidget = Container(color: Colors.black);
      }
    } else {
      ////print('[_buildBackground] 单图层模式，背景内容: $background');
      // 单图层模式（原有逻辑）
      // 检查是否为十六进制颜色格式
      if (ColorBackgroundRenderer.isValidHexColor(background)) {
        ////print('[_buildBackground] 识别为十六进制颜色背景');
        backgroundWidget = ColorBackgroundRenderer.createColorBackgroundWidget(background);
      } else {
        ////print('[_buildBackground] 识别为图片背景，开始处理图片路径');
        
        // 检查是否为内存缓存路径
        if (background.startsWith('/memory_cache/cg_cache/')) {
          //print('[_buildBackground] 🐛 检测到内存缓存路径，使用SmartImage加载: $background');
          // 使用SmartImage处理内存缓存路径
          backgroundWidget = SmartImage.asset(
            background,
            key: ValueKey('memory_cache_bg_$background'),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorWidget: Container(color: Colors.black),
          );
        } else if (background.startsWith('/')) {
          //print('[_buildBackground] 🐛 检测到绝对文件路径，直接使用Image.file加载: $background');
          // 直接使用Image.file，不预缓存，避免FutureBuilder导致的黑屏
          backgroundWidget = Image.file(
            File(background),
            key: ValueKey('direct_bg_$background'),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            // 关键：不使用frameBuilder，让图像立即显示
            errorBuilder: (context, error, stackTrace) {
              //print('[_buildBackground] ❌ 直接文件加载失败: $background, 错误: $error');
              return Container(color: Colors.black);
            },
          );
        } else {
          ////print('[_buildBackground] 使用AssetManager查找相对路径');
          // 处理相对路径图片背景（原有逻辑）
          backgroundWidget = FutureBuilder<String?>(
            key: ValueKey('bg_$background'), // 添加key避免重建
            future: AssetManager().findAsset('backgrounds/${background.replaceAll(' ', '-')}'),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                return SmartImage.asset(
                  snapshot.data!,
                  key: ValueKey(snapshot.data!), // 为图片添加key
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorWidget: Container(color: Colors.black),
                );
              }
              return Container(color: Colors.black);
            },
          );
        }
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
  
  /// 预缓存背景图像到Flutter的ImageCache中
  Future<void> _precacheBackgroundImage(String imagePath, BuildContext context) async {
    try {
      print('[_precacheBackgroundImage] 开始预缓存: $imagePath');
      
      final file = File(imagePath);
      if (await file.exists()) {
        await precacheImage(FileImage(file), context);
        print('[_precacheBackgroundImage] 预缓存完成: $imagePath');
      } else {
        print('[_precacheBackgroundImage] 文件不存在: $imagePath');
      }
    } catch (e) {
      print('[_precacheBackgroundImage] 预缓存失败: $imagePath, 错误: $e');
    }
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
            // 获取差分偏移、透明度和缩放（仅对表情图层有效）
            final (xOffset, yOffset, alpha, scale) = ExpressionOffsetManager().getExpressionOffset(
              characterId: characterState.resourceId,
              pose: characterState.pose ?? 'pose1',
              layerType: layerInfo.layerType,
            );
            
            // 调试输出
            // ${layerInfo.layerType}, 偏移: ($xOffset, $yOffset), 透明度: $alpha');
            
            return _CharacterLayer(
              key: ValueKey('${characterState.resourceId}-${layerInfo.layerType}'),
              assetName: layerInfo.assetName,
              isFadingOut: characterState.isFadingOut,
              expressionOffsetX: xOffset, // 横向偏移
              expressionOffsetY: yOffset, // 纵向偏移
              expressionAlpha: alpha, // 透明度
              expressionScale: scale, // 缩放比例
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
  final double expressionOffsetX; // 横向偏移（归一化值）
  final double expressionOffsetY; // 纵向偏移（归一化值）
  final double expressionAlpha; // 透明度（0.0到1.0）
  final double expressionScale; // 缩放比例（1.0为原始大小）
  final VoidCallback? onFadeOutComplete;
  
  const _CharacterLayer({
    super.key, 
    required this.assetName,
    this.isFadingOut = false,
    this.expressionOffsetX = 0.0, // 默认无偏移
    this.expressionOffsetY = 0.0, // 默认无偏移
    this.expressionAlpha = 1.0, // 默认完全不透明
    this.expressionScale = 1.0, // 默认原始大小
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
      _loadImage(); // 移除.then回调，因为_loadImage内部已处理动画触发
    }
  }

  Future<void> _loadImage() async {
    final assetPath = await AssetManager().findAsset(widget.assetName);
    if (assetPath != null && mounted) {
      final image = await ImageLoader.loadImage(assetPath);
      if (mounted && image != null) {
        // 使用post frame callback避免在build期间调用setState
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _currentImage = image;
            });
            
            // 修复：如果当前正在淡出，不要触发淡入动画
            if (!widget.isFadingOut) {
              _controller.forward(from: 0.0);
            }
          }
        });
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

    Widget imageWidget = AnimatedBuilder(
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
            
            Widget customPaintWidget = CustomPaint(
              size: paintSize,
              painter: _DissolvePainter(
                program: _dissolveProgram!,
                progress: _animation.value,
                imageFrom: _previousImage ?? _currentImage!,
                imageTo: _currentImage!,
              ),
            );
            
            // 应用透明度（如果不是完全不透明）
            if (widget.expressionAlpha != 1.0) {
              customPaintWidget = Opacity(
                opacity: widget.expressionAlpha,
                child: customPaintWidget,
              );
            }
            
            // 应用缩放（如果不是原始大小），锚点为左上角
            if (widget.expressionScale != 1.0) {
              customPaintWidget = Transform.scale(
                scale: widget.expressionScale,
                alignment: Alignment.topLeft,
                child: customPaintWidget,
              );
            }
            
            // 应用差分偏移（如果有偏移），基于实际绘制尺寸
            if (widget.expressionOffsetX != 0.0 || widget.expressionOffsetY != 0.0) {
              final pixelOffsetX = paintSize.width * widget.expressionOffsetX;
              final pixelOffsetY = paintSize.height * widget.expressionOffsetY;
              
              return Transform.translate(
                offset: Offset(pixelOffsetX, pixelOffsetY),
                child: customPaintWidget,
              );
            }
            
            return customPaintWidget;
          },
        );
      },
    );
    
    return imageWidget;
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
