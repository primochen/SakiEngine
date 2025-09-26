import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sakiengine/src/sks_parser/sks_ast.dart';
import 'package:sakiengine/src/utils/cg_script_pre_analyzer.dart';

/// 智能CG预测系统
/// 
/// 根据当前游戏位置智能预测并预热附近的CG组合
/// 避免预热整个游戏的所有CG，提高启动速度
class SmartCgPredictor {
  static final SmartCgPredictor _instance = SmartCgPredictor._internal();
  factory SmartCgPredictor() => _instance;
  SmartCgPredictor._internal();

  final CgScriptPreAnalyzer _preAnalyzer = CgScriptPreAnalyzer();
  
  /// 当前标签的脚本索引范围
  int _currentLabelStart = 0;
  int _currentLabelEnd = 0;
  
  /// 当前预热的范围
  int _currentPredictionStart = 0;
  int _currentPredictionEnd = 0;
  
  /// 预热范围（前后行数）
  static const int _predictionRange = 100;
  
  /// 智能预热：基于当前位置预热局部CG
  Future<void> smartPreWarm({
    required List<SksNode> scriptNodes,
    required int currentIndex,
    String? currentLabel,
  }) async {
    if (kDebugMode) {
      print('[SmartCgPredictor] 开始智能预热，当前位置: $currentIndex, 标签: $currentLabel');
    }
    
    // 1. 确定当前标签的范围
    _findCurrentLabelRange(scriptNodes, currentIndex, currentLabel);
    
    // 2. 计算预热范围（当前位置前后100行，但不超出标签范围）
    var predictionStart = (currentIndex - _predictionRange).clamp(_currentLabelStart, _currentLabelEnd);
    var predictionEnd = (currentIndex + _predictionRange).clamp(_currentLabelStart, _currentLabelEnd);
    
    if (kDebugMode) {
      print('[SmartCgPredictor] 标签范围: $_currentLabelStart - $_currentLabelEnd');
      print('[SmartCgPredictor] 初始预热范围: $predictionStart - $predictionEnd');
    }
    
    // 3. 收集范围内的CG组合
    var cgCombinations = _collectCgInRange(scriptNodes, predictionStart, predictionEnd);
    
    // 4. 如果没有找到CG组合，渐进式扩大搜索范围
    if (cgCombinations.isEmpty) {
      if (kDebugMode) {
        print('[SmartCgPredictor] 当前范围内无CG组合，开始渐进式扩大搜索');
      }
      
      // 第一次扩展：扩大到当前标签范围
      if (predictionStart > _currentLabelStart || predictionEnd < _currentLabelEnd) {
        predictionStart = _currentLabelStart;
        predictionEnd = _currentLabelEnd;
        cgCombinations = _collectCgInRange(scriptNodes, predictionStart, predictionEnd);
        
        if (kDebugMode) {
          print('[SmartCgPredictor] 扩展到标签范围: $predictionStart - $predictionEnd, 找到 ${cgCombinations.length} 个组合');
        }
      }
      
      // 第二次扩展：如果标签范围内仍然没有，适度向前后扩展
      if (cgCombinations.isEmpty) {
        final moderateExpandStart = (currentIndex - _predictionRange * 2).clamp(0, scriptNodes.length - 1);
        final moderateExpandEnd = (currentIndex + _predictionRange * 2).clamp(0, scriptNodes.length - 1);
        
        cgCombinations = _collectCgInRange(scriptNodes, moderateExpandStart, moderateExpandEnd);
        predictionStart = moderateExpandStart;
        predictionEnd = moderateExpandEnd;
        
        if (kDebugMode) {
          print('[SmartCgPredictor] 适度扩展范围: $predictionStart - $predictionEnd, 找到 ${cgCombinations.length} 个组合');
        }
        
        // 第三次扩展：仅在确实必要时才进一步扩大
        if (cgCombinations.isEmpty) {
          final maxExpandStart = (currentIndex - _predictionRange * 5).clamp(0, scriptNodes.length - 1);
          final maxExpandEnd = (currentIndex + _predictionRange * 5).clamp(0, scriptNodes.length - 1);
          
          cgCombinations = _collectCgInRange(scriptNodes, maxExpandStart, maxExpandEnd);
          predictionStart = maxExpandStart;
          predictionEnd = maxExpandEnd;
          
          if (kDebugMode) {
            print('[SmartCgPredictor] 最大扩展范围: $predictionStart - $predictionEnd, 找到 ${cgCombinations.length} 个组合');
          }
        }
      }
    }
    
    // 5. 检查预热范围是否有变化
    if (predictionStart == _currentPredictionStart && predictionEnd == _currentPredictionEnd && cgCombinations.isEmpty) {
      if (kDebugMode) {
        print('[SmartCgPredictor] 预热范围未变化且无新组合，跳过');
      }
      return;
    }
    
    _currentPredictionStart = predictionStart;
    _currentPredictionEnd = predictionEnd;
    
    if (kDebugMode) {
      print('[SmartCgPredictor] 最终预热范围: $predictionStart - $predictionEnd');
    }
    
    // 6. 异步预热这些组合
    _preWarmCombinations(cgCombinations);
  }
  
