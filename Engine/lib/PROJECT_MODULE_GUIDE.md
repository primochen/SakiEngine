# SakiEngine 项目模块系统使用指南

## 🎯 系统概述

SakiEngine 的项目模块系统让每个项目都能拥有自己的自定义代码，同时保持引擎核心的稳定性。这是一个智能的分层架构：

- **引擎核心层** (`src/`) - 稳定的引擎功能，所有项目共享
- **项目定制层** (`项目名/`) - 项目特定的自定义实现
- **智能路由层** - 自动选择使用项目定制还是引擎默认

## 🚀 快速开始

### 1. 创建项目模块

在 `lib/` 目录下创建你的项目文件夹（小写），比如 `lib/myproject/`：

```dart
// lib/myproject/myproject_module.dart
import 'package:flutter/material.dart';
import 'package:sakiengine/src/core/game_module.dart';
import 'package:sakiengine/src/core/module_registry.dart';

class MyProjectModule extends DefaultGameModule {
  
  @override
  ThemeData? createTheme() {
    // 自定义项目主题
    return ThemeData(
      primarySwatch: Colors.green,
      fontFamily: 'SourceHanSansCN-Bold',
    );
  }

  @override
  Future<void> initialize() async {
    print('[MyProjectModule] 项目模块初始化完成');
    // 项目特定的初始化逻辑
  }
}

// 自动注册模块
final _ = (() {
  registerProjectModule('myproject', () => MyProjectModule());
  return null;
})();
```

### 2. 注册模块

在 `lib/src/core/module_registry.dart` 中添加导入：

```dart
// 添加到导入区域
import 'package:sakiengine/myproject/myproject_module.dart';
```

### 3. 运行项目

当你运行名为 "MyProject" 的游戏项目时，系统会自动：
1. 检测项目名称为 "myproject"（转换为小写）
2. 发现你的 `MyProjectModule`
3. 使用你的自定义实现替换默认组件

## 🎨 可定制的组件

### 屏幕组件

```dart
class MyProjectModule extends DefaultGameModule {
  
  @override
  Widget createMainMenuScreen({
    required VoidCallback onNewGame,
    required VoidCallback onLoadGame,
  }) {
    return MyCustomMainMenuScreen(
      onNewGame: onNewGame,
      onLoadGame: onLoadGame,
    );
  }

  @override
  Widget createGamePlayScreen({SaveSlot? saveSlotToLoad}) {
    return MyCustomGamePlayScreen(saveSlotToLoad: saveSlotToLoad);
  }

  @override
  Widget createSaveLoadScreen({
    required SaveLoadMode mode,
    GameManager? gameManager,
    VoidCallback? onClose,
  }) {
    return MyCustomSaveLoadScreen(
      mode: mode,
      gameManager: gameManager,
      onClose: onClose,
    );
  }
}
```

### 主题定制

```dart
@override
ThemeData? createTheme() {
  return ThemeData(
    primarySwatch: Colors.purple,
    fontFamily: 'YourCustomFont',
    colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.purple).copyWith(
      secondary: Colors.amber,
      background: Colors.grey[50],
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.purple,
      elevation: 4,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold),
    ),
  );
}
```

### 自定义应用标题

```dart
@override
Future<String> getAppTitle() async {
  // 方案1: 使用项目名作为标题
  return 'My Awesome Game';
  
  // 方案2: 基于默认标题添加后缀
  try {
    final defaultTitle = await super.getAppTitle();
    return '$defaultTitle - Special Edition';
  } catch (e) {
    return 'My Game';
  }
  
  // 方案3: 动态标题（根据游戏状态变化）
  // final gameState = await loadGameState();
  // return gameState.isNewPlayer ? 'Welcome to MyGame' : 'MyGame - Continue';
}
```

### 配置定制

```dart
@override
SakiEngineConfig? createCustomConfig() {
  final config = SakiEngineConfig();
  // 自定义配置逻辑
  return config;
}

@override
bool get enableDebugFeatures => false; // 禁用调试功能
```

## 📁 项目结构示例

```
lib/
├── src/                    # 引擎核心（不要修改）
│   ├── screens/           # 默认屏幕实现
│   ├── widgets/           # 默认组件实现
│   ├── config/            # 引擎配置
│   └── core/              # 核心系统
├── myproject/              # 你的项目模块
│   ├── myproject_module.dart
│   ├── screens/           # 项目特定屏幕
│   ├── widgets/           # 项目特定组件
│   └── config/            # 项目特定配置
└── anothergame/            # 另一个项目模块
    ├── anothergame_module.dart
    └── ...
```

## 🔄 回退机制

如果你的项目模块没有实现某个方法，系统会自动使用 `src/` 下的默认实现：

```dart
class PartialModule extends DefaultGameModule {
  // 只自定义主题，其他都使用默认实现
  @override
  ThemeData? createTheme() {
    return ThemeData(primarySwatch: Colors.red);
  }
  
  // 不覆盖 createMainMenuScreen，会使用默认的 MainMenuScreen
}
```

## 🛠️ 高级用法

### 创建自定义组件

```dart
// lib/myproject/screens/my_custom_main_menu.dart
import 'package:flutter/material.dart';

class MyCustomMainMenuScreen extends StatefulWidget {
  final VoidCallback onNewGame;
  final VoidCallback onLoadGame;

  const MyCustomMainMenuScreen({
    Key? key,
    required this.onNewGame,
    required this.onLoadGame,
  }) : super(key: key);

  @override
  State<MyCustomMainMenuScreen> createState() => _MyCustomMainMenuScreenState();
}

class _MyCustomMainMenuScreenState extends State<MyCustomMainMenuScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple, Colors.blue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '我的自定义游戏',
                style: TextStyle(
                  fontSize: 48,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: widget.onNewGame,
                child: const Text('开始游戏'),
              ),
              ElevatedButton(
                onPressed: widget.onLoadGame,
                child: const Text('读取存档'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

### 项目特定服务

```dart
class MyProjectModule extends DefaultGameModule {
  late MyProjectService _projectService;

  @override
  Future<void> initialize() async {
    _projectService = MyProjectService();
    await _projectService.initialize();
    print('[MyProjectModule] 项目服务初始化完成');
  }
}

class MyProjectService {
  Future<void> initialize() async {
    // 项目特定的服务初始化
  }
}
```

## 🎯 最佳实践

1. **渐进式定制**：只覆盖需要修改的组件，其他使用默认实现
2. **保持接口兼容**：确保自定义组件接受相同的参数
3. **适当的命名**：使用清晰的命名约定，如 `ProjectNameModule`
4. **文档注释**：为自定义组件添加充分的文档
5. **错误处理**：在 `initialize()` 中处理可能的错误

## 🔧 调试技巧

启用模块调试信息：

```dart
@override
Future<void> initialize() async {
  print('[MyProjectModule] 开始初始化');
  // 你的初始化代码
  print('[MyProjectModule] 初始化完成');
}
```

检查模块加载状态：
- 控制台会显示 `[ProjectModuleLoader]` 的日志信息
- 显示哪些模块被注册和加载
- 显示是否回退到默认模块

这样，每个项目都能拥有完全自定义的体验，同时保持引擎核心的稳定和可复用性！