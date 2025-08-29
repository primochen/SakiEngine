import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/widgets/common/configurable_menu_button.dart';
import 'package:sakiengine/soranouta/widgets/soranouta_text_button.dart';

class SoranoutaMenuButtons {
  static const double buttonSpacing = 0;
  static Widget createButtonsWidget({
    required VoidCallback onNewGame,
    required VoidCallback onLoadGame,
    required VoidCallback onSettings,
    required VoidCallback onExit,
    required SakiEngineConfig config,
    required double scale,
    required Size screenSize,
  }) {
    return Positioned(
      top: screenSize.height * 0.08,
      right: screenSize.width * 0.05,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SoranoutaTextButton(
            text: '新游戏',
            onPressed: onNewGame,
            scale: scale,
          ),
          SizedBox(height: buttonSpacing * scale),
          SoranoutaTextButton(
            text: '读取存档',
            onPressed: onLoadGame,
            scale: scale,
          ),
          SizedBox(height: buttonSpacing * scale),
          SoranoutaTextButton(
            text: '设置',
            onPressed: onSettings,
            scale: scale,
          ),
          SizedBox(height: buttonSpacing * scale),
          SoranoutaTextButton(
            text: '退出',
            onPressed: onExit,
            scale: scale,
          ),
        ],
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