# 剧情流程图系统 - 错误修复指南

## 需要修复的错误

### 1. 导入缺失的类

在以下文件中添加缺失的导入：

**lib/src/game/story_flowchart_manager.dart:**
```dart
// 在文件顶部添加
import 'package:sakiengine/src/utils/binary_serializer.dart';
```

**lib/src/screens/story_flowchart_screen.dart:**
```dart
// 在文件顶部添加
import 'package:sakiengine/src/utils/binary_serializer.dart';
```

**lib/src/utils/story_flowchart_helper.dart:**
```dart
// 在文件顶部添加
import 'package:sakiengine/src/utils/binary_serializer.dart';
```

### 2. MenuNode API修复

**lib/src/game/story_flowchart_analyzer.dart 第90行:**

需要查看MenuNode的实际API。查找MenuNode定义后修复：

```dart
// 原代码（可能错误）:
for (final option in node.options) {

// 修改为（需要根据实际MenuNode API调整）:
for (final option in node.choices) {
// 或者
for (int i = 0; i < node.choices.length; i++) {
  final option = node.choices[i];
```

### 3. UnifiedGameDataManager API修复

UnifiedGameDataManager的API可能不同。需要检查实际API并修复：

**lib/src/game/story_flowchart_manager.dart:**

方法1 - 使用正确的API（如果存在）:
```dart
// 查找UnifiedGameDataManager的实际方法名
// 可能是 get, set, delete 而不是 getValue, setValue, deleteValue
```

方法2 - 使用SharedPreferences替代:
```dart
import 'package:shared_preferences/shared_preferences.dart';

Future<void> initialize() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString('story_flowchart');
    // ... 其余代码
  }
}

Future<void> save() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('story_flowchart', jsonEncode(jsonData));
  }
}

Future<void> clearAll() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('story_flowchart');
}
```

### 4. SaveLoadManager API修复

**lib/src/game/story_flowchart_manager.dart 第267行:**
**lib/src/screens/story_flowchart_screen.dart 第405行:**

需要检查SaveLoadManager的实际API：

```dart
// 查找正确的方法名
// 可能是 save, load 而不是 saveToSlot, loadFromSlot

// 或者直接使用GameManager的存档功能
final gameManager = GameManager();
gameManager.saveStateSnapshot();
```

## 快速修复步骤

### 步骤1: 添加导入
在这三个文件顶部添加：
```dart
import 'package:sakiengine/src/utils/binary_serializer.dart';
```

- lib/src/game/story_flowchart_manager.dart
- lib/src/screens/story_flowchart_screen.dart
- lib/src/utils/story_flowchart_helper.dart

### 步骤2: 检查MenuNode API
```bash
# 运行命令查看MenuNode的实际属性
grep -A 20 "class MenuNode" lib/src/sks_parser/sks_ast.dart
```

### 步骤3: 检查UnifiedGameDataManager API
```bash
# 查看可用方法
grep "Future.*(" lib/src/game/unified_game_data_manager*.dart
```

### 步骤4: 检查SaveLoadManager API
```bash
# 查看存档相关方法
grep "save\|load" lib/src/game/save_load_manager.dart | grep "Future"
```

## 临时禁用方案

如果需要快速让代码编译通过，可以临时注释掉problematic代码：

**story_flowchart_analyzer.dart:**
```dart
// 临时注释掉分支选项处理
// for (final option in node.options) {
//   ...
// }
```

**story_flowchart_manager.dart:**
```dart
// 临时使用内存存储
final Map<String, String> _memoryStorage = {};

Future<void> initialize() async {
  final savedData = _memoryStorage['story_flowchart'];
  // ...
}

Future<void> save() async {
  _memoryStorage['story_flowchart'] = jsonEncode(jsonData);
}
```

## 完整修复后的验证

运行以下命令验证修复：
```bash
flutter analyze lib/src/game/story_flowchart*.dart
flutter analyze lib/src/screens/story_flowchart_screen.dart
flutter run
```

---

**注意**: 这些错误大多是API不匹配导致的。需要根据实际的代码库API进行调整。建议先查看相关类的定义，然后进行精确修复。
