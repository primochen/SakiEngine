import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/config/config_models.dart';
import 'package:sakiengine/src/core/module_registry.dart';
import 'package:sakiengine/src/core/project_module_loader.dart';
import 'package:sakiengine/src/utils/debug_logger.dart';
import 'package:sakiengine/src/utils/binary_serializer.dart';

enum AppState { mainMenu, inGame }

class GameContainer extends StatefulWidget {
  const GameContainer({super.key});

  @override
  State<GameContainer> createState() => _GameContainerState();
}

class _GameContainerState extends State<GameContainer> {
  AppState _currentState = AppState.mainMenu;
  SaveSlot? _saveSlotToLoad;

  void _enterGame({SaveSlot? saveSlot}) {
    setState(() {
      _currentState = AppState.inGame;
      _saveSlotToLoad = saveSlot;
    });
  }

  void _returnToMainMenu() {
    setState(() {
      _currentState = AppState.mainMenu;
      _saveSlotToLoad = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: moduleLoader.getCurrentModule(),
      builder: (builderContext, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final gameModule = snapshot.data!;

        switch (_currentState) {
          case AppState.mainMenu:
            return gameModule.createMainMenuScreen(
              onNewGame: () => _enterGame(),
              onLoadGame: () {
                // 这个回调现在只是个占位符，实际的load逻辑在MainMenuScreen内部处理
              },
              onLoadGameWithSave: (saveSlot) => _enterGame(saveSlot: saveSlot),
            );
          case AppState.inGame:
            return gameModule.createGamePlayScreen(
              key: ValueKey(_saveSlotToLoad?.id ?? 'new_game'),
              saveSlotToLoad: _saveSlotToLoad,
              onReturnToMenu: _returnToMainMenu,
              onLoadGame: (saveSlot) => _enterGame(saveSlot: saveSlot),
            );
        }
      },
    );
  }
}

void main() async {
  // 设置调试日志收集器
  setupDebugLogger();
  
  // 在Zone中运行应用，捕获所有print输出
  runZoned(() async {
    // 初始化Flutter绑定
    WidgetsFlutterBinding.ensureInitialized();
    
    // 初始化系统热键，清理之前的注册（用于热重载）
    await hotKeyManager.unregisterAll();
    
    // 加载引擎配置
    await SakiEngineConfig().loadConfig();
    
    // 初始化项目模块
    initializeProjectModules();
    
    // 启动应用
    runApp(const SakiEngineApp());
  }, zoneSpecification: ZoneSpecification(
    print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
      // 记录到我们的日志系统
      DebugLogger().addLog(line);
      // 保持正常的控制台输出
      parent.print(zone, line);
    },
  ));
}

class SakiEngineApp extends StatefulWidget {
  const SakiEngineApp({super.key});

  @override
  State<SakiEngineApp> createState() => _SakiEngineAppState();
}

class _SakiEngineAppState extends State<SakiEngineApp> {
  String _appTitle = 'SakiEngine';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: moduleLoader.getCurrentModule(),
      builder: (builderContext, snapshot) {
        if (!snapshot.hasData) {
          // 显示加载画面
          return MaterialApp(
            title: _appTitle,
            debugShowCheckedModeBanner: false,
            home: const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        final gameModule = snapshot.data!;

        return FutureBuilder<String>(
          future: gameModule.getAppTitle(),
          builder: (context, titleSnapshot) {
            final appTitle = titleSnapshot.data ?? 'SakiEngine';
            final customTheme = gameModule.createTheme();

            return MaterialApp(
              title: appTitle,
              debugShowCheckedModeBanner: false,
              theme: customTheme ?? ThemeData(
                primarySwatch: Colors.blue,
                fontFamily: 'SourceHanSansCN-Bold',
              ),
              home: const GameContainer(),
            );
          },
        );
      },
    );
  }
}
