import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/asset_manager.dart';
import 'package:sakiengine/src/config/config_models.dart';
import 'package:sakiengine/src/config/config_parser.dart';
import 'package:sakiengine/src/sks_parser/sks_ast.dart';
import 'package:sakiengine/src/sks_parser/sks_parser.dart';
import 'package:sakiengine/src/game/script_merger.dart';
import 'package:sakiengine/src/widgets/common/black_screen_transition.dart';
import 'package:sakiengine/src/effects/scene_filter.dart';
import 'package:sakiengine/src/effects/scene_transition_effects.dart';

class GameManager {
  final _gameStateController = StreamController<GameState>.broadcast();
  Stream<GameState> get gameStateStream => _gameStateController.stream;

  late GameState _currentState;
  late ScriptNode _script;
  int _scriptIndex = 0;
  bool _isProcessing = false;
  bool _isWaitingForTimer = false; // 新增：专门的计时器等待标志
  Timer? _currentTimer; // 新增：当前活跃的计时器引用
  Map<String, int> _labelIndexMap = {};
  
  // 脚本合并器
  final ScriptMerger _scriptMerger = ScriptMerger();

  Map<String, CharacterConfig> _characterConfigs = {};
  Map<String, PoseConfig> _poseConfigs = {};
  VoidCallback? onReturn;
  BuildContext? _context;
  final Set<String> _everShownCharacters = {};
  
  GameStateSnapshot? _savedSnapshot;
  
  List<DialogueHistoryEntry> _dialogueHistory = [];
  static const int maxHistoryEntries = 100;

  // Getters for accessing configurations
  Map<String, PoseConfig> get poseConfigs => _poseConfigs;
  String get currentScriptFile => _scriptMerger.getFileNameByIndex(_scriptIndex) ?? 'start';

  GameManager({this.onReturn});

  /// 设置BuildContext用于转场效果
  void setContext(BuildContext context) {
    //print('[GameManager] 设置上下文用于转场效果');
    _context = context;
  }

  Future<void> _loadConfigs() async {
    final charactersContent = await AssetManager().loadString('assets/GameScript/configs/characters.sks');
    _characterConfigs = ConfigParser().parseCharacters(charactersContent);

    final posesContent = await AssetManager().loadString('assets/GameScript/configs/poses.sks');
    _poseConfigs = ConfigParser().parsePoses(posesContent);
  }

  Future<void> startGame(String scriptName) async {
    await _loadConfigs();
    _script = await _scriptMerger.getMergedScript();
    _buildLabelIndexMap();
    _currentState = GameState.initial();
    _dialogueHistory = [];
    
    // 如果指定了非 start 脚本，跳转到对应位置
    if (scriptName != 'start') {
      final startIndex = _scriptMerger.getFileStartIndex(scriptName);
      if (startIndex != null) {
        _scriptIndex = startIndex;
      }
    }
    
    _executeScript();
  }
  
  void _buildLabelIndexMap() {
    _labelIndexMap = {};
    for (int i = 0; i < _script.children.length; i++) {
      final node = _script.children[i];
      if (node is LabelNode) {
        _labelIndexMap[node.name] = i;
        if (kDebugMode) {
          //print('[GameManager] 标签映射: ${node.name} -> $i');
        }
      }
    }
  }

  Future<void> jumpToLabel(String label) async {
    // 在合并的脚本中查找标签
    if (_labelIndexMap.containsKey(label)) {
      _scriptIndex = _labelIndexMap[label]!;
      _currentState = _currentState.copyWith(forceNullCurrentNode: true, everShownCharacters: _everShownCharacters);
      if (kDebugMode) {
        //print('[GameManager] 跳转到标签: $label, 索引: $_scriptIndex');
      }
      _executeScript();
    } else {
      if (kDebugMode) {
        //print('[GameManager] 错误: 标签 $label 未找到');
      }
    }
  }

  void next() {
    _executeScript();
  }

