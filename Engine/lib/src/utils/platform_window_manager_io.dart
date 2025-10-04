import 'dart:io' show Platform;
import 'package:window_manager/window_manager.dart';

// 导出WindowListener作为mixin以便使用
export 'package:window_manager/window_manager.dart' show WindowListener;

/// 非Web平台的窗口管理器实现
class PlatformWindowManager {
  // 检查是否为桌面平台（Windows、macOS、Linux）
  static bool get _isDesktop {
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  static Future<void> ensureInitialized() async {
    // 只在桌面平台初始化 window_manager
    if (_isDesktop) {
      await windowManager.ensureInitialized();
    }
  }

  static Future<void> setPreventClose(bool prevent) async {
    // 只在桌面平台执行
    if (_isDesktop) {
      await windowManager.setPreventClose(prevent);
    }
  }

  static Future<void> maximize() async {
    // 只在桌面平台执行
    if (_isDesktop) {
      await windowManager.maximize();
    }
  }

  static void addListener(WindowListener listener) {
    // 只在桌面平台执行
    if (_isDesktop) {
      windowManager.addListener(listener);
    }
  }

  static void removeListener(WindowListener listener) {
    // 只在桌面平台执行
    if (_isDesktop) {
      windowManager.removeListener(listener);
    }
  }

  static Future<void> destroy() async {
    // 只在桌面平台执行
    if (_isDesktop) {
      await windowManager.destroy();
    }
  }

  static Future<void> setTitle(String title) async {
    // 只在桌面平台执行
    if (_isDesktop) {
      await windowManager.setTitle(title);
    }
  }

  static Future<void> setFullScreen(bool fullScreen) async {
    // 只在桌面平台执行
    if (_isDesktop) {
      await windowManager.setFullScreen(fullScreen);
    }
  }
}