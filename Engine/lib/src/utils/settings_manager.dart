import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';

class SettingsManager extends ChangeNotifier {
  static final SettingsManager _instance = SettingsManager._internal();
  factory SettingsManager() => _instance;
  SettingsManager._internal();

  static const String _dialogOpacityKey = 'dialog_opacity';
  static const String _isFullscreenKey = 'is_fullscreen';
  static const String _darkModeKey = 'dark_mode';
  
  // 打字机设置键
  static const String _typewriterSpeedKey = 'typewriter_chars_per_second';
  static const String _skipPunctuationDelayKey = 'skip_punctuation_delay';
  static const String _speakerAnimationKey = 'speaker_animation';
  
  // 默认值
  static const double defaultDialogOpacity = 0.9;
  static const bool defaultIsFullscreen = false;
  static const bool defaultDarkMode = false;
  
  // 打字机默认值 - 每秒显示字数
  static const double defaultTypewriterCharsPerSecond = 50.0;
  static const bool defaultSkipPunctuationDelay = false;
  static const bool defaultSpeakerAnimation = true;

  SharedPreferences? _prefs;
  double _currentDialogOpacity = defaultDialogOpacity;
  bool _currentIsFullscreen = defaultIsFullscreen;
  bool _currentDarkMode = defaultDarkMode;
  
  // 打字机设置状态变量
  double _currentTypewriterCharsPerSecond = defaultTypewriterCharsPerSecond;
  bool _currentSkipPunctuationDelay = defaultSkipPunctuationDelay;
  bool _currentSpeakerAnimation = defaultSpeakerAnimation;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    // 初始化时加载当前值
    _currentDialogOpacity = _prefs?.getDouble(_dialogOpacityKey) ?? defaultDialogOpacity;
    _currentIsFullscreen = _prefs?.getBool(_isFullscreenKey) ?? defaultIsFullscreen;
    _currentDarkMode = _prefs?.getBool(_darkModeKey) ?? defaultDarkMode;
    
    // 加载打字机设置
    _currentTypewriterCharsPerSecond = _prefs?.getDouble(_typewriterSpeedKey) ?? defaultTypewriterCharsPerSecond;
    _currentSkipPunctuationDelay = _prefs?.getBool(_skipPunctuationDelayKey) ?? defaultSkipPunctuationDelay;
    _currentSpeakerAnimation = _prefs?.getBool(_speakerAnimationKey) ?? defaultSpeakerAnimation;
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

  // 深色模式
  Future<bool> getDarkMode() async {
    await init();
    return _currentDarkMode;
  }

  bool get currentDarkMode => _currentDarkMode;

  Future<void> setDarkMode(bool isDarkMode) async {
    await init();
    _currentDarkMode = isDarkMode;
    await _prefs?.setBool(_darkModeKey, isDarkMode);
    
    // 更新主题颜色
    SakiEngineConfig().updateThemeForDarkMode();
    
    notifyListeners(); // 通知所有监听者
  }

  // 打字机每秒字符数设置
  Future<double> getTypewriterCharsPerSecond() async {
    await init();
    return _currentTypewriterCharsPerSecond;
  }

  Future<void> setTypewriterCharsPerSecond(double charsPerSecond) async {
    await init();
    _currentTypewriterCharsPerSecond = charsPerSecond;
    await _prefs?.setDouble(_typewriterSpeedKey, charsPerSecond);
    notifyListeners();
  }

  // 跳过标点符号延迟设置
  Future<bool> getSkipPunctuationDelay() async {
    await init();
    return _currentSkipPunctuationDelay;
  }

  Future<void> setSkipPunctuationDelay(bool skip) async {
    await init();
    _currentSkipPunctuationDelay = skip;
    await _prefs?.setBool(_skipPunctuationDelayKey, skip);
    notifyListeners();
  }

  // 说话人动画设置
  Future<bool> getSpeakerAnimation() async {
    await init();
    return _currentSpeakerAnimation;
  }

  bool get currentSpeakerAnimation => _currentSpeakerAnimation;

  Future<void> setSpeakerAnimation(bool enabled) async {
    await init();
    _currentSpeakerAnimation = enabled;
    await _prefs?.setBool(_speakerAnimationKey, enabled);
    notifyListeners();
  }

  // 恢复默认设置
  Future<void> resetToDefault() async {
    await init();
    _currentDialogOpacity = defaultDialogOpacity;
    _currentIsFullscreen = defaultIsFullscreen;
    _currentDarkMode = defaultDarkMode;
    _currentTypewriterCharsPerSecond = defaultTypewriterCharsPerSecond;
    _currentSkipPunctuationDelay = defaultSkipPunctuationDelay;
    _currentSpeakerAnimation = defaultSpeakerAnimation;
    
    await _prefs?.setDouble(_dialogOpacityKey, defaultDialogOpacity);
    await _prefs?.setBool(_isFullscreenKey, defaultIsFullscreen);
    await _prefs?.setBool(_darkModeKey, defaultDarkMode);
    await _prefs?.setDouble(_typewriterSpeedKey, defaultTypewriterCharsPerSecond);
    await _prefs?.setBool(_skipPunctuationDelayKey, defaultSkipPunctuationDelay);
    await _prefs?.setBool(_speakerAnimationKey, defaultSpeakerAnimation);
    
    // 应用默认全屏设置
    await windowManager.setFullScreen(defaultIsFullscreen);
    
    notifyListeners(); // 通知所有监听者
  }

  // 获取所有设置
  Future<Map<String, dynamic>> getAllSettings() async {
    return {
      'dialogOpacity': await getDialogOpacity(),
      'isFullscreen': await getIsFullscreen(),
      'typewriterCharsPerSecond': await getTypewriterCharsPerSecond(),
      'skipPunctuationDelay': await getSkipPunctuationDelay(),
    };
  }
}