  /// 查找当前标签的范围
  void _findCurrentLabelRange(List<SksNode> scriptNodes, int currentIndex, String? currentLabel) {
    if (currentLabel == null) {
      // 没有标签信息，使用整个脚本
      _currentLabelStart = 0;
      _currentLabelEnd = scriptNodes.length - 1;
      return;
    }
    
    // 向前查找标签开始
    _currentLabelStart = 0;
    for (int i = currentIndex; i >= 0; i--) {
      final node = scriptNodes[i];
      if (node is LabelNode && node.name == currentLabel) {
        _currentLabelStart = i;
        break;
      }
    }
    
    // 向后查找标签结束（下一个标签开始）
    _currentLabelEnd = scriptNodes.length - 1;
    for (int i = currentIndex; i < scriptNodes.length; i++) {
      final node = scriptNodes[i];
      if (node is LabelNode && node.name != currentLabel) {
        _currentLabelEnd = i - 1;
        break;
      }
    }
  }
  
  /// 收集指定范围内的CG组合
  Map<String, Set<String>> _collectCgInRange(List<SksNode> scriptNodes, int start, int end) {
    final combinations = <String, Set<String>>{};
    
    for (int i = start; i <= end && i < scriptNodes.length; i++) {
      final node = scriptNodes[i];
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
      print('[SmartCgPredictor] 发现局部CG组合:');
      combinations.forEach((key, expressions) {
        print('  $key: ${expressions.toList()}');
      });
    }
    
    return combinations;
  }
  
  /// 预热CG组合
  void _preWarmCombinations(Map<String, Set<String>> combinations) {
    if (combinations.isEmpty) {
      if (kDebugMode) {
        print('[SmartCgPredictor] 没有需要预热的CG组合');
      }
      return;
    }
    
    // 异步预热，不阻塞UI
    Future.microtask(() async {
      int totalPrewarmed = 0;
      
      for (final entry in combinations.entries) {
        final parts = entry.key.split('_');
        if (parts.length >= 2) { // 至少需要resourceId和pose
          // 重新构建resourceId和pose
          final pose = parts.last; // 最后一部分是pose
          final resourceId = parts.sublist(0, parts.length - 1).join('_'); // 其余部分组成resourceId
          final expressions = entry.value;
          
          if (kDebugMode) {
            print('[SmartCgPredictor] 预热CG组合: $resourceId, pose: $pose, 表情: ${expressions.toList()}');
          }
          
          for (final expression in expressions) {
            try {
              await _preAnalyzer.precomposeCg(
                resourceId: resourceId,
                pose: pose,
                expression: expression,
              );
              totalPrewarmed++;
              
              // 小延迟避免阻塞
              if (totalPrewarmed % 2 == 0) {
                await Future.delayed(const Duration(milliseconds: 2));
              }
            } catch (e) {
              if (kDebugMode) {
                print('[SmartCgPredictor] 预热失败: $resourceId, $pose, $expression - $e');
              }
            }
          }
        } else {
          if (kDebugMode) {
            print('[SmartCgPredictor] 跳过无效的CG组合键: ${entry.key}');
          }
        }
      }
      
      if (kDebugMode) {
        print('[SmartCgPredictor] 智能预热完成！共预热 $totalPrewarmed 个组合');
      }
    });
  }
  
  /// 根据标签预热（用于新游戏和读档）
  Future<void> preWarmByLabel({
    required List<SksNode> scriptNodes,
    required String labelName,
    int baseIndex = 0,
  }) async {
    if (kDebugMode) {
      print('[SmartCgPredictor] 根据标签预热: $labelName, 基础索引: $baseIndex');
    }
    
    // 执行标准的智能预热（已经包含渐进式扩展）
    await smartPreWarm(
      scriptNodes: scriptNodes,
      currentIndex: baseIndex,
      currentLabel: labelName,
    );
    
    // 只有在标准预热找到的CG组合较少时，才进行额外的周围预热
    final standardRange = (_currentPredictionEnd - _currentPredictionStart).abs();
    if (standardRange < _predictionRange * 2) {
      if (kDebugMode) {
        print('[SmartCgPredictor] 标准预热范围较小($standardRange)，启动轻量级周围预热');
      }
      await _preWarmLabelSurroundingsLite(scriptNodes, labelName, baseIndex);
    } else {
      if (kDebugMode) {
        print('[SmartCgPredictor] 标准预热范围充足($standardRange)，跳过额外预热');
      }
    }
  }
  
