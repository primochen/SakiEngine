import 'dart:html' as html;

/// Web平台的窗口管理器实现
class PlatformWindowManager {
  static Future<void> ensureInitialized() async {
    // Web平台不需要初始化窗口管理器
  }

  static Future<void> setPreventClose(bool prevent) async {
    // Web平台无法阻止窗口关闭
  }

  static Future<void> maximize() async {
    // Web平台无法最大化窗口
  }

  static void addListener(WindowListener listener) {
    // Web平台添加beforeunload事件监听
    html.window.onBeforeUnload.listen((event) {
      listener.onWindowClose();
    });
  }

  static void removeListener(WindowListener listener) {
    // Web平台无法精确移除特定监听器，但这不会造成问题
  }

  static Future<void> destroy() async {
    // Web平台关闭窗口
    html.window.close();
  }

  static Future<void> setTitle(String title) async {
    // Web平台设置页面标题
    html.document.title = title;
  }

  static Future<void> setFullScreen(bool fullScreen) async {
    // Web平台处理全屏模式
    if (fullScreen) {
      try {
        final element = html.document.documentElement;
        if (element != null) {
          await element.requestFullscreen();
        }
      } catch (e) {
        // 全屏请求可能失败，忽略错误
        print('Web fullscreen request failed: $e');
      }
    } else {
      try {
        if (html.document.fullscreenElement != null) {
          html.document.exitFullscreen();
        }
      } catch (e) {
        // 退出全屏可能失败，忽略错误
        print('Web exit fullscreen failed: $e');
      }
    }
  }
}

/// Web平台的WindowListener实现 - 使用mixin
mixin WindowListener {
  Future<void> onWindowClose();
}