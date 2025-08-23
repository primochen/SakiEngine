import 'package:flutter/material.dart';
import 'package:sakiengine/src/screens/main_menu_screen.dart';
import 'package:sakiengine/src/screens/game_play_screen.dart';
import 'package:sakiengine/src/screens/save_load_screen.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/config/project_info_manager.dart';
import 'package:sakiengine/src/game/game_manager.dart';
import 'package:sakiengine/src/utils/binary_serializer.dart';

/// 游戏模块接口 - 定义项目可以覆盖的所有组件
abstract class GameModule {
  
  /// 主菜单屏幕工厂
  Widget createMainMenuScreen({
    required VoidCallback onNewGame,
    required VoidCallback onLoadGame,
  });

  /// 游戏界面屏幕工厂
  Widget createGamePlayScreen({SaveSlot? saveSlotToLoad});

  /// 存档界面屏幕工厂
  Widget createSaveLoadScreen({
    required SaveLoadMode mode,
    GameManager? gameManager,
    VoidCallback? onClose,
  });

  /// 自定义配置（可选）
  SakiEngineConfig? createCustomConfig() => null;

  /// 是否启用调试功能
  bool get enableDebugFeatures => true;

  /// 项目特定的主题配置
  ThemeData? createTheme() => null;

  /// 获取应用标题
  Future<String> getAppTitle() async {
    try {
      return await ProjectInfoManager().getAppName();
    } catch (e) {
      return 'SakiEngine'; // 默认标题
    }
  }

  /// 模块初始化（可选）
  Future<void> initialize() async {}
}

/// 默认游戏模块实现 - 使用src/下的默认组件
class DefaultGameModule implements GameModule {
  @override
  Widget createMainMenuScreen({
    required VoidCallback onNewGame,
    required VoidCallback onLoadGame,
  }) {
    return MainMenuScreen(
      onNewGame: onNewGame,
      onLoadGame: onLoadGame,
    );
  }

  @override
  Widget createGamePlayScreen({SaveSlot? saveSlotToLoad}) {
    return GamePlayScreen(saveSlotToLoad: saveSlotToLoad);
  }

  @override
  Widget createSaveLoadScreen({
    required SaveLoadMode mode,
    GameManager? gameManager,
    VoidCallback? onClose,
  }) {
    return SaveLoadScreen(
      mode: mode,
      gameManager: gameManager,
      onClose: onClose ?? () {},
    );
  }

  @override
  SakiEngineConfig? createCustomConfig() => null;

  @override
  bool get enableDebugFeatures => true;

  @override
  ThemeData? createTheme() => null;

  @override
  Future<String> getAppTitle() async {
    try {
      return await ProjectInfoManager().getAppName();
    } catch (e) {
      return 'SakiEngine'; // 默认标题
    }
  }

  @override
  Future<void> initialize() async {
    // 默认模块无需特殊初始化
  }
}