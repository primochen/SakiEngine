import 'package:flutter/foundation.dart';
import 'package:sakiengine/src/sks_parser/sks_ast.dart';
import 'package:sakiengine/src/game/story_flowchart_manager.dart';
import 'package:sakiengine/src/game/script_merger.dart';

/// 剧情流程图分析器
/// 扫描脚本，自动构建剧情分支流程图
class StoryFlowchartAnalyzer {
  final StoryFlowchartManager _flowchartManager = StoryFlowchartManager();
  final ScriptMerger _scriptMerger = ScriptMerger();

  /// 分析整个脚本，构建流程图
  Future<void> analyzeScript() async {
    try {
      if (kDebugMode) {
        print('[FlowchartAnalyzer] 开始分析脚本...');
      }

      // 获取合并后的脚本
      final script = await _scriptMerger.getMergedScript();
      final nodes = script.children;

      // 临时变量
      String? currentChapter;           // 当前章节名
      String? lastNodeId;               // 上一个节点ID
      int lastChapterIndex = -1;        // 上一个章节的索引
      final Map<String, int> labelIndexMap = {}; // 标签到索引的映射

      // 第一遍扫描：建立标签索引
      for (int i = 0; i < nodes.length; i++) {
        final node = nodes[i];
        if (node is LabelNode) {
          labelIndexMap[node.name] = i;
        }
      }

      // 第二遍扫描：构建流程图
      for (int i = 0; i < nodes.length; i++) {
        final node = nodes[i];

        // 1. 检测章节开始
        if (node is BackgroundNode || node is MovieNode) {
          final bgName = node is BackgroundNode ? node.background : (node as MovieNode).movieFile;

          // 判断是否为章节背景
          if (_isChapterBackground(bgName)) {
            currentChapter = _extractChapterName(bgName);

            // 创建章节节点（作为独立的根节点，没有父节点）
            final chapterNodeId = 'chapter_$currentChapter';
            final chapterNode = StoryFlowNode(
              id: chapterNodeId,
              label: _findNearestLabel(i, nodes, labelIndexMap) ?? 'chapter_$i',
              type: StoryNodeType.chapter,
              displayName: currentChapter,
              scriptIndex: i,
              chapterName: currentChapter,
              parentNodeId: null, // 章节是根节点，没有父节点
            );

            await _flowchartManager.addOrUpdateNode(chapterNode);
            lastNodeId = chapterNodeId; // 更新lastNodeId，后续的分支将以此章节为父节点
            lastChapterIndex = i;

            if (kDebugMode) {
              print('[FlowchartAnalyzer] 发现章节: $currentChapter at index $i (根节点)');
            }
          }
        }

        // 2. 检测分支选择
        if (node is MenuNode) {
          final branchNodeId = 'branch_$i';
          final label = _findNearestLabel(i, nodes, labelIndexMap) ?? 'menu_$i';

          // 创建分支节点
          final branchNode = StoryFlowNode(
            id: branchNodeId,
            label: label,
            type: StoryNodeType.branch,
            displayName: '分支选择: $label',
            scriptIndex: i,
            chapterName: currentChapter,
            parentNodeId: lastNodeId,
          );

          await _flowchartManager.addOrUpdateNode(branchNode);

          // 为每个选项创建子节点
          for (final option in node.choices) {
            final targetLabel = option.targetLabel;
            final optionIndex = labelIndexMap[targetLabel];

            if (optionIndex != null) {
              final optionNodeId = 'option_${branchNodeId}_$targetLabel';
              final optionNode = StoryFlowNode(
                id: optionNodeId,
                label: targetLabel,
                type: StoryNodeType.branch,
                displayName: option.text,
                scriptIndex: optionIndex,
                chapterName: currentChapter,
                parentNodeId: branchNodeId,
                metadata: {'branchText': option.text},
              );

              await _flowchartManager.addOrUpdateNode(optionNode);

              // 分析选项后的路径
              await _analyzePathAfterBranch(
                optionNodeId,
                optionIndex,
                nodes,
                labelIndexMap,
                currentChapter,
              );
            }
          }

          lastNodeId = branchNodeId;
        }

        // 3. 检测结局（return 前的最后一个 scene）
        if (node is ReturnNode) {
          final lastSceneIndex = _findLastSceneBeforeReturn(i, nodes);
          if (lastSceneIndex != null) {
            final endingNodeId = 'ending_$lastSceneIndex';
            final label = _findNearestLabel(lastSceneIndex, nodes, labelIndexMap) ?? 'ending_$lastSceneIndex';

            final endingNode = StoryFlowNode(
              id: endingNodeId,
              label: label,
              type: StoryNodeType.ending,
              displayName: '结局: $label',
              scriptIndex: lastSceneIndex,
              chapterName: currentChapter,
              parentNodeId: lastNodeId,
            );

            await _flowchartManager.addOrUpdateNode(endingNode);

            if (kDebugMode) {
              print('[FlowchartAnalyzer] 发现结局: $label at index $lastSceneIndex');
            }
          }
        }
      }

      // 检测分支汇合点
      await _detectMergePoints(nodes, labelIndexMap);

      if (kDebugMode) {
        print('[FlowchartAnalyzer] 脚本分析完成');
        print('[FlowchartAnalyzer] 统计信息: ${_flowchartManager.exportData()['stats']}');
      }
    } catch (e, stack) {
      if (kDebugMode) {
        print('[FlowchartAnalyzer] 分析失败: $e');
        print(stack);
      }
    }
  }