  void exitNvlMode() {
    //print('📚 退出 NVL 模式');
    _currentState = _currentState.copyWith(
      isNvlMode: false,
      nvlDialogues: [],
      clearDialogueAndSpeaker: true,
      everShownCharacters: _everShownCharacters,
    );
    _gameStateController.add(_currentState);
    _executeScript();
  }

  void _executeScript() {
    if (_isProcessing || _isWaitingForTimer) {
      return;
    }
    _isProcessing = true;

    //print('🎮 开始处理脚本，当前索引: $_scriptIndex');
    
    while (_scriptIndex < _script.children.length) {
      final node = _script.children[_scriptIndex];
      final currentNodeIndex = _scriptIndex; // 保存当前节点索引
      //print('🎮 处理节点[$_scriptIndex]: ${node.runtimeType} - $node');

      // 跳过注释节点（文件边界标记）
      if (node is CommentNode) {
        if (kDebugMode) {
          //print('[GameManager] 跳过注释: ${node.comment}');
        }
        _scriptIndex++;
        continue;
      }

      // 跳过标签节点
      if (node is LabelNode) {
        _scriptIndex++;
        continue;
      }

      if (node is BackgroundNode) {
        // 检查下一个节点是否是FxNode，如果是则一起处理
        SceneFilter? sceneFilter;
        int nextIndex = _scriptIndex + 1;
        if (nextIndex < _script.children.length && _script.children[nextIndex] is FxNode) {
          final fxNode = _script.children[nextIndex] as FxNode;
          sceneFilter = SceneFilter.fromString(fxNode.filterString);
        }
        
        // 检查是否是游戏开始时的初始背景设置
        final isInitialBackground = _currentState.background == null;
        
        if (_context != null && !isInitialBackground) {
          // 只有在非初始背景时才使用转场效果
          // 立即递增索引，如果有fx节点也跳过
          _scriptIndex += sceneFilter != null ? 2 : 1;
          
          // 如果没有指定timer，默认使用0.01秒，确保转场后正确执行后续脚本
          final timerDuration = node.timer ?? 0.01;
          
          // 提前设置计时器等待标志
          _isWaitingForTimer = true;
          _isProcessing = false; // 释放当前处理锁，但保持timer锁
          
          _transitionToNewBackground(node.background, sceneFilter, node.layers, node.transitionType).then((_) {
            // 转场完成后启动计时器
            _startSceneTimer(timerDuration);
          });
          return; // 转场过程中暂停脚本执行，将在转场完成后自动恢复
        } else {
          //print('[GameManager] 直接设置背景（${isInitialBackground ? "初始背景" : "无转场"}）');
          // 直接切换背景 - 初始背景或无context时
          _currentState = _currentState.copyWith(
              background: node.background, 
              sceneFilter: sceneFilter,
              clearSceneFilter: sceneFilter == null, // 如果没有滤镜，清除现有滤镜
              sceneLayers: node.layers,
              clearSceneLayers: node.layers == null, // 如果是单图层，清除多图层数据
              clearDialogueAndSpeaker: true,
              everShownCharacters: _everShownCharacters);
          _gameStateController.add(_currentState);
          
          // 如果有计时器，启动计时器
          if (node.timer != null && node.timer! > 0) {
            // 启动计时器，保持 _isProcessing = true 直到计时器结束
            _startSceneTimer(node.timer!);
            return;
          }
        }
        // 如果有fx节点也跳过
        _scriptIndex += sceneFilter != null ? 2 : 1;
        continue;
      }

      if (node is ShowNode) {
        final characterConfig = _characterConfigs[node.character];
        if (characterConfig == null) {
          _scriptIndex++;
          continue;
        }

        // 跟踪角色是否曾经显示过
        _everShownCharacters.add(node.character);

        final currentCharacterState = _currentState.characters[node.character] ?? CharacterState(
          resourceId: characterConfig.resourceId,
          positionId: characterConfig.defaultPoseId,
        );
        final newCharacters = Map.of(_currentState.characters);

        newCharacters[node.character] = currentCharacterState.copyWith(
          pose: node.pose,
          expression: node.expression,
        );
        _currentState =
            _currentState.copyWith(characters: newCharacters, clearDialogueAndSpeaker: true, everShownCharacters: _everShownCharacters);
        _gameStateController.add(_currentState);
        _scriptIndex++;
        continue;
      }

      if (node is HideNode) {
        final newCharacters = Map.of(_currentState.characters);
        newCharacters.remove(node.character);
        _currentState =
            _currentState.copyWith(characters: newCharacters, clearDialogueAndSpeaker: true, everShownCharacters: _everShownCharacters);
        _gameStateController.add(_currentState);
        _scriptIndex++;
        continue;
      }

      if (node is SayNode) {
        final characterConfig = _characterConfigs[node.character];
        CharacterState? currentCharacterState;

        if (node.character != null) {
          currentCharacterState = _currentState.characters[node.character!];
          if(currentCharacterState == null && characterConfig != null) {
            currentCharacterState = CharacterState(
              resourceId: characterConfig.resourceId,
              positionId: characterConfig.defaultPoseId,
            );
          }
        }

        if (currentCharacterState != null) {
          final newCharacters = Map.of(_currentState.characters);
          newCharacters[node.character!] = currentCharacterState.copyWith(
            pose: node.pose,
            expression: node.expression,
          );
          _currentState = _currentState.copyWith(characters: newCharacters, everShownCharacters: _everShownCharacters);
        }

        // 在 NVL 模式下的特殊处理
        if (_currentState.isNvlMode) {
          final newNvlDialogue = NvlDialogue(
            speaker: characterConfig?.name,
            dialogue: node.dialogue,
            timestamp: DateTime.now(),
          );
          
          final updatedNvlDialogues = List<NvlDialogue>.from(_currentState.nvlDialogues);
          updatedNvlDialogues.add(newNvlDialogue);
          
          _currentState = _currentState.copyWith(
            nvlDialogues: updatedNvlDialogues,
            clearDialogueAndSpeaker: true,
            everShownCharacters: _everShownCharacters,
          );
          
          // 也添加到对话历史
          _addToDialogueHistory(
            speaker: characterConfig?.name,
            dialogue: node.dialogue,
            timestamp: DateTime.now(),
            currentNodeIndex: currentNodeIndex,
          );
          
          _gameStateController.add(_currentState);
          
          // NVL 模式下每句话都要停下来等待点击
          _scriptIndex++;
          _isProcessing = false;
          return;
        } else {
          // 普通对话模式
          _currentState = _currentState.copyWith(
            dialogue: node.dialogue,
            speaker: characterConfig?.name,
            poseConfigs: _poseConfigs,
            currentNode: null,
            clearDialogueAndSpeaker: false,
            forceNullSpeaker: node.character == null,
            everShownCharacters: _everShownCharacters,
          );

          _addToDialogueHistory(
            speaker: characterConfig?.name,
            dialogue: node.dialogue,
            timestamp: DateTime.now(),
            currentNodeIndex: currentNodeIndex,
          );

          _gameStateController.add(_currentState);
          _scriptIndex++;
          _isProcessing = false;
          return;
        }
      }

      if (node is MenuNode) {
        _currentState = _currentState.copyWith(currentNode: node, clearDialogueAndSpeaker: true, everShownCharacters: _everShownCharacters);
        _gameStateController.add(_currentState);
        _scriptIndex++;
        _isProcessing = false;
        return;
      }

      if (node is ReturnNode) {
        _scriptIndex++;
        onReturn?.call();
        _isProcessing = false;
        return;
      }
      
      if (node is JumpNode) {
        _scriptIndex++;
        _isProcessing = false;
        jumpToLabel(node.targetLabel);
        return;
      }

      if (node is NvlNode) {
        _currentState = _currentState.copyWith(
          isNvlMode: true,
          isNvlMovieMode: false,
          nvlDialogues: [],
          clearDialogueAndSpeaker: true,
          everShownCharacters: _everShownCharacters,
        );
        _gameStateController.add(_currentState);
        _scriptIndex++;
        continue;
      }

      if (node is NvlMovieNode) {
        _currentState = _currentState.copyWith(
          isNvlMode: true,
          isNvlMovieMode: true,
          nvlDialogues: [],
          clearDialogueAndSpeaker: true,
          everShownCharacters: _everShownCharacters,
        );
        _gameStateController.add(_currentState);
        _scriptIndex++;
        continue;
      }

      if (node is EndNvlNode) {
        // 退出 NVL 模式并继续执行后续脚本
        _currentState = _currentState.copyWith(
          isNvlMode: false,
          isNvlMovieMode: false,
          nvlDialogues: [],
          clearDialogueAndSpeaker: true,
          everShownCharacters: _everShownCharacters,
        );
        _gameStateController.add(_currentState);
        _scriptIndex++;
        continue; // 继续执行后续节点
      }

      if (node is EndNvlMovieNode) {
        // 退出 NVL 电影模式并继续执行后续脚本
        _currentState = _currentState.copyWith(
          isNvlMode: false,
          isNvlMovieMode: false,
          nvlDialogues: [],
          clearDialogueAndSpeaker: true,
          everShownCharacters: _everShownCharacters,
        );
        _gameStateController.add(_currentState);
        _scriptIndex++;
        continue; // 继续执行后续节点
      }

      if (node is FxNode) {
        final filter = SceneFilter.fromString(node.filterString);
        if (filter != null) {
          _currentState = _currentState.copyWith(
            sceneFilter: filter,
            everShownCharacters: _everShownCharacters,
          );
          _gameStateController.add(_currentState);
        }
        _scriptIndex++;
        continue;
      }
    }
    _isProcessing = false;
  }

