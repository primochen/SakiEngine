# 🚀 剧情流程图系统 - 5分钟快速启动

## 第一步：在主菜单添加按钮 (2分钟)

打开 `lib/soranouta/screens/soranouta_main_menu_screen.dart`，添加导入：

```dart
import 'package:sakiengine/src/utils/story_flowchart_helper.dart';
```

在合适的位置添加按钮（例如在设置按钮旁边）：

```dart
// 添加流程图按钮
IconButton(
  icon: const Icon(Icons.account_tree, size: 32, color: Colors.white),
  tooltip: '剧情流程图',
  onPressed: () {
    StoryFlowchartHelper.showFlowchart(
      context,
      analyzeScriptFirst: true,  // 首次打开时自动分析脚本
      onLoadSave: (saveSlot) {
        widget.onLoadGameWithSave?.call(saveSlot);
      },
    );
  },
)
```

## 第二步：初始化流程图 (1分钟)

在 `lib/soranouta/screens/soranouta_startup_flow.dart` 的 `initState` 方法中添加：

```dart
import 'package:sakiengine/src/game/story_flowchart_analyzer.dart';

@override
void initState() {
  super.initState();

  // 后台初始化流程图
  Future.microtask(() async {
    try {
      final analyzer = StoryFlowchartAnalyzer();
      await analyzer.analyzeScript();
      print('[SoraNoUta] 剧情流程图初始化完成');
    } catch (e) {
      print('[SoraNoUta] 流程图初始化失败: $e');
    }
  });
}
```

## 第三步：运行游戏 (2分钟)

```bash
flutter run
```

完成！现在你可以：
1. 点击主菜单的流程图按钮
2. 查看自动生成的剧情流程图
3. 点击已解锁的节点快速跳转

---

## 📝 脚本要求

确保你的脚本包含章节标识：

```sks
# ✅ 正确的章节标识
scene chapter1_opening
scene ch01_school
scene prologue_start

# ✅ 分支示例
label important_choice
menu
    "选项A" -> route_a
    "选项B" -> route_b

# ✅ 结局示例
label ending_happy
scene ending_celebration
    "Happy Ending!"
return
```

## 🎯 效果预览

**主菜单**: 右上角会出现 🌲 图标按钮

**流程图界面**:
- 顶部：结局达成统计
- 中间：可缩放的流程图
- 右侧：当前位置信息
- 点击节点：快速跳转

**节点颜色**:
- 🔵 蓝色 = 章节
- 🟠 橙色 = 分支选择
- 🟣 紫色 = 汇合点
- 🟢 绿色 = 已达成结局
- ⚫ 灰色 = 未达成结局

---

## 🐛 常见问题

**Q: 流程图是空的？**
A: 确保脚本中有 `chapter`, `ch\d+`, `prologue` 等关键字

**Q: 节点无法点击？**
A: 需要先玩到该节点才会解锁

**Q: 自动存档在哪？**
A: 存档ID格式为 `auto_chapter_xxx` 或 `auto_branch_xxx`

---

**就这么简单！享受你的剧情流程图系统吧！** 🎉
