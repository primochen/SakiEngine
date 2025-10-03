# 剧情流程图系统使用指南

## 📖 功能介绍

剧情流程图系统为 SakiEngine 提供了类似柚子社、人狼村之谜、十三机兵防卫圈等游戏的**分支导航功能**。玩家可以通过可视化的流程图查看剧情走向，快速跳转到不同的章节、分支和结局。

## ✨ 主要特性

### 1. 自动存档触发点
- **章节开始**: 检测到章节标识（如 `chapter1`, `ch01`, `prologue` 等）时自动创建存档
- **分支选择**: 遇到 `menu` 选项时自动创建存档
- **分支汇合**: 多个分支路径汇聚到同一点时自动标记
- **结局达成**: `return` 语法前的最后一个 `scene` 会被标记为结局

### 2. 流程图可视化
- 树状结构展示剧情流程
- 不同颜色标识不同节点类型
- 已解锁/未解锁状态区分
- 当前位置高亮显示

### 3. 快速跳转
- 点击已解锁节点立即跳转
- 自动加载关联的自动存档
- 平滑的转场效果

## 🚀 快速开始

### 1. 在主菜单添加流程图按钮

```dart
// 在 MainMenuScreen 或自定义主菜单中添加按钮
import 'package:sakiengine/src/utils/story_flowchart_helper.dart';

ElevatedButton(
  onPressed: () {
    StoryFlowchartHelper.showFlowchart(
      context,
      analyzeScriptFirst: true, // 首次打开时分析脚本
      onLoadSave: (saveSlot) {
        // 加载存档并返回游戏
        widget.onLoadGameWithSave?.call(saveSlot);
      },
    );
  },
  child: const Text('剧情流程图'),
)
```

### 2. 在游戏内菜单添加入口

```dart
// 在游戏暂停菜单或设置菜单中
IconButton(
  icon: const Icon(Icons.account_tree),
  onPressed: () async {
    await StoryFlowchartHelper.showFlowchart(
      context,
      onLoadSave: (saveSlot) {
        // 加载到指定节点
        gameManager.restoreFromSnapshot(
          'current_script',
          saveSlot.gameStateSnapshot,
        );
      },
    );
  },
  tooltip: '剧情流程图',
)
```

### 3. 首次使用时分析脚本

```dart
// 在游戏启动时或首次打开流程图前
import 'package:sakiengine/src/game/story_flowchart_analyzer.dart';

final analyzer = StoryFlowchartAnalyzer();
await analyzer.analyzeScript();
```

## 📝 脚本标识规范

为了让系统正确识别章节和分支，需要遵循以下命名规范：

### 章节标识
背景或视频文件名包含以下关键字会被识别为章节：

```
chapter1, chapter_1, chapter-1   -> 第1章
ch1, ch01                        -> 第1章
prologue                         -> 序章
epilogue                         -> 尾声
```

示例脚本：
```sks
scene chapter1_opening
    "第一章开始"

scene ch02_school
    "第二章：学校"
```

### 分支标识
使用 `menu` 命令会自动创建分支节点：

```sks
label choice_point
menu
    "选择A" -> route_a
    "选择B" -> route_b
    "选择C" -> route_c
```

### 结局标识
在 `return` 前的最后一个场景会被标记为结局：

```sks
label ending_true
scene ending_happy
    "真结局达成！"
return

label ending_bad
scene ending_sad
    "Bad End..."
return
```

## 🎨 自定义流程图样式

### 修改节点颜色

在 `StoryFlowchartScreen` 中修改 `_getNodeColor` 方法：

```dart
Color _getNodeColor(StoryFlowNode node) {
  switch (node.type) {
    case StoryNodeType.chapter:
      return Colors.deepPurple;  // 章节颜色
    case StoryNodeType.branch:
      return Colors.teal;         // 分支颜色
    case StoryNodeType.merge:
      return Colors.indigo;       // 汇合颜色
    case StoryNodeType.ending:
      return node.isUnlocked
        ? Colors.amber           // 已达成结局
        : Colors.grey;          // 未达成结局
  }
}
```

### 自定义节点布局

修改 `_buildNodeTree` 方法中的位置计算：