  GameStateSnapshot saveStateSnapshot() {
    return GameStateSnapshot(
      scriptIndex: _scriptIndex,
      currentState: _currentState,
      dialogueHistory: List.from(_dialogueHistory),
      isNvlMode: _currentState.isNvlMode,
      isNvlMovieMode: _currentState.isNvlMovieMode,
      nvlDialogues: List.from(_currentState.nvlDialogues),
    );
  }

  Future<void> restoreFromSnapshot(String scriptName, GameStateSnapshot snapshot, {bool shouldReExecute = true}) async {
    //print('📚 restoreFromSnapshot: scriptName = $scriptName');
    //print('📚 restoreFromSnapshot: snapshot.scriptIndex = ${snapshot.scriptIndex}');
    //print('📚 restoreFromSnapshot: isNvlMode = ${snapshot.isNvlMode}');
    //print('📚 restoreFromSnapshot: nvlDialogues count = ${snapshot.nvlDialogues.length}');
    
    await _loadConfigs();
    _script = await _scriptMerger.getMergedScript();
    _buildLabelIndexMap();
    //print('📚 加载合并脚本后: _script.children.length = ${_script.children.length}');
    
    _scriptIndex = snapshot.scriptIndex;
    
    // 重置所有处理标志，确保恢复状态时没有遗留的锁定状态
    _isProcessing = false;
    _isWaitingForTimer = false;
    
    // 取消当前活跃的计时器
    _currentTimer?.cancel();
    _currentTimer = null;
    
    // 恢复 NVL 状态
    _currentState = snapshot.currentState.copyWith(
      poseConfigs: _poseConfigs,
      isNvlMode: snapshot.isNvlMode,
      isNvlMovieMode: snapshot.isNvlMovieMode,
      nvlDialogues: snapshot.nvlDialogues,
      everShownCharacters: _everShownCharacters,
    );
    
    if (snapshot.dialogueHistory.isNotEmpty) {
      _dialogueHistory = List.from(snapshot.dialogueHistory);
    }
    
    if (shouldReExecute) {
      _executeScript();
    } else {
      _gameStateController.add(_currentState);
    }
  }

