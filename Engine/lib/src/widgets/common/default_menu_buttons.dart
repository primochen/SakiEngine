import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/widgets/common/configurable_menu_button.dart';

class DefaultMenuButtons {
  static List<MenuButtonConfig> createDefaultConfigs({
    required VoidCallback onNewGame,
    required VoidCallback onLoadGame,
    required VoidCallback onSettings,
    required VoidCallback onExit,
    required SakiEngineConfig config,
    required double scale,
  }) {
    return [
      MenuButtonConfig(
        text: '新游戏',
        onPressed: onNewGame,
        backgroundColor: config.themeColors.background.withValues(alpha: 0.9),
        textColor: config.themeColors.primary,
        hoverColor: HSLColor.fromColor(config.themeColors.background)
            .withLightness((HSLColor.fromColor(config.themeColors.background).lightness - 0.1).clamp(0.0, 1.0))
            .toColor().withValues(alpha: 0.9),
        border: Border.all(
          color: config.themeColors.primary.withValues(alpha: 0.5),
          width: 1,
        ),
        textStyle: TextStyle(
          fontFamily: 'SourceHanSansCN',
          fontSize: 28 * scale,
          color: config.themeColors.primary,
          letterSpacing: 2,
        ),
      ),
      MenuButtonConfig(
        text: '继续游戏',
        onPressed: onLoadGame,
        backgroundColor: config.themeColors.background.withValues(alpha: 0.9),
        textColor: config.themeColors.primary,
        hoverColor: HSLColor.fromColor(config.themeColors.background)
            .withLightness((HSLColor.fromColor(config.themeColors.background).lightness - 0.1).clamp(0.0, 1.0))
            .toColor().withValues(alpha: 0.9),
        border: Border.all(
          color: config.themeColors.primary.withValues(alpha: 0.5),
          width: 1,
        ),
        textStyle: TextStyle(
          fontFamily: 'SourceHanSansCN',
          fontSize: 28 * scale,
          color: config.themeColors.primary,
          letterSpacing: 2,
        ),
      ),
      MenuButtonConfig(
        text: '设置',
        onPressed: onSettings,
        backgroundColor: config.themeColors.background.withValues(alpha: 0.9),
        textColor: config.themeColors.primary,
        hoverColor: HSLColor.fromColor(config.themeColors.background)
            .withLightness((HSLColor.fromColor(config.themeColors.background).lightness - 0.1).clamp(0.0, 1.0))
            .toColor().withValues(alpha: 0.9),
        border: Border.all(
          color: config.themeColors.primary.withValues(alpha: 0.5),
          width: 1,
        ),
        textStyle: TextStyle(
          fontFamily: 'SourceHanSansCN',
          fontSize: 28 * scale,
          color: config.themeColors.primary,
          letterSpacing: 2,
        ),
      ),
      MenuButtonConfig(
        text: '退出游戏',
        onPressed: onExit,
        backgroundColor: config.themeColors.background.withValues(alpha: 0.9),
        textColor: config.themeColors.primary,
        hoverColor: HSLColor.fromColor(config.themeColors.background)
            .withLightness((HSLColor.fromColor(config.themeColors.background).lightness - 0.1).clamp(0.0, 1.0))
            .toColor().withValues(alpha: 0.9),
        border: Border.all(
          color: config.themeColors.primary.withValues(alpha: 0.5),
          width: 1,
        ),
        textStyle: TextStyle(
          fontFamily: 'SourceHanSansCN',
          fontSize: 28 * scale,
          color: config.themeColors.primary,
          letterSpacing: 2,
        ),
      ),
    ];
  }
}