import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sakiengine/src/config/asset_manager.dart';
import 'package:sakiengine/src/config/config_models.dart';
import 'package:sakiengine/src/config/config_parser.dart';
import 'package:sakiengine/src/skr_parser/skr_ast.dart';
import 'package:sakiengine/src/skr_parser/skr_parser.dart';

class GameManager {
  final _gameStateController = StreamController<GameState>.broadcast();
  Stream<GameState> get gameStateStream => _gameStateController.stream;

  late GameState _currentState;
  late ScriptNode _script;
  int _scriptIndex = 0;
  bool _isProcessing = false;
  Map<String, int> _labelIndexMap = {};

  Map<String, CharacterConfig> _characterConfigs = {};
  Map<String, PoseConfig> _poseConfigs = {};
  VoidCallback? onReturn;
  
  // 用于热重载时保存状态
  GameStateSnapshot? _savedSnapshot;
  
  // 对话历史记录（最多保存100条）
  final List<DialogueHistoryEntry> _dialogueHistory = [];
  static const int maxHistoryEntries = 100;

  GameManager({this.onReturn});

  Future<void> _loadConfigs() async {
    final charactersContent = await AssetManager().loadString('assets/GameScript/configs/characters.skn');
    _characterConfigs = ConfigParser().parseCharacters(charactersContent);

    final posesContent = await AssetManager().loadString('assets/GameScript/configs/poses.skp');
    _poseConfigs = ConfigParser().parsePoses(posesContent);
  }

  Future<void> startGame(String scriptName) async {
    await _loadConfigs();
    final scriptContent =
        await AssetManager().loadString('assets/GameScript/labels/$scriptName.skr');
    _script = SkrParser().parse(scriptContent);
    _buildLabelIndexMap();
    _currentState = GameState.initial();
    _executeScript();
  }

  void _buildLabelIndexMap() {
    _labelIndexMap = {};
    for (int i = 0; i < _script.children.length; i++) {
      final node = _script.children[i];
      if (node is LabelNode) {
        _labelIndexMap[node.name] = i;
      }
    }
  }

  void jumpToLabel(String label) {
    if (_labelIndexMap.containsKey(label)) {
      _scriptIndex = _labelIndexMap[label]!;
      _currentState = _currentState.copyWith(forceNullCurrentNode: true);
      _executeScript();
    }
  }

  void next() {
    _executeScript();
  }

