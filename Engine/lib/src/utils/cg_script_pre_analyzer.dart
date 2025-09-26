import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sakiengine/src/sks_parser/sks_ast.dart';
import 'package:sakiengine/src/utils/cg_image_compositor.dart';
import 'package:sakiengine/src/utils/cg_pre_warm_manager.dart';

/// CG脚本预分析器
/// 
/// 功能：
/// - 分析脚本中的CG命令
/// - 智能预热即将出现的CG图像
/// - 后台异步处理，不阻塞主线程
class CgScriptPreAnalyzer {
  static final CgScriptPreAnalyzer _instance = CgScriptPreAnalyzer._internal();
  factory CgScriptPreAnalyzer() => _instance;
  CgScriptPreAnalyzer._internal();

  final CgImageCompositor _compositor = CgImageCompositor();
  final CgPreWarmManager _preWarmManager = CgPreWarmManager();
  final Map<String, Timer> _precompositionTasks = {};
  
  /// 初始化预分析器
  void initialize() {
    _preWarmManager.start();
    if (kDebugMode) {
      print('[CgScriptPreAnalyzer] 预分析器已初始化，预热管理器已启动');
    }
  }
  
  /// 销毁预分析器
  void dispose() {
    cancelAllTasks();
    _preWarmManager.stop();
    if (kDebugMode) {
      print('[CgScriptPreAnalyzer] 预分析器已销毁');
    }
  }
  
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
    
    // 延迟100ms后开始预合成和预热，避免阻塞主线程
    _precompositionTasks[cacheKey] = Timer(const Duration(milliseconds: 100), () {
      _performBackgroundCompositionAndPreWarm(resourceId, pose, expression, cacheKey);
    });
  }
  
  /// 执行后台合成和预热
  Future<void> _performBackgroundCompositionAndPreWarm(
    String resourceId, 
    String pose, 
    String expression, 
    String cacheKey
  ) async {
    try {
      if (kDebugMode) {
        print('[CgScriptPreAnalyzer] 后台预合成和预热: $resourceId $pose $expression');
      }
      
      // 1. 首先进行图像合成
      final compositePath = await _compositor.getCompositeImagePath(
        resourceId: resourceId,
        pose: pose,
        expression: expression,
      );
      
      if (compositePath != null) {
        if (kDebugMode) {
          print('[CgScriptPreAnalyzer] ✅ 预合成完成: $compositePath');
        }
        
        // 2. 立即启动预热任务（高优先级，因为即将出现）
        await _preWarmManager.preWarm(
          resourceId: resourceId,
          pose: pose,
          expression: expression,
          priority: PreWarmPriority.high,
        );
        
        if (kDebugMode) {
          print('[CgScriptPreAnalyzer] 🔥 预热任务已启动: $cacheKey');
        }
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('[CgScriptPreAnalyzer] 后台合成和预热失败: $e');
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
  
  /// 预热当前CG（用于读档恢复等场景）
  Future<bool> preWarmCurrentCg({
    required String resourceId,
    required String pose,
    required String expression,
  }) async {
    if (kDebugMode) {
      print('[CgScriptPreAnalyzer] 预热当前CG: $resourceId $pose $expression');
    }
    
    return await _preWarmManager.preWarmUrgent(
      resourceId: resourceId,
      pose: pose,
      expression: expression,
    );
  }
  
  /// 批量预热CG列表
  Future<void> batchPreWarm(List<Map<String, String>> cgList) async {
    final preWarmList = cgList.map((cg) => {
      'resourceId': cg['resourceId']!,
      'pose': cg['pose'] ?? 'pose1',
      'expression': cg['expression'] ?? '1',
      'priority': PreWarmPriority.medium,
    }).toList();
    
    await _preWarmManager.preWarmBatch(preWarmList);
  }
  
  /// 获取预热管理器状态（用于调试）
  Map<String, dynamic> getPreWarmStatus() {
    return _preWarmManager.getStatus();
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
}