  Future<void> hotReload(String scriptName) async {
    if (_dialogueHistory.isNotEmpty) {
      _dialogueHistory.removeLast();
    }
    
    _savedSnapshot = saveStateSnapshot();
    
    // 清理缓存并重新合并脚本
    _scriptMerger.clearCache();
    await _loadConfigs();
    _script = await _scriptMerger.getMergedScript();
    _buildLabelIndexMap();
    
    if (_savedSnapshot != null) {
      _scriptIndex = _savedSnapshot!.scriptIndex;
      _dialogueHistory = List.from(_savedSnapshot!.dialogueHistory);
      
      if (_scriptIndex > 0) {
        _scriptIndex--;
      }
      
      _currentState = _savedSnapshot!.currentState.copyWith(
        poseConfigs: _poseConfigs,
        clearDialogueAndSpeaker: true,
        forceNullCurrentNode: true,
        // 恢复 NVL 状态
        isNvlMode: _savedSnapshot!.isNvlMode,
        isNvlMovieMode: _savedSnapshot!.isNvlMovieMode,
        nvlDialogues: _savedSnapshot!.nvlDialogues,
        everShownCharacters: _everShownCharacters,
      );
      
      _isProcessing = false;
      _isWaitingForTimer = false; // 重置计时器标志
      
      // 取消当前活跃的计时器
      _currentTimer?.cancel();
      _currentTimer = null;
      
      _executeScript();
    }
  }