  /// 轻量级周围预热（仅预热紧邻的少量CG）
  Future<void> _preWarmLabelSurroundingsLite(List<SksNode> scriptNodes, String labelName, int baseIndex) async {
    if (kDebugMode) {
      print('[SmartCgPredictor] 开始轻量级周围预热');
    }
    
    // 仅轻度扩展搜索范围（当前位置前后150行）
    final lightExtendStart = (baseIndex - _predictionRange * 1.5).clamp(0, scriptNodes.length - 1).round();
    final lightExtendEnd = (baseIndex + _predictionRange * 1.5).clamp(0, scriptNodes.length - 1).round();
    
    // 收集轻度扩展范围内的CG组合
    final lightCombinations = _collectCgInRange(scriptNodes, lightExtendStart, lightExtendEnd);
    
    // 过滤掉已经预热过的组合
    final newCombinations = <String, Set<String>>{};
    for (final entry in lightCombinations.entries) {
      // 简化逻辑：只预热最多3个新组合，避免过度预热
      if (newCombinations.length >= 3) break;
      newCombinations[entry.key] = entry.value;
    }
    
    if (newCombinations.isNotEmpty) {
      if (kDebugMode) {
        print('[SmartCgPredictor] 轻量级周围预热: ${newCombinations.length} 个组合');
        newCombinations.forEach((key, expressions) {
          print('  轻量CG: $key -> ${expressions.take(2).toList()}'); // 只显示前2个表情
        });
      }
      
      // 异步预热，使用更长的延迟
      _preWarmCombinationsWithDelay(newCombinations, delayMs: 1000);
    }
  }
  
  /// 带延迟的预热组合（用于背景预热）
  void _preWarmCombinationsWithDelay(Map<String, Set<String>> combinations, {int delayMs = 500}) {
    if (combinations.isEmpty) return;
    
    // 使用可配置的延迟时间
    Future.delayed(Duration(milliseconds: delayMs), () async {
      int totalPrewarmed = 0;
      
      for (final entry in combinations.entries) {
        final parts = entry.key.split('_');
        if (parts.length >= 3) {
          final resourceId = parts.sublist(0, parts.length - 1).join('_');
          final pose = parts.last;
          final expressions = entry.value;
          
          // 限制每个组合最多预热3个表情，避免过度预热
          final limitedExpressions = expressions.take(3);
          
          for (final expression in limitedExpressions) {
            try {
              await _preAnalyzer.precomposeCg(
                resourceId: resourceId,
                pose: pose,
                expression: expression,
              );
              totalPrewarmed++;
              
              // 根据延迟时间调整处理间隔
              if (totalPrewarmed % 1 == 0) {
                await Future.delayed(Duration(milliseconds: delayMs ~/ 50));
              }
            } catch (e) {
              // 静默处理失败
            }
          }
        }
      }
      
      if (kDebugMode) {
        print('[SmartCgPredictor] 背景预热完成！共预热 $totalPrewarmed 个组合');
      }
    });
  }
  
  /// 紧急预热：当即将显示的CG还未预热时立即预热
  Future<void> emergencyPreWarm({
    required String resourceId,
    required String pose,
    required String expression,
  }) async {
    if (kDebugMode) {
      print('[SmartCgPredictor] 紧急预热: ${resourceId}_${pose}_$expression');
    }
    
    try {
      await _preAnalyzer.precomposeCg(
        resourceId: resourceId,
        pose: pose,
        expression: expression,
      );
      
      if (kDebugMode) {
        print('[SmartCgPredictor] 紧急预热完成');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[SmartCgPredictor] 紧急预热失败: $e');
      }
    }
  }
  
  /// 检查CG组合是否已经预热
  bool isCgPreWarmed({
    required String resourceId,
    required String pose,
    required String expression,
  }) {
    // 这里应该检查CgImageCompositor的缓存
    // 但为了简化，我们返回false，让系统主动预热
    return false;
  }
  
  /// 清理预测状态
  void clearPrediction() {
    _currentLabelStart = 0;
    _currentLabelEnd = 0;
    _currentPredictionStart = 0;
    _currentPredictionEnd = 0;
    
    if (kDebugMode) {
      print('[SmartCgPredictor] 预测状态已清理');
    }
  }
}