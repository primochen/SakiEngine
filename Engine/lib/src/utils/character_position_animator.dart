import 'dart:async';
import 'package:flutter/material.dart';

/// 角色位置变化的描述
class CharacterPositionChange {
  final String characterId;
  final double fromX;
  final double toX;
  
  CharacterPositionChange({
    required this.characterId,
    required this.fromX,
    required this.toX,
  });
}

/// 角色位置补间动画管理器
/// 处理角色从一个位置平滑移动到另一个位置的动画
class CharacterPositionAnimator {
  AnimationController? _controller;
  Animation<double>? _animation;
  List<CharacterPositionChange> _positionChanges = [];
  Map<String, double> _currentPositions = {};
  void Function(Map<String, double>)? _onUpdate;
  VoidCallback? _onComplete;
  
  /// 开始角色位置变化的补间动画
  /// [positionChanges] 所有需要动画的角色位置变化
  /// [vsync] TickerProvider用于创建AnimationController
  /// [duration] 动画持续时间，默认0.5秒
  /// [curve] 动画曲线，默认easeInOut
  /// [onUpdate] 动画更新回调，参数是角色ID到当前位置的映射
  /// [onComplete] 动画完成回调
  Future<void> animatePositionChanges({
    required List<CharacterPositionChange> positionChanges,
    required TickerProvider vsync,
    Duration duration = const Duration(milliseconds: 500),
    Curve curve = Curves.easeInOut,
    void Function(Map<String, double>)? onUpdate,
    VoidCallback? onComplete,
  }) async {
    if (positionChanges.isEmpty) {
      onComplete?.call();
      return;
    }
    
    _positionChanges = positionChanges;
    _onUpdate = onUpdate;
    _onComplete = onComplete;
    
    // 初始化当前位置
    _currentPositions.clear();
    for (final change in positionChanges) {
      _currentPositions[change.characterId] = change.fromX;
    }
    
    // 创建动画控制器
    _controller?.dispose();
    _controller = AnimationController(
      duration: duration,
      vsync: vsync,
    );
    
    // 创建动画
    final curvedAnimation = CurvedAnimation(
      parent: _controller!,
      curve: curve,
    );
    
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation);
    
    _animation!.addListener(_updatePositions);
    
    // 启动动画
    await _controller!.forward();
    
    // 清理
    _animation!.removeListener(_updatePositions);
    _controller?.dispose();
    _controller = null;
    _animation = null;
    
    _onComplete?.call();
  }
  
  /// 更新角色位置
  void _updatePositions() {
    final progress = _animation!.value;
    
    for (final change in _positionChanges) {
      final currentX = change.fromX + (change.toX - change.fromX) * progress;
      _currentPositions[change.characterId] = currentX;
    }
    
    _onUpdate?.call(Map.from(_currentPositions));
  }
  
  /// 立即停止动画
  void stop() {
    if (_controller != null && _controller!.isAnimating) {
      _animation?.removeListener(_updatePositions);
      _controller?.stop();
      _controller?.dispose();
      _controller = null;
      _animation = null;
    }
  }
  
  /// 释放资源
  void dispose() {
    stop();
  }
  
  /// 获取当前是否正在动画中
  bool get isAnimating => _controller?.isAnimating ?? false;
}