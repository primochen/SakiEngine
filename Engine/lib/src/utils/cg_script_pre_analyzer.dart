import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sakiengine/src/sks_parser/sks_ast.dart';
import 'package:sakiengine/src/utils/cg_image_compositor.dart';

/// CG脚本预分析器
/// 
/// 功能：
/// - 分析脚本中的CG命令
/// - 预合成即将出现的CG图像
/// - 后台异步处理，不阻塞主线程
class CgScriptPreAnalyzer {
  static final CgScriptPreAnalyzer _instance = CgScriptPreAnalyzer._internal();
  factory CgScriptPreAnalyzer() => _instance;
  CgScriptPreAnalyzer._internal();

  final CgImageCompositor _compositor = CgImageCompositor();
  final Map<String, Timer> _precompositionTasks = {};
  
  /// 预分析当前位置后的脚本，预合成CG图像
  /// 
  /// [scriptNodes] - 脚本节点列表
  /// [currentIndex] - 当前脚本位置
  /// [lookAheadLines] - 向前查看的行数（默认10行）
  Future<void> preAnalyzeScript({
    required List<SksNode> scriptNodes,
    required int currentIndex,
    int lookAheadLines = 10,
  }) async {
    try {
      // 计算分析范围
      final endIndex = (currentIndex + lookAheadLines).clamp(0, scriptNodes.length - 1);
      
      // 收集即将出现的CG命令
      final upcomingCgCommands = <CgNode>[];
      
      for (int i = currentIndex + 1; i <= endIndex && i < scriptNodes.length; i++) {
        final node = scriptNodes[i];
        if (node is CgNode) {
          upcomingCgCommands.add(node);
        }
      }
      
      if (upcomingCgCommands.isEmpty) {
        return;
      }
      
      if (kDebugMode) {
        print('[CgScriptPreAnalyzer] 发现 ${upcomingCgCommands.length} 个即将出现的CG命令');
      }
      
      // 异步预合成CG图像
      for (final cgNode in upcomingCgCommands) {
        _schedulePrecomposition(cgNode);
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('[CgScriptPreAnalyzer] 预分析脚本失败: $e');
      }
    }
  }
  
  /// 调度预合成任务
  void _schedulePrecomposition(CgNode cgNode) {
    final resourceId = cgNode.character;
    final pose = cgNode.pose ?? 'pose1';
    final expression = cgNode.expression ?? 'happy';
    
    final cacheKey = '${resourceId}_${pose}_${expression}';
    
    // 避免重复预合成
    if (_precompositionTasks.containsKey(cacheKey)) {
      return;
    }
    
    // 延迟100ms后开始预合成，避免阻塞主线程
    _precompositionTasks[cacheKey] = Timer(const Duration(milliseconds: 100), () {
      _performBackgroundComposition(resourceId, pose, expression, cacheKey);
    });
  }
  
  /// 执行后台合成
  Future<void> _performBackgroundComposition(
    String resourceId, 
    String pose, 
    String expression, 
    String cacheKey
  ) async {
    try {
      if (kDebugMode) {
        print('[CgScriptPreAnalyzer] 后台预合成: $resourceId $pose $expression');
      }
      
      final compositePath = await _compositor.getCompositeImagePath(
        resourceId: resourceId,
        pose: pose,
        expression: expression,
      );
      
      if (compositePath != null && kDebugMode) {
        print('[CgScriptPreAnalyzer] ✅ 预合成完成: $compositePath');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('[CgScriptPreAnalyzer] 后台合成失败: $e');
      }
    } finally {
      // 清理任务记录
      _precompositionTasks.remove(cacheKey);
    }
  }
  
  /// 预合成指定的CG参数
  Future<void> precomposeCg({
    required String resourceId,
    required String pose,
    required String expression,
  }) async {
    final cacheKey = '${resourceId}_${pose}_${expression}';
    
    // 避免重复预合成
    if (_precompositionTasks.containsKey(cacheKey)) {
      return;
    }
    
    _schedulePrecomposition(CgNode(
      resourceId,
      pose: pose,
      expression: expression,
    ));
  }
  
  /// 批量预合成CG列表
  Future<void> batchPrecompose(List<Map<String, String>> cgList) async {
    for (final cg in cgList) {
      final resourceId = cg['resourceId'];
      final pose = cg['pose'] ?? 'pose1';
      final expression = cg['expression'] ?? 'happy';
      
      if (resourceId != null) {
        await precomposeCg(
          resourceId: resourceId,
          pose: pose,
          expression: expression,
        );
      }
    }
  }
  
  /// 取消所有预合成任务
  void cancelAllTasks() {
    for (final timer in _precompositionTasks.values) {
      timer.cancel();
    }
    _precompositionTasks.clear();
  }
  
  /// 获取当前正在进行的预合成任务数量
  int get activeTasks => _precompositionTasks.length;
  
  /// 清理资源
  void dispose() {
    cancelAllTasks();
  }
}