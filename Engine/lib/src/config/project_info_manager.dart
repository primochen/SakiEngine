import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

class ProjectInfoManager {
  static final ProjectInfoManager _instance = ProjectInfoManager._internal();
  factory ProjectInfoManager() => _instance;
  ProjectInfoManager._internal();

  String? _cachedProjectName;
  String? _cachedAppName;

  /// 获取当前项目名称（文件夹名）
  Future<String> getProjectName() async {
    if (_cachedProjectName != null) {
      return _cachedProjectName!;
    }

    try {
      // 优先从环境变量获取游戏路径
      const fromDefine = String.fromEnvironment('SAKI_GAME_PATH', defaultValue: '');
      if (fromDefine.isNotEmpty) {
        _cachedProjectName = p.basename(fromDefine);
        return _cachedProjectName!;
      }
      
      final fromEnv = Platform.environment['SAKI_GAME_PATH'];
      if (fromEnv != null && fromEnv.isNotEmpty) {
        _cachedProjectName = p.basename(fromEnv);
        return _cachedProjectName!;
      }
      
      // 从assets读取default_game.txt
      final assetContent = await rootBundle.loadString('assets/default_game.txt');
      final projectName = assetContent.trim();
      
      if (projectName.isEmpty) {
        throw Exception('Project name is empty in default_game.txt');
      }
      
      _cachedProjectName = projectName;
      return _cachedProjectName!;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting project name: $e');
      }
      // 如果无法获取项目名称，使用默认值
      _cachedProjectName = 'SakiEngine';
      return _cachedProjectName!;
    }
  }

  /// 获取应用显示名称（从game_config.txt读取）
  Future<String> getAppName() async {
    if (_cachedAppName != null) {
      return _cachedAppName!;
    }

    try {
      // 优先尝试从game_config.txt获取应用名称
      String gamePath = '';
      
      // 获取游戏路径
      const fromDefine = String.fromEnvironment('SAKI_GAME_PATH', defaultValue: '');
      if (fromDefine.isNotEmpty) {
        gamePath = fromDefine;
      } else {
        final fromEnv = Platform.environment['SAKI_GAME_PATH'];
        if (fromEnv != null && fromEnv.isNotEmpty) {
          gamePath = fromEnv;
        } else {
          // 从assets读取default_game.txt
          final assetContent = await rootBundle.loadString('assets/default_game.txt');
          final projectName = assetContent.trim();
          if (projectName.isNotEmpty) {
            gamePath = p.join(Directory.current.path, 'Game', projectName);
          }
        }
      }

      if (gamePath.isNotEmpty && kDebugMode) {
        // 在调试模式下，尝试从game_config.txt读取应用名称
        final configFile = File(p.join(gamePath, 'game_config.txt'));
        if (await configFile.exists()) {
          final lines = await configFile.readAsLines();
          if (lines.isNotEmpty) {
            _cachedAppName = lines.first.trim();
            return _cachedAppName!;
          }
        }
      }
      
      // 如果无法从配置读取，使用项目名称
      _cachedAppName = await getProjectName();
      return _cachedAppName!;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting app name: $e');
      }
      // fallback到项目名称
      _cachedAppName = await getProjectName();
      return _cachedAppName!;
    }
  }

  /// 清除缓存（用于项目切换时）
  void clearCache() {
    _cachedProjectName = null;
    _cachedAppName = null;
  }
}