  void returnToPreviousScreen() {
    onReturn?.call();
  }

  void _addToDialogueHistory({
    String? speaker,
    required String dialogue,
    required DateTime timestamp,
    required int currentNodeIndex,
  }) {
    // 为历史条目创建快照时，使用正确的节点索引
    // 对于NVL模式，只保存当前单句对话而不是整个NVL列表，避免回退时重复显示
    final nvlDialoguesForSnapshot = _currentState.isNvlMode 
        ? [NvlDialogue(speaker: speaker, dialogue: dialogue, timestamp: timestamp)]
        : List.from(_currentState.nvlDialogues);
    
    final snapshot = GameStateSnapshot(
      scriptIndex: currentNodeIndex,
      currentState: _currentState,
      dialogueHistory: const [], // 避免循环引用
      isNvlMode: _currentState.isNvlMode,
      isNvlMovieMode: _currentState.isNvlMovieMode,
      nvlDialogues: List.from(_currentState.nvlDialogues),
    );
    
    _dialogueHistory.add(DialogueHistoryEntry(
      speaker: speaker,
      dialogue: dialogue,
      timestamp: timestamp,
      scriptIndex: currentNodeIndex,
      stateSnapshot: snapshot,
    ));
    
    if (_dialogueHistory.length > maxHistoryEntries) {
      _dialogueHistory.removeAt(0);
    }
  }

  List<DialogueHistoryEntry> getDialogueHistory() {
    return List.unmodifiable(_dialogueHistory);
  }

  Future<void> jumpToHistoryEntry(DialogueHistoryEntry entry, String scriptName) async {
    final targetIndex = _dialogueHistory.indexOf(entry);
    if (targetIndex != -1) {
      _dialogueHistory.removeRange(targetIndex + 1, _dialogueHistory.length);
    }
    
    // 使用合并的脚本，不需要重新加载特定脚本
    // 恢复历史条目时，需要检查是否处于 NVL 模式
    final snapshot = entry.stateSnapshot;
    await restoreFromSnapshot(scriptName, snapshot, shouldReExecute: false);
    
    // 修复NVL模式回退bug：将脚本索引移动到下一个节点，避免重复执行当前节点
    if (snapshot.isNvlMode && _scriptIndex < _script.children.length - 1) {
      _scriptIndex++;
    }
  }