  /// 分析分支选项后的路径（增强版）
  Future<void> _analyzePathAfterBranch(
    String parentNodeId,
    int startIndex,
    List<SksNode> nodes,
    Map<String, int> labelIndexMap,
    String? currentChapter,
  ) async {
    // 跟踪路径，直到遇到下一个分支、章节、结局或跳转
    for (int i = startIndex; i < nodes.length; i++) {
      final node = nodes[i];

      // 遇到章节背景或章节相关节点，立即停止（章节应该由主循环处理）
      if (node is BackgroundNode && _isChapterBackground(node.background)) {
        if (kDebugMode) {
          print('[FlowchartAnalyzer] 路径分析遇到新章节，停止 (index: $i)');
        }
        break;
      }
      if (node is MovieNode && _isChapterBackground(node.movieFile)) {
        if (kDebugMode) {
          print('[FlowchartAnalyzer] 路径分析遇到新章节(Movie)，停止 (index: $i)');
        }
        break;
      }

      // 遇到新的分支，创建分支节点并继续分析
      if (node is MenuNode) {
        final branchNodeId = 'branch_$i';
        final label = _findNearestLabel(i, nodes, labelIndexMap) ?? 'menu_$i';

        // 检查是否已存在
        if (!_flowchartManager.nodes.containsKey(branchNodeId)) {
          // 创建分支节点
          final branchNode = StoryFlowNode(
            id: branchNodeId,
            label: label,
            type: StoryNodeType.branch,
            displayName: '分支选择: $label',
            scriptIndex: i,
            chapterName: currentChapter,
            parentNodeId: parentNodeId,
          );

          await _flowchartManager.addOrUpdateNode(branchNode);

          // 为每个选项创建子节点
          for (final option in node.choices) {
            final targetLabel = option.targetLabel;
            final optionIndex = labelIndexMap[targetLabel];

            if (optionIndex != null) {
              final optionNodeId = 'option_${branchNodeId}_$targetLabel';

              // 检查是否已存在
              if (!_flowchartManager.nodes.containsKey(optionNodeId)) {
                final optionNode = StoryFlowNode(
                  id: optionNodeId,
                  label: targetLabel,
                  type: StoryNodeType.branch,
                  displayName: option.text,
                  scriptIndex: optionIndex,
                  chapterName: currentChapter,
                  parentNodeId: branchNodeId,
                  metadata: {'branchText': option.text},
                );

                await _flowchartManager.addOrUpdateNode(optionNode);

                // 递归分析选项后的路径
                await _analyzePathAfterBranch(
                  optionNodeId,
                  optionIndex,
                  nodes,
                  labelIndexMap,
                  currentChapter,
                );
              }
            }
          }
        }
        break; // 分支已处理，停止当前路径分析
      }

      // 遇到跳转，停止当前路径（跳转目标会在汇合点检测中处理）
      if (node is JumpNode) {
        if (kDebugMode) {
          print('[FlowchartAnalyzer] 路径分析遇到跳转，停止 (target: ${node.targetLabel})');
        }
        break;
      }

      // 遇到返回，检查结局
      if (node is ReturnNode) {
        final lastSceneIndex = _findLastSceneBeforeReturn(i, nodes);
        if (lastSceneIndex != null) {
          final endingNodeId = 'ending_$lastSceneIndex';

          // 检查是否已存在
          if (!_flowchartManager.nodes.containsKey(endingNodeId)) {
            final label = _findNearestLabel(lastSceneIndex, nodes, labelIndexMap) ?? 'ending_$lastSceneIndex';

            final endingNode = StoryFlowNode(
              id: endingNodeId,
              label: label,
              type: StoryNodeType.ending,
              displayName: '结局: $label',
              scriptIndex: lastSceneIndex,
              chapterName: currentChapter,
              parentNodeId: parentNodeId,
            );

            await _flowchartManager.addOrUpdateNode(endingNode);
          }
        }
        break;
      }
    }
  }

