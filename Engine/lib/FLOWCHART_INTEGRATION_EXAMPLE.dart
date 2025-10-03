// 这是一个示例，展示如何在 SoraNoUta 主菜单中集成剧情流程图功能

import 'package:flutter/material.dart';
import 'package:sakiengine/src/utils/story_flowchart_helper.dart';
import 'package:sakiengine/src/game/story_flowchart_analyzer.dart';
import 'package:sakiengine/src/utils/binary_serializer.dart';

/// 在 SoraNoutaMainMenuScreen 中添加流程图按钮的示例
class FlowchartIntegrationExample {

  /// 方式1: 在主菜单按钮列表中添加
  static Widget buildFlowchartButton(BuildContext context, {
    required Function(SaveSlot)? onLoadGameWithSave,
  }) {
    return ElevatedButton.icon(
      onPressed: () async {
        // 首次打开时分析脚本
        await StoryFlowchartHelper.showFlowchart(
          context,
          analyzeScriptFirst: true,
          onLoadSave: (saveSlot) {
            onLoadGameWithSave?.call(saveSlot);
          },
        );
      },
      icon: const Icon(Icons.account_tree),
      label: const Text('剧情流程图'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      ),
    );
  }

  /// 方式2: 作为浮动按钮添加到右上角
  static Widget buildFloatingFlowchartButton(BuildContext context, {
    required Function(SaveSlot)? onLoadGameWithSave,
  }) {
    return Positioned(
      top: 20,
      right: 20,
      child: IconButton(
        icon: const Icon(Icons.account_tree, size: 32),
        tooltip: '剧情流程图',
        onPressed: () async {
          await StoryFlowchartHelper.showFlowchart(
            context,
            analyzeScriptFirst: true,
            onLoadSave: (saveSlot) {
              onLoadGameWithSave?.call(saveSlot);
            },
          );
        },
      ),
    );
  }

  /// 方式3: 在游戏启动时后台分析脚本（推荐）
  static Future<void> initializeFlowchartOnStartup() async {
    try {
      final analyzer = StoryFlowchartAnalyzer();
      await analyzer.analyzeScript();
      print('[Flowchart] 剧情流程图初始化完成');
    } catch (e) {
      print('[Flowchart] 初始化失败: $e');
    }
  }

  /// 使用示例：修改 SoraNoutaStartupFlow
  ///
  /// @override
  /// void initState() {
  ///   super.initState();
  ///
  ///   // 在启动流程中初始化流程图
  ///   FlowchartIntegrationExample.initializeFlowchartOnStartup();
  /// }
}

/// 完整的主菜单集成示例
class SoraNoutaMainMenuWithFlowchart extends StatelessWidget {
  final VoidCallback onNewGame;
  final VoidCallback onLoadGame;
  final Function(SaveSlot)? onLoadGameWithSave;
  final VoidCallback? onContinueGame;

  const SoraNoutaMainMenuWithFlowchart({
    Key? key,
    required this.onNewGame,
    required this.onLoadGame,
    this.onLoadGameWithSave,
    this.onContinueGame,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 原有的背景和UI
          // ...

          // 添加流程图按钮到右上角
          FlowchartIntegrationExample.buildFloatingFlowchartButton(
            context,
            onLoadGameWithSave: onLoadGameWithSave,
          ),

          // 或者添加到按钮列表中
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: onNewGame,
                  child: const Text('新游戏'),
                ),
                ElevatedButton(
                  onPressed: onLoadGame,
                  child: const Text('读取存档'),
                ),
                // 添加流程图按钮
                FlowchartIntegrationExample.buildFlowchartButton(
                  context,
                  onLoadGameWithSave: onLoadGameWithSave,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
