import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sakiengine/src/game/game_manager.dart';
import 'package:sakiengine/src/utils/dialogue_progression_manager.dart';
import 'package:sakiengine/src/utils/read_text_tracker.dart';

/// 已读文本快进管理器
/// 
/// 只跳过已经阅读过的文本内容，区别于Ctrl的强制快进
/// 这是主流视觉小说的标准功能
class ReadTextSkipManager {
  final GameManager gameManager;
  final DialogueProgressionManager dialogueProgressionManager;
  final ReadTextTracker readTextTracker;
  
  // 快进状态
  bool _isSkipping = false;
  Timer? _skipTimer;
  
  // 快进配置 - 比强制快进稍慢，让用户看清内容
  static const Duration _skipInterval = Duration(milliseconds: 100); // 比强制快进慢一些
  static const Duration _initialDelay = Duration(milliseconds: 100);
  
  // 状态回调
  final ValueChanged<bool>? onSkipStateChanged;
  final bool Function()? canSkip; // 检查是否可以快进的回调
  
  ReadTextSkipManager({
    required this.gameManager,
    required this.dialogueProgressionManager,
    required this.readTextTracker,
    this.onSkipStateChanged,
    this.canSkip,
  });
  
  /// 获取当前快进状态
  bool get isSkipping => _isSkipping;
  
  /// 开始跳过已读文本
  void startSkipping() {
    if (_isSkipping) return;
    
    // 检查是否可以快进
    if (canSkip != null && !canSkip!()) {
      return;
    }
    
    print('📖 开始跳过已读文本');
    _isSkipping = true;
    onSkipStateChanged?.call(true);
    
    // 设置GameManager为快进模式（用于跳过动画等）
    gameManager.setFastForwardMode(true);
    
    // 启动快进计时器
    _skipTimer = Timer.periodic(_skipInterval, (timer) {
      _performSkipStep();
    });
  }
  
  /// 停止跳过已读文本
  void stopSkipping() {
    if (!_isSkipping) return;
    
    print('⏹️ 停止跳过已读文本');
    _isSkipping = false;
    onSkipStateChanged?.call(false);
    
    // 退出GameManager快进模式
    gameManager.setFastForwardMode(false);
    
    _skipTimer?.cancel();
    _skipTimer = null;
  }
  
  /// 执行跳过步骤
  void _performSkipStep() {
    // 检查是否还在跳过状态
    if (!_isSkipping) return;
    
    // 再次检查是否可以跳过
    if (canSkip != null && !canSkip!()) {
      stopSkipping();
      return;
    }
    
    // 检查当前对话是否已读
    final currentState = gameManager.currentState;
    if (currentState.dialogue != null && currentState.dialogue!.isNotEmpty) {
      final isCurrentRead = readTextTracker.isRead(
        currentState.speaker, 
        currentState.dialogue!, 
        gameManager.currentScriptIndex
      );
      
      print('📖 检查对话: "${currentState.dialogue!.length > 20 ? currentState.dialogue!.substring(0, 20) + '...' : currentState.dialogue!}" 是否已读: $isCurrentRead (脚本索引: ${gameManager.currentScriptIndex})');
      
      // 如果当前对话未读，停止跳过
      if (!isCurrentRead) {
        print('📖 遇到未读文本，停止跳过');
        stopSkipping();
        return;
      }
    }
    
    // 推进对话
    try {
      dialogueProgressionManager.progressDialogue();
    } catch (e) {
      print('跳过已读文本时发生错误: $e');
      stopSkipping();
    }
  }
  
  /// 切换跳过状态
  void toggleSkipping() {
    if (_isSkipping) {
      stopSkipping();
    } else {
      startSkipping();
    }
  }
  
  /// 检查是否应该自动跳过当前对话
  /// 这个方法可以在对话显示时调用，用于自动跳过已读内容
  bool shouldAutoSkip() {
    if (!_isSkipping) return false;
    
    final currentState = gameManager.currentState;
    if (currentState.dialogue == null || currentState.dialogue!.isEmpty) {
      return false;
    }
    
    return readTextTracker.isRead(
      currentState.speaker, 
      currentState.dialogue!, 
      gameManager.currentScriptIndex
    );
  }
  
  /// 强制停止跳过（由外部逻辑调用）
  void forceStopSkipping() {
    stopSkipping();
    print('[ReadTextSkip] 已读文本跳过被强制停止');
  }
  
  /// 清理资源
  void dispose() {
    stopSkipping();
  }
}