  /// 检测分支汇合点
  /// 当多个分支路径跳转到同一个label时，该label就是汇合点
  Future<void> _detectMergePoints(
    List<SksNode> nodes,
    Map<String, int> labelIndexMap,
  ) async {
    final Map<String, List<String>> labelToParents = {}; // label -> 来源节点列表

    // 收集所有跳转关系
    for (final entry in _flowchartManager.nodes.entries) {
      final node = entry.value;

      // 找到该节点后续的跳转目标
      if (node.scriptIndex < nodes.length) {
        for (int i = node.scriptIndex; i < nodes.length; i++) {
          final scriptNode = nodes[i];

          if (scriptNode is JumpNode) {
            final targetLabel = scriptNode.targetLabel;
            if (!labelToParents.containsKey(targetLabel)) {
              labelToParents[targetLabel] = [];
            }
            labelToParents[targetLabel]!.add(node.id);
            break; // 只关心第一个跳转
          }

          // 遇到新的分支、章节或返回，停止
          if (scriptNode is MenuNode ||
              scriptNode is ReturnNode ||
              _isChapterBackground(_getNodeBackground(scriptNode))) {
            break;
          }
        }
      }
    }

    // 创建汇合点节点
    for (final entry in labelToParents.entries) {
      final label = entry.key;
      final parents = entry.value;

      // 如果有多个父节点，说明是汇合点
      if (parents.length > 1) {
        final targetIndex = labelIndexMap[label];
        if (targetIndex != null) {
          final mergeNodeId = 'merge_$label';

          // 获取当前章节（从第一个父节点获取）
          final firstParent = _flowchartManager.nodes[parents.first];
          final currentChapter = firstParent?.chapterName;

          final mergeNode = StoryFlowNode(
            id: mergeNodeId,
            label: label,
            type: StoryNodeType.merge,
            displayName: '汇合点: $label',
            scriptIndex: targetIndex,
            chapterName: currentChapter, // 设置章节名
            parentNodeId: parents.first, // 保留第一个父节点作为主父节点
            metadata: {
              'parentCount': parents.length,
              'parentIds': parents, // 保存所有父节点ID列表
            },
          );

          await _flowchartManager.addOrUpdateNode(mergeNode);

          if (kDebugMode) {
            print('[FlowchartAnalyzer] 发现汇合点: $label (来自 ${parents.length} 个分支: ${parents.join(", ")})');
          }

          // 关键：继续分析汇合点之后的路径
          await _analyzePathAfterBranch(
            mergeNodeId,
            targetIndex,
            nodes,
            labelIndexMap,
            currentChapter,
          );
        }
      }
    }
  }

  /// 判断背景是否为章节背景
  bool _isChapterBackground(String? bgName) {
    if (bgName == null) return false;
    final lower = bgName.toLowerCase();
    return lower.contains('chapter') ||
        lower.contains('prologue') ||
        lower.contains('epilogue') ||
        RegExp(r'\bch\d+\b').hasMatch(lower) ||
        RegExp(r'\bep\d+\b').hasMatch(lower);
  }

  /// 提取章节名
  String _extractChapterName(String? bgName) {
    if (bgName == null) return 'Unknown';

    // 尝试提取章节编号
    final chapterMatch = RegExp(r'chapter[_\s-]?(\d+)', caseSensitive: false).firstMatch(bgName);
    if (chapterMatch != null) {
      return '第${chapterMatch.group(1)}章';
    }

    final chMatch = RegExp(r'\bch(\d+)\b', caseSensitive: false).firstMatch(bgName);
    if (chMatch != null) {
      return '第${chMatch.group(1)}章';
    }

    if (bgName.toLowerCase().contains('prologue')) {
      return '序章';
    }

    if (bgName.toLowerCase().contains('epilogue')) {
      return '尾声';
    }

    return bgName;
  }

  /// 查找最近的label
  String? _findNearestLabel(int index, List<SksNode> nodes, Map<String, int> labelIndexMap) {
    // 向前查找
    for (int i = index; i >= 0; i--) {
      if (nodes[i] is LabelNode) {
        return (nodes[i] as LabelNode).name;
      }
    }
    return null;
  }

  /// 查找return前的最后一个scene
  int? _findLastSceneBeforeReturn(int returnIndex, List<SksNode> nodes) {
    for (int i = returnIndex - 1; i >= 0; i--) {
      final node = nodes[i];
      if (node is BackgroundNode || node is MovieNode) {
        return i;
      }
    }
    return null;
  }

  /// 获取索引处的背景
  String? _getBackgroundAtIndex(int index, List<SksNode> nodes) {
    if (index < 0 || index >= nodes.length) return null;
    final node = nodes[index];
    if (node is BackgroundNode) return node.background;
    if (node is MovieNode) return node.movieFile;
    return null;
  }

  /// 获取节点的背景名
  String? _getNodeBackground(SksNode node) {
    if (node is BackgroundNode) return node.background;
    if (node is MovieNode) return node.movieFile;
    return null;
  }

  /// 清空流程图并重新分析
  Future<void> resetAndAnalyze() async {
    await _flowchartManager.clearAll();
    await analyzeScript();
  }
}
