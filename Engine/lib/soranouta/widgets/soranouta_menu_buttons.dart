import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/widgets/common/configurable_menu_button.dart';
import 'package:sakiengine/soranouta/widgets/soranouta_text_button.dart';

class SoranoutaMenuButtons {
  static const double buttonSpacing = 10;
  static Widget createButtonsWidget({
    required VoidCallback onNewGame,
    required VoidCallback onLoadGame,
    required VoidCallback onSettings,
    required VoidCallback onExit,
    required SakiEngineConfig config,
    required double scale,
    required Size screenSize,
  }) {
    final List<Widget> buttons = [
      SoranoutaTextButton(
        text: '新游戏',
        onPressed: onNewGame,
        scale: scale,
      ),
      SoranoutaTextButton(
        text: '读取存档',
        onPressed: onLoadGame,
        scale: scale,
      ),
      SoranoutaTextButton(
        text: '设置',
        onPressed: onSettings,
        scale: scale,
      ),
      SoranoutaTextButton(
        text: '退出',
        onPressed: onExit,
        scale: scale,
      ),
    ];

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
              color: Colors.black,
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
            top: 20 * scale, // 调整顶部位置与按钮文字对齐
            right: 0,
            child: Container(
              width: 3 * scale,
              height: (buttons.length * 80 + (buttons.length - 1) * 20) * scale, // 大幅增加高度
              color: Colors.black,
            ),
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