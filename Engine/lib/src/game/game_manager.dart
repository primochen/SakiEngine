import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sakiengine/src/config/asset_manager.dart';
import 'package:sakiengine/src/config/config_models.dart';
import 'package:sakiengine/src/config/config_parser.dart';
import 'package:sakiengine/src/sks_parser/sks_ast.dart';
import 'package:sakiengine/src/sks_parser/sks_parser.dart';

class GameManager {
  final _gameStateController = StreamController<GameState>.broadcast();
  Stream<GameState> get gameStateStream => _gameStateController.stream;

  late GameState _currentState;
  late ScriptNode _script;
  int _scriptIndex = 0;
  bool _isProcessing = false;
  Map<String, int> _labelIndexMap = {};
  
  // 跨文件标签支持
  Map<String, String> _globalLabelMap = {}; // label -> filename
  Map<String, ScriptNode> _loadedScripts = {}; // filename -> script
  String _currentScriptFile = '';

  Map<String, CharacterConfig> _characterConfigs = {};
  Map<String, PoseConfig> _poseConfigs = {};
  VoidCallback? onReturn;
  
  GameStateSnapshot? _savedSnapshot;
  
  List<DialogueHistoryEntry> _dialogueHistory = [];
  static const int maxHistoryEntries = 100;

  // Getters for accessing configurations
  Map<String, PoseConfig> get poseConfigs => _poseConfigs;

  GameManager({this.onReturn});

  Future<void> _loadConfigs() async {
    final charactersContent = await AssetManager().loadString('assets/GameScript/configs/characters.sks');
    _characterConfigs = ConfigParser().parseCharacters(charactersContent);

    final posesContent = await AssetManager().loadString('assets/GameScript/configs/poses.sks');
    _poseConfigs = ConfigParser().parsePoses(posesContent);
  }

  Future<void> startGame(String scriptName) async {
    await _loadConfigs();
    await _buildGlobalLabelMap(); // 构建全局标签映射
    await _loadScript(scriptName);
    _currentState = GameState.initial();
    _dialogueHistory = [];
    _executeScript();
  }
  
