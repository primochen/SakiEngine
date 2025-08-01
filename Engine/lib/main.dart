import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hotkey_system/hotkey_system.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/screens/main_menu_screen.dart';
import 'package:sakiengine/src/screens/game_play_screen.dart';
import 'package:sakiengine/src/utils/debug_logger.dart';

void main() async {
  // 设置调试日志收集器
  setupDebugLogger();
  
  // 在Zone中运行应用，捕获所有print输出
  runZoned(() async {
    // 将 ensureInitialized 移动到 runZoned 内部
    WidgetsFlutterBinding.ensureInitialized();
    
    // 初始化系统热键，清理之前的注册（用于热重载）
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS)) {
      await hotKeySystem.unregisterAll();
    }
    
    await SakiEngineConfig().loadConfig();
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

class SakiEngineApp extends StatelessWidget {
  const SakiEngineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SakiEngine',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'SourceHanSansCN-Bold',
      ),
      home: Builder(
        builder: (context) {
          return MainMenuScreen(
            onNewGame: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const GamePlayScreen(),
                ),
                (Route<dynamic> route) => false,
              );
            },
            onLoadGame: () {
               // This callback might seem redundant now with MainMenuScreen's internal state,
               // but we'll leave it for potential future use where the app might want to
               // trigger the load screen from an external event.
               // A better approach is what's implemented in MainMenuScreen itself.
            },
          );
        }
      ),
    );
  }
}
