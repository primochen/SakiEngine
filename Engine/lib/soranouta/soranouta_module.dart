import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:sakiengine/src/core/game_module.dart';
import 'package:sakiengine/src/core/module_registry.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/soranouta/screens/soranouta_main_menu_screen.dart';

/// SoraNoUta 项目的自定义模块
/// 这个示例展示了如何为特定项目创建自定义模块
class SoranoutaModule extends DefaultGameModule {
  
  @override
  Widget createMainMenuScreen({
    required VoidCallback onNewGame,
    required VoidCallback onLoadGame,
  }) {
    // 🎯 使用 SoraNoUta 特色的圆角矩形按钮主菜单！
    return SoraNoutaMainMenuScreen(
      onNewGame: onNewGame,
      onLoadGame: onLoadGame,
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
    // 可以返回项目特定的配置
    // final config = SakiEngineConfig();
    // config.themeColors = CustomThemeColors(...);
    // return config;
    return null; // 使用默认配置
  }

  @override
  bool get enableDebugFeatures => true; // SoraNoUta 启用调试功能

  @override
  Future<void> initialize() async {
    if (kDebugMode) {
      print('[SoraNoutaModule] 🎯 SoraNoUta 项目模块初始化完成 - 使用圆角矩形按钮！');
    }
    // 在这里可以进行项目特定的初始化
    // 比如加载特殊的资源、设置特殊的配置等
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