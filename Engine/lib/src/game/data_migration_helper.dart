import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakiengine/src/game/unified_game_data_manager.dart';

/// 数据迁移助手
/// 将旧的 SharedPreferences 数据迁移到新的统一数据管理器
class DataMigrationHelper {
  static const String _migrationCompleteKey = 'data_migration_v1_complete';

  /// 检查并执行迁移
  static Future<void> migrateIfNeeded(String projectName) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 检查是否已经迁移过
      final migrationComplete = prefs.getBool(_migrationCompleteKey) ?? false;
      if (migrationComplete) {
        if (kDebugMode) {
          print('[DataMigration] 数据已迁移，跳过');
        }
        return;
      }

      if (kDebugMode) {
        print('[DataMigration] 开始迁移数据...');
      }

      final dataManager = UnifiedGameDataManager();
      await dataManager.init(projectName);

      // ============ 迁移设置数据 ============
      final dialogOpacity = prefs.getDouble('dialog_opacity');
      if (dialogOpacity != null) {
        await dataManager.setDialogOpacity(dialogOpacity, projectName);
      }

      final isFullscreen = prefs.getBool('is_fullscreen');
      if (isFullscreen != null) {
        await dataManager.setIsFullscreen(isFullscreen, projectName);
      }

      final darkMode = prefs.getBool('dark_mode');
      if (darkMode != null) {
        await dataManager.setDarkMode(darkMode, projectName);
      }

      final typewriterSpeed = prefs.getDouble('typewriter_chars_per_second');
      if (typewriterSpeed != null) {
        await dataManager.setTypewriterCharsPerSecond(typewriterSpeed, projectName);
      }

      final skipPunctuationDelay = prefs.getBool('skip_punctuation_delay');
      if (skipPunctuationDelay != null) {
        await dataManager.setSkipPunctuationDelay(skipPunctuationDelay, projectName);
      }

      final speakerAnimation = prefs.getBool('speaker_animation');
      if (speakerAnimation != null) {
        await dataManager.setSpeakerAnimation(speakerAnimation, projectName);
      }

      final autoHideQuickMenu = prefs.getBool('auto_hide_quick_menu');
      if (autoHideQuickMenu != null) {
        await dataManager.setAutoHideQuickMenu(autoHideQuickMenu, projectName);
      }

      final menuDisplayMode = prefs.getString('menu_display_mode');
      if (menuDisplayMode != null) {
        await dataManager.setMenuDisplayMode(menuDisplayMode, projectName);
      }

      final fastForwardMode = prefs.getString('fast_forward_mode');
      if (fastForwardMode != null) {
        await dataManager.setFastForwardMode(fastForwardMode, projectName);
      }

      // ============ 迁移音频设置 ============
      final musicEnabled = prefs.getBool('music_enabled');
      if (musicEnabled != null) {
        await dataManager.setMusicEnabled(musicEnabled, projectName);
      }

      final soundEnabled = prefs.getBool('sound_enabled');
      if (soundEnabled != null) {
        await dataManager.setSoundEnabled(soundEnabled, projectName);
      }

      final musicVolume = prefs.getDouble('music_volume');
      if (musicVolume != null) {
        await dataManager.setMusicVolume(musicVolume, projectName);
      }

      final soundVolume = prefs.getDouble('sound_volume');
      if (soundVolume != null) {
        await dataManager.setSoundVolume(soundVolume, projectName);
      }

      // ============ 迁移持久化变量 ============
      final allKeys = prefs.getKeys();
      for (final key in allKeys) {
        if (key.startsWith('game_bool_var_')) {
          final variableName = key.substring('game_bool_var_'.length);
          final value = prefs.getBool(key) ?? false;
          await dataManager.setBoolVariable(variableName, value, projectName);

          if (kDebugMode) {
            print('[DataMigration] 迁移布尔变量: $variableName = $value');
          }
        }
      }

      // 标记迁移完成
      await prefs.setBool(_migrationCompleteKey, true);

      if (kDebugMode) {
        print('[DataMigration] 数据迁移完成！');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[DataMigration] 迁移失败: $e');
      }
    }
  }

  /// 重置迁移标记（用于测试）
  static Future<void> resetMigrationFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_migrationCompleteKey);
    if (kDebugMode) {
      print('[DataMigration] 迁移标记已重置');
    }
  }
}