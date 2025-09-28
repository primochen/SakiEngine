import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/config/project_info_manager.dart';
import 'platform_window_manager_io.dart' if (dart.library.html) 'platform_window_manager_web.dart';

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
  static const String _autoHideQuickMenuKey = 'auto_hide_quick_menu';
  static const String _menuDisplayModeKey = 'menu_display_mode';
  static const String _fastForwardModeKey = 'fast_forward_mode';
  
  // 默认值
  static const double defaultDialogOpacity = 0.9;
  static const bool defaultIsFullscreen = false;
  static const bool defaultDarkMode = false;
  
  // 打字机默认值 - 每秒显示字数
  static const double defaultTypewriterCharsPerSecond = 50.0;
  static const bool defaultSkipPunctuationDelay = false;
  static const bool defaultSpeakerAnimation = true;
  static const bool defaultAutoHideQuickMenu = false;
  static const String defaultMenuDisplayMode = 'windowed'; // 'windowed' or 'fullscreen'
  static const String defaultFastForwardMode = 'read_only'; // 'read_only' or 'force'

  SharedPreferences? _prefs;
  double _currentDialogOpacity = defaultDialogOpacity;
  bool _currentIsFullscreen = defaultIsFullscreen;
  bool _currentDarkMode = defaultDarkMode;
  
  // 打字机设置状态变量
  double _currentTypewriterCharsPerSecond = defaultTypewriterCharsPerSecond;
  bool _currentSkipPunctuationDelay = defaultSkipPunctuationDelay;
  bool _currentSpeakerAnimation = defaultSpeakerAnimation;
  bool _currentAutoHideQuickMenu = defaultAutoHideQuickMenu;
  String _currentMenuDisplayMode = defaultMenuDisplayMode;
  String _currentFastForwardMode = defaultFastForwardMode;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    
    // 获取项目名称以确定默认值
    String projectName = 'SakiEngine';
    try {
      projectName = await ProjectInfoManager().getAppName();
    } catch (e) {
      // 使用默认项目名称
    }
    
    // 根据项目设置不同的默认菜单显示模式
    String projectDefaultMenuDisplayMode = defaultMenuDisplayMode;
    if (projectName == 'SoraNoUta') {
      projectDefaultMenuDisplayMode = 'fullscreen';
    }
    
    // 初始化时加载当前值
    _currentDialogOpacity = _prefs?.getDouble(_dialogOpacityKey) ?? defaultDialogOpacity;
    _currentIsFullscreen = _prefs?.getBool(_isFullscreenKey) ?? defaultIsFullscreen;
    _currentDarkMode = _prefs?.getBool(_darkModeKey) ?? defaultDarkMode;
    
    // 加载打字机设置
    _currentTypewriterCharsPerSecond = _prefs?.getDouble(_typewriterSpeedKey) ?? defaultTypewriterCharsPerSecond;
    _currentSkipPunctuationDelay = _prefs?.getBool(_skipPunctuationDelayKey) ?? defaultSkipPunctuationDelay;
    _currentSpeakerAnimation = _prefs?.getBool(_speakerAnimationKey) ?? defaultSpeakerAnimation;
    _currentAutoHideQuickMenu = _prefs?.getBool(_autoHideQuickMenuKey) ?? defaultAutoHideQuickMenu;
    _currentMenuDisplayMode = _prefs?.getString(_menuDisplayModeKey) ?? projectDefaultMenuDisplayMode;
    _currentFastForwardMode = _prefs?.getString(_fastForwardModeKey) ?? defaultFastForwardMode;
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
    
    // 应用全屏设置（非Web平台）
    if (!kIsWeb) {
      if (isFullscreen) {
        await PlatformWindowManager.setFullScreen(true);
      } else {
        await PlatformWindowManager.setFullScreen(false);
      }
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

  // 自动隐藏快捷菜单设置
  Future<bool> getAutoHideQuickMenu() async {
    await init();
    return _currentAutoHideQuickMenu;
  }

  bool get currentAutoHideQuickMenu => _currentAutoHideQuickMenu;

  Future<void> setAutoHideQuickMenu(bool enabled) async {
    await init();
    _currentAutoHideQuickMenu = enabled;
    await _prefs?.setBool(_autoHideQuickMenuKey, enabled);
    notifyListeners();
  }

  // 菜单页面显示模式设置
  Future<String> getMenuDisplayMode() async {
    await init();
    return _currentMenuDisplayMode;
  }

  String get currentMenuDisplayMode => _currentMenuDisplayMode;

  Future<void> setMenuDisplayMode(String mode) async {
    await init();
    _currentMenuDisplayMode = mode;
    await _prefs?.setString(_menuDisplayModeKey, mode);
    notifyListeners();
  }

  // 快进模式设置
  Future<String> getFastForwardMode() async {
    await init();
    return _currentFastForwardMode;
  }

  String get currentFastForwardMode => _currentFastForwardMode;

  Future<void> setFastForwardMode(String mode) async {
    await init();
    _currentFastForwardMode = mode;
    await _prefs?.setString(_fastForwardModeKey, mode);
    notifyListeners();
  }

  // 恢复默认设置
  Future<void> resetToDefault() async {
    await init();
    
    // 获取项目名称以确定默认值
    String projectName = 'SakiEngine';
    try {
      projectName = await ProjectInfoManager().getAppName();
    } catch (e) {
      // 使用默认项目名称
    }
    
    // 根据项目设置不同的默认菜单显示模式
    String projectDefaultMenuDisplayMode = defaultMenuDisplayMode;
    if (projectName == 'SoraNoUta') {
      projectDefaultMenuDisplayMode = 'fullscreen';
    }
    
    _currentDialogOpacity = defaultDialogOpacity;
    _currentIsFullscreen = defaultIsFullscreen;
    _currentDarkMode = defaultDarkMode;
    _currentTypewriterCharsPerSecond = defaultTypewriterCharsPerSecond;
    _currentSkipPunctuationDelay = defaultSkipPunctuationDelay;
    _currentSpeakerAnimation = defaultSpeakerAnimation;
    _currentAutoHideQuickMenu = defaultAutoHideQuickMenu;
    _currentMenuDisplayMode = projectDefaultMenuDisplayMode;
    _currentFastForwardMode = defaultFastForwardMode;
    
    await _prefs?.setDouble(_dialogOpacityKey, defaultDialogOpacity);
    await _prefs?.setBool(_isFullscreenKey, defaultIsFullscreen);
    await _prefs?.setBool(_darkModeKey, defaultDarkMode);
    await _prefs?.setDouble(_typewriterSpeedKey, defaultTypewriterCharsPerSecond);
    await _prefs?.setBool(_skipPunctuationDelayKey, defaultSkipPunctuationDelay);
    await _prefs?.setBool(_speakerAnimationKey, defaultSpeakerAnimation);
    await _prefs?.setBool(_autoHideQuickMenuKey, defaultAutoHideQuickMenu);
    await _prefs?.setString(_menuDisplayModeKey, projectDefaultMenuDisplayMode);
    await _prefs?.setString(_fastForwardModeKey, defaultFastForwardMode);
    
    // 应用默认全屏设置（非Web平台）
    if (!kIsWeb) {
      await PlatformWindowManager.setFullScreen(defaultIsFullscreen);
    }
    
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