  /// 启动场景计时器
  void _startSceneTimer(double seconds) {
    // 取消之前的计时器（如果存在）
    _currentTimer?.cancel();
    
    final durationMs = (seconds * 1000).round();
    
    _currentTimer = Timer(Duration(milliseconds: durationMs), () {
      // 检查计时器是否仍然有效（防止已被取消的计时器执行）
      if (_isWaitingForTimer && _currentTimer != null && _currentTimer!.isActive == false) {
        _isWaitingForTimer = false;
        _currentTimer = null;
        _executeScript();
      }
    });
  }

  /// 使用转场效果切换背景
  Future<void> _transitionToNewBackground(String newBackground, [SceneFilter? sceneFilter, List<String>? layers, String? transitionType]) async {
    if (_context == null) return;
    
    //print('[GameManager] 开始scene转场到背景: $newBackground, 转场类型: ${transitionType ?? "fade"}');
    
    // 解析转场类型
    final effectType = TransitionTypeParser.parseTransitionType(transitionType ?? 'fade');
    
    // 如果是diss转场，需要准备旧背景和新背景名称
    String? oldBackgroundName;
    String? newBackgroundName;
    
    if (effectType == TransitionType.diss) {
      // 传递背景名称而不是Widget
      oldBackgroundName = _currentState.background;
      newBackgroundName = newBackground;
    }
    
    // 根据转场类型选择转场管理器
    if (effectType == TransitionType.fade) {
      // 使用原有的黑屏转场
      await SceneTransitionManager.instance.transition(
        context: _context!,
        onMidTransition: () {
        //print('[GameManager] scene转场中点 - 切换背景到: $newBackground');
        // 在黑屏最深时切换背景，清除对话和所有角色（类似Renpy）
        final oldState = _currentState;
        _currentState = _currentState.copyWith(
          background: newBackground,
          sceneFilter: sceneFilter,
          clearSceneFilter: sceneFilter == null, // 如果没有滤镜，清除现有滤镜
          sceneLayers: layers,
          clearSceneLayers: layers == null, // 如果是单图层，清除多图层数据
          clearDialogueAndSpeaker: true,
          clearCharacters: true,
          everShownCharacters: _everShownCharacters,
        );
        //print('[GameManager] 状态更新 - 旧背景: ${oldState.background}, 新背景: ${_currentState.background}');
        _gameStateController.add(_currentState);
        //print('[GameManager] 状态已发送到Stream');
      },
        duration: const Duration(milliseconds: 800),
      );
    } else {
      // 使用新的转场效果系统
      await SceneTransitionEffectManager.instance.transition(
        context: _context!,
        transitionType: effectType,
        oldBackground: oldBackgroundName,
        newBackground: newBackgroundName,
        onMidTransition: () {
          //print('[GameManager] scene转场中点 - 切换背景到: $newBackground');
          // 在转场中点切换背景，清除对话和所有角色（类似Renpy）
          final oldState = _currentState;
          _currentState = _currentState.copyWith(
            background: newBackground,
            sceneFilter: sceneFilter,
            clearSceneFilter: sceneFilter == null, // 如果没有滤镜，清除现有滤镜
            sceneLayers: layers,
            clearSceneLayers: layers == null, // 如果是单图层，清除多图层数据
            clearDialogueAndSpeaker: true,
            clearCharacters: true,
            everShownCharacters: _everShownCharacters,
          );
          //print('[GameManager] 状态更新 - 旧背景: ${oldState.background}, 新背景: ${_currentState.background}');
          _gameStateController.add(_currentState);
          //print('[GameManager] 状态已发送到Stream');
        },
        duration: const Duration(milliseconds: 800),
      );
    }
    
    //print('[GameManager] scene转场完成，等待计时器结束');
    // 转场完成，等待计时器结束后自动执行后续脚本
    _isProcessing = false;
  }

  void dispose() {
    _currentTimer?.cancel(); // 取消活跃的计时器
    _gameStateController.close();
  }
}

class GameState {
  final String? background;
  final Map<String, CharacterState> characters;
  final String? dialogue;
  final String? speaker;
  final Map<String, PoseConfig> poseConfigs;
  final SksNode? currentNode;
  final bool isNvlMode;
  final bool isNvlMovieMode;
  final List<NvlDialogue> nvlDialogues;
  final Set<String> everShownCharacters;
  final SceneFilter? sceneFilter;
  final List<String>? sceneLayers; // 新增：多图层支持

