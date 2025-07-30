import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/screens/main_menu_screen.dart';
import 'package:sakiengine/src/screens/game_play_screen.dart';
import 'package:sakiengine/src/utils/debug_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 设置调试日志收集器
  setupDebugLogger();
  
  // 在Zone中运行应用，捕获所有print输出
  runZoned(() async {
    await SakiEngineConfig().loadConfig();
    runApp(SakiEngineApp());
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
    return MaterialApp(
      title: 'SakiEngine',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'SourceHanSansCN-Bold',
      ),
      home: MainMenuScreen(
        onNewGame: () {
          // 从主菜单启动新游戏，并销毁主菜单
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => GamePlayScreen(),
            ),
            (Route<dynamic> route) => false, // 移除所有之前的路由
          );
        },
        onLoadGame: () {
          // TODO: 实现读取进度功能
        },
      ),
    );
  }
} 