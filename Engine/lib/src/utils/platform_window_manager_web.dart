import 'dart:html' as html;
import 'dart:async';

/// Web平台的窗口管理器实现
class PlatformWindowManager {
  static final Map<WindowListener, StreamSubscription> _listeners = {};
  
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
    // 如果已经添加过这个监听器，先移除旧的
    removeListener(listener);
    
    // Web平台添加beforeunload事件监听，使用更安全的方式
    try {
      final subscription = html.window.onBeforeUnload.listen((event) {
        try {
          // 异步执行避免阻塞
          Future.microtask(() => listener.onWindowClose());
        } catch (e) {
          // 忽略监听器中的错误，避免影响其他监听器
          print('Window listener error: $e');
        }
      });
      
      _listeners[listener] = subscription;
    } catch (e) {
      print('Failed to add window listener: $e');
    }
  }

  static void removeListener(WindowListener listener) {
    // 正确移除特定监听器的订阅
    final subscription = _listeners.remove(listener);
    subscription?.cancel();
  }

  static Future<void> destroy() async {
    // 清理所有监听器
    for (final subscription in _listeners.values) {
      subscription.cancel();
    }
    _listeners.clear();
    
    // Web平台关闭窗口
    try {
      html.window.close();
    } catch (e) {
      // 关闭窗口可能失败，忽略错误
      print('Web window close failed: $e');
    }
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