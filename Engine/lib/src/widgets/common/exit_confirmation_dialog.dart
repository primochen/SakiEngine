import 'package:flutter/material.dart';
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
      await windowManager.destroy();
    }
  }
}