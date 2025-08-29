import 'package:flutter/material.dart';
import 'package:sakiengine/src/screens/main_menu_screen.dart';
import 'package:sakiengine/src/screens/game_play_screen.dart';
import 'package:sakiengine/src/screens/save_load_screen.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/config/project_info_manager.dart';
import 'package:sakiengine/src/game/game_manager.dart';
import 'package:sakiengine/src/utils/binary_serializer.dart';
import 'package:sakiengine/src/widgets/common/configurable_menu_button.dart';
import 'package:sakiengine/src/widgets/common/default_menu_buttons.dart';

/// 游戏模块接口 - 定义项目可以覆盖的所有组件
abstract class GameModule {
  
  /// 主菜单屏幕工厂
  Widget createMainMenuScreen({
    required VoidCallback onNewGame,
    required VoidCallback onLoadGame,
    Function(SaveSlot)? onLoadGameWithSave,
  });

  /// 游戏界面屏幕工厂
  Widget createGamePlayScreen({
    Key? key,
    SaveSlot? saveSlotToLoad,
    VoidCallback? onReturnToMenu,
    Function(SaveSlot)? onLoadGame,
  });

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

  /// 创建主菜单按钮配置列表
  List<MenuButtonConfig> createMainMenuButtonConfigs({
    required VoidCallback onNewGame,
    required VoidCallback onLoadGame,
    required VoidCallback onSettings,
    required VoidCallback onExit,
    required SakiEngineConfig config,
    required double scale,
  });

  /// 获取主菜单按钮布局配置
  MenuButtonsLayoutConfig getMenuButtonsLayoutConfig() {
    return const MenuButtonsLayoutConfig(
      isVertical: false,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.end,
      spacing: 20,
      bottom: 0.05,
      right: 0.01,
    );
  }

  /// 是否显示底部横条
  bool get showBottomBar => true;
}

/// 默认游戏模块实现 - 使用src/下的默认组件
class DefaultGameModule implements GameModule {
  @override
  Widget createMainMenuScreen({
    required VoidCallback onNewGame,
    required VoidCallback onLoadGame,
    Function(SaveSlot)? onLoadGameWithSave,
  }) {
    return MainMenuScreen(
      onNewGame: onNewGame,
      onLoadGame: onLoadGame,
      onLoadGameWithSave: onLoadGameWithSave,
      gameModule: this,
    );
  }

  @override
  Widget createGamePlayScreen({
    Key? key,
    SaveSlot? saveSlotToLoad,
    VoidCallback? onReturnToMenu,
    Function(SaveSlot)? onLoadGame,
  }) {
    return GamePlayScreen(
      key: key,
      saveSlotToLoad: saveSlotToLoad,
      onReturnToMenu: onReturnToMenu,
      onLoadGame: onLoadGame,
    );
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

  @override
  List<MenuButtonConfig> createMainMenuButtonConfigs({
    required VoidCallback onNewGame,
    required VoidCallback onLoadGame,
    required VoidCallback onSettings,
    required VoidCallback onExit,
    required SakiEngineConfig config,
    required double scale,
  }) {
    return DefaultMenuButtons.createDefaultConfigs(
      onNewGame: onNewGame,
      onLoadGame: onLoadGame,
      onSettings: onSettings,
      onExit: onExit,
      config: config,
      scale: scale,
    );
  }

  @override
  MenuButtonsLayoutConfig getMenuButtonsLayoutConfig() {
    return const MenuButtonsLayoutConfig(
      isVertical: false,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.end,
      spacing: 20,
      bottom: 0.05,
      right: 0.01,
    );
  }

  @override
  bool get showBottomBar => true;
}