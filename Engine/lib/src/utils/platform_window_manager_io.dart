import 'package:window_manager/window_manager.dart';

// 导出WindowListener作为mixin以便使用
export 'package:window_manager/window_manager.dart' show WindowListener;

/// 非Web平台的窗口管理器实现
class PlatformWindowManager {
  static Future<void> ensureInitialized() async {
    await windowManager.ensureInitialized();
  }

  static Future<void> setPreventClose(bool prevent) async {
    await windowManager.setPreventClose(prevent);
  }

  static Future<void> maximize() async {
    await windowManager.maximize();
  }

  static void addListener(WindowListener listener) {
    windowManager.addListener(listener);
  }

  static void removeListener(WindowListener listener) {
    windowManager.removeListener(listener);
  }

  static Future<void> destroy() async {
    await windowManager.destroy();
  }

  static Future<void> setTitle(String title) async {
    await windowManager.setTitle(title);
  }

  static Future<void> setFullScreen(bool fullScreen) async {
    await windowManager.setFullScreen(fullScreen);
  }
}