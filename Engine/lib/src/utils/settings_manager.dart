import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

class SettingsManager extends ChangeNotifier {
  static final SettingsManager _instance = SettingsManager._internal();
  factory SettingsManager() => _instance;
  SettingsManager._internal();

  static const String _dialogOpacityKey = 'dialog_opacity';
  static const String _isFullscreenKey = 'is_fullscreen';
  
  // 默认值
  static const double defaultDialogOpacity = 0.9;
  static const bool defaultIsFullscreen = false;

  SharedPreferences? _prefs;
  double _currentDialogOpacity = defaultDialogOpacity;
  bool _currentIsFullscreen = defaultIsFullscreen;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    // 初始化时加载当前值
    _currentDialogOpacity = _prefs?.getDouble(_dialogOpacityKey) ?? defaultDialogOpacity;
    _currentIsFullscreen = _prefs?.getBool(_isFullscreenKey) ?? defaultIsFullscreen;
  }

  // 对话框不透明度
  Future<double> getDialogOpacity() async {
    await init();
    return _currentDialogOpacity;
  }

  double get currentDialogOpacity => _currentDialogOpacity;

  Future<void> setDialogOpacity(double opacity) async {
    await init();
    _currentDialogOpacity = opacity;
    await _prefs?.setDouble(_dialogOpacityKey, opacity);
    notifyListeners(); // 通知所有监听者
  }

  // 全屏状态
  Future<bool> getIsFullscreen() async {
    await init();
    return _currentIsFullscreen;
  }

  bool get currentIsFullscreen => _currentIsFullscreen;

  Future<void> setIsFullscreen(bool isFullscreen) async {
    await init();
    _currentIsFullscreen = isFullscreen;
    await _prefs?.setBool(_isFullscreenKey, isFullscreen);
    
    // 应用全屏设置
    if (isFullscreen) {
      await windowManager.setFullScreen(true);
    } else {
      await windowManager.setFullScreen(false);
    }
    
    notifyListeners(); // 通知所有监听者
  }

  // 恢复默认设置
  Future<void> resetToDefault() async {
    await init();
    _currentDialogOpacity = defaultDialogOpacity;
    _currentIsFullscreen = defaultIsFullscreen;
    
    await _prefs?.setDouble(_dialogOpacityKey, defaultDialogOpacity);
    await _prefs?.setBool(_isFullscreenKey, defaultIsFullscreen);
    
    // 应用默认全屏设置
    await windowManager.setFullScreen(defaultIsFullscreen);
    
    notifyListeners(); // 通知所有监听者
  }

  // 获取所有设置
  Future<Map<String, dynamic>> getAllSettings() async {
    return {
      'dialogOpacity': await getDialogOpacity(),
      'isFullscreen': await getIsFullscreen(),
    };
  }
}