  void _executeScript() {
    if (_isProcessing) return;
    _isProcessing = true;

    while (_scriptIndex < _script.children.length) {
      final node = _script.children[_scriptIndex];
      _scriptIndex++;

      if (node is BackgroundNode) {
        _currentState = _currentState.copyWith(
            background: node.background, clearDialogueAndSpeaker: true);
        _gameStateController.add(_currentState);
        continue;
      }

      if (node is ShowNode) {
        final characterConfig = _characterConfigs[node.character];
        if (characterConfig == null) continue;

        final currentCharacterState = _currentState.characters[node.character] ?? CharacterState(
          resourceId: characterConfig.resourceId,
          positionId: characterConfig.defaultPoseId,
        );
        final newCharacters = Map.of(_currentState.characters);

        newCharacters[node.character] = currentCharacterState.copyWith(
          pose: node.pose, // Script overrides pose image
          expression: node.expression, // Script overrides expression image
        );
        _currentState =
            _currentState.copyWith(characters: newCharacters, clearDialogueAndSpeaker: true);
        _gameStateController.add(_currentState);
        continue;
      }

      if (node is HideNode) {
        final newCharacters = Map.of(_currentState.characters);
        newCharacters.remove(node.character);
        _currentState =
            _currentState.copyWith(characters: newCharacters, clearDialogueAndSpeaker: true);
        _gameStateController.add(_currentState);
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
          _currentState = _currentState.copyWith(characters: newCharacters);
        }

        // 先更新对话状态
        _currentState = _currentState.copyWith(
          dialogue: node.dialogue,
          speaker: characterConfig?.name,
          poseConfigs: _poseConfigs,
          currentNode: null,
          clearDialogueAndSpeaker: false,
          forceNullSpeaker: node.character == null, // 如果没有角色，强制清空speaker
        );

        // 然后添加到历史记录（此时状态已完整）
        _addToDialogueHistory(
          speaker: characterConfig?.name,
          dialogue: node.dialogue,
          timestamp: DateTime.now(),
          currentNodeIndex: _scriptIndex - 1, // 传入当前节点的正确索引
        );

        _gameStateController.add(_currentState);

        _isProcessing = false;
        return;
      }

      if (node is MenuNode) {
        _currentState = _currentState.copyWith(currentNode: node, clearDialogueAndSpeaker: true);
        _gameStateController.add(_currentState);
        _isProcessing = false;
        return;
      }

      if (node is ReturnNode) {
        onReturn?.call();
        _isProcessing = false;
        return;
      }
    }
    _isProcessing = false;
  }

  // 保存当前游戏状态快照
  GameStateSnapshot saveStateSnapshot() {
    return GameStateSnapshot(
      scriptIndex: _scriptIndex,
      currentState: _currentState,
      labelIndexMap: Map.from(_labelIndexMap),
    );
  }

  // 从快照恢复游戏状态
  Future<void> restoreFromSnapshot(String scriptName, GameStateSnapshot snapshot, {bool shouldReExecute = true}) async {
    await _loadConfigs();
    final scriptContent =
        await AssetManager().loadString('assets/GameScript/labels/$scriptName.skr');
    _script = SkrParser().parse(scriptContent);
    _buildLabelIndexMap();
    
    // 恢复状态
    _scriptIndex = snapshot.scriptIndex;
    _currentState = snapshot.currentState.copyWith(poseConfigs: _poseConfigs);
    
    if (shouldReExecute) {
      // 重新执行当前节点以显示正确的对话（用于热重载）
      _isProcessing = false;  // 确保可以执行
      _executeScript();
    } else {
      // 直接显示恢复的状态（用于回档）
      _isProcessing = false;  // 重置处理状态，准备下次继续游戏
      _gameStateController.add(_currentState);
    }
  }

  // 热重载：保存当前状态，重新加载脚本，然后恢复并重新执行
  Future<void> hotReload(String scriptName) async {
    // 如果历史记录不为空，移除最后一个条目，因为它将被重新添加
    if (_dialogueHistory.isNotEmpty) {
      _dialogueHistory.removeLast();
    }
    
    // 保存当前状态
    _savedSnapshot = saveStateSnapshot();
    
    // 重新加载脚本和配置
    await _loadConfigs();
    final scriptContent =
        await AssetManager().loadString('assets/GameScript/labels/$scriptName.skr');
    _script = SkrParser().parse(scriptContent);
    _buildLabelIndexMap();
    
    // 恢复状态并重新执行当前节点
    if (_savedSnapshot != null) {
      // 重新执行当前节点以应用新内容
      _scriptIndex = _savedSnapshot!.scriptIndex;
      
      // 重要：回退一步，这样下次执行时会重新处理当前节点
      if (_scriptIndex > 0) {
        _scriptIndex--;
      }
      
      // 恢复基础状态但清除对话内容，这样会重新显示
      _currentState = _savedSnapshot!.currentState.copyWith(
        poseConfigs: _poseConfigs,
        clearDialogueAndSpeaker: true,
        forceNullCurrentNode: true,
      );
      
      // 重新执行脚本以显示新内容
      _isProcessing = false; // 确保可以执行
      _executeScript();
    }
  }

  void returnToPreviousScreen() {
    onReturn?.call();
  }

  // 添加对话到历史记录
  void _addToDialogueHistory({
    String? speaker,
    required String dialogue,
    required DateTime timestamp,
    required int currentNodeIndex,
  }) {
    // 保存当前状态快照用于跳转
    final snapshot = GameStateSnapshot(
      scriptIndex: _scriptIndex, // 保存执行完当前节点后的scriptIndex，下次继续时从下一个节点开始
      currentState: _currentState,
      labelIndexMap: Map.from(_labelIndexMap),
    );
    
    _dialogueHistory.add(DialogueHistoryEntry(
      speaker: speaker,
      dialogue: dialogue,
      timestamp: timestamp,
      scriptIndex: currentNodeIndex,
      stateSnapshot: snapshot,
    ));
    
    // 保持历史记录在最大限制内
    if (_dialogueHistory.length > maxHistoryEntries) {
      _dialogueHistory.removeAt(0);
    }
  }

  // 获取对话历史记录
  List<DialogueHistoryEntry> getDialogueHistory() {
    return List.unmodifiable(_dialogueHistory);
  }

  // 从对话历史记录跳转到指定位置（回档功能）
  Future<void> jumpToHistoryEntry(DialogueHistoryEntry entry, String scriptName) async {
    // 回档：清除该点之后的所有历史记录
    final targetIndex = _dialogueHistory.indexOf(entry);
    if (targetIndex != -1) {
      // 保留到目标点为止的历史记录，清除之后的所有记录
      _dialogueHistory.removeRange(targetIndex + 1, _dialogueHistory.length);
    }
    
    // 回档时不重新执行脚本，避免重复添加历史记录
    await restoreFromSnapshot(scriptName, entry.stateSnapshot, shouldReExecute: false);
  }

  void dispose() {
    _gameStateController.close();
  }
}

class GameState {
  final String? background;
  final Map<String, CharacterState> characters;
  final String? dialogue;
  final String? speaker;
  final Map<String, PoseConfig> poseConfigs;
  final SkrNode? currentNode;

  GameState({
    this.background,
    this.characters = const {},
    this.dialogue,
    this.speaker,
    this.poseConfigs = const {},
    this.currentNode,
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
    SkrNode? currentNode,
    bool clearDialogueAndSpeaker = false,
    bool forceNullCurrentNode = false,
    bool forceNullSpeaker = false,
  }) {
    return GameState(
      background: background ?? this.background,
      characters: characters ?? this.characters,
      dialogue: clearDialogueAndSpeaker ? null : (dialogue ?? this.dialogue),
      speaker: forceNullSpeaker ? null : (clearDialogueAndSpeaker ? null : (speaker ?? this.speaker)),
      poseConfigs: poseConfigs ?? this.poseConfigs,
      currentNode: forceNullCurrentNode ? null : (currentNode ?? this.currentNode),
    );
  }
}

class CharacterState {
  final String resourceId;
  final String? pose;
  final String? expression;
  final String? positionId;

  CharacterState({required this.resourceId, this.pose, this.expression, this.positionId});

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
  final Map<String, int> labelIndexMap;

  GameStateSnapshot({
    required this.scriptIndex,
    required this.currentState,
    required this.labelIndexMap,
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