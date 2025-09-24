import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/asset_manager.dart';
import 'package:sakiengine/src/config/config_models.dart';
import 'package:sakiengine/src/config/config_parser.dart';
import 'package:sakiengine/src/sks_parser/sks_ast.dart';
import 'package:sakiengine/src/game/script_merger.dart';
import 'package:sakiengine/src/widgets/common/black_screen_transition.dart';
import 'package:sakiengine/src/effects/scene_filter.dart';
import 'package:sakiengine/src/effects/scene_transition_effects.dart';
import 'package:sakiengine/src/utils/music_manager.dart';
import 'package:sakiengine/src/utils/animation_manager.dart';
import 'package:sakiengine/src/utils/scene_animation_controller.dart';
import 'package:sakiengine/src/utils/character_position_animator.dart';
import 'package:sakiengine/src/utils/character_auto_distribution.dart';
import 'package:sakiengine/src/utils/rich_text_parser.dart';
import 'package:sakiengine/src/utils/global_variable_manager.dart';
import 'package:sakiengine/src/utils/webp_preload_cache.dart';
import 'package:sakiengine/src/rendering/color_background_renderer.dart';

/// 音乐区间类
/// 定义音乐播放的有效范围，从play music到下一个play music/stop music之间
class MusicRegion {
  final String musicFile; // 音乐文件名
  final int startScriptIndex; // 区间开始的脚本索引
  final int? endScriptIndex; // 区间结束的脚本索引（null表示区间还没结束）
  
  MusicRegion({
    required this.musicFile,
    required this.startScriptIndex,
    this.endScriptIndex,
  });
  
  /// 检查指定的脚本索引是否在音乐区间内
  bool containsIndex(int scriptIndex) {
    if (scriptIndex < startScriptIndex) return false;
    if (endScriptIndex != null && scriptIndex >= endScriptIndex!) return false;
    return true;
  }
  
  /// 创建一个新的区间，设置结束索引
  MusicRegion copyWithEndIndex(int endIndex) {
    return MusicRegion(
      musicFile: musicFile,
      startScriptIndex: startScriptIndex,
      endScriptIndex: endIndex,
    );
  }
  
  @override
  String toString() {
    return 'MusicRegion(musicFile: $musicFile, start: $startScriptIndex, end: $endScriptIndex)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MusicRegion) return false;
    return musicFile == other.musicFile && 
           startScriptIndex == other.startScriptIndex && 
           endScriptIndex == other.endScriptIndex;
  }
  
