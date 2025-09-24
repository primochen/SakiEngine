import 'package:flutter/foundation.dart';

/// 差分偏移配置类
class ExpressionOffsetConfig {
  final String characterId;
  final String pose;
  final double yOffset; // 纵向偏移量（归一化值，相对于角色高度，-1.0到1.0）
  final double xOffset; // 横向偏移量（归一化值，相对于角色宽度，-1.0到1.0）
  
  const ExpressionOffsetConfig({
    required this.characterId,
    required this.pose,
    required this.yOffset,
    this.xOffset = 0.0,
  });
  
  String get key => '${characterId}_$pose';
  
  @override
  String toString() => 'ExpressionOffsetConfig($characterId, $pose, x:$xOffset, y:$yOffset)';
}

/// 差分偏移管理器
/// 用于管理特定角色、特定姿势下差分（表情）图层的位置偏移
/// 所有偏移值都是归一化的，适应窗口缩放
class ExpressionOffsetManager {
  static final ExpressionOffsetManager _instance = ExpressionOffsetManager._internal();
  factory ExpressionOffsetManager() => _instance;
  ExpressionOffsetManager._internal();
  
  // 偏移配置映射表
  final Map<String, ExpressionOffsetConfig> _offsetConfigs = {};
  
  /// 初始化默认配置
  void initializeDefaultConfigs() {
    // xiayo1 角色的特定姿势偏移配置
    // 负值向上/左偏移，正值向下/右偏移
    addOffsetConfig(ExpressionOffsetConfig(
      characterId: 'xiayo1',
      pose: 'pose6',
      xOffset: -0.015, // 横向偏移（可调整）
      yOffset: 0.02, // 纵向偏移（可调整）
    ));
    
    addOffsetConfig(ExpressionOffsetConfig(
      characterId: 'xiayo1',
      pose: 'pose7',
      xOffset: 0.0, // 横向偏移（可调整）
      yOffset: -0.08, // 向上偏移8%的角色高度
    ));
    
    addOffsetConfig(ExpressionOffsetConfig(
      characterId: 'xiayo1',
      pose: 'pose8',
      xOffset: 0.0, // 横向偏移（可调整）
      yOffset: -0.10, // 向上偏移10%的角色高度
    ));
    
    if (kDebugMode) {
      print('[ExpressionOffsetManager] 已初始化默认配置: ${_offsetConfigs.keys}');
    }
  }
  
  /// 添加偏移配置
  void addOffsetConfig(ExpressionOffsetConfig config) {
    _offsetConfigs[config.key] = config;
    if (kDebugMode) {
      print('[ExpressionOffsetManager] 添加配置: ${config.toString()}');
    }
  }
  
  /// 移除偏移配置
  void removeOffsetConfig(String characterId, String pose) {
    final key = '${characterId}_$pose';
    final removed = _offsetConfigs.remove(key);
    if (kDebugMode && removed != null) {
      print('[ExpressionOffsetManager] 移除配置: $key');
    }
  }
  
  /// 获取差分偏移（归一化值）
  /// [characterId] 角色ID (如 'xiayo1')
  /// [pose] 姿势 (如 'pose6', 'pose7', 'pose8')
  /// [layerType] 图层类型，只有包含 'expression' 的图层类型才应用偏移
  /// 返回 (xOffset, yOffset) 归一化偏移量，相对于角色尺寸
  (double, double) getExpressionOffset({
    required String characterId,
    required String pose,
    required String layerType,
  }) {
    // 只对表情图层应用偏移（包含 'expression' 关键词的图层）
    if (!layerType.contains('expression')) {
      return (0.0, 0.0);
    }
    
    final key = '${characterId}_$pose';
    final config = _offsetConfigs[key];
    
    if (config != null) {
      return (config.xOffset, config.yOffset);
    }
    
    return (0.0, 0.0);
  }
  
  /// 获取所有配置（用于调试）
  Map<String, ExpressionOffsetConfig> getAllConfigs() => Map.unmodifiable(_offsetConfigs);
  
  /// 清空所有配置
  void clearAllConfigs() {
    _offsetConfigs.clear();
    if (kDebugMode) {
      print('[ExpressionOffsetManager] 已清空所有配置');
    }
  }
  
  /// 动态调整偏移量（用于实时调试）
  /// [characterId] 角色ID
  /// [pose] 姿势
  /// [yOffset] 纵向偏移量（归一化值，相对于角色高度）
  /// [xOffset] 横向偏移量（归一化值，相对于角色宽度）
  void adjustOffset({
    required String characterId,
    required String pose,
    required double yOffset,
    double xOffset = 0.0,
  }) {
    final config = ExpressionOffsetConfig(
      characterId: characterId,
      pose: pose,
      yOffset: yOffset,
      xOffset: xOffset,
    );
    addOffsetConfig(config);
  }
  
  /// 批量设置 xiayo1 姿势 6、7、8 的偏移量（便于调试）
  /// 所有偏移量都是归一化值
  void setXiayo1SpecialPosesOffset({
    required double pose6YOffset,
    required double pose7YOffset,
    required double pose8YOffset,
    double xOffset = 0.0,
  }) {
    adjustOffset(characterId: 'xiayo1', pose: '6', yOffset: pose6YOffset, xOffset: xOffset);
    adjustOffset(characterId: 'xiayo1', pose: '7', yOffset: pose7YOffset, xOffset: xOffset);
    adjustOffset(characterId: 'xiayo1', pose: '8', yOffset: pose8YOffset, xOffset: xOffset);
    
    if (kDebugMode) {
      print('[ExpressionOffsetManager] 批量设置xiayo1特殊姿势归一化偏移: 6=$pose6YOffset, 7=$pose7YOffset, 8=$pose8YOffset');
    }
  }
  
  /// 纳米级控制方法 - 微调单个姿势的偏移量
  /// [delta] 偏移增量（归一化值），正值向下/右，负值向上/左
  void tweakOffset({
    required String characterId,
    required String pose,
    required double deltaY,
    double deltaX = 0.0,
  }) {
    final key = '${characterId}_$pose';
    final currentConfig = _offsetConfigs[key];
    
    if (currentConfig != null) {
      final newConfig = ExpressionOffsetConfig(
        characterId: characterId,
        pose: pose,
        yOffset: currentConfig.yOffset + deltaY,
        xOffset: currentConfig.xOffset + deltaX,
      );
      addOffsetConfig(newConfig);
      if (kDebugMode) {
        print('[ExpressionOffsetManager] 微调偏移 $key: 旧值(${currentConfig.yOffset}) -> 新值(${newConfig.yOffset})');
      }
    } else {
      // 如果没有配置，创建新的
      adjustOffset(characterId: characterId, pose: pose, yOffset: deltaY, xOffset: deltaX);
    }
  }
}