  GameState({
    this.background,
    this.characters = const {},
    this.dialogue,
    this.speaker,
    this.poseConfigs = const {},
    this.currentNode,
    this.isNvlMode = false,
    this.isNvlMovieMode = false,
    this.nvlDialogues = const [],
    this.everShownCharacters = const {},
    this.sceneFilter,
    this.sceneLayers,
  });

  factory GameState.initial() {
    return GameState();
  }


  GameState copyWith({
    String? background,
    Map<String, CharacterState>? characters,
    String? dialogue,
    String? speaker,
    Map<String, PoseConfig>? poseConfigs,
    SksNode? currentNode,
    bool clearDialogueAndSpeaker = false,
    bool clearCharacters = false,
    bool forceNullCurrentNode = false,
    bool forceNullSpeaker = false,
    bool? isNvlMode,
    bool? isNvlMovieMode,
    List<NvlDialogue>? nvlDialogues,
    Set<String>? everShownCharacters,
    SceneFilter? sceneFilter,
    bool clearSceneFilter = false,
    List<String>? sceneLayers,
    bool clearSceneLayers = false,
  }) {
    return GameState(
      background: background ?? this.background,
      characters: clearCharacters ? <String, CharacterState>{} : (characters ?? this.characters),
      dialogue: clearDialogueAndSpeaker ? null : (dialogue ?? this.dialogue),
      speaker: forceNullSpeaker
          ? null
          : (clearDialogueAndSpeaker ? null : (speaker ?? this.speaker)),
      poseConfigs: poseConfigs ?? this.poseConfigs,
      currentNode: forceNullCurrentNode ? null : (currentNode ?? this.currentNode),
      isNvlMode: isNvlMode ?? this.isNvlMode,
      isNvlMovieMode: isNvlMovieMode ?? this.isNvlMovieMode,
      nvlDialogues: nvlDialogues ?? this.nvlDialogues,
      everShownCharacters: everShownCharacters ?? this.everShownCharacters,
      sceneFilter: clearSceneFilter ? null : (sceneFilter ?? this.sceneFilter),
      sceneLayers: clearSceneLayers ? null : (sceneLayers ?? this.sceneLayers),
    );
  }
}

class NvlDialogue {
  final String? speaker;
  final String dialogue;
  final DateTime timestamp;

  NvlDialogue({
    this.speaker,
    required this.dialogue,
    required this.timestamp,
  });
}

class CharacterState {
  final String resourceId;
  final String? pose;
  final String? expression;
  final String? positionId;

  CharacterState(
      {required this.resourceId, this.pose, this.expression, this.positionId});
  

  CharacterState copyWith({String? pose, String? expression, String? positionId}) {
    return CharacterState(
      resourceId: resourceId,
      pose: pose ?? this.pose,
      expression: expression ?? this.expression,
      positionId: positionId ?? this.positionId,
    );
  }
}

class GameStateSnapshot {
  final int scriptIndex;
  final GameState currentState;
  final List<DialogueHistoryEntry> dialogueHistory;
  final bool isNvlMode;
  final bool isNvlMovieMode;
  final List<NvlDialogue> nvlDialogues;

  GameStateSnapshot({
    required this.scriptIndex,
    required this.currentState,
    this.dialogueHistory = const [],
    this.isNvlMode = false,
    this.isNvlMovieMode = false,
    this.nvlDialogues = const [],
  });

}

class DialogueHistoryEntry {
  final String? speaker;
  final String dialogue;
  final DateTime timestamp;
  final int scriptIndex;
  final GameStateSnapshot stateSnapshot;

  DialogueHistoryEntry({
    this.speaker,
    required this.dialogue,
    required this.timestamp,
    required this.scriptIndex,
    required this.stateSnapshot,
  });

}