  @override
  int get hashCode {
    return Object.hash(musicFile, startScriptIndex, endScriptIndex);
  }
}

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
  TickerProvider? _tickerProvider;
  final Set<String> _everShownCharacters = {};
  
  // 快进状态
  bool _isFastForwardMode = false;
  
  // 场景动画控制器
  SceneAnimationController? _sceneAnimationController;
  
  // 角色位置动画管理器
  CharacterPositionAnimator? _characterPositionAnimator;
  
  /// 检测并播放角色属性变化动画（用于pose切换）
  Future<void> _checkAndAnimatePoseAttributeChanges({
    required String characterId,
    required String? oldPositionId,
    required String? newPositionId,
  }) async {
    if (_tickerProvider == null || oldPositionId == newPositionId) return;
    
    // 获取旧的和新的pose配置
    final oldPoseConfig = oldPositionId != null ? _poseConfigs[oldPositionId] : null;
    final newPoseConfig = newPositionId != null ? _poseConfigs[newPositionId] : null;
    
    if (oldPoseConfig == null || newPoseConfig == null) return;
    
    // 比较属性，创建变化描述
    final fromAttributes = <String, double>{
      'xcenter': oldPoseConfig.xcenter,
      'ycenter': oldPoseConfig.ycenter,
      'scale': oldPoseConfig.scale,
      'alpha': 1.0, // 暂时硬编码，后续可扩展
    };
    
    final toAttributes = <String, double>{
      'xcenter': newPoseConfig.xcenter,
      'ycenter': newPoseConfig.ycenter,
      'scale': newPoseConfig.scale,
      'alpha': 1.0, // 暂时硬编码，后续可扩展
    };
    
    final attributeChange = CharacterAttributeChange(
      characterId: characterId,
      fromAttributes: fromAttributes,
      toAttributes: toAttributes,
    );
    
    // 如果没有变化，跳过动画
    if (!attributeChange.hasChanges) return;
    
    //print('[PoseAttributeAnimation] 检测到属性变化: $characterId');
    //print('[PoseAttributeAnimation] 从 $oldPositionId 到 $newPositionId');
    //print('[PoseAttributeAnimation] 属性变化: $fromAttributes -> $toAttributes');
    
    // 停止之前的动画
    _characterPositionAnimator?.stop();
    _characterPositionAnimator = CharacterPositionAnimator();
    
    // 开始属性补间动画
    await _characterPositionAnimator!.animateAttributeChanges(
      attributeChanges: [attributeChange],
      vsync: _tickerProvider!,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      onUpdate: (attributesMap) {
        // 更新角色的动画属性
        final updatedCharacters = Map<String, CharacterState>.from(_currentState.characters);
        final attributes = attributesMap[characterId];
        
        if (attributes != null) {
          final character = updatedCharacters[characterId];
          if (character != null) {
            updatedCharacters[characterId] = character.copyWith(
              animationProperties: attributes,
            );
            
            // 立即更新状态以显示动画效果
            _currentState = _currentState.copyWith(characters: updatedCharacters);
            _gameStateController.add(_currentState);
          }
        }
      },
      onComplete: () {
        //print('[PoseAttributeAnimation] 属性动画完成: $characterId');
        // 动画完成后，清除动画属性，让角色使用新pose的正常属性
        final updatedCharacters = Map<String, CharacterState>.from(_currentState.characters);
        final character = updatedCharacters[characterId];
        if (character != null) {
          updatedCharacters[characterId] = character.copyWith(
            animationProperties: null, // 清除动画属性，回到新pose的基础位置
          );
          _currentState = _currentState.copyWith(characters: updatedCharacters);
          _gameStateController.add(_currentState);
        }
      },
    );
  }
  Future<void> _checkAndAnimateCharacterPositions(Map<String, CharacterState> newCharacters) async {
    if (_tickerProvider == null) return;
    
    //print('[CharacterPositionAnimation] 检测位置变化...');
    //print('[CharacterPositionAnimation] 旧角色: ${_currentState.characters.keys.toList()}');
    //print('[CharacterPositionAnimation] 新角色: ${newCharacters.keys.toList()}');
    
    // 检测位置变化
    final characterOrder = newCharacters.keys.toList();
    final positionChanges = CharacterAutoDistribution.calculatePositionChanges(
      _currentState.characters, 
      newCharacters, 
      _poseConfigs, 
      _poseConfigs,
      characterOrder,
    );
    
    //print('[CharacterPositionAnimation] 检测到 ${positionChanges.length} 个位置变化');
    for (final change in positionChanges) {
      //print('[CharacterPositionAnimation] ${change.characterId}: ${change.fromX} -> ${change.toX}');
    }
    
    if (positionChanges.isNotEmpty) {
      // 如果有位置变化，播放动画
      _characterPositionAnimator?.stop();
      _characterPositionAnimator = CharacterPositionAnimator();
      
      //print('[CharacterPositionAnimation] 开始播放位置动画...');
      
      await _characterPositionAnimator!.animatePositionChanges(
        positionChanges: positionChanges,
        vsync: _tickerProvider!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        onUpdate: (positions) {
          // 更新角色的动画属性
          final updatedCharacters = Map<String, CharacterState>.from(_currentState.characters);
          for (final entry in positions.entries) {
            final characterId = entry.key;
            final xPosition = entry.value;
            final character = updatedCharacters[characterId];
            if (character != null) {
              updatedCharacters[characterId] = character.copyWith(
                animationProperties: {
                  ...character.animationProperties ?? {},
                  'xcenter': xPosition,
                },
              );
            }
          }
          
          _currentState = _currentState.copyWith(characters: updatedCharacters);
          _gameStateController.add(_currentState);
        },
        onComplete: () {
          // 动画完成，清理动画属性
          //print('[CharacterPositionAnimation] 角色位置动画完成');
        },
      );
    } else {
      //print('[CharacterPositionAnimation] 无需位置动画');
    }
  }

  /// 分析脚本并预加载anime资源
  Future<void> _analyzeAndPreloadAnimeResources() async {
    final animeResources = <String>{};
    
    // 遍历整个脚本，收集所有anime命令
    for (int i = 0; i < _script.children.length; i++) {
      final node = _script.children[i];
      if (node is AnimeNode) {
        animeResources.add(node.animeName);
      }
    }
    
    if (animeResources.isEmpty) {
      return;
    }
    
    // 并发预加载所有anime资源
    final futures = animeResources.map((animeName) {
      return WebPPreloadCache().preloadWebP(animeName);
    }).toList();
    
    try {
      await Future.wait(futures);
    } catch (e) {
      if (kDebugMode) {
        ////print('[GameManager] anime资源预加载出现错误: $e');
      }
      rethrow;
    }
  }
  String? _findExistingCharacterKey(String resourceId) {
    ////print('[GameManager] 查找resourceId=$resourceId的角色，当前角色列表: ${_currentState.characters.keys}');
    for (final entry in _currentState.characters.entries) {
      ////print('[GameManager] 检查角色 ${entry.key}, resourceId=${entry.value.resourceId}');
      if (entry.value.resourceId == resourceId) {
        ////print('[GameManager] 找到匹配的角色: ${entry.key}');
        return entry.key;
      }
    }
    ////print('[GameManager] 未找到resourceId=$resourceId的角色');
    return null;
  }
  
  GameStateSnapshot? _savedSnapshot;
  
  List<DialogueHistoryEntry> _dialogueHistory = [];
  static const int maxHistoryEntries = 100;
  
  // 音乐区间管理
  final List<MusicRegion> _musicRegions = []; // 所有音乐区间的列表

  // Getters for accessing configurations
  Map<String, PoseConfig> get poseConfigs => _poseConfigs;
  String get currentScriptFile => _scriptMerger.getFileNameByIndex(_scriptIndex) ?? 'start';
  
  // 获取当前脚本执行索引（用于开发者面板定位）
  int get currentScriptIndex => _scriptIndex;
  
  // 获取当前对话文本（用于开发者面板定位）
  String get currentDialogueText => _dialogueHistory.isNotEmpty ? _dialogueHistory.last.dialogue : '';
  
  // 获取当前游戏状态（用于表情选择器）
  GameState get currentState => _currentState;
  
  // 获取角色配置（用于表情选择器）
  Map<String, CharacterConfig> get characterConfigs => _characterConfigs;
  
  // 快进模式控制
  bool get isFastForwardMode => _isFastForwardMode;
  void setFastForwardMode(bool enabled) {
    _isFastForwardMode = enabled;
    // 更新GameState中的快进状态
    _currentState = _currentState.copyWith(isFastForwarding: enabled, everShownCharacters: _everShownCharacters);
    _gameStateController.add(_currentState);
    //print('[FastForward] 快进模式: ${enabled ? "开启" : "关闭"}');
  }
  
  // 自动播放模式控制
  bool _isAutoPlayMode = false;
  bool get isAutoPlayMode => _isAutoPlayMode;
  void setAutoPlayMode(bool enabled) {
    _isAutoPlayMode = enabled;
    // 更新GameState中的自动播放状态
    _currentState = _currentState.copyWith(isAutoPlaying: enabled, everShownCharacters: _everShownCharacters);
    _gameStateController.add(_currentState);
    //print('[AutoPlay] 自动播放模式: ${enabled ? "开启" : "关闭"}');
  }
  
  /// 检测背景名称是否包含章节信息
  /// 检测规则：包含以下关键字之一（不区分大小写）：
  /// - "chapter" 
  /// - "ch" (后跟数字)
  /// - "ep" (episode的缩写)
  /// - "prologue" (序章)
  /// - "epilogue" (尾声)
  bool _containsChapter(String backgroundName) {
    final lowerName = backgroundName.toLowerCase();
    
    // 检测常见的章节标识
    if (lowerName.contains('chapter') || 
        lowerName.contains('prologue') || 
        lowerName.contains('epilogue')) {
      return true;
    }
    
    // 检测 ch + 数字 的模式（如 ch1, ch01, chapter1 等）
    if (RegExp(r'\bch\d+\b').hasMatch(lowerName)) {
      return true;
    }
    
    // 检测 ep + 数字 的模式（如 ep1, ep01 等）
    if (RegExp(r'\bep\d+\b').hasMatch(lowerName)) {
      return true;
    }
    
    return false;
  }

  /// 检查当前场景是否包含章节标识
  /// 用于决定是否应该隐藏快捷菜单
  bool get isCurrentSceneChapter {
    // 检查当前背景是否包含章节标识
    final currentBg = _currentState.background;
    if (currentBg != null && _containsChapter(currentBg)) {
      return true;
    }
    
    // 检查当前视频是否包含章节标识
    final currentMovie = _currentState.movieFile;
    if (currentMovie != null && _containsChapter(currentMovie)) {
      return true;
    }
    
    return false;
  }

  GameManager({this.onReturn}) {
    _currentState = GameState.initial(); // 提前初始化，避免late变量访问错误
  }

  /// 设置BuildContext用于转场效果
  void setContext(BuildContext context, [TickerProvider? tickerProvider]) {
    //////print('[GameManager] 设置上下文用于转场效果');
    _context = context;
    _tickerProvider = tickerProvider;
    
    // 如果当前状态有场景动画且之前没有TickerProvider，现在检测并启动动画
    if (tickerProvider != null && _sceneAnimationController == null) {
      // 延迟一点时间执行动画检测，确保context完全设置好
      Future.delayed(const Duration(milliseconds: 50), () async {
        if (_tickerProvider != null) {
          await _checkAndRestoreSceneAnimation();
        }
      });
    }
  }

  /// 构建音乐区间列表
  /// 遍历整个脚本，找出所有的play music和stop music节点，创建音乐区间
  void _buildMusicRegions() {
    _musicRegions.clear();
    
    MusicRegion? currentRegion;
    
    for (int i = 0; i < _script.children.length; i++) {
      final node = _script.children[i];
      
      if (node is PlayMusicNode) {
        // 结束当前区间（如果有的话）
        if (currentRegion != null) {
          _musicRegions.add(currentRegion.copyWithEndIndex(i));
        }
        
        // 开始新的音乐区间
        currentRegion = MusicRegion(
          musicFile: node.musicFile,
          startScriptIndex: i,
        );
        if (kDebugMode) {
          //print('[MusicRegion] 开始新音乐区间: ${node.musicFile} at index $i');
        }
      } else if (node is StopMusicNode) {
        // 结束当前区间
        if (currentRegion != null) {
          _musicRegions.add(currentRegion.copyWithEndIndex(i));
          if (kDebugMode) {
            //print('[MusicRegion] 结束音乐区间: ${currentRegion.musicFile} at index $i');
          }
          currentRegion = null;
        }
      }
    }
    
    // 如果脚本结束时还有未结束的音乐区间，添加它
    if (currentRegion != null) {
      _musicRegions.add(currentRegion);
      if (kDebugMode) {
        //print('[MusicRegion] 脚本结束，添加未结束的音乐区间: ${currentRegion.musicFile}');
      }
    }
    
    if (kDebugMode) {
      //print('[MusicRegion] 总共构建了 ${_musicRegions.length} 个音乐区间');
      for (final region in _musicRegions) {
        //print('[MusicRegion] $region');
      }
    }
  }

  /// 获取指定脚本索引处应该播放的音乐区间
  MusicRegion? _getMusicRegionForIndex(int scriptIndex) {
    for (final region in _musicRegions) {
      if (region.containsIndex(scriptIndex)) {
        return region;
      }
    }
    return null;
  }

  /// 检查当前位置是否应该播放音乐
  /// 如果当前位置不在任何音乐区间内，则停止音乐
  Future<void> _checkMusicRegionAtCurrentIndex({bool forceCheck = false}) async {
    final currentRegion = _getMusicRegionForIndex(_scriptIndex);
    final stateRegion = _currentState.currentMusicRegion;
    
    if (kDebugMode) {
      //print('[MusicRegion] 检查位置($_scriptIndex): currentRegion=${currentRegion?.toString() ?? 'null'}, stateRegion=${stateRegion?.toString() ?? 'null'}');
    }
    
    // 强制检查时，即使区间相同也要验证音乐状态
    if (forceCheck || currentRegion != stateRegion) {
      if (currentRegion == null) {
        // 当前位置不在任何音乐区间内，应该停止音乐
        if (kDebugMode) {
          //print('[MusicRegion] 当前位置($_scriptIndex)不在音乐区间内，停止音乐');
        }
        await MusicManager().forceStopBackgroundMusic(
          fadeOut: true,
          fadeDuration: const Duration(milliseconds: 800),
        );
        _currentState = _currentState.copyWith(currentMusicRegion: null);
      } else {
        // 当前位置在音乐区间内
        String musicFile = currentRegion.musicFile;
        if (!musicFile.contains('.')) {
          musicFile = '$musicFile.mp3';
        }
        final fullMusicPath = 'Assets/music/$musicFile';
        
        // 检查是否需要开始播放或切换音乐
        if (stateRegion == null || 
            stateRegion.musicFile != currentRegion.musicFile || 
            !MusicManager().isPlayingMusic(fullMusicPath) || 
            forceCheck) {
          
          if (kDebugMode) {
            //print('[MusicRegion] 当前位置($_scriptIndex)需要播放音乐: ${currentRegion.musicFile}');
          }
          
          await MusicManager().playBackgroundMusic(
            fullMusicPath,
            fadeTransition: true,
            fadeDuration: const Duration(milliseconds: 1200),
          );
          _currentState = _currentState.copyWith(currentMusicRegion: currentRegion);
        }
      }
    }
  }

  Future<void> _loadConfigs() async {
    final charactersContent = await AssetManager().loadString('assets/GameScript/configs/characters.sks');
    _characterConfigs = ConfigParser().parseCharacters(charactersContent);

    final posesContent = await AssetManager().loadString('assets/GameScript/configs/poses.sks');
    _poseConfigs = ConfigParser().parsePoses(posesContent);
  }

  Future<void> startGame(String scriptName) async {
    // 平滑清除主菜单音乐
    await MusicManager().clearBackgroundMusic(
      fadeOut: true,
      fadeDuration: const Duration(milliseconds: 1000),
    );
    
    await _loadConfigs();
    await GlobalVariableManager().init(); // 初始化全局变量管理器
    
    // 打印所有全局变量的值
    final allVars = GlobalVariableManager().getAllVariables();
    print('=== 游戏启动 - 全局变量状态 ===');
    if (allVars.isEmpty) {
      print('暂无全局变量');
    } else {
      allVars.forEach((name, value) {
        print('全局变量: $name = $value');
      });
    }
    print('=== 全局变量状态结束 ===');
    
    await AnimationManager.loadAnimations(); // 加载动画
    _script = await _scriptMerger.getMergedScript();
    _buildLabelIndexMap();
    _buildMusicRegions(); // 构建音乐区间
    
    // 预加载anime资源（同步执行，确保能看到错误）
    try {
      await _analyzeAndPreloadAnimeResources();
    } catch (e) {
      if (kDebugMode) {
        ////print('[GameManager] 预加载anime资源失败: $e');
      }
    }
    
    _currentState = GameState.initial();
    _dialogueHistory = [];
    
    // 如果指定了非 start 脚本，跳转到对应位置
    if (scriptName != 'start') {
      final startIndex = _scriptMerger.getFileStartIndex(scriptName);
      if (startIndex != null) {
        _scriptIndex = startIndex;
      }
    }
    
    // 检查初始位置的音乐区间
    await _checkMusicRegionAtCurrentIndex(forceCheck: true);
    
    await _executeScript();
  }
  
  void _buildLabelIndexMap() {
    _labelIndexMap = {};
    for (int i = 0; i < _script.children.length; i++) {
      final node = _script.children[i];
      if (node is LabelNode) {
        _labelIndexMap[node.name] = i;
        if (kDebugMode) {
          //////print('[GameManager] 标签映射: ${node.name} -> $i');
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
        //////print('[GameManager] 跳转到标签: $label, 索引: $_scriptIndex');
      }
      
      // 检查跳转后位置的音乐区间（强制检查）
      await _checkMusicRegionAtCurrentIndex(forceCheck: true);
      await _executeScript();
    } else {
      if (kDebugMode) {
        //////print('[GameManager] 错误: 标签 $label 未找到');
      }
    }
  }

  void next() async {
    // 检查是否需要清除anime覆盖层（在用户交互时）
    if (_currentState.animeOverlay != null && !_currentState.animeKeep) {
      ////print('[GameManager] 用户点击继续，清除anime覆盖层: ${_currentState.animeOverlay}');
      _currentState = _currentState.copyWith(
        clearAnimeOverlay: true,
        everShownCharacters: _everShownCharacters,
      );
      _gameStateController.add(_currentState);
    }
    
    // 在用户点击继续时检查音乐区间
    await _checkMusicRegionAtCurrentIndex();
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

  /// 视频播放完成后继续执行脚本
  void executeScriptAfterMovie() {
    //print('[GameManager] 视频播放完成，开始黑屏转场');
    
    // 如果有context，使用转场效果；否则直接切换
    if (_context != null) {
      TransitionOverlayManager.instance.transition(
        context: _context!,
        duration: const Duration(milliseconds: 600), // 转场时长
        onMidTransition: () {
          // 在黑屏最深时清理movie状态并继续执行脚本
          //print('[GameManager] 转场中点：清理movie状态并继续执行脚本');
          _currentState = _currentState.copyWith(
            clearMovieFile: true, // 清理视频文件
          );
          _gameStateController.add(_currentState);
          _executeScript();
        },
      );
    } else {
      // 兼容性处理：如果没有context，直接切换
      //print('[GameManager] 无context，直接清理movie状态并继续执行脚本');
      _currentState = _currentState.copyWith(
        clearMovieFile: true, // 清理视频文件
      );
      _gameStateController.add(_currentState);
      _executeScript();
    }
  }

  Future<void> _executeScript() async {
    if (_isProcessing || _isWaitingForTimer) {
      return;
    }
    _isProcessing = true;

    //print('🎮 开始处理脚本，当前索引: $_scriptIndex');
    
    while (_scriptIndex < _script.children.length) {
      final node = _script.children[_scriptIndex];
      ////print('[GameManager] 处理脚本索引 $_scriptIndex: ${node.runtimeType}');
      final currentNodeIndex = _scriptIndex; // 保存当前节点索引
      //print('🎮 处理节点[$_scriptIndex]: ${node.runtimeType} - $node');

      // 跳过注释节点（文件边界标记）
      if (node is CommentNode) {
        if (kDebugMode) {
          //////print('[GameManager] 跳过注释: ${node.comment}');
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
        // 检测是否包含chapter，如果是则停止快进
        if (_isFastForwardMode && _containsChapter(node.background)) {
          //print('[GameManager] 检测到chapter场景，停止快进: ${node.background}');
          setFastForwardMode(false);
          // 通知UI层快进状态已改变，这样快进指示器会消失
          // GameState已在setFastForwardMode中更新
        }
        
        // 检查是否要清空CG状态
        // 如果新背景不是CG且当前有CG显示，则清空CG
        final isNewBackgroundCG = node.background.toLowerCase().contains('cg');
        final shouldClearCG = !isNewBackgroundCG && _currentState.cgCharacters.isNotEmpty;
        
        if (shouldClearCG) {
          ////print('[GameManager] 切换到非CG背景，清空CG状态');
        }
        
        // 检查下一个节点是否是FxNode，如果是则一起处理
        SceneFilter? sceneFilter;
        int nextIndex = _scriptIndex + 1;
        if (nextIndex < _script.children.length && _script.children[nextIndex] is FxNode) {
          final fxNode = _script.children[nextIndex] as FxNode;
          sceneFilter = SceneFilter.fromString(fxNode.filterString);
        }
        
        // 检查是否是游戏开始时的初始背景设置
        final isInitialBackground = _currentState.background == null && _currentState.cgCharacters.isEmpty;
        final isSameBackground = _currentState.background == node.background;
        // 检查是否从CG切换到场景，如果是则强制使用转场效果
        final isFromCGToScene = _currentState.cgCharacters.isNotEmpty && !node.background.toLowerCase().contains('cg');
        
        // 快进模式下跳过转场效果，或其他需要跳过转场的情况
        // 但从CG切换到场景时必须使用转场效果
        if ((_isFastForwardMode || _context == null || isInitialBackground || isSameBackground) && !isFromCGToScene) {
          ////print('[GameManager] 跳过转场：${_isFastForwardMode ? "快进模式" : (isInitialBackground ? "初始背景" : (isSameBackground ? "相同背景" : "无context"))}');
          // 直接切换背景
          _currentState = _currentState.copyWith(
              background: node.background, 
              movieFile: null, // 新增：scene命令清理视频状态
              clearMovieFile: true, // 修复：使用clearMovieFile标志确保视频状态被清理
              sceneFilter: sceneFilter,
              clearSceneFilter: sceneFilter == null,
              sceneLayers: node.layers,
              clearSceneLayers: node.layers == null,
              clearDialogueAndSpeaker: !isSameBackground,
              clearCharacters: !isSameBackground, // 新增：非相同背景时清除所有角色立绘
              sceneAnimation: node.animation,
              sceneAnimationRepeat: node.repeatCount,
              sceneAnimationProperties: (node.animation != null && !isSameBackground) ? <String, double>{} : null,
              clearSceneAnimation: node.animation == null,
              clearCgCharacters: shouldClearCG,
              everShownCharacters: _everShownCharacters);
          //print('[GameManager] Scene命令清理movie状态: 新状态 movieFile=${_currentState.movieFile}, background=${_currentState.background}');
          _gameStateController.add(_currentState);
          
          // 快进模式下跳过场景动画
          if (!_isFastForwardMode && node.animation != null && _tickerProvider != null) {
            _startSceneAnimation(node.animation!, node.repeatCount);
          }
          
          // 快进模式下跳过计时器
          if (!_isFastForwardMode && node.timer != null && node.timer! > 0) {
            _startSceneTimer(node.timer!);
            return;
          }
        } else {
          // 需要使用转场效果
          // 立即递增索引，如果有fx节点也跳过
          _scriptIndex += sceneFilter != null ? 2 : 1;
          
          // 如果没有指定timer，默认使用0.01秒，确保转场后正确执行后续脚本
          final timerDuration = node.timer ?? 0.01;
          
          // 提前设置计时器等待标志
          _isWaitingForTimer = true;
          _isProcessing = false; // 释放当前处理锁，但保持timer锁
          
          // 检查是否是CG到CG的转场，如果是且没有指定转场类型，则使用dissolve
          // 同时检查从CG切换到普通场景的情况
          String? finalTransitionType = node.transitionType;
          final currentBg = _currentState.background;
          final newBg = node.background;
          final isCurrentCG = currentBg != null && currentBg.toLowerCase().contains('cg');
          final isNewCG = newBg.toLowerCase().contains('cg');
          final hasCurrentCGCharacters = _currentState.cgCharacters.isNotEmpty;
          
          if ((isCurrentCG && isNewCG) || (hasCurrentCGCharacters && isNewCG)) {
            if (finalTransitionType == null) {
              finalTransitionType = 'diss'; // CG到CG默认使用dissolve转场
              ////print('[GameManager] CG到CG转场，使用默认dissolve效果');
            }
          } else if (hasCurrentCGCharacters && !isNewCG && finalTransitionType == null) {
            // 从CG切换到普通场景，默认使用fade转场
            finalTransitionType = 'fade';
            ////print('[GameManager] 从CG切换到场景，使用默认fade效果');
          }
          
          _transitionToNewBackground(node.background, sceneFilter, node.layers, finalTransitionType, node.animation, node.repeatCount, shouldClearCG).then((_) {
            // 转场完成后启动计时器
            _startSceneTimer(timerDuration);
          });
          return; // 转场过程中暂停脚本执行，将在转场完成后自动恢复
        }
        
        // 如果有fx节点也跳过
        _scriptIndex += sceneFilter != null ? 2 : 1;
        continue;
      }

      if (node is MovieNode) {
        // Movie处理逻辑，类似BackgroundNode但用于视频播放
        // 检测是否包含chapter，如果是则停止快进
        if (_isFastForwardMode && _containsChapter(node.movieFile)) {
          //print('[GameManager] 检测到chapter视频，停止快进: ${node.movieFile}');
          setFastForwardMode(false);
        }
        
        // 清空CG状态和角色立绘，因为视频会全屏显示
        final shouldClearAll = true;
        
        // 检查下一个节点是否是FxNode，如果是则一起处理
        SceneFilter? sceneFilter;
        int nextIndex = _scriptIndex + 1;
        if (nextIndex < _script.children.length && _script.children[nextIndex] is FxNode) {
          final fxNode = _script.children[nextIndex] as FxNode;
          sceneFilter = SceneFilter.fromString(fxNode.filterString);
        }
        
        // 检查是否是游戏开始时的初始视频
        final isInitialMovie = _currentState.movieFile == null;
        final isSameMovie = _currentState.movieFile == node.movieFile;
        
        // 快进模式下跳过转场效果，或其他需要跳过转场的情况
        if (_isFastForwardMode || _context == null || isInitialMovie || isSameMovie) {
          // 直接切换到视频
          _currentState = _currentState.copyWith(
              movieFile: node.movieFile,
              movieRepeatCount: node.repeatCount, // 新增：传递视频重复播放次数
              background: null, // 清空背景，视频优先显示
              sceneFilter: sceneFilter,
              clearSceneFilter: sceneFilter == null,
              sceneLayers: node.layers,
              clearSceneLayers: node.layers == null,
              clearDialogueAndSpeaker: true,
              clearCharacters: true, // 清除所有角色立绘
              clearCgCharacters: true, // 清除CG
              sceneAnimation: node.animation,
              sceneAnimationRepeat: node.repeatCount,
              sceneAnimationProperties: (node.animation != null && !isSameMovie) ? <String, double>{} : null,
              clearSceneAnimation: node.animation == null,
              everShownCharacters: _everShownCharacters);
          _gameStateController.add(_currentState);
          
          // 快进模式下跳过计时器，但正常模式下需要等待视频播放完成
          if (!_isFastForwardMode) {
            // 设置处理锁，等待视频播放完成后再继续
            _isProcessing = false;
            // 脚本索引推进，避免重复执行当前节点
            _scriptIndex += sceneFilter != null ? 2 : 1;
            return; // 等待视频播放完成的回调
          } else {
            // 快进模式下跳过视频等待
            if (node.timer != null && node.timer! > 0) {
              _startSceneTimer(node.timer!);
              return;
            }
          }
        } else {
          // 需要使用转场效果
          _scriptIndex += sceneFilter != null ? 2 : 1;
          
          final timerDuration = node.timer ?? 0.01;
          
          _isWaitingForTimer = true;
          _isProcessing = false;
          
          _transitionToNewMovie(node.movieFile, sceneFilter, node.layers, node.transitionType, node.animation, node.repeatCount).then((_) {
            _startSceneTimer(timerDuration);
          });
          return;
        }
        
        // 如果有fx节点也跳过
        _scriptIndex += sceneFilter != null ? 2 : 1;
        continue;
      }

      if (node is AnimeNode) {
        ////print('[GameManager] 处理AnimeNode: ${node.animeName}, loop: ${node.loop}, keep: ${node.keep}');
        
        // 快进模式下跳过anime显示
        if (!_isFastForwardMode) {
          // 正常模式下显示anime
          _currentState = _currentState.copyWith(
            animeOverlay: node.animeName,
            animeLoop: node.loop,
            animeKeep: node.keep,
            clearDialogueAndSpeaker: true,
            everShownCharacters: _everShownCharacters,
          );
          _gameStateController.add(_currentState);
        }
        
        // 快进模式下跳过计时器
        if (!_isFastForwardMode && node.timer != null && node.timer! > 0) {
          _isWaitingForTimer = true;
          _startSceneTimer(node.timer!);
          return; // 等待计时器结束
        }
        
        _scriptIndex++;
        continue;
      }

      if (node is ShowNode) {
        // 检查是否有CG正在显示，如果有则跳过立绘显示
        if (_currentState.cgCharacters.isNotEmpty) {
          ////print('[GameManager] CG正在显示，跳过ShowNode: ${node.character}');
          _scriptIndex++;
          continue;
        }
        
        ////print('[GameManager] 处理ShowNode: character=${node.character}, pose=${node.pose}, expression=${node.expression}, position=${node.position}, animation=${node.animation}');
        // 优先使用角色配置，如果没有配置则直接使用资源ID
        final characterConfig = _characterConfigs[node.character];
        String resourceId;
        String positionId;
        String finalCharacterKey; // 最终使用的角色key
        
        if (characterConfig != null) {
          ////print('[GameManager] 使用角色配置: ${characterConfig.id}');
          resourceId = characterConfig.resourceId;
          positionId = characterConfig.defaultPoseId ?? 'pose';
          finalCharacterKey = resourceId; // 使用resourceId作为key
        } else {
          ////print('[GameManager] 直接使用资源ID: ${node.character}');
          resourceId = node.character;
          positionId = node.position ?? 'pose';
          finalCharacterKey = node.character; // 使用原始名称作为key
        }

        // 跟踪角色是否曾经显示过
        _everShownCharacters.add(finalCharacterKey);

        final newCharacters = Map.of(_currentState.characters);
        
        final currentCharacterState = _currentState.characters[finalCharacterKey] ?? CharacterState(
          resourceId: resourceId,
          positionId: positionId,
        );
        
        // 检测角色位置变化并触发动画（如果需要）
        // 先将新角色添加到临时角色列表，然后检测位置变化
        final tempCharacters = Map.of(newCharacters);
        
        // 清理现有角色的动画属性，确保位置计算基于基础位置
        for (final entry in tempCharacters.entries) {
          tempCharacters[entry.key] = entry.value.copyWith(
            clearAnimationProperties: true, // 清理动画属性
          );
        }
        
        tempCharacters[finalCharacterKey] = currentCharacterState.copyWith(
          pose: node.pose,
          expression: node.expression,
          clearAnimationProperties: false,
        );
        
        // 快进模式下跳过位置动画
        if (!_isFastForwardMode) {
          await _checkAndAnimateCharacterPositions(tempCharacters);
        }

        newCharacters[finalCharacterKey] = currentCharacterState.copyWith(
          pose: node.pose,
          expression: node.expression,
          clearAnimationProperties: false,
        );
        
        _currentState =
            _currentState.copyWith(characters: newCharacters, clearDialogueAndSpeaker: true, everShownCharacters: _everShownCharacters);
        _gameStateController.add(_currentState);
        
        // 如果有动画，启动动画播放（非阻塞）
        if (!_isFastForwardMode && node.animation != null) {
          _playCharacterAnimation(finalCharacterKey, node.animation!, repeatCount: node.repeatCount);
        }
        
        _scriptIndex++;
        continue;
      }

      if (node is CgNode) {
        if (kDebugMode) {
          //print('[GameManager] 处理CgNode: character=${node.character}, pose=${node.pose}, expression=${node.expression}, position=${node.position}, animation=${node.animation}');
        }
        
        // CG显示命令，类似ShowNode但渲染方式像scene一样铺满
        final characterConfig = _characterConfigs[node.character];
        String resourceId;
        String positionId;
        String finalCharacterKey; // 最终使用的角色key
        
        if (characterConfig != null) {
          if (kDebugMode) {
            //print('[GameManager] 使用角色配置: ${characterConfig.id}');
          }
          resourceId = characterConfig.resourceId;
          positionId = characterConfig.defaultPoseId ?? 'pose';
          finalCharacterKey = resourceId; // 使用resourceId作为key
        } else {
          if (kDebugMode) {
            //print('[GameManager] 直接使用资源ID: ${node.character}');
          }
          resourceId = node.character;
          positionId = node.position ?? 'pose';
          finalCharacterKey = node.character; // 使用原始名称作为key
        }

        // 确保pose和expression的值被正确设置
        final newPose = node.pose ?? 'pose1';
        final newExpression = node.expression ?? 'happy';
        
        if (kDebugMode) {
          //print('[GameManager] CG参数: resourceId=$resourceId, pose=$newPose, expression=$newExpression, finalKey=$finalCharacterKey');
        }
        
        // CG只通过CG角色系统处理，不设置为背景
        // 先清除背景，确保CG角色层可以正常显示
        _currentState = _currentState.copyWith(
          background: null, // 清除背景，让CG角色层显示
          clearSceneFilter: true,
          clearSceneLayers: true,
          clearSceneAnimation: true,
          everShownCharacters: _everShownCharacters
        );
        
        if (kDebugMode) {
          //print('[GameManager] 已清除背景，准备显示CG角色');
        }

        // 跟踪角色是否曾经显示过
        _everShownCharacters.add(finalCharacterKey);

        final newCgCharacters = Map.of(_currentState.cgCharacters);
        
        final currentCharacterState = _currentState.cgCharacters[finalCharacterKey] ?? CharacterState(
          resourceId: resourceId,
          positionId: positionId,
        );
        
        if (kDebugMode) {
          //print('[GameManager] CG更新前: cgCharacters数量=${_currentState.cgCharacters.length}');
        }

        newCgCharacters[finalCharacterKey] = currentCharacterState.copyWith(
          pose: newPose,
          expression: newExpression,
          clearAnimationProperties: false,
        );
        
        _currentState = _currentState.copyWith(
          cgCharacters: newCgCharacters, 
          clearDialogueAndSpeaker: true, 
          everShownCharacters: _everShownCharacters
        );
        _gameStateController.add(_currentState);
        
        if (kDebugMode) {
          //print('[GameManager] CG状态已更新，当前CG角色数量: ${_currentState.cgCharacters.length}');
          //print('[GameManager] CG角色列表: ${_currentState.cgCharacters.keys.toList()}');
        }
        
        // 如果有动画，启动动画播放（非阻塞）
        if (!_isFastForwardMode && node.animation != null) {
          _playCharacterAnimation(finalCharacterKey, node.animation!, repeatCount: node.repeatCount);
        }
        
        _scriptIndex++;
        continue;
      }

      if (node is HideNode) {
        final newCharacters = Map.of(_currentState.characters);
        final character = newCharacters[node.character];
        
        if (character != null) {
          // 不立即移除角色，而是标记为正在淡出
          newCharacters[node.character] = character.copyWith(isFadingOut: true);
          
          _currentState = _currentState.copyWith(
            characters: newCharacters,
            clearDialogueAndSpeaker: false,
            everShownCharacters: _everShownCharacters
          );
          _gameStateController.add(_currentState);
        }
        
        _scriptIndex++;
        continue;
      }

      if (node is ConditionalSayNode) {
        // 检查条件是否满足
        final currentValue = GlobalVariableManager().getBoolVariableSync(
          node.conditionVariable, 
          defaultValue: false
        );
        
        if (currentValue != node.conditionValue) {
          // 条件不满足，跳过这个节点
          if (kDebugMode) {
            print('[ConditionalSay] 条件不满足，跳过对话: ${node.dialogue}');
            print('[ConditionalSay] 变量 ${node.conditionVariable} = $currentValue, 需要 ${node.conditionValue}');
          }
          _scriptIndex++;
          continue;
        }
        
        if (kDebugMode) {
          print('[ConditionalSay] 条件满足，显示对话: ${node.dialogue}');
        }
        
        // 条件满足，按照正常SayNode处理
        final characterConfig = _characterConfigs[node.character];
        CharacterState? currentCharacterState;

        if (node.character != null) {
          // 确定最终的角色key
          String finalCharacterKey;
          if (characterConfig != null) {
            finalCharacterKey = characterConfig.resourceId; // 使用resourceId作为key
          } else {
            finalCharacterKey = node.character!; // 使用原始名称作为key
          }
          
          currentCharacterState = _currentState.characters[finalCharacterKey];
          
          if (currentCharacterState != null) {
            // 角色已存在，更新表情、姿势和位置
            final newCharacters = Map.of(_currentState.characters);
            
            // 如果角色已存在且有正在播放的动画，继承动画属性
            final existingAnimController = _activeCharacterAnimations[finalCharacterKey];
            Map<String, double>? inheritedAnimationProperties;
            
            if (existingAnimController != null && currentCharacterState.animationProperties != null) {
              // 继承当前的动画属性，这样角色的差分改变但动画位置保持
              inheritedAnimationProperties = Map.from(currentCharacterState.animationProperties!);
              //print('[GameManager] ConditionalSay: 角色 $finalCharacterKey 差分切换时继承动画属性: $inheritedAnimationProperties');
            }
            
            final updatedCharacter = currentCharacterState.copyWith(
              pose: node.pose,
              expression: node.expression,
              positionId: node.position ?? currentCharacterState.positionId, // 如果有新position则更新，否则保持原值
              animationProperties: inheritedAnimationProperties, // 继承动画属性
              clearAnimationProperties: false,
            );
            newCharacters[finalCharacterKey] = updatedCharacter;
            
            // 如果位置发生变化，播放pose属性变化动画
            if (node.position != null && node.position != currentCharacterState.positionId) {
              // 快进模式下跳过位置变化动画
              if (!_isFastForwardMode) {
                await _checkAndAnimatePoseAttributeChanges(
                  characterId: finalCharacterKey,
                  oldPositionId: currentCharacterState.positionId,
                  newPositionId: node.position,
                );
              }
            }
            
            _currentState = _currentState.copyWith(characters: newCharacters, everShownCharacters: _everShownCharacters);
            _gameStateController.add(_currentState);
            
            // 如果有动画，启动动画播放（非阻塞）
            if (!_isFastForwardMode && node.animation != null) {
              _playCharacterAnimation(finalCharacterKey, node.animation!, repeatCount: node.repeatCount);
            }
          } else if (characterConfig != null) {
            // 角色不存在，创建新角色
            currentCharacterState = CharacterState(
              resourceId: characterConfig.resourceId,
              positionId: node.position ?? characterConfig.defaultPoseId, // 优先使用指定的position，否则使用默认值
            );
            
            final newCharacters = Map.of(_currentState.characters);
            
            // 清理现有角色的动画属性，确保位置计算基于基础位置
            for (final entry in newCharacters.entries) {
              newCharacters[entry.key] = entry.value.copyWith(
                clearAnimationProperties: true, // 清理动画属性
              );
            }
            
            newCharacters[finalCharacterKey] = currentCharacterState.copyWith(
              pose: node.pose,
              expression: node.expression,
              clearAnimationProperties: false,
            );
            
            // 检测角色位置变化并触发动画（如果需要）
            if (!_isFastForwardMode) {
              await _checkAndAnimateCharacterPositions(newCharacters);
            }
            
            _currentState = _currentState.copyWith(characters: newCharacters, everShownCharacters: _everShownCharacters);
            _gameStateController.add(_currentState);
            
            // 如果有动画，启动动画播放（非阻塞）
            if (!_isFastForwardMode && node.animation != null) {
              _playCharacterAnimation(finalCharacterKey, node.animation!, repeatCount: node.repeatCount);
            }
          }
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
            speakerAlias: node.character, // 传入角色简写
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

      if (node is SayNode) {
        ////print('[GameManager] 处理SayNode: character=${node.character}, pose=${node.pose}, expression=${node.expression}, animation=${node.animation}');
        final characterConfig = _characterConfigs[node.character];
        ////print('[GameManager] 角色配置: $characterConfig');
        CharacterState? currentCharacterState;

        if (node.character != null) {
          // 检查当前背景是否为CG，如果是CG则不更新角色立绘
          if (_isCurrentBackgroundCG()) {
            ////print('[GameManager] 当前背景为CG，跳过角色立绘更新');
            // 直接更新对话内容，不处理角色状态
            _currentState = _currentState.copyWith(
              speaker: characterConfig?.name ?? node.character,
              speakerAlias: node.character, // 传入角色简写
              dialogue: node.dialogue,
              everShownCharacters: _everShownCharacters,
            );
          } else {
            // 正常处理角色立绘逻辑
            // 确定最终的角色key
            String finalCharacterKey;
            if (characterConfig != null) {
              finalCharacterKey = characterConfig.resourceId; // 使用resourceId作为key
            } else {
              finalCharacterKey = node.character!; // 使用原始名称作为key
            }
            
            currentCharacterState = _currentState.characters[finalCharacterKey];
            ////print('[GameManager] 查找角色 $finalCharacterKey: ${currentCharacterState != null ? "找到" : "未找到"}');
            
            if (currentCharacterState != null) {
              // 角色已存在，更新表情、姿势和位置
              ////print('[GameManager] 更新已存在角色 $finalCharacterKey: pose=${node.pose}, expression=${node.expression}, position=${node.position}');
              final newCharacters = Map.of(_currentState.characters);
              
              // 处理时序差分切换
              String? finalExpression = node.expression;
              if (node.hasTimedExpression) {
                if (_isFastForwardMode) {
                  // 快进模式下直接使用目标差分
                  finalExpression = node.endExpression;
                  //print('[GameManager] 快进模式: 直接使用目标差分 ${node.endExpression}');
                } else {
                  // 先设置起始差分
                  finalExpression = node.startExpression;
                  //print('[GameManager] 时序差分切换: 起始差分 ${node.startExpression}, ${node.switchDelay}秒后切换到 ${node.endExpression}');
                  
                  // 启动定时器进行差分切换
                  _scheduleExpressionSwitch(
                    characterKey: finalCharacterKey,
                    targetExpression: node.endExpression!,
                    delay: node.switchDelay!,
                  );
                }
              }
              
              // 如果角色已存在且有正在播放的动画，继承动画属性
              final existingAnimController = _activeCharacterAnimations[finalCharacterKey];
              Map<String, double>? inheritedAnimationProperties;
              
              if (existingAnimController != null && currentCharacterState.animationProperties != null) {
                // 继承当前的动画属性，这样角色的差分改变但动画位置保持
                inheritedAnimationProperties = Map.from(currentCharacterState.animationProperties!);
                //print('[GameManager] 角色 $finalCharacterKey 差分切换时继承动画属性: $inheritedAnimationProperties');
              }
              
              final updatedCharacter = currentCharacterState.copyWith(
                pose: node.pose,
                expression: finalExpression,
                positionId: node.position ?? currentCharacterState.positionId, // 如果有新position则更新，否则保持原值
                animationProperties: inheritedAnimationProperties, // 继承动画属性
                clearAnimationProperties: false,
              );
              newCharacters[finalCharacterKey] = updatedCharacter;
              
              // 如果位置发生变化，播放pose属性变化动画
              if (node.position != null && node.position != currentCharacterState.positionId) {
                await _checkAndAnimatePoseAttributeChanges(
                  characterId: finalCharacterKey,
                  oldPositionId: currentCharacterState.positionId,
                  newPositionId: node.position,
                );
              }
              
              ////print('[GameManager] 角色更新后状态: pose=${updatedCharacter.pose}, expression=${updatedCharacter.expression}, position=${updatedCharacter.positionId}');
              _currentState = _currentState.copyWith(characters: newCharacters, everShownCharacters: _everShownCharacters);
              _gameStateController.add(_currentState);
              ////print('[GameManager] 发送状态更新，当前角色列表: ${newCharacters.keys}');
              
              // 如果有动画，启动动画播放（非阻塞）
              if (!_isFastForwardMode && node.animation != null) {
                _playCharacterAnimation(finalCharacterKey, node.animation!, repeatCount: node.repeatCount);
              }
            } else if (characterConfig != null) {
              // 角色不存在，创建新角色
              ////print('[GameManager] 创建新角色 $finalCharacterKey');
              currentCharacterState = CharacterState(
                resourceId: characterConfig.resourceId,
                positionId: node.position ?? characterConfig.defaultPoseId, // 优先使用指定的position，否则使用默认值
              );
              
              final newCharacters = Map.of(_currentState.characters);
              
              // 清理现有角色的动画属性，确保位置计算基于基础位置
              for (final entry in newCharacters.entries) {
                newCharacters[entry.key] = entry.value.copyWith(
                  clearAnimationProperties: true, // 清理动画属性
                );
              }
              
              // 处理时序差分切换
              String? finalExpression = node.expression;
              if (node.hasTimedExpression) {
                if (_isFastForwardMode) {
                  // 快进模式下直接使用目标差分
                  finalExpression = node.endExpression;
                  //print('[GameManager] 快进模式: 直接使用目标差分 ${node.endExpression}');
                } else {
                  // 先设置起始差分
                  finalExpression = node.startExpression;
                  //print('[GameManager] 时序差分切换: 起始差分 ${node.startExpression}, ${node.switchDelay}秒后切换到 ${node.endExpression}');
                  
                  // 启动定时器进行差分切换
                  _scheduleExpressionSwitch(
                    characterKey: finalCharacterKey,
                    targetExpression: node.endExpression!,
                    delay: node.switchDelay!,
                  );
                }
              }
              
              newCharacters[finalCharacterKey] = currentCharacterState.copyWith(
                pose: node.pose,
                expression: finalExpression,
                clearAnimationProperties: false,
              );
              
              // 检测角色位置变化并触发动画（如果需要）
              if (!_isFastForwardMode) {
                await _checkAndAnimateCharacterPositions(newCharacters);
              }
              
              _currentState = _currentState.copyWith(characters: newCharacters, everShownCharacters: _everShownCharacters);
              _gameStateController.add(_currentState);
              ////print('[GameManager] 发送状态更新，当前角色列表: ${newCharacters.keys}');
              
              // 如果有动画，启动动画播放（非阻塞）
              if (!_isFastForwardMode && node.animation != null) {
                _playCharacterAnimation(finalCharacterKey, node.animation!, repeatCount: node.repeatCount);
              }
            }
          }
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
          // 在CG背景下，如果之前已经设置了对话内容，就不要重复设置
          if (!(_isCurrentBackgroundCG() && node.character != null)) {
            _currentState = _currentState.copyWith(
              dialogue: node.dialogue,
              speaker: characterConfig?.name,
              speakerAlias: node.character, // 传入角色简写
              currentNode: null,
              clearDialogueAndSpeaker: false,
              forceNullSpeaker: node.character == null,
              everShownCharacters: _everShownCharacters,
            );
          }

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
        // 注意：不立即推进脚本索引，让存档能够保存到MenuNode的位置
        // _scriptIndex 将在选择完成后由 jumpToLabel 推进
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

      if (node is PlayMusicNode) {
        // 使用音乐区间系统处理音乐播放
        final musicRegion = _getMusicRegionForIndex(_scriptIndex);
        if (musicRegion != null) {
          // 检查文件名是否已有扩展名，如果没有则尝试添加 .ogg 或 .mp3
          String musicFile = node.musicFile;
          if (!musicFile.contains('.')) {
            // 尝试 .ogg 扩展名（优先）
            musicFile = '$musicFile.mp3';
          }
          await MusicManager().playBackgroundMusic(
            'Assets/music/$musicFile',
            fadeTransition: true,
            fadeDuration: const Duration(milliseconds: 1000),
          );
          _currentState = _currentState.copyWith(currentMusicRegion: musicRegion);
          
          if (kDebugMode) {
            //print('[MusicRegion] 开始播放音乐区间: ${musicRegion.musicFile} at index $_scriptIndex');
          }
        }
        _scriptIndex++;
        continue;
      }

      if (node is StopMusicNode) {
        // 使用音乐区间系统处理音乐停止
        await MusicManager().stopBackgroundMusic(
          fadeOut: true,
          fadeDuration: const Duration(milliseconds: 800),
        );
        _currentState = _currentState.copyWith(currentMusicRegion: null);
        
        if (kDebugMode) {
          //print('[MusicRegion] 停止音乐 at index $_scriptIndex');
        }
        _scriptIndex++;
        continue;
      }

      if (node is PlaySoundNode) {
        // 播放音效
        String soundFile = node.soundFile;
        if (!soundFile.contains('.')) {
          // 尝试 .ogg 扩展名（优先）
          soundFile = '$soundFile.mp3';
        }
        
        await MusicManager().playAudio(
          'Assets/sound/$soundFile',
          AudioTrackConfig.sound,
          fadeTransition: true,
          fadeDuration: const Duration(milliseconds: 300), // 音效淡入较快
          loop: node.loop,
        );
        
        if (kDebugMode) {
          print('[SoundManager] 播放音效: ${node.soundFile}, loop: ${node.loop} at index $_scriptIndex');
        }
        _scriptIndex++;
        continue;
      }

      if (node is StopSoundNode) {
        // 停止音效
        await MusicManager().stopAudio(
          AudioTrackConfig.sound,
          fadeOut: true,
          fadeDuration: const Duration(milliseconds: 200),
        );
        
        if (kDebugMode) {
          print('[SoundManager] 停止音效 at index $_scriptIndex');
        }
        _scriptIndex++;
        continue;
      }

      if (node is BoolNode) {
        // 设置全局bool变量
        await GlobalVariableManager().setBoolVariable(node.variableName, node.value);
        if (kDebugMode) {
          print('[GlobalVariable] 设置变量 ${node.variableName} = ${node.value}');
        }
        _scriptIndex++;
        continue;
      }

      if (node is PauseNode) {
        // 处理暂停命令：pause(0.5)
        if (kDebugMode) {
          print('[PauseNode] 暂停 ${node.duration} 秒');
        }
        
        // 设置暂停等待标志
        _isWaitingForTimer = true;
        _isProcessing = false; // 释放处理锁，但保持timer锁
        _scriptIndex++; // 预先递增索引
        
        // 启动计时器
        Timer(Duration(milliseconds: (node.duration * 1000).round()), () {
          if (kDebugMode) {
            print('[PauseNode] 暂停结束，继续执行脚本');
          }
          _isWaitingForTimer = false;
          _executeScript(); // 恢复脚本执行
        });
        
        return; // 暂停期间停止脚本执行
      }

      if (node is ShakeNode) {
        // 处理震动命令
        final duration = node.duration ?? 1.0; // 默认1秒
        final intensity = node.intensity ?? 8.0; // 默认强度8
        final target = node.target ?? 'background'; // 默认震动背景
        
        if (kDebugMode) {
          print('[ShakeNode] 触发震动: target=$target, duration=$duration, intensity=$intensity');
        }
        
        // 设置震动状态
        _currentState = _currentState.copyWith(
          isShaking: true,
          shakeTarget: target,
          shakeDuration: duration,
          shakeIntensity: intensity,
          everShownCharacters: _everShownCharacters,
        );
        _gameStateController.add(_currentState);
        
        // 启动计时器，震动结束后清除震动状态
        Timer(Duration(milliseconds: (duration * 1000).round()), () {
          _currentState = _currentState.copyWith(
            isShaking: false,
            shakeTarget: null,
            shakeDuration: null,
            shakeIntensity: null,
            everShownCharacters: _everShownCharacters,
          );
          _gameStateController.add(_currentState);
        });
        
        _scriptIndex++;
        continue;
      }
    }
    _isProcessing = false;
  }

  GameStateSnapshot saveStateSnapshot() {
    if (kDebugMode) {
      //print('[GameManager] 保存存档：cgCharacters数量 = ${_currentState.cgCharacters.length}');
      //print('[GameManager] 保存存档：cgCharacters内容 = ${_currentState.cgCharacters.keys.toList()}');
    }
    
    return GameStateSnapshot(
      scriptIndex: _scriptIndex,
      currentState: _currentState,
      dialogueHistory: List.from(_dialogueHistory),
      isNvlMode: _currentState.isNvlMode,
      isNvlMovieMode: _currentState.isNvlMovieMode,
      nvlDialogues: List.from(_currentState.nvlDialogues),
      isFastForwardMode: _isFastForwardMode, // 保存快进状态
    );
  }

  Future<void> restoreFromSnapshot(String scriptName, GameStateSnapshot snapshot, {bool shouldReExecute = true}) async {
    //print('📚 restoreFromSnapshot: scriptName = $scriptName');
    //print('📚 restoreFromSnapshot: snapshot.scriptIndex = ${snapshot.scriptIndex}');
    //print('📚 restoreFromSnapshot: isNvlMode = ${snapshot.isNvlMode}');
    //print('📚 restoreFromSnapshot: nvlDialogues count = ${snapshot.nvlDialogues.length}');
    
    await _loadConfigs();
    await GlobalVariableManager().init(); // 初始化全局变量管理器
    await AnimationManager.loadAnimations(); // 加载动画
    _script = await _scriptMerger.getMergedScript();
    _buildLabelIndexMap();
    _buildMusicRegions(); // 构建音乐区间
    
    // 预加载anime资源（同步执行）
    try {
      await _analyzeAndPreloadAnimeResources();
    } catch (e) {
      if (kDebugMode) {
        ////print('[GameManager] 存档恢复：预加载anime资源失败: $e');
      }
    }
    //print('📚 加载合并脚本后: _script.children.length = ${_script.children.length}');
    
    _scriptIndex = snapshot.scriptIndex;
    
    // 重置所有处理标志，确保恢复状态时没有遗留的锁定状态
    _isProcessing = false;
    _isWaitingForTimer = false;
    
    // 修复快进回退bug：强制重置快进状态为非快进
    // 回退到历史状态时，应该始终处于正常播放模式，而不是快进模式
    setFastForwardMode(false);
    
    // 取消当前活跃的计时器
    _currentTimer?.cancel();
    _currentTimer = null;
    
    // 清理旧的场景动画控制器
    _sceneAnimationController?.dispose();
    _sceneAnimationController = null;
    
    // 恢复 NVL 状态
    if (kDebugMode) {
      //print('[GameManager] 存档恢复：cgCharacters数量 = ${snapshot.currentState.cgCharacters.length}');
      //print('[GameManager] 存档恢复：cgCharacters内容 = ${snapshot.currentState.cgCharacters.keys.toList()}');
    }
    
    _currentState = snapshot.currentState.copyWith(
      isNvlMode: snapshot.isNvlMode,
      isNvlMovieMode: snapshot.isNvlMovieMode,
      nvlDialogues: snapshot.nvlDialogues,
      everShownCharacters: _everShownCharacters,
      isFastForwarding: false, // 修复快进回退bug：强制设置为非快进状态
      // 明确恢复CG角色状态（修复CG存档恢复bug）
      cgCharacters: snapshot.currentState.cgCharacters,
    );
    
    if (kDebugMode) {
      //print('[GameManager] 存档恢复后：cgCharacters数量 = ${_currentState.cgCharacters.length}');
      //print('[GameManager] 存档恢复后：cgCharacters内容 = ${_currentState.cgCharacters.keys.toList()}');
    }
    
    // 立即发送状态更新以确保UI正确显示包括场景动画属性
    _gameStateController.add(_currentState);
    
    if (snapshot.dialogueHistory.isNotEmpty) {
      _dialogueHistory = List.from(snapshot.dialogueHistory);
    }
    
    // 检查恢复位置的音乐区间（强制检查）
    await _checkMusicRegionAtCurrentIndex(forceCheck: true);
    
    // 检测并恢复当前场景的动画
    await _checkAndRestoreSceneAnimation();
    
    if (shouldReExecute) {
      await _executeScript();
    } else {
      // 不重新执行脚本时，检查当前位置是否是MenuNode
      if (_scriptIndex < _script.children.length) {
        final currentNode = _script.children[_scriptIndex];
        if (currentNode is MenuNode) {
          // 如果当前位置是MenuNode，确保currentNode被正确设置
          _currentState = _currentState.copyWith(
            currentNode: currentNode,
            everShownCharacters: _everShownCharacters,
          );
          if (kDebugMode) {
            //print('[GameManager] 存档恢复：检测到MenuNode，设置currentNode');
          }
        }
      }
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
    AnimationManager.clearCache(); // 清除动画缓存
    await _loadConfigs();
    await GlobalVariableManager().init(); // 初始化全局变量管理器
    await AnimationManager.loadAnimations(); // 加载动画
    _script = await _scriptMerger.getMergedScript();
    _buildLabelIndexMap();
    _buildMusicRegions(); // 构建音乐区间
    
    if (_savedSnapshot != null) {
      _scriptIndex = _savedSnapshot!.scriptIndex;
      _dialogueHistory = List.from(_savedSnapshot!.dialogueHistory);
      
      if (_scriptIndex > 0) {
        _scriptIndex--;
      }
      
      _currentState = _savedSnapshot!.currentState.copyWith(
        clearDialogueAndSpeaker: true,
        forceNullCurrentNode: true,
        // 恢复 NVL 状态
        isNvlMode: _savedSnapshot!.isNvlMode,
        isNvlMovieMode: _savedSnapshot!.isNvlMovieMode,
        nvlDialogues: _savedSnapshot!.nvlDialogues,
        everShownCharacters: _everShownCharacters,
        isFastForwarding: false, // 修复快进回退bug：强制设置为非快进状态
      );
      
      _isProcessing = false;
      _isWaitingForTimer = false; // 重置计时器标志
      
      // 取消当前活跃的计时器
      _currentTimer?.cancel();
      _currentTimer = null;
      
      // 清理旧的场景动画控制器
      _sceneAnimationController?.dispose();
      _sceneAnimationController = null;
      
      // 检测并恢复当前场景的动画
      await _checkAndRestoreSceneAnimation();
      
      await _executeScript();
    }
  }

  Future<void> _transitionToNewMovie(String movieFile, [SceneFilter? sceneFilter, List<String>? layers, String? transitionType, String? animation, int? repeatCount]) async {
    if (_context == null) return;
    
    //////print('[GameManager] 开始movie转场到视频: $movieFile, 转场类型: ${transitionType ?? "fade"}');
    
    final oldBackground = _currentState.background;
    
    try {
      await SceneTransitionEffectManager.instance.transition(
        context: _context!,
        transitionType: transitionType != null 
            ? TransitionTypeParser.parseTransitionType(transitionType)
            : TransitionType.fade,
        oldBackground: oldBackground,
        newBackground: null, // 视频会占据整个背景
        onMidTransition: () async {
          //////print('[GameManager] movie转场中点，更新状态');
          _currentState = _currentState.copyWith(
            movieFile: movieFile,
            movieRepeatCount: repeatCount, // 新增：传递视频重复播放次数
            background: null, // 清空背景，视频优先显示
            sceneFilter: sceneFilter,
            clearSceneFilter: sceneFilter == null,
            sceneLayers: layers,
            clearSceneLayers: layers == null,
            clearDialogueAndSpeaker: true,
            clearCharacters: true,
            clearCgCharacters: true,
            sceneAnimation: animation,
            sceneAnimationRepeat: repeatCount,
            sceneAnimationProperties: animation != null ? <String, double>{} : null,
            clearSceneAnimation: animation == null,
            everShownCharacters: _everShownCharacters,
          );
          _gameStateController.add(_currentState);
          
          // 启动场景动画（如果有）
          if (animation != null && _tickerProvider != null) {
            _startSceneAnimation(animation, repeatCount);
          }
        },
      );
      
      //////print('[GameManager] movie转场完成');
    } catch (e) {
      //print('[GameManager] movie转场失败: $e');
      // 转场失败时直接更新状态
      _currentState = _currentState.copyWith(
        movieFile: movieFile,
        movieRepeatCount: repeatCount, // 新增：传递视频重复播放次数
        background: null,
        sceneFilter: sceneFilter,
        clearSceneFilter: sceneFilter == null,
        sceneLayers: layers,
        clearSceneLayers: layers == null,
        clearDialogueAndSpeaker: true,
        clearCharacters: true,
        clearCgCharacters: true,
        sceneAnimation: animation,
        sceneAnimationRepeat: repeatCount,
        sceneAnimationProperties: animation != null ? <String, double>{} : null,
        clearSceneAnimation: animation == null,
        everShownCharacters: _everShownCharacters,
      );
      _gameStateController.add(_currentState);
      
      if (animation != null && _tickerProvider != null) {
        _startSceneAnimation(animation, repeatCount);
      }
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
      dialogue: RichTextParser.cleanText(dialogue),
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
    
    // 检查目标场景和当前场景是否不同，如果不同则使用场景转场
    final snapshot = entry.stateSnapshot;
    final currentBackground = _currentState.background;
    final targetBackground = snapshot.currentState.background;
    
    if (_context != null && currentBackground != targetBackground) {
      // 需要场景转场，找出目标场景是用什么转场出现的
      String originalTransitionType = 'fade'; // 默认使用fade
      
      // 在历史记录中向前搜索，找到切换到目标场景时使用的转场类型
      for (int i = _scriptIndex; i >= 0; i--) {
        if (i < _script.children.length) {
          final node = _script.children[i];
          if (node is BackgroundNode && node.background == targetBackground) {
            originalTransitionType = node.transitionType ?? 'fade';
            break;
          }
        }
      }
      
      await SceneTransitionEffectManager.instance.transition(
        context: _context!,
        transitionType: TransitionTypeParser.parseTransitionType(originalTransitionType),
        oldBackground: currentBackground,
        newBackground: targetBackground,
        onMidTransition: () async {
          // 在转场中点恢复历史状态
          await restoreFromSnapshot(scriptName, snapshot, shouldReExecute: false);
          
          // 修复NVL模式回退bug：将脚本索引移动到下一个节点，避免重复执行当前节点
          if (snapshot.isNvlMode && _scriptIndex < _script.children.length - 1) {
            _scriptIndex++;
          }
          // 修复普通对话模式回退bug：对于普通对话也需要推进到下一个节点，避免重复执行
          else if (!snapshot.isNvlMode && _scriptIndex < _script.children.length - 1) {
            _scriptIndex++;
          }
          
          // 历史回退后强制检查音乐区间
          await _checkMusicRegionAtCurrentIndex(forceCheck: true);
        },
        duration: const Duration(milliseconds: 600), // 回退转场稍微快一些
      );
    } else {
      // 不需要场景转场，直接恢复状态
      await restoreFromSnapshot(scriptName, snapshot, shouldReExecute: false);
      
      if (snapshot.isNvlMode && _scriptIndex < _script.children.length - 1) {
        _scriptIndex++;
      }
      else if (!snapshot.isNvlMode && _scriptIndex < _script.children.length - 1) {
        _scriptIndex++;
      }
      
      await _checkMusicRegionAtCurrentIndex(forceCheck: true);
    }
  }

  /// 启动场景计时器
  void _startSceneTimer(double seconds) {
    // 取消之前的计时器（如果存在）
    _currentTimer?.cancel();
    
    final durationMs = (seconds * 1000).round();
    
    _currentTimer = Timer(Duration(milliseconds: durationMs), () async {
      // 检查计时器是否仍然有效（防止已被取消的计时器执行）
      if (_isWaitingForTimer && _currentTimer != null && _currentTimer!.isActive == false) {
        _isWaitingForTimer = false;
        _currentTimer = null;
        await _executeScript();
      }
    });
  }
  
  /// 定时切换角色差分表情
  void _scheduleExpressionSwitch({
    required String characterKey,
    required String targetExpression,
    required double delay,
  }) {
    final delayMs = (delay * 1000).round();
    
    Timer(Duration(milliseconds: delayMs), () {
      // 检查角色是否仍然存在
      final currentCharacter = _currentState.characters[characterKey];
      if (currentCharacter != null) {
        //print('[GameManager] 执行时序差分切换: $characterKey -> $targetExpression');
        
        final newCharacters = Map.of(_currentState.characters);
        newCharacters[characterKey] = currentCharacter.copyWith(
          expression: targetExpression,
          clearAnimationProperties: false,
        );
        
        _currentState = _currentState.copyWith(
          characters: newCharacters,
          everShownCharacters: _everShownCharacters,
        );
        _gameStateController.add(_currentState);
      }
    });
  }

  /// 检查当前背景是否为CG
  bool _isCurrentBackgroundCG() {
    // 新的CG检测逻辑：检查是否有CG角色正在显示
    if (_currentState.cgCharacters.isNotEmpty) {
      return true;
    }
    
    // 保留原有逻辑作为兜底（向后兼容）
    final currentBg = _currentState.background;
    if (currentBg == null) return false;
    
    // 检查背景名称是否包含"cg"关键词（不区分大小写）
    return currentBg.toLowerCase().contains('cg');
  }

  /// 使用转场效果切换背景
  /// 计算包含预设属性的场景动画属性
  Map<String, double>? _calculateSceneAnimationPropertiesWithPresets(String? animationName) {
    if (animationName == null) return null;
    
    // 获取动画定义
    final animDef = AnimationManager.getAnimation(animationName);
    if (animDef == null) return null;
    
    // 基础属性
    final baseProperties = {
      'xcenter': 0.0,
      'ycenter': 0.0,
      'scale': 1.0,
      'alpha': 1.0,
      'rotation': 0.0,
    };
    
    // 应用预设属性
    final presetProperties = animDef.presetProperties;
    if (presetProperties.isNotEmpty) {
      //print('[GameManager] 场景动画 $animationName 应用预设属性: $presetProperties');
      for (final entry in presetProperties.entries) {
        final currentValue = baseProperties[entry.key] ?? 0.0;
        baseProperties[entry.key] = currentValue + entry.value;
        //print('[GameManager] 场景预设 ${entry.key}: $currentValue + ${entry.value} = ${baseProperties[entry.key]}');
      }
      //print('[GameManager] 场景最终属性: $baseProperties');
      return baseProperties;
    }
    
    return null;
  }

  Future<void> _transitionToNewBackground(String newBackground, [SceneFilter? sceneFilter, List<String>? layers, String? transitionType, String? animation, int? repeatCount, bool? clearCG]) async {
    if (_context == null) return;
    
    //////print('[GameManager] 开始scene转场到背景: $newBackground, 转场类型: ${transitionType ?? "fade"}');
    
    // 预加载背景图片以避免动画闪烁
    if (!ColorBackgroundRenderer.isValidHexColor(newBackground)) {
      try {
        // 先尝试使用AssetManager的智能查找，它会处理CG的特殊路径
        String? assetPath = await AssetManager().findAsset(newBackground);
        
        // 如果AssetManager找不到，再尝试backgrounds路径
        if (assetPath == null) {
          assetPath = await AssetManager().findAsset('backgrounds/${newBackground.replaceAll(' ', '-')}');
        }
        
        if (assetPath != null && _context != null) {
          // 预加载图片到缓存
          if (kDebugMode && !assetPath.startsWith('assets/')) {
            // Debug模式下，如果是绝对路径，使用FileImage
            await precacheImage(FileImage(File(assetPath)), _context!);
          } else {
            // 发布模式或assets路径，使用AssetImage
            await precacheImage(AssetImage(assetPath), _context!);
          }
          ////print('[GameManager] 预加载背景图片完成: $newBackground -> $assetPath');
        } else {
          ////print('[GameManager] 警告: 无法找到背景图片进行预加载: $newBackground');
        }
      } catch (e) {
        ////print('[GameManager] 预加载背景图片失败: $e');
      }
    }
    
    // 解析转场类型
    final effectType = TransitionTypeParser.parseTransitionType(transitionType ?? 'fade');
    ////print('[GameManager] 转场类型解析: 输入="$transitionType" -> 解析结果=${effectType.name}');
    
    // 如果是diss转场，需要准备旧背景和新背景名称
    String? oldBackgroundName;
    String? newBackgroundName;
    
    if (effectType == TransitionType.diss) {
      // 传递背景名称而不是Widget，让AssetManager智能查找正确路径
      if (_currentState.background != null) {
        // 先尝试直接使用背景名称，让AssetManager智能查找
        final oldBgPath = await AssetManager().findAsset(_currentState.background!);
        if (oldBgPath != null) {
          oldBackgroundName = _currentState.background!;
        } else {
          // 回退到backgrounds路径
          oldBackgroundName = 'backgrounds/${_currentState.background!.replaceAll(' ', '-')}';
        }
      }
      
      // 对新背景也做同样处理
      final newBgPath = await AssetManager().findAsset(newBackground);
      if (newBgPath != null) {
        newBackgroundName = newBackground;
      } else {
        // 回退到backgrounds路径
        newBackgroundName = 'backgrounds/${newBackground.replaceAll(' ', '-')}';
      }
      
      ////print('[GameManager] diss转场参数: 旧背景="$oldBackgroundName", 新背景="$newBackgroundName"');
    }
    
    // 在转场开始前先清除对话框，避免"残留"效果
    _currentState = _currentState.copyWith(
      clearDialogueAndSpeaker: true,
      everShownCharacters: _everShownCharacters,
    );
    _gameStateController.add(_currentState);
    
    // 根据转场类型选择转场管理器
    if (effectType == TransitionType.fade) {
      // 使用原有的黑屏转场
      await SceneTransitionManager.instance.transition(
        context: _context!,
        onMidTransition: () {
        //////print('[GameManager] scene转场中点 - 切换背景到: $newBackground');
        // 在黑屏最深时切换背景和清除所有角色（类似Renpy）
        // 先停止并清理旧的场景动画控制器
        _sceneAnimationController?.dispose();
        _sceneAnimationController = null;
        
        _currentState = _currentState.copyWith(
          background: newBackground,
          clearMovieFile: true, // 新增：scene转场时清理视频状态
          sceneFilter: sceneFilter,
          clearSceneFilter: sceneFilter == null, // 如果没有滤镜，清除现有滤镜
          sceneLayers: layers,
          clearSceneLayers: layers == null, // 如果是单图层，清除多图层数据
          clearCharacters: true,
          clearCgCharacters: clearCG ?? false, // 清空CG角色
          sceneAnimation: animation,
          sceneAnimationRepeat: repeatCount,
          sceneAnimationProperties: _calculateSceneAnimationPropertiesWithPresets(animation), // 应用预设属性
          clearSceneAnimation: animation == null,
          everShownCharacters: _everShownCharacters,
        );
        //////print('[GameManager] 状态更新 - 旧背景: ${oldState.background}, 新背景: ${_currentState.background}');
        _gameStateController.add(_currentState);
        //////print('[GameManager] 状态已发送到Stream');
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
          //////print('[GameManager] scene转场中点 - 切换背景到: $newBackground');
          // 对于dissolve转场，不在中点更新背景状态，避免与转场效果冲突
          // 只更新其他状态，背景更新延迟到转场完成
          if (effectType != TransitionType.diss) {
            // 在转场中点切换背景和清除所有角色（类似Renpy）
            // 先停止并清理旧的场景动画控制器
            _sceneAnimationController?.dispose();
            _sceneAnimationController = null;
            
            _currentState = _currentState.copyWith(
              background: newBackground,
              clearMovieFile: true, // 新增：scene转场时清理视频状态
              sceneFilter: sceneFilter,
              clearSceneFilter: sceneFilter == null, // 如果没有滤镜，清除现有滤镜
              sceneLayers: layers,
              clearSceneLayers: layers == null, // 如果是单图层，清除多图层数据
              clearCharacters: true,
              clearCgCharacters: clearCG ?? false, // 清空CG角色
              sceneAnimation: animation,
              sceneAnimationRepeat: repeatCount,
              sceneAnimationProperties: _calculateSceneAnimationPropertiesWithPresets(animation), // 应用预设属性
              clearSceneAnimation: animation == null,
              everShownCharacters: _everShownCharacters,
            );
            //////print('[GameManager] 状态更新 - 旧背景: ${oldState.background}, 新背景: ${_currentState.background}');
            _gameStateController.add(_currentState);
            //////print('[GameManager] 状态已发送到Stream');
          } else {
            // 对于dissolve转场，在转场中点就更新背景，避免结束时闪烁
            _sceneAnimationController?.dispose();
            _sceneAnimationController = null;
            
            _currentState = _currentState.copyWith(
              background: newBackground, // 在中点就更新背景，避免结束时的闪烁
              clearMovieFile: true, // 新增：scene转场时清理视频状态
              sceneFilter: sceneFilter,
              clearSceneFilter: sceneFilter == null,
              sceneLayers: layers,
              clearSceneLayers: layers == null,
              clearCharacters: true,
              clearCgCharacters: clearCG ?? false, // 清空CG角色
              sceneAnimation: animation,
              sceneAnimationRepeat: repeatCount,
              sceneAnimationProperties: _calculateSceneAnimationPropertiesWithPresets(animation), // 应用预设属性
              clearSceneAnimation: animation == null,
              everShownCharacters: _everShownCharacters,
            );
            _gameStateController.add(_currentState);
          }
        },
        duration: const Duration(milliseconds: 800),
      );
      
      // dissolve转场的背景已在中点更新，这里不需要重复更新
    }
    
    //////print('[GameManager] scene转场完成，等待计时器结束');
    // 转场完成，等待计时器结束后自动执行后续脚本
    _isProcessing = false;
    
    // 如果有场景动画，延迟启动动画以确保背景图片完全加载
    if (animation != null && _tickerProvider != null) {
      // 等待足够的时间让背景图片完全加载和渲染
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_tickerProvider != null) {
          _startSceneAnimation(animation, repeatCount);
        }
      });
    }
  }
  
  /// 检查脚本是否已初始化
  bool _isScriptInitialized() {
    try {
      // 尝试访问_script，如果未初始化会抛出LateInitializationError
      return _script.children.isNotEmpty;
    } catch (e) {
      // 如果抛出异常，说明_script尚未初始化
      return false;
    }
  }

  /// 检测当前脚本位置的场景动画并重新启动
  Future<void> _checkAndRestoreSceneAnimation() async {
    if (_tickerProvider == null) return;
    
    // 检查_script是否已初始化
    if (!_isScriptInitialized()) return;
    
    // 向前搜索最近的BackgroundNode，找出当前场景的动画设置
    BackgroundNode? lastBackgroundNode;
    
    for (int i = _scriptIndex; i >= 0; i--) {
      if (i < _script.children.length && _script.children[i] is BackgroundNode) {
        lastBackgroundNode = _script.children[i] as BackgroundNode;
        break;
      }
    }
    
    if (lastBackgroundNode != null && lastBackgroundNode.animation != null) {
      ////print('[GameManager] 检测到当前场景有动画: ${lastBackgroundNode.animation}, repeat: ${lastBackgroundNode.repeatCount}');
      
      // 更新当前状态的场景动画信息
      _currentState = _currentState.copyWith(
        sceneAnimation: lastBackgroundNode.animation,
        sceneAnimationRepeat: lastBackgroundNode.repeatCount,
        sceneAnimationProperties: _calculateSceneAnimationPropertiesWithPresets(lastBackgroundNode.animation), // 应用预设属性
        everShownCharacters: _everShownCharacters,
      );
      
      // 立即启动场景动画
      _startSceneAnimation(lastBackgroundNode.animation!, lastBackgroundNode.repeatCount);
      
      // 发送状态更新
      _gameStateController.add(_currentState);
    } else {
      ////print('[GameManager] 当前场景没有检测到动画');
    }
  }
  void stopAllSounds() {
    MusicManager().stopAudio(AudioTrackConfig.sound);
  }

  // 存储当前正在播放动画的角色控制器
  final Map<String, CharacterAnimationController> _activeCharacterAnimations = {};

  /// 播放角色动画
  Future<void> _playCharacterAnimation(String characterId, String animationName, {int? repeatCount}) async {
    final characterState = _currentState.characters[characterId];
    if (characterState == null) return;
    
    // 检查该角色是否已经有动画在播放
    final existingAnimController = _activeCharacterAnimations[characterId];
    if (existingAnimController != null) {
      // 如果已经有动画在播放同一个动画，直接返回，让动画继续
      if (existingAnimController.animationName == animationName) {
        //print('[GameManager] 角色 $characterId 已在播放动画 $animationName，继承动画状态');
        return;
      } else {
        // 如果在播放不同的动画，停止旧动画
        //print('[GameManager] 角色 $characterId 切换动画: ${existingAnimController.animationName} -> $animationName');
        existingAnimController.stopInfiniteLoop();
        existingAnimController.dispose();
        _activeCharacterAnimations.remove(characterId);
      }
    }
    
    // 应用自动分布逻辑，获取实际的分布后位置
    final characterOrder = _currentState.characters.keys.toList();
    final distributedPoseConfigs = CharacterAutoDistribution.calculateAutoDistribution(
      _currentState.characters,
      _poseConfigs,
      characterOrder,
    );
    
    // 优先查找角色专属的自动分布配置，如果没有则使用原始配置
    final autoDistributedPoseId = '${characterId}_auto_distributed';
    final poseConfig = distributedPoseConfigs[autoDistributedPoseId] ?? 
                        distributedPoseConfigs[characterState.positionId] ?? 
                        _poseConfigs[characterState.positionId];
    if (poseConfig == null) return;
    
    // 获取基础属性（使用自动站位后的实际位置）
    final baseProperties = {
      'xcenter': poseConfig.xcenter,
      'ycenter': poseConfig.ycenter,
      'scale': poseConfig.scale,
      'alpha': 1.0,
    };
    
    // 创建动画控制器
    final animController = CharacterAnimationController(
      characterId: characterId,
      onAnimationUpdate: (properties) {
        // 实时更新角色状态
        final newCharacters = Map.of(_currentState.characters);
        final currentCharacterState = newCharacters[characterId];
        if (currentCharacterState != null) {
          newCharacters[characterId] = currentCharacterState.copyWith(
            animationProperties: properties,
          );
          _currentState = _currentState.copyWith(
            characters: newCharacters,
            everShownCharacters: _everShownCharacters,
          );
          _gameStateController.add(_currentState);
        }
      },
      onComplete: () {
        //print('[GameManager] 角色 $characterId 动画 $animationName 播放完成');
        // 动画完成后，清除动画属性，让角色回到原本的位置
        // 不修改原始的pose配置，避免影响其他使用相同positionId的角色
        final newCharacters = Map.of(_currentState.characters);
        final currentCharacterState = newCharacters[characterId];
        if (currentCharacterState != null) {
          newCharacters[characterId] = currentCharacterState.copyWith(
            animationProperties: null, // 清除动画属性，回到基础位置
          );
          _currentState = _currentState.copyWith(
            characters: newCharacters,
            everShownCharacters: _everShownCharacters,
          );
          _gameStateController.add(_currentState);
        }
        // 从活跃动画列表中移除
        _activeCharacterAnimations.remove(characterId);
      },
    );
    
    // 添加到活跃动画列表
    _activeCharacterAnimations[characterId] = animController;
    
    // 播放动画，传递repeatCount参数
    if (_tickerProvider != null) {
      await animController.playAnimation(
        animationName,
        _tickerProvider!,
        baseProperties,
        repeatCount: repeatCount,
      );
    } else {
      ////print('[GameManager] 无TickerProvider，跳过动画播放');
      // 如果无法播放动画，从活跃列表中移除
      _activeCharacterAnimations.remove(characterId);
    }
    
    // 动画播放完成后自动清理（如果还在活跃列表中）
    if (_activeCharacterAnimations[characterId] == animController) {
      animController.dispose();
      _activeCharacterAnimations.remove(characterId);
    }
  }

  /// 播放场景动画
  Future<void> _startSceneAnimation(String animationName, int? repeatCount) async {
    ////print('[GameManager] 开始播放场景动画: $animationName, repeat: $repeatCount');
    
    // 停止之前的场景动画
    _sceneAnimationController?.dispose();
    
    // 获取基础属性（场景的默认位置）
    final baseProperties = <String, double>{
      'xcenter': 0.0,
      'ycenter': 0.0,
      'scale': 1.0,
      'alpha': 1.0,
      'rotation': 0.0,
    };
    
    // 创建场景动画控制器
    _sceneAnimationController = SceneAnimationController(
      sceneId: 'scene_background',
      onAnimationUpdate: (properties) {
        // 实时更新场景动画属性
        _currentState = _currentState.copyWith(
          sceneAnimationProperties: properties,
          everShownCharacters: _everShownCharacters,
        );
        _gameStateController.add(_currentState);
      },
      onComplete: () {
        ////print('[GameManager] 场景动画 $animationName 播放完成');
        // 保持动画的最终状态，不清除动画属性
        final finalProperties = _sceneAnimationController?.currentProperties;
        if (finalProperties != null) {
          _currentState = _currentState.copyWith(
            sceneAnimationProperties: finalProperties,
            everShownCharacters: _everShownCharacters,
          );
          _gameStateController.add(_currentState);
        }
        _sceneAnimationController?.dispose();
        _sceneAnimationController = null;
      },
    );
    
    // 播放动画
    if (_tickerProvider != null) {
      await _sceneAnimationController!.playAnimation(
        animationName,
        _tickerProvider!,
        baseProperties,
        repeatCount: repeatCount,
      );
    }
  }

  /// 淡出动画完成后移除角色
  void removeCharacterAfterFadeOut(String characterId) {
    final oldCharacters = Map.of(_currentState.characters);
    final newCharacters = Map.of(_currentState.characters);
    newCharacters.remove(characterId);
    
    if (_tickerProvider == null || newCharacters.length < 2) {
      _currentState = _currentState.copyWith(
        characters: newCharacters,
        clearDialogueAndSpeaker: false,
        everShownCharacters: _everShownCharacters
      );
      _gameStateController.add(_currentState);
      return;
    }
    
    // 手动计算位置变化，考虑角色的实际当前位置（包括动画属性）
    final characterOrder = newCharacters.keys.toList();
    final newDistributed = CharacterAutoDistribution.calculateAutoDistribution(
      newCharacters, 
      _poseConfigs, 
      characterOrder,
    );
    
    final positionChanges = <CharacterPositionChange>[];
    for (final characterId in newCharacters.keys) {
      final character = newCharacters[characterId]!;
      final originalPose = _poseConfigs[character.positionId];
      
      if (originalPose != null && originalPose.isAutoAnchor) {
        // 获取角色当前的实际显示位置
        double currentX = originalPose.xcenter;
        if (character.animationProperties != null && character.animationProperties!.containsKey('xcenter')) {
          currentX = character.animationProperties!['xcenter']!;
        } else {
          // 如果没有动画属性，使用当前自动分布后的位置
          final currentDistributed = CharacterAutoDistribution.calculateAutoDistribution(
            oldCharacters, 
            _poseConfigs, 
            oldCharacters.keys.toList(),
          );
          final currentAutoDistributedPoseId = '${characterId}_auto_distributed';
          final currentDistributedPose = currentDistributed[currentAutoDistributedPoseId] ?? originalPose;
          currentX = currentDistributedPose.xcenter;
        }
        
        // 获取新的目标位置
        final newAutoDistributedPoseId = '${characterId}_auto_distributed';
        final newDistributedPose = newDistributed[newAutoDistributedPoseId] ?? originalPose;
        final targetX = newDistributedPose.xcenter;
        
        // 如果位置有变化，添加到动画列表
        if ((currentX - targetX).abs() > 0.001) {
          positionChanges.add(CharacterPositionChange(
            characterId: characterId,
            fromX: currentX,
            toX: targetX,
          ));
        }
      }
    }
    
    // 如果有位置变化，播放动画
    if (positionChanges.isNotEmpty) {
      // 先移除角色，同时设置剩余角色的动画属性为当前位置，避免闪烁
      final updatedCharacters = Map<String, CharacterState>.from(newCharacters);
      for (final change in positionChanges) {
        final character = updatedCharacters[change.characterId];
        if (character != null) {
          updatedCharacters[change.characterId] = character.copyWith(
            animationProperties: {'xcenter': change.fromX}, // 设置为当前位置，避免闪烁
          );
        }
      }
      
      _currentState = _currentState.copyWith(
        characters: updatedCharacters,
        clearDialogueAndSpeaker: false,
        everShownCharacters: _everShownCharacters
      );
      _gameStateController.add(_currentState);
      
      // 然后播放动画
      _characterPositionAnimator?.stop();
      _characterPositionAnimator = CharacterPositionAnimator();
      
      _characterPositionAnimator!.animatePositionChanges(
        positionChanges: positionChanges,
        vsync: _tickerProvider!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        onUpdate: (positions) {
          final animatingCharacters = Map<String, CharacterState>.from(_currentState.characters);
          for (final entry in positions.entries) {
            final targetCharacterId = entry.key;
            final xPosition = entry.value;
            final character = animatingCharacters[targetCharacterId];
            if (character != null) {
              animatingCharacters[targetCharacterId] = character.copyWith(
                animationProperties: {'xcenter': xPosition},
              );
            }
          }
          
          _currentState = _currentState.copyWith(
            characters: animatingCharacters,
            clearDialogueAndSpeaker: false,
            everShownCharacters: _everShownCharacters
          );
          _gameStateController.add(_currentState);
        },
        onComplete: () {
          // 动画完成，简单更新状态，不清理动画属性
          // 让后续的正常操作（如添加新角色）自然地处理最终状态
        },
      );
    } else {
      // 没有位置变化，直接移除角色
      _currentState = _currentState.copyWith(
        characters: newCharacters,
        clearDialogueAndSpeaker: false,
        everShownCharacters: _everShownCharacters
      );
      _gameStateController.add(_currentState);
    }
  }

  /// 清除anime覆盖层
  void clearAnimeOverlay() {
    _currentState = _currentState.copyWith(
      clearAnimeOverlay: true,
      everShownCharacters: _everShownCharacters,
    );
    _gameStateController.add(_currentState);
  }

  void dispose() {
    _currentTimer?.cancel(); // 取消活跃的计时器
    _sceneAnimationController?.dispose(); // 清理场景动画控制器
    
    // 清理所有活跃的角色动画控制器
    for (final controller in _activeCharacterAnimations.values) {
      controller.stopInfiniteLoop();
      controller.dispose();
    }
    _activeCharacterAnimations.clear();
    
    stopAllSounds(); // 停止所有音效
    _gameStateController.close();
  }

  // 全局变量管理方法
  Future<bool> getBoolVariable(String name, {bool defaultValue = false}) async {
    return await GlobalVariableManager().getBoolVariable(name, defaultValue: defaultValue);
  }

  bool getBoolVariableSync(String name, {bool defaultValue = false}) {
    return GlobalVariableManager().getBoolVariableSync(name, defaultValue: defaultValue);
  }

  Future<void> setBoolVariable(String name, bool value) async {
    await GlobalVariableManager().setBoolVariable(name, value);
  }
}

class GameState {
  final String? background;
  final String? movieFile; // 新增：当前视频文件
  final int? movieRepeatCount; // 新增：视频重复播放次数
  final Map<String, CharacterState> characters;
  final String? dialogue;
  final String? speaker;
  final String? speakerAlias; // 新增：角色简写
  final SksNode? currentNode;
  final bool isNvlMode;
  final bool isNvlMovieMode;
  final List<NvlDialogue> nvlDialogues;
  final Set<String> everShownCharacters;
  final SceneFilter? sceneFilter;
  final List<String>? sceneLayers; // 新增：多图层支持
  final MusicRegion? currentMusicRegion; // 新增：当前音乐区间
  final Map<String, double>? sceneAnimationProperties; // 新增：场景动画属性
  final String? sceneAnimation; // 新增：当前场景动画名称
  final int? sceneAnimationRepeat; // 新增：场景动画重复次数
  final String? animeOverlay; // 新增：anime覆盖动画名称
  final bool animeLoop; // 新增：anime是否循环播放
  final bool animeKeep; // 新增：anime完成后是否保留
  final Map<String, CharacterState> cgCharacters; // 新增：CG角色状态，像scene一样铺满显示
  final bool isFastForwarding; // 新增：当前是否处于快进模式
  final bool isAutoPlaying; // 新增：当前是否处于自动播放模式
  final bool isShaking; // 新增：当前是否正在震动
  final String? shakeTarget; // 新增：震动目标 (dialogue/background)
  final double? shakeDuration; // 新增：震动持续时间
  final double? shakeIntensity; // 新增：震动强度

  GameState({
    this.background,
    this.movieFile, // 新增：视频文件参数
    this.movieRepeatCount, // 新增：视频重复播放次数参数
    this.characters = const {},
    this.dialogue,
    this.speaker,
    this.speakerAlias, // 新增：角色简写
    this.currentNode,
    this.isNvlMode = false,
    this.isNvlMovieMode = false,
    this.nvlDialogues = const [],
    this.everShownCharacters = const {},
    this.sceneFilter,
    this.sceneLayers,
    this.currentMusicRegion,
    this.sceneAnimationProperties,
    this.sceneAnimation,
    this.sceneAnimationRepeat,
    this.animeOverlay, // 新增
    this.animeLoop = false, // 新增，默认不循环
    this.animeKeep = false, // 新增，默认不保留
    this.cgCharacters = const {}, // 新增：CG角色状态，默认为空
    this.isFastForwarding = false, // 新增：快进状态，默认false
    this.isAutoPlaying = false, // 新增：自动播放状态，默认false
    this.isShaking = false, // 新增：震动状态，默认false
    this.shakeTarget, // 新增：震动目标
    this.shakeDuration, // 新增：震动持续时间
    this.shakeIntensity, // 新增：震动强度
  });

  factory GameState.initial() {
    return GameState();
  }


  GameState copyWith({
    String? background,
    String? movieFile, // 新增：视频文件参数
    int? movieRepeatCount, // 新增：视频重复播放次数参数
    bool clearMovieFile = false, // 新增：清理视频文件标志
    Map<String, CharacterState>? characters,
    String? dialogue,
    String? speaker,
    String? speakerAlias, // 新增：角色简写参数
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
    MusicRegion? currentMusicRegion,
    Map<String, double>? sceneAnimationProperties,
    bool clearSceneAnimation = false,
    String? sceneAnimation,
    int? sceneAnimationRepeat,
    String? animeOverlay, // 新增
    bool? animeLoop, // 新增
    bool? animeKeep, // 新增
    bool clearAnimeOverlay = false, // 新增
    Map<String, CharacterState>? cgCharacters, // 新增：CG角色状态
    bool clearCgCharacters = false, // 新增：是否清空CG角色
    bool? isFastForwarding, // 新增：快进状态
    bool? isAutoPlaying, // 新增：自动播放状态
    bool? isShaking, // 新增：震动状态
    String? shakeTarget, // 新增：震动目标
    double? shakeDuration, // 新增：震动持续时间
    double? shakeIntensity, // 新增：震动强度
  }) {
    return GameState(
      background: background ?? this.background,
      movieFile: clearMovieFile ? null : (movieFile ?? this.movieFile), // 修复：正确处理movie文件清理
      movieRepeatCount: clearMovieFile ? null : (movieRepeatCount ?? this.movieRepeatCount), // 新增：处理视频重复次数
      characters: clearCharacters ? <String, CharacterState>{} : (characters ?? this.characters),
      dialogue: clearDialogueAndSpeaker ? null : (dialogue ?? this.dialogue),
      speaker: forceNullSpeaker
          ? null
          : (clearDialogueAndSpeaker ? null : (speaker ?? this.speaker)),
      speakerAlias: forceNullSpeaker
          ? null
          : (clearDialogueAndSpeaker ? null : (speakerAlias ?? this.speakerAlias)), // 新增：角色简写处理
      currentNode: forceNullCurrentNode ? null : (currentNode ?? this.currentNode),
      isNvlMode: isNvlMode ?? this.isNvlMode,
      isNvlMovieMode: isNvlMovieMode ?? this.isNvlMovieMode,
      nvlDialogues: nvlDialogues ?? this.nvlDialogues,
      everShownCharacters: everShownCharacters ?? this.everShownCharacters,
      sceneFilter: clearSceneFilter ? null : (sceneFilter ?? this.sceneFilter),
      sceneLayers: clearSceneLayers ? null : (sceneLayers ?? this.sceneLayers),
      currentMusicRegion: currentMusicRegion ?? this.currentMusicRegion,
      sceneAnimationProperties: clearSceneAnimation ? null : (sceneAnimationProperties ?? this.sceneAnimationProperties),
      sceneAnimation: clearSceneAnimation ? null : (sceneAnimation ?? this.sceneAnimation),
      sceneAnimationRepeat: clearSceneAnimation ? null : (sceneAnimationRepeat ?? this.sceneAnimationRepeat),
      animeOverlay: clearAnimeOverlay ? null : (animeOverlay ?? this.animeOverlay), // 新增
      animeLoop: animeLoop ?? this.animeLoop, // 新增
      animeKeep: animeKeep ?? this.animeKeep, // 新增
      cgCharacters: clearCgCharacters ? <String, CharacterState>{} : (cgCharacters ?? this.cgCharacters), // 新增
      isFastForwarding: isFastForwarding ?? this.isFastForwarding, // 新增：快进状态
      isAutoPlaying: isAutoPlaying ?? this.isAutoPlaying, // 新增：自动播放状态
      isShaking: isShaking ?? this.isShaking, // 新增：震动状态
      shakeTarget: shakeTarget ?? this.shakeTarget, // 新增：震动目标
      shakeDuration: shakeDuration ?? this.shakeDuration, // 新增：震动持续时间
      shakeIntensity: shakeIntensity ?? this.shakeIntensity, // 新增：震动强度
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
  final Map<String, double>? animationProperties;
  final bool isFadingOut;

  CharacterState({
    required this.resourceId, 
    this.pose, 
    this.expression, 
    this.positionId,
    this.animationProperties,
    this.isFadingOut = false,
  });
  

  CharacterState copyWith({
    String? pose, 
    String? expression, 
    String? positionId,
    Map<String, double>? animationProperties,
    bool clearAnimationProperties = false,
    bool? isFadingOut,
  }) {
    return CharacterState(
      resourceId: resourceId,
      pose: pose ?? this.pose,
      expression: expression ?? this.expression,
      positionId: positionId ?? this.positionId,
      animationProperties: clearAnimationProperties ? null : (animationProperties ?? this.animationProperties),
      isFadingOut: isFadingOut ?? this.isFadingOut,
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
  final bool isFastForwardMode; // 添加快进状态保存

  GameStateSnapshot({
    required this.scriptIndex,
    required this.currentState,
    this.dialogueHistory = const [],
    this.isNvlMode = false,
    this.isNvlMovieMode = false,
    this.nvlDialogues = const [],
    this.isFastForwardMode = false, // 默认非快进状态
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
