import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:sakiengine/src/core/game_module.dart';
import 'package:sakiengine/src/core/module_registry.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/utils/binary_serializer.dart';
import 'package:sakiengine/src/widgets/common/configurable_menu_button.dart';
import 'package:sakiengine/src/screens/main_menu_screen.dart';

/// SoraNoUta 项目的自定义模块
/// 这个示例展示了如何为特定项目创建自定义模块
class SoranoutaModule extends DefaultGameModule {
  
  @override
  Widget createMainMenuScreen({
    required VoidCallback onNewGame,
    required VoidCallback onLoadGame,
    Function(SaveSlot)? onLoadGameWithSave,
  }) {
    // 使用默认主菜单，但传递自己作为模块来应用自定义按钮配置
    return MainMenuScreen(
      onNewGame: onNewGame,
      onLoadGame: onLoadGame,
      onLoadGameWithSave: onLoadGameWithSave,
      gameModule: this,
    );
  }

  @override
  ThemeData? createTheme() {
    // SoraNoUta 项目的自定义主题
    return ThemeData(
      primarySwatch: Colors.indigo,
      fontFamily: 'SourceHanSansCN-Bold',
      // 可以在这里定义更多自定义主题属性
      colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.indigo).copyWith(
        secondary: Colors.purpleAccent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.indigo,
        elevation: 0,
      ),
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
    // SoraNoUta 项目的自定义应用标题
    try {
      final defaultTitle = await super.getAppTitle();
      return '$defaultTitle - SoraNoUta';
    } catch (e) {
      return 'SoraNoUta - SakiEngine';
    }
  }

  @override
  Future<void> initialize() async {
    if (kDebugMode) {
      print('[SoraNoutaModule] 🎯 SoraNoUta 项目模块初始化完成 - 使用圆角矩形按钮！');
    }
    // 在这里可以进行项目特定的初始化
    // 比如加载特殊的资源、设置特殊的配置等
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
    // SoraNoUta 项目自定义圆角按钮配置
    return [
      MenuButtonConfig(
        text: '新游戏',
        onPressed: onNewGame,
        backgroundColor: Colors.indigo.withValues(alpha: 0.9),
        textColor: Colors.white,
        hoverColor: Colors.indigo,
        borderRadius: 30, // 圆角矩形
        shadows: [
          BoxShadow(
            color: Colors.indigo.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        padding: EdgeInsets.symmetric(
          horizontal: 32 * scale,
          vertical: 20 * scale,
        ),
        textStyle: TextStyle(
          fontFamily: 'SourceHanSansCN',
          fontSize: 24 * scale,
          color: Colors.white,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
          shadows: [
            Shadow(
              blurRadius: 3,
              color: Colors.black.withValues(alpha: 0.5),
              offset: const Offset(1, 1),
            ),
          ],
        ),
      ),
      MenuButtonConfig(
        text: '读取存档',
        onPressed: onLoadGame,
        backgroundColor: Colors.purple.withValues(alpha: 0.9),
        textColor: Colors.white,
        hoverColor: Colors.purple,
        borderRadius: 30, // 圆角矩形
        shadows: [
          BoxShadow(
            color: Colors.purple.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        padding: EdgeInsets.symmetric(
          horizontal: 32 * scale,
          vertical: 20 * scale,
        ),
        textStyle: TextStyle(
          fontFamily: 'SourceHanSansCN',
          fontSize: 24 * scale,
          color: Colors.white,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
          shadows: [
            Shadow(
              blurRadius: 3,
              color: Colors.black.withValues(alpha: 0.5),
              offset: const Offset(1, 1),
            ),
          ],
        ),
      ),
      MenuButtonConfig(
        text: '设置',
        onPressed: onSettings,
        backgroundColor: Colors.teal.withValues(alpha: 0.9),
        textColor: Colors.white,
        hoverColor: Colors.teal,
        borderRadius: 30, // 圆角矩形
        icon: Icon(
          Icons.settings,
          color: Colors.white,
          size: 20 * scale,
        ),
        shadows: [
          BoxShadow(
            color: Colors.teal.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        padding: EdgeInsets.symmetric(
          horizontal: 32 * scale,
          vertical: 20 * scale,
        ),
        textStyle: TextStyle(
          fontFamily: 'SourceHanSansCN',
          fontSize: 24 * scale,
          color: Colors.white,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
          shadows: [
            Shadow(
              blurRadius: 3,
              color: Colors.black.withValues(alpha: 0.5),
              offset: const Offset(1, 1),
            ),
          ],
        ),
      ),
      MenuButtonConfig(
        text: '退出',
        onPressed: onExit,
        backgroundColor: Colors.red.withValues(alpha: 0.9),
        textColor: Colors.white,
        hoverColor: Colors.red,
        borderRadius: 30, // 圆角矩形
        icon: Icon(
          Icons.exit_to_app,
          color: Colors.white,
          size: 20 * scale,
        ),
        shadows: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        padding: EdgeInsets.symmetric(
          horizontal: 32 * scale,
          vertical: 20 * scale,
        ),
        textStyle: TextStyle(
          fontFamily: 'SourceHanSansCN',
          fontSize: 24 * scale,
          color: Colors.white,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
          shadows: [
            Shadow(
              blurRadius: 3,
              color: Colors.black.withValues(alpha: 0.5),
              offset: const Offset(1, 1),
            ),
          ],
        ),
      ),
    ];
  }
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