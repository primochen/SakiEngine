import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/config/config_models.dart';
import 'package:sakiengine/src/core/module_registry.dart';
import 'package:sakiengine/src/core/project_module_loader.dart';
import 'package:sakiengine/src/utils/debug_logger.dart';
import 'package:sakiengine/src/utils/binary_serializer.dart';
import 'package:sakiengine/src/utils/settings_manager.dart';
import 'package:sakiengine/src/widgets/common/black_screen_transition.dart';
import 'package:sakiengine/src/widgets/confirm_dialog.dart';

enum AppState { mainMenu, inGame }

class GameContainer extends StatefulWidget {
  const GameContainer({super.key});

  @override
  State<GameContainer> createState() => _GameContainerState();
}

class _GameContainerState extends State<GameContainer> with WindowListener {
  AppState _currentState = AppState.mainMenu;
  SaveSlot? _saveSlotToLoad;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Future<void> onWindowClose() async {
    bool shouldClose = await _showExitConfirmation();
    if (shouldClose) {
      await windowManager.destroy();
    }
  }

  Future<bool> _showExitConfirmation() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return ConfirmDialog(
          title: '退出游戏',
          content: '确定要退出游戏吗？未保存的游戏进度将会丢失。',
          onConfirm: () => Navigator.of(context).pop(true),
        );
      },
    );
    return shouldExit ?? false;
  }

  void _enterGame({SaveSlot? saveSlot}) {
    TransitionOverlayManager.instance.transition(
      context: context,
      onMidTransition: () {
        setState(() {
          _currentState = AppState.inGame;
          _saveSlotToLoad = saveSlot;
        });
      },
    );
  }

  void _returnToMainMenu() {
    TransitionOverlayManager.instance.transition(
      context: context,
      onMidTransition: () {
        setState(() {
          _currentState = AppState.mainMenu;
          _saveSlotToLoad = null;
        });
      },
    );
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

        Widget currentScreen;
        switch (_currentState) {
          case AppState.mainMenu:
            currentScreen = gameModule.createMainMenuScreen(
              onNewGame: () => _enterGame(),
              onLoadGame: () {
                // 这个回调现在只是个占位符，实际的load逻辑在MainMenuScreen内部处理
              },
              onLoadGameWithSave: (saveSlot) => _enterGame(saveSlot: saveSlot),
            );
            break;
          case AppState.inGame:
            currentScreen = gameModule.createGamePlayScreen(
              key: ValueKey(_saveSlotToLoad?.id ?? 'new_game'),
              saveSlotToLoad: _saveSlotToLoad,
              onReturnToMenu: _returnToMainMenu,
              onLoadGame: (saveSlot) => _enterGame(saveSlot: saveSlot),
            );
            break;
        }

        return currentScreen;
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
    
    // 初始化窗口管理器
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    
    // 初始化系统热键，清理之前的注册（用于热重载）
    await hotKeyManager.unregisterAll();
    
    // 加载引擎配置
    await SakiEngineConfig().loadConfig();
    
    // 初始化设置管理器
    await SettingsManager().init();
    
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: moduleLoader.getCurrentModule(),
      builder: (builderContext, snapshot) {
        if (!snapshot.hasData) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
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

            // 设置窗口标题
            if (titleSnapshot.hasData) {
              windowManager.setTitle(appTitle);
            }

            return MaterialApp(
              title: appTitle,
              debugShowCheckedModeBanner: false,
              theme: customTheme ?? ThemeData(
                primarySwatch: Colors.blue,
                fontFamily: 'SourceHanSansCN',
              ),
              home: const GameContainer(),
            );
          },
        );
      },
    );
  }
}
