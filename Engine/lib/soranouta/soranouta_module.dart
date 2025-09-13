import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:sakiengine/src/core/game_module.dart';
import 'package:sakiengine/src/core/module_registry.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/utils/binary_serializer.dart';
import 'package:sakiengine/src/utils/dialogue_progression_manager.dart';
import 'package:sakiengine/src/utils/music_manager.dart';
import 'package:sakiengine/src/widgets/common/configurable_menu_button.dart';
import 'package:sakiengine/src/screens/main_menu_screen.dart';
import 'package:sakiengine/soranouta/widgets/soranouta_menu_buttons.dart';
import 'package:sakiengine/soranouta/widgets/soranouta_dialogue_box.dart';
import 'package:sakiengine/soranouta/screens/soranouta_main_menu_screen.dart';

/// SoraNoUta 项目的自定义模块
/// 这个示例展示了如何为特定项目创建自定义模块
class SoranoutaModule extends DefaultGameModule {
  
  @override
  Widget createMainMenuScreen({
    required VoidCallback onNewGame,
    required VoidCallback onLoadGame,
    Function(SaveSlot)? onLoadGameWithSave,
    bool skipMusicDelay = false,
  }) {
    // 使用专门的 SoraNoUta 主菜单，继承标题但使用专用按钮
    return SoraNoutaMainMenuScreen(
      onNewGame: onNewGame,
      onLoadGame: onLoadGame,
      onLoadGameWithSave: onLoadGameWithSave,
      skipMusicDelay: skipMusicDelay,
    );
  }

  @override
  SakiEngineConfig? createCustomConfig() {
    // SoraNoUta 项目特定配置
    final config = SakiEngineConfig();
    // 可以在这里添加项目特定的配置
    return config;
  }

  @override
  bool get enableDebugFeatures => true; // SoraNoUta 启用调试功能

  @override
  Future<String> getAppTitle() async {
    return 'SoraNoUta';
  }

  @override
  Future<void> initialize() async {
    await MusicManager().initialize();
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
    return SoranoutaMenuButtons.createConfigs(
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
    return SoranoutaMenuButtons.getLayoutConfig();
  }

  @override
  Widget createDialogueBox({
    String? speaker,
    required String dialogue,
    DialogueProgressionManager? progressionManager,
    required int scriptIndex, // 新增：脚本索引参数
  }) {
    return SoranoUtaDialogueBox(
      speaker: speaker,
      dialogue: dialogue,
      progressionManager: progressionManager,
      scriptIndex: scriptIndex, // 传递脚本索引
    );
  }

  @override
  bool get showBottomBar => false;
}

// 自动注册这个模块
// 当这个文件被导入时，模块会自动注册
void _registerModule() {
  registerProjectModule('soranouta', () => SoranoutaModule());
}

// 使用顶级变量触发注册，避免编译器警告
final bool _isRegistered = (() {
  _registerModule();
  return true;
})();