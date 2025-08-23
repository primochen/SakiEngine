import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/core/module_registry.dart';
import 'package:sakiengine/src/core/project_module_loader.dart';
import 'package:sakiengine/src/utils/debug_logger.dart';

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
              home: Builder(
                builder: (innerContext) {
                  return gameModule.createMainMenuScreen(
                    onNewGame: () {
                      Navigator.of(innerContext).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => gameModule.createGamePlayScreen(),
                        ),
                        (Route<dynamic> route) => false,
                      );
                    },
                    onLoadGame: () {
                      // 加载游戏的逻辑由MainMenuScreen内部处理
                    },
                  );
                }
              ),
            );
          },
        );
      },
    );
  }
}