  // 构建全局标签映射，扫描所有脚本文件
  Future<void> _buildGlobalLabelMap() async {
    _globalLabelMap = {};
    _loadedScripts = {};
    
    try {
      // 获取所有 .sks 文件
      final scriptFiles = await AssetManager().listAssets('assets/GameScript/labels/', '.sks');
      
      for (final fileName in scriptFiles) {
        final fileNameWithoutExt = fileName.replaceAll('.sks', '');
        try {
          final scriptContent = await AssetManager().loadString('assets/GameScript/labels/$fileName');
          final script = SksParser().parse(scriptContent);
          _loadedScripts[fileNameWithoutExt] = script;
          
          // 扫描该文件中的所有标签
          for (final node in script.children) {
            if (node is LabelNode) {
              _globalLabelMap[node.name] = fileNameWithoutExt;
              if (kDebugMode) {
                print('[GameManager] 发现标签: ${node.name} 在文件 $fileNameWithoutExt 中');
              }
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('[GameManager] 加载脚本文件失败: $fileName - $e');
          }
        }
      }
      
      if (kDebugMode) {
        print('[GameManager] 全局标签映射构建完成，共 ${_globalLabelMap.length} 个标签');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[GameManager] 构建全局标签映射失败: $e');
      }
    }
  }
  
  // 加载指定脚本文件
  Future<void> _loadScript(String scriptName) async {
    _currentScriptFile = scriptName;
    if (_loadedScripts.containsKey(scriptName)) {
      _script = _loadedScripts[scriptName]!;
    } else {
      final scriptContent = await AssetManager().loadString('assets/GameScript/labels/$scriptName.sks');
      _script = SksParser().parse(scriptContent);
      _loadedScripts[scriptName] = _script;
    }
    _buildLabelIndexMap();
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

  Future<void> jumpToLabel(String label) async {
    // 首先检查当前脚本中是否有该标签
    if (_labelIndexMap.containsKey(label)) {
      _scriptIndex = _labelIndexMap[label]!;
      _currentState = _currentState.copyWith(forceNullCurrentNode: true);
      _executeScript();
      return;
    }
    
    // 检查全局标签映射
    if (_globalLabelMap.containsKey(label)) {
      final targetFile = _globalLabelMap[label]!;
      if (kDebugMode) {
        print('[GameManager] 跨文件跳转: $label -> $targetFile');
      }
      
      // 加载目标文件
      await _loadScript(targetFile);
      
      // 跳转到目标标签
      if (_labelIndexMap.containsKey(label)) {
        _scriptIndex = _labelIndexMap[label]!;
        _currentState = _currentState.copyWith(forceNullCurrentNode: true);
        _executeScript();
      } else {
        if (kDebugMode) {
          print('[GameManager] 警告: 标签 $label 在文件 $targetFile 中未找到');
        }
      }
    } else {
      if (kDebugMode) {
        print('[GameManager] 错误: 标签 $label 未找到');
      }
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
          pose: node.pose,
          expression: node.expression,
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
        
        _currentState = _currentState.copyWith(
          dialogue: node.dialogue,
          speaker: characterConfig?.name,
          poseConfigs: _poseConfigs,
          currentNode: null,
          clearDialogueAndSpeaker: false,
          forceNullSpeaker: node.character == null,
        );

        _addToDialogueHistory(
          speaker: characterConfig?.name,
          dialogue: node.dialogue,
          timestamp: DateTime.now(),
          currentNodeIndex: _scriptIndex - 1,
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
      
      if (node is JumpNode) {
        _isProcessing = false;
        jumpToLabel(node.targetLabel);
        return;
      }
    }
    _isProcessing = false;
  }

  GameStateSnapshot saveStateSnapshot() {
    return GameStateSnapshot(
      scriptIndex: _scriptIndex,
      currentState: _currentState,
      dialogueHistory: List.from(_dialogueHistory),
    );
  }

  Future<void> restoreFromSnapshot(String scriptName, GameStateSnapshot snapshot, {bool shouldReExecute = true}) async {
    await _loadConfigs();
    final scriptContent =
        await AssetManager().loadString('assets/GameScript/labels/$scriptName.sks');
    _script = SksParser().parse(scriptContent);
    _buildLabelIndexMap();
    
    _scriptIndex = snapshot.scriptIndex;
    _currentState = snapshot.currentState.copyWith(poseConfigs: _poseConfigs);
    if (snapshot.dialogueHistory.isNotEmpty) {
      _dialogueHistory = List.from(snapshot.dialogueHistory);
    }
    
    if (shouldReExecute) {
      _isProcessing = false;
      _executeScript();
    } else {
      _isProcessing = false;
      _gameStateController.add(_currentState);
    }
  }

  Future<void> hotReload(String scriptName) async {
    if (_dialogueHistory.isNotEmpty) {
      _dialogueHistory.removeLast();
    }
    
    _savedSnapshot = saveStateSnapshot();
    
    await _loadConfigs();
    final scriptContent =
        await AssetManager().loadString('assets/GameScript/labels/$scriptName.sks');
    _script = SksParser().parse(scriptContent);
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
      );
      
      _isProcessing = false;
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
    // 为历史条目创建快照时，不包含历史记录本身，以避免循环引用。
    final snapshot = GameStateSnapshot(
      scriptIndex: _scriptIndex,
      currentState: _currentState,
      dialogueHistory: const [], 
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
  final SksNode? currentNode;

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
    SksNode? currentNode,
    bool clearDialogueAndSpeaker = false,
    bool forceNullCurrentNode = false,
    bool forceNullSpeaker = false,
  }) {
    return GameState(
      background: background ?? this.background,
      characters: characters ?? this.characters,
      dialogue: clearDialogueAndSpeaker ? null : (dialogue ?? this.dialogue),
      speaker: forceNullSpeaker
          ? null
          : (clearDialogueAndSpeaker ? null : (speaker ?? this.speaker)),
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

  GameStateSnapshot({
    required this.scriptIndex,
    required this.currentState,
    this.dialogueHistory = const [],
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
