import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sakiengine/src/sks_parser/sks_ast.dart';
import 'package:sakiengine/src/utils/cg_image_compositor.dart';
import 'package:sakiengine/src/utils/gpu_image_compositor.dart';
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
  final GpuImageCompositor _gpuCompositor = GpuImageCompositor();
  final CgPreWarmManager _preWarmManager = CgPreWarmManager();
  final Map<String, Timer> _precompositionTasks = {};
  
  /// 性能优化开关
  bool _useGpuAcceleration = true;
  bool _useBatchProcessing = true;
  
  /// 初始化预分析器
  void initialize() {
    _preWarmManager.start();
    
    // 预热GPU加速器
    if (_useGpuAcceleration) {
      _gpuCompositor.warmUpGpu();
    }
    
    if (kDebugMode) {
      print('[CgScriptPreAnalyzer] 预分析器已初始化，GPU加速: $_useGpuAcceleration，批量处理: $_useBatchProcessing');
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
  /// [lookAheadLines] - 向前查看的行数（快进模式下大幅增加）
  /// [isSkipping] - 是否处于快进模式
  Future<void> preAnalyzeScript({
    required List<SksNode> scriptNodes,
    required int currentIndex,
    int lookAheadLines = 10,
    bool isSkipping = false,
  }) async {
    try {
      // 快进模式下大幅增加预分析范围
      int effectiveLookAhead = lookAheadLines;
      if (isSkipping) {
        effectiveLookAhead = (scriptNodes.length * 0.1).round().clamp(50, 200); // 快进时看整个脚本的10%，至少50行，最多200行
        if (kDebugMode) {
          print('[CgScriptPreAnalyzer] 快进模式：扩大预分析范围到 $effectiveLookAhead 行');
        }
      }
      
      // 计算分析范围
      final endIndex = (currentIndex + effectiveLookAhead).clamp(0, scriptNodes.length - 1);
      
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
      
      // 快进模式下并行预合成，否则序列预合成
      if (isSkipping) {
        await _batchPrecomposition(upcomingCgCommands);
      } else {
        // 异步预合成CG图像
        for (final cgNode in upcomingCgCommands) {
          _schedulePrecomposition(cgNode);
        }
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
    
    final cacheKey = '${resourceId}_${pose}_$expression';
    
    // 避免重复预合成
    if (_precompositionTasks.containsKey(cacheKey)) {
      return;
    }
    
    // 延迟100ms后开始预合成和预热，避免阻塞主线程
    _precompositionTasks[cacheKey] = Timer(const Duration(milliseconds: 100), () {
      _performBackgroundCompositionAndPreWarm(resourceId, pose, expression, cacheKey);
    });
  }
  
  /// 执行后台合成和预热 - GPU加速版本
  Future<void> _performBackgroundCompositionAndPreWarm(
    String resourceId, 
    String pose, 
    String expression, 
    String cacheKey
  ) async {
    final startTime = DateTime.now();
    try {
      if (kDebugMode) {
        print('[CgScriptPreAnalyzer] 开始预合成: $resourceId $pose $expression');
      }
      
      String? compositePath;
      
      // 选择合成器
      if (_useGpuAcceleration) {
        // 使用GPU加速合成器
        compositePath = await _gpuCompositor.getCompositeImagePath(
          resourceId: resourceId,
          pose: pose,
          expression: expression,
        );
      } else {
        // 使用传统CPU合成器
        compositePath = await _compositor.getCompositeImagePath(
          resourceId: resourceId,
          pose: pose,
          expression: expression,
        );
      }
      
      if (compositePath != null) {
        final compositionTime = DateTime.now();
        final compositionDuration = compositionTime.difference(startTime).inMilliseconds;
        
        if (kDebugMode) {
          final mode = _useGpuAcceleration ? 'GPU' : 'CPU';
          print('[CgScriptPreAnalyzer] ✅ $mode图像合成完成 ($compositionDuration ms): $compositePath');
        }
        
        // 2. 立即启动预热任务（高优先级，因为即将出现）
        await _preWarmManager.preWarm(
          resourceId: resourceId,
          pose: pose,
          expression: expression,
          priority: PreWarmPriority.high,
        );
        
        final endTime = DateTime.now();
        final totalDuration = endTime.difference(startTime).inMilliseconds;
        final preWarmDuration = endTime.difference(compositionTime).inMilliseconds;
        
        if (kDebugMode) {
          print('[CgScriptPreAnalyzer] 🔥 预热完成 ($preWarmDuration ms): $cacheKey');
          print('[CgScriptPreAnalyzer] 📊 总耗时 $totalDuration ms (合成: $compositionDuration ms, 预热: $preWarmDuration ms): $resourceId $pose $expression');
        }
      }
      
    } catch (e) {
      final endTime = DateTime.now();
      final totalDuration = endTime.difference(startTime).inMilliseconds;
      if (kDebugMode) {
        print('[CgScriptPreAnalyzer] ❌ 预合成失败 ($totalDuration ms): $e');
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
    final cacheKey = '${resourceId}_${pose}_$expression';
    
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
  
  /// 批量预合成（快进模式专用）- GPU加速版本
  Future<void> _batchPrecomposition(List<CgNode> cgCommands) async {
    if (cgCommands.isEmpty) return;
    
    final startTime = DateTime.now();
    
    if (kDebugMode) {
      print('[CgScriptPreAnalyzer] 🚀 启动批量预合成 ${cgCommands.length} 个CG命令（GPU加速: $_useGpuAcceleration）');
    }
    
    try {
      if (_useGpuAcceleration && _useBatchProcessing) {
        // GPU批量处理模式
        await _gpuBatchPrecomposition(cgCommands);
      } else {
        // 传统并行处理模式
        await _traditionalBatchPrecomposition(cgCommands);
      }
      
      final totalTime = DateTime.now().difference(startTime).inMilliseconds;
      
      if (kDebugMode) {
        print('[CgScriptPreAnalyzer] ✅ 批量预合成完成，总耗时: ${totalTime}ms，平均每张: ${(totalTime / cgCommands.length).round()}ms');
      }
      
    } catch (e) {
      final errorTime = DateTime.now().difference(startTime).inMilliseconds;
      if (kDebugMode) {
        print('[CgScriptPreAnalyzer] ❌ 批量预合成失败 ($errorTime ms): $e');
      }
    }
  }

  /// GPU批量预合成
  Future<void> _gpuBatchPrecomposition(List<CgNode> cgCommands) async {
    // 准备批量请求
    final requests = cgCommands.map((cgNode) => {
      'resourceId': cgNode.character,
      'pose': cgNode.pose ?? 'pose1',
      'expression': cgNode.expression ?? 'happy',
    }).toList();
    
    // GPU批量合成
    final results = await _gpuCompositor.batchCompose(requests);
    
    // 启动预热任务
    final preWarmTasks = <Future<void>>[];
    for (int i = 0; i < cgCommands.length; i++) {
      final cgNode = cgCommands[i];
      if (results[i] != null) {
        final preWarmTask = _preWarmManager.preWarm(
          resourceId: cgNode.character,
          pose: cgNode.pose ?? 'pose1',
          expression: cgNode.expression ?? 'happy',
          priority: PreWarmPriority.high,
        );
        preWarmTasks.add(preWarmTask);
      }
    }
    
    // 等待所有预热完成
    await Future.wait(preWarmTasks, eagerError: false);
  }

  /// 传统批量预合成（回退方案）
  Future<void> _traditionalBatchPrecomposition(List<CgNode> cgCommands) async {
    final precompositionTasks = cgCommands.map((cgNode) {
      final resourceId = cgNode.character;
      final pose = cgNode.pose ?? 'pose1';
      final expression = cgNode.expression ?? 'happy';
      
      return _performBackgroundCompositionAndPreWarm(
        resourceId, 
        pose, 
        expression, 
        '${resourceId}_${pose}_${expression}_batch'
      );
    }).toList();
    
    // 等待所有预合成任务完成
    await Future.wait(precompositionTasks, eagerError: false);
  }

  /// 分析整个脚本，收集所有CG差分组合
  Map<String, Set<String>> analyzeAllCgCombinations(List<SksNode> scriptNodes) {
    final combinations = <String, Set<String>>{};
    
    for (final node in scriptNodes) {
      if (node is CgNode) {
        final resourceId = node.character;
        final pose = node.pose ?? 'pose1';
        final expression = node.expression ?? 'happy';
        
        final key = '${resourceId}_$pose';
        if (!combinations.containsKey(key)) {
          combinations[key] = <String>{};
        }
        combinations[key]!.add(expression);
      }
    }
    
    if (kDebugMode) {
      print('[CgScriptPreAnalyzer] 发现的CG组合:');
      combinations.forEach((key, expressions) {
        print('  $key: ${expressions.toList()}');
      });
    }
    
    return combinations;
  }
  
  /// 获取指定角色和姿势的所有表情差分
  Set<String> getExpressionsForCharacter(String resourceId, String pose, List<SksNode> scriptNodes) {
    final expressions = <String>{};
    
    for (final node in scriptNodes) {
      if (node is CgNode && 
          node.character == resourceId && 
          (node.pose ?? 'pose1') == pose) {
        expressions.add(node.expression ?? 'happy');
      }
    }
    
    return expressions;
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
  
  /// 设置GPU加速开关
  void setGpuAcceleration(bool enabled) {
    _useGpuAcceleration = enabled;
    _preWarmManager.setGpuAcceleration(enabled);
    if (kDebugMode) {
      print('[CgScriptPreAnalyzer] GPU加速已${enabled ? "启用" : "禁用"}（同步设置预热管理器）');
    }
  }
  
  /// 设置批量处理开关
  void setBatchProcessing(bool enabled) {
    _useBatchProcessing = enabled;
    if (kDebugMode) {
      print('[CgScriptPreAnalyzer] 批量处理已${enabled ? "启用" : "禁用"}');
    }
  }
  
  /// 获取性能统计信息
  Map<String, dynamic> getPerformanceStats() {
    return {
      'gpu_acceleration': _useGpuAcceleration,
      'batch_processing': _useBatchProcessing,
      'active_tasks': activeTasks,
      'preWarm_status': _preWarmManager.getStatus(),
      'gpu_compositor_stats': _gpuCompositor.getCacheStats(),
      'cpu_compositor_stats': _compositor.getCacheStats(),
    };
  }
}