import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:sakiengine/src/widgets/confirm_dialog.dart';

class ExitConfirmationDialog {
  static const String title = '退出游戏';
  static const String contentWithProgress = '确定要退出游戏吗？未保存的游戏进度将会丢失。';
  static const String contentSimple = '确定要退出游戏吗？';

  static Future<bool> showExitConfirmation(BuildContext context, {bool hasProgress = true}) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return ConfirmDialog(
          title: title,
          content: hasProgress ? contentWithProgress : contentSimple,
          onConfirm: () => Navigator.of(context).pop(true),
        );
      },
    );
    return shouldExit ?? false;
  }

  static Future<void> showExitConfirmationAndDestroy(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return ConfirmDialog(
          title: title,
          content: contentSimple,
          onConfirm: () => Navigator.of(context).pop(true),
        );
      },
    );
    
    if (shouldExit == true) {
      // 优化退出流程：先关闭窗口再退出程序
      try {
        await windowManager.close();
        await Future.delayed(const Duration(milliseconds: 100));
        SystemNavigator.pop();
      } catch (e) {
        // 如果关闭失败，使用原有方法
        await windowManager.destroy();
      }
    }
  }
}