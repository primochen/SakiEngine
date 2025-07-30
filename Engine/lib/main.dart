import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/screens/main_menu_screen.dart';
import 'package:sakiengine/src/screens/game_play_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SakiEngineConfig().loadConfig();
  runApp(SakiEngineApp());
}

class SakiEngineApp extends StatefulWidget {
  const SakiEngineApp({super.key});

  @override
  State<SakiEngineApp> createState() => _SakiEngineAppState();
}

class _SakiEngineAppState extends State<SakiEngineApp> {
  void _startNewGame() {
    // 启动新游戏的初始化逻辑
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GamePlayScreen(),
      ),
    );
  }

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