import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/widgets/common/configurable_menu_button.dart';
import 'package:sakiengine/soranouta/widgets/soranouta_text_button.dart';
import 'package:sakiengine/src/utils/settings_manager.dart';
import 'package:sakiengine/src/localization/localization_manager.dart';
import 'dart:ui' as ui;

class SoranoutaMenuButtons {
  static const double buttonSpacing = 10;

  /// 判断是否应该显示退出按钮
  /// Web端和移动端不显示退出按钮
  static bool _shouldShowExitButton() {
    if (kIsWeb) return false; // Web端不显示
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) return false; // 移动端不显示
    return true; // 桌面端显示
  }

  static Widget createButtonsWidget({
    required VoidCallback onNewGame,
    required VoidCallback onLoadGame,
    required VoidCallback onSettings,
    required VoidCallback onExit,
    required SakiEngineConfig config,
    required double scale,
    required Size screenSize,
  }) {
    final isDarkMode = SettingsManager().currentDarkMode;
    final lineColor = isDarkMode ? Colors.black : Colors.white;
    final localization = LocalizationManager();

    final List<Widget> buttons = [
      SoranoutaTextButton(
        text: localization.t('menu.newGame'),
        onPressed: onNewGame,
        scale: scale,
      ),
      SoranoutaTextButton(
        text: localization.t('menu.loadGame'),
        onPressed: onLoadGame,
        scale: scale,
      ),
      SoranoutaTextButton(
        text: localization.t('menu.settings'),
        onPressed: onSettings,
        scale: scale,
      ),
    ];

    if (_shouldShowExitButton()) {
      buttons.add(
        SoranoutaTextButton(
          text: localization.t('menu.exit'),
          onPressed: onExit,
          scale: scale,
        ),
      );
    }

    final List<Widget> widgetsWithSeparators = [];
    for (int i = 0; i < buttons.length; i++) {
      widgetsWithSeparators.add(buttons[i]);
      if (i < buttons.length - 1) {
        widgetsWithSeparators.add(
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 200 * scale, // 恢复原始宽度
              height: 2 * scale,
              color: lineColor,
              margin: EdgeInsets.only(right: 0), // 分割线延伸到竖线
            ),
          ),
        );
      }
    }

    return Positioned(
      top: screenSize.height * 0.08,
      right: screenSize.width * 0.04,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: widgetsWithSeparators,
          ),
          Positioned(
            top: 20 * scale,
            right: 0,
            child: Container(
              width: 3 * scale,
              height: (buttons.length * 80 + (buttons.length - 1) * 20) * scale,
              color: lineColor,
            ),
          ),
        ],
      ),
    );
  }

  static Widget createShadowWidget({
    required SakiEngineConfig config,
    required double scale,
    required Size screenSize,
  }) {
    final localization = LocalizationManager();
    final List<String> buttonTexts = [
      localization.t('menu.newGame'),
      localization.t('menu.loadGame'),
      localization.t('menu.settings'),
      if (_shouldShowExitButton()) localization.t('menu.exit'),
    ];
    final isDarkMode = SettingsManager().currentDarkMode;
    final shadowColor = isDarkMode ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.9);
    
    return Positioned(
      top: screenSize.height * 0.08,
      right: screenSize.width * 0.04,
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
        child: Stack(
          children: [
            // 阴影按钮文字和横线
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < buttonTexts.length; i++) ...[
                  Container(
                    margin: EdgeInsets.only(right: 20 * scale),
                    child: Text(
                      buttonTexts[i],
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: 'ChillJinshuSongPro_Soft',
                        fontSize: 55 * scale,
                        color: shadowColor,
                        fontWeight: FontWeight.normal,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                  if (i < buttonTexts.length - 1)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        width: 200 * scale,
                        height: 2 * scale,
                        color: shadowColor,
                        margin: EdgeInsets.only(right: 0),
                      ),
                    ),
                ],
              ],
            ),
            // 阴影竖线
            Positioned(
              top: 20 * scale,
              right: 0,
              child: Container(
                width: 3 * scale,
                height: (buttonTexts.length * 80 + (buttonTexts.length - 1) * 20) * scale,
                color: shadowColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static List<MenuButtonConfig> createConfigs({
    required VoidCallback onNewGame,
    required VoidCallback onLoadGame,
    required VoidCallback onSettings,
    required VoidCallback onExit,
    required SakiEngineConfig config,
    required double scale,
  }) {
    return [];
  }

  static MenuButtonsLayoutConfig getLayoutConfig() {
    return const MenuButtonsLayoutConfig(
      isVertical: true,
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.start,
      spacing: buttonSpacing,
      top: 0.08,
      right: 0.05,
    );
  }
}