```dart
Widget _buildNodeTree(StoryFlowNode node, int depth, int siblingIndex) {
  // 调整水平/垂直间距
  final double x = 100 + depth * 400.0;      // 水平间距
  final double y = 100 + siblingIndex * 200.0;  // 垂直间距

  // ... 其他代码
}
```

## 🔧 高级功能

### 1. 手动创建流程图节点

```dart
import 'package:sakiengine/src/game/story_flowchart_manager.dart';

final flowchartManager = StoryFlowchartManager();

// 创建自定义节点
final customNode = StoryFlowNode(
  id: 'custom_node_1',
  label: 'special_scene',
  type: StoryNodeType.chapter,
  displayName: '特殊场景',
  scriptIndex: 100,
  chapterName: '第1章',
);

await flowchartManager.addOrUpdateNode(customNode);
```

### 2. 查询流程图数据

```dart
// 获取所有已解锁节点
final unlockedNodes = flowchartManager.getUnlockedNodes();

// 获取所有结局
final endings = flowchartManager.getEndingNodes();

// 获取结局达成率
final unlocked = flowchartManager.getUnlockedEndingsCount();
final total = flowchartManager.getTotalEndingsCount();
final rate = (unlocked / total * 100).toStringAsFixed(1);
print('结局达成率: $rate%');
```

### 3. 导出流程图数据

```dart
// 导出为JSON（用于调试或分享）
final data = flowchartManager.exportData();
print(jsonEncode(data));

// 输出包含：
// - 所有节点信息
// - 节点关系
// - 统计数据
```

### 4. 重置流程图

```dart
// 清空所有流程图数据（用于新游戏）
await flowchartManager.clearAll();

// 重新分析脚本
final analyzer = StoryFlowchartAnalyzer();
await analyzer.resetAndAnalyze();
```

## 💡 最佳实践

### 1. 性能优化
- 首次分析脚本可能耗时较长，建议在游戏启动时后台执行
- 流程图界面使用 `InteractiveViewer` 支持缩放和平移
- 大型项目建议限制同时显示的节点数量

### 2. 用户体验
- 在主菜单明显位置放置流程图入口
- 提供结局达成提示和奖励
- 未解锁节点显示"???"增加神秘感

### 3. 调试技巧
```dart
// 开启调试日志
if (kDebugMode) {
  // 查看流程图统计
  final stats = flowchartManager.exportData()['stats'];
  print('总节点: ${stats['totalNodes']}');
  print('已解锁: ${stats['unlockedNodes']}');
  print('结局数: ${stats['totalEndings']}');
}
```

## 🐛 故障排除

### 问题1: 流程图为空
**原因**: 脚本未分析或章节标识不规范
**解决**:
```dart
// 确保先分析脚本
await StoryFlowchartHelper.resetAndAnalyzeScript();

// 检查脚本中是否有符合规范的章节标识
```

### 问题2: 节点无法点击
**原因**: 节点未解锁或缺少自动存档
**解决**:
```dart
// 检查节点是否已解锁
final node = flowchartManager.nodes['node_id'];
print('已解锁: ${node?.isUnlocked}');
print('存档ID: ${node?.autoSaveId}');
```

### 问题3: 自动存档未创建
**原因**: GameManager 未正确触发自动存档
**解决**: 确保在 `_executeScript` 方法中添加了触发逻辑

## 📚 相关文件

- `lib/src/game/story_flowchart_manager.dart` - 流程图管理器
- `lib/src/game/story_flowchart_analyzer.dart` - 脚本分析器
- `lib/src/screens/story_flowchart_screen.dart` - 流程图UI界面
- `lib/src/utils/story_flowchart_helper.dart` - 辅助工具类
- `lib/src/game/game_manager.dart` - 自动存档触发逻辑

## 🎮 示例项目

SoraNoUta 项目已集成流程图功能，可参考：
- `lib/soranouta/screens/soranouta_main_menu_screen.dart` - 主菜单集成示例
- `assets/GameScript/` - 脚本标识示例

---

**提示**: 如需更复杂的流程图布局（如力导向图、树形图等），可考虑集成第三方图形库如 `graphview` 或 `flutter_graph`。
