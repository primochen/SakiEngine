import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/utils/scaling_manager.dart';
import 'package:sakiengine/src/utils/settings_manager.dart';
import 'package:sakiengine/src/utils/music_manager.dart';
import 'package:sakiengine/src/widgets/confirm_dialog.dart';
import 'package:sakiengine/src/widgets/common/overlay_scaffold.dart';
import 'package:sakiengine/src/widgets/game_style_switch.dart';
import 'package:sakiengine/src/widgets/game_style_slider.dart';
import 'package:sakiengine/src/widgets/game_style_scrollbar.dart';
import 'package:sakiengine/src/widgets/typewriter_animation_manager.dart';
import 'package:sakiengine/src/widgets/typewriter_preview.dart';
import 'package:sakiengine/src/localization/localization_manager.dart';
import 'package:sakiengine/src/widgets/game_style_dropdown.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onClose;

  const SettingsScreen({
    super.key,
    required this.onClose,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsManager _settingsManager = SettingsManager();
  final MusicManager _musicManager = MusicManager();
  
  double _dialogOpacity = SettingsManager.defaultDialogOpacity;
  bool _isFullscreen = SettingsManager.defaultIsFullscreen;
  bool _darkMode = SettingsManager.defaultDarkMode;
  bool _isLoading = true;
  
  // 打字机设置
  double _typewriterCharsPerSecond = SettingsManager.defaultTypewriterCharsPerSecond;
  bool _skipPunctuationDelay = SettingsManager.defaultSkipPunctuationDelay;
  bool _speakerAnimation = SettingsManager.defaultSpeakerAnimation;
  bool _autoHideQuickMenu = SettingsManager.defaultAutoHideQuickMenu;
  String _menuDisplayMode = SettingsManager.defaultMenuDisplayMode;
  String _fastForwardMode = SettingsManager.defaultFastForwardMode;
  
  // 预览文本（在设置界面生命周期内固定）
  late String _previewText;
  
  // 音频设置
  bool _musicEnabled = true;
  double _musicVolume = 0.8;
  double _soundVolume = 0.8;
  
  int _selectedTabIndex = 0;
  static const List<String> _tabTitleKeys = [
    'settings.tabs.video',
    'settings.tabs.audio',
    'settings.tabs.gameplay',
    'settings.tabs.control',
  ];

  late SupportedLanguage _selectedLanguage;
  late final Listenable _combinedListenable;

  @override
  void initState() {
    super.initState();
    // 在设置界面初始化时选择一次随机文本
    _previewText = TypewriterPreview.getRandomPreviewText();
    _selectedLanguage = LocalizationManager().currentLanguage;
    _combinedListenable = Listenable.merge([
      SettingsManager(),
      LocalizationManager(),
    ]);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    
    try {
      // 使用新的getter方法获取当前值
      _dialogOpacity = SettingsManager().currentDialogOpacity;
      _isFullscreen = SettingsManager().currentIsFullscreen;
      _darkMode = SettingsManager().currentDarkMode;
      
      // 确保SettingsManager已初始化
      await SettingsManager().init();
      
      // 再次获取以确保是最新值
      _dialogOpacity = await SettingsManager().getDialogOpacity();
      _isFullscreen = await SettingsManager().getIsFullscreen();
      _darkMode = await SettingsManager().getDarkMode();
      
      // 加载打字机设置
      _typewriterCharsPerSecond = await SettingsManager().getTypewriterCharsPerSecond();
      _skipPunctuationDelay = await SettingsManager().getSkipPunctuationDelay();
      _speakerAnimation = await SettingsManager().getSpeakerAnimation();
      _autoHideQuickMenu = await SettingsManager().getAutoHideQuickMenu();
      _menuDisplayMode = await SettingsManager().getMenuDisplayMode();
      _fastForwardMode = await SettingsManager().getFastForwardMode();
      
      // 加载音频设置
      _musicEnabled = _musicManager.isMusicEnabled;
      _musicVolume = _musicManager.musicVolume;
      _soundVolume = _musicManager.soundVolume;

      _selectedLanguage = LocalizationManager().currentLanguage;
      _previewText = TypewriterPreview.getRandomPreviewText();
      
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateDialogOpacity(double value) async {
    setState(() => _dialogOpacity = value);
    await _settingsManager.setDialogOpacity(value);
  }

  Future<void> _updateFullscreen(bool value) async {
    setState(() => _isFullscreen = value);
    await _settingsManager.setIsFullscreen(value);
  }

  Future<void> _updateDarkMode(bool value) async {
    setState(() => _darkMode = value);
    await _settingsManager.setDarkMode(value);
    // 确保主题配置立即更新
    SakiEngineConfig().updateThemeForDarkMode();
    // 强制重建当前设置屏幕
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _updateTypewriterCharsPerSecond(double value) async {
    setState(() => _typewriterCharsPerSecond = value);
    await _settingsManager.setTypewriterCharsPerSecond(value);
    // 通知所有TypewriterAnimationManager实例更新设置
    TypewriterAnimationManager.notifySettingsChanged();
  }

  Future<void> _updateSkipPunctuationDelay(bool value) async {
    setState(() => _skipPunctuationDelay = value);
    await _settingsManager.setSkipPunctuationDelay(value);
    // 通知所有TypewriterAnimationManager实例更新设置
    TypewriterAnimationManager.notifySettingsChanged();
  }

  Future<void> _updateSpeakerAnimation(bool value) async {
    setState(() => _speakerAnimation = value);
    await _settingsManager.setSpeakerAnimation(value);
  }

  Future<void> _updateAutoHideQuickMenu(bool value) async {
    setState(() => _autoHideQuickMenu = value);
    await _settingsManager.setAutoHideQuickMenu(value);
  }

  Future<void> _updateMenuDisplayMode(String value) async {
    setState(() => _menuDisplayMode = value);
    await _settingsManager.setMenuDisplayMode(value);
  }

  Future<void> _updateFastForwardMode(String value) async {
    setState(() => _fastForwardMode = value);
    await _settingsManager.setFastForwardMode(value);
  }

  Future<void> _updateMusicEnabled(bool value) async {
    setState(() => _musicEnabled = value);
    await _musicManager.setMusicEnabled(value);
  }

  Future<void> _updateMusicVolume(double value) async {
    setState(() => _musicVolume = value);
    await _musicManager.setMusicVolume(value);
  }

  Future<void> _updateSoundVolume(double value) async {
    setState(() => _soundVolume = value);
    await _musicManager.setSoundVolume(value);
  }

  Future<void> _updateLanguage(SupportedLanguage language) async {
    if (_selectedLanguage == language) {
      return;
    }
    await LocalizationManager().switchLanguage(language);
    if (!mounted) return;
    setState(() {
      _selectedLanguage = language;
      _previewText = TypewriterPreview.getRandomPreviewText();
    });
  }

  Future<void> _resetToDefault() async {
    final localization = LocalizationManager();
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return ConfirmDialog(
          title: localization.t('settings.reset.title'),
          content: localization.t('settings.reset.content'),
          confirmResult: true,
          cancelResult: false,
        );
      },
    );

    if (shouldReset == true) {
      await _settingsManager.resetToDefault();
      await _loadSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _combinedListenable,
      builder: (context, child) {
        // 当设置变化时，重新更新主题配置
        SakiEngineConfig().updateThemeForDarkMode();
        final localization = LocalizationManager();
        
        return OverlayScaffold(
          title: localization.t('settings.title'),
          content: _isLoading ? _buildLoadingContent() : _buildSettingsContent(),
          footer: _isLoading ? null : _buildFooter(),
          onClose: widget.onClose,
        );
      },
    );
  }

  Widget _buildLoadingContent() {
    return Center(
      child: Container(color: const Color.fromARGB(0, 0, 0, 0)),
    );
  }

  Widget _buildSettingsContent() {
    final config = SakiEngineConfig();
    final scale = context.scaleFor(ComponentType.ui);

    return Column(
      children: [
        _buildTabBar(config, scale),
        Expanded(
          child: _buildTabContent(config, scale),
        ),
      ],
    );
  }

  Widget _buildTabBar(SakiEngineConfig config, double scale) {
    final localization = LocalizationManager();
    final tabTitles = _tabTitleKeys.map(localization.t).toList();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 8 * scale),
      decoration: BoxDecoration(
        color: config.themeColors.surface.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(
            color: config.themeColors.primary.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: List.generate(tabTitles.length, (index) {
          return _SettingsTab(
            title: tabTitles[index],
            isSelected: _selectedTabIndex == index,
            onTap: () => setState(() => _selectedTabIndex = index),
            config: config,
            scale: scale,
          );
        }),
      ),
    );
  }

  Widget _buildTabContent(SakiEngineConfig config, double scale) {
    switch (_selectedTabIndex) {
      case 0: // 画面设置
        return _buildVideoSettings(config, scale);
      case 1: // 音频设置
        return _buildAudioSettings(config, scale);
      case 2: // 玩法设置
        return _buildGameplaySettings(config, scale);
      case 3: // 操控设置
        return _buildControlSettings(config, scale);
      default:
        return _buildVideoSettings(config, scale);
    }
  }

  Widget _buildVideoSettings(SakiEngineConfig config, double scale) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideLayout = constraints.maxWidth > constraints.maxHeight;
        
        if (isWideLayout) {
          return _buildVideoSettingsDualColumn(config, scale, constraints);
        } else {
          return _buildVideoSettingsSingleColumn(config, scale);
        }
      },
    );
  }

  Widget _buildVideoSettingsSingleColumn(SakiEngineConfig config, double scale) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(32 * scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLanguageSelector(config, scale),
            SizedBox(height: 40 * scale),
            _buildOpacitySlider(config, scale),
            SizedBox(height: 40 * scale),
            _buildMenuDisplayModeToggle(config, scale),
            SizedBox(height: 40 * scale),
            _buildFullscreenToggle(config, scale),
            SizedBox(height: 40 * scale),
            _buildDarkModeToggle(config, scale),
            SizedBox(height: 40 * scale),
            _buildSpeakerAnimationToggle(config, scale),
            SizedBox(height: 40 * scale),
            _buildAutoHideQuickMenuSetting(config, scale),
            SizedBox(height: 40 * scale),
            _buildTypewriterSpeedSlider(config, scale),
            SizedBox(height: 40 * scale), // 底部间距
          ],
        ),
      ),
    );
  }

  Widget _buildVideoSettingsDualColumn(SakiEngineConfig config, double scale, BoxConstraints constraints) {
    return Stack(
      children: [
        // 主要内容区域
        Row(
          crossAxisAlignment: CrossAxisAlignment.start, // 确保顶对齐
          children: [
            // 左列
            Expanded(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 32 * scale,
                    top: 32 * scale,
                    bottom: 32 * scale,
                    right: 32 * scale,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOpacitySlider(config, scale),
                      SizedBox(height: 40 * scale),
                      _buildTypewriterSpeedSlider(config, scale),
                      SizedBox(height: 40 * scale), // 底部间距
                    ],
                  ),
                ),
              ),
            ),
            
            // 右列间距
            SizedBox(width: 0), // 移除间距，让分割线居中
            
            // 右列
            Expanded(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 32 * scale,
                    top: 32 * scale,
                    bottom: 32 * scale,
                    right: 32 * scale,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLanguageSelector(config, scale),
                      SizedBox(height: 40 * scale),
                      _buildMenuDisplayModeToggle(config, scale),
                      SizedBox(height: 40 * scale),
                      _buildFullscreenToggle(config, scale),
                      SizedBox(height: 40 * scale),
                      _buildDarkModeToggle(config, scale),
                      SizedBox(height: 40 * scale),
                      _buildSpeakerAnimationToggle(config, scale),
                      SizedBox(height: 40 * scale),
                      _buildAutoHideQuickMenuSetting(config, scale),
                      SizedBox(height: 40 * scale),
                      // 可以在这里添加更多右列设置项
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        
        // 固定的中间分割线 - 简化居中定位
        Positioned.fill(
          child: Align(
            alignment: Alignment.center,
            child: Container(
              width: 1 * scale,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    config.themeColors.primary.withOpacity(0.3),
                    config.themeColors.primary.withOpacity(0.6),
                    config.themeColors.primary.withOpacity(0.3),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAudioSettings(SakiEngineConfig config, double scale) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideLayout = constraints.maxWidth > constraints.maxHeight;
        
        if (isWideLayout) {
          return _buildAudioSettingsDualColumn(config, scale, constraints);
        } else {
          return _buildAudioSettingsSingleColumn(config, scale);
        }
      },
    );
  }

  Widget _buildAudioSettingsSingleColumn(SakiEngineConfig config, double scale) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(32 * scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMusicEnabledToggle(config, scale),
            SizedBox(height: 40 * scale),
            _buildMusicVolumeSlider(config, scale),
            SizedBox(height: 40 * scale),
            _buildSoundVolumeSlider(config, scale),
            SizedBox(height: 40 * scale),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioSettingsDualColumn(SakiEngineConfig config, double scale, BoxConstraints constraints) {
    return Stack(
      children: [
        // 主要内容区域
        Row(
          crossAxisAlignment: CrossAxisAlignment.start, // 确保顶对齐
          children: [
            // 左列 - 音乐设置
            Expanded(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 32 * scale,
                    top: 32 * scale,
                    bottom: 32 * scale,
                    right: 32 * scale,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMusicEnabledToggle(config, scale),
                      SizedBox(height: 40 * scale),
                      _buildMusicVolumeSlider(config, scale),
                      SizedBox(height: 40 * scale), // 底部间距
                    ],
                  ),
                ),
              ),
            ),
            
            // 右列间距
            SizedBox(width: 0), // 移除间距，让分割线居中
            
            // 右列 - 音效设置
            Expanded(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 32 * scale,
                    top: 32 * scale,
                    bottom: 32 * scale,
                    right: 32 * scale,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSoundVolumeSlider(config, scale),
                      SizedBox(height: 40 * scale),
                      // 可以在这里添加更多音效设置项
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        
        // 固定的中间分割线 - 简化居中定位
        Positioned.fill(
          child: Align(
            alignment: Alignment.center,
            child: Container(
              width: 1 * scale,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    config.themeColors.primary.withOpacity(0.3),
                    config.themeColors.primary.withOpacity(0.6),
                    config.themeColors.primary.withOpacity(0.3),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGameplaySettings(SakiEngineConfig config, double scale) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(32 * scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFastForwardModeToggle(config, scale),
            SizedBox(height: 40 * scale),
          ],
        ),
      ),
    );
  }

  Widget _buildControlSettings(SakiEngineConfig config, double scale) {
    final textScale = context.scaleFor(ComponentType.text);
    final localization = LocalizationManager();
    return Center(
      child: Text(
        localization.t('settings.controls.placeholder'),
        style: config.reviewTitleTextStyle.copyWith(
          fontSize: config.reviewTitleTextStyle.fontSize! * textScale * 0.8,
          color: config.themeColors.primary.withOpacity(0.6),
        ),
      ),
    );
  }

  Widget _buildOpacitySlider(SakiEngineConfig config, double scale) {
    final textScale = context.scaleFor(ComponentType.text);
    final localization = LocalizationManager();
    
    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: config.themeColors.surface.withOpacity(0.5),
        border: Border.all(
          color: config.themeColors.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.opacity,
                color: config.themeColors.primary,
                size: 24 * scale,
              ),
              SizedBox(width: 16 * scale),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localization.t('settings.opacity.title'),
                      style: config.reviewTitleTextStyle.copyWith(
                        fontSize: config.reviewTitleTextStyle.fontSize! * textScale * 0.7,
                        color: config.themeColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      localization.t('settings.opacity.description'),
                      style: config.dialogueTextStyle.copyWith(
                        fontSize: config.dialogueTextStyle.fontSize! * textScale * 0.6,
                        color: config.themeColors.primary.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16 * scale),
          GameStyleSlider(
            value: _dialogOpacity,
            min: 0.3,
            max: 1.0,
            divisions: 7,
            scale: scale,
            config: config,
            onChanged: _updateDialogOpacity,
            showValue: false,
          ),
          SizedBox(height: 8 * scale),
          Text(
            localization.t('settings.opacity.current', params: {
              'value': (_dialogOpacity * 100).round().toString(),
            }),
            style: config.dialogueTextStyle.copyWith(
              fontSize: config.dialogueTextStyle.fontSize! * textScale * 0.5,
              color: config.themeColors.primary.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullscreenToggle(SakiEngineConfig config, double scale) {
    final textScale = context.scaleFor(ComponentType.text);
    final localization = LocalizationManager();

    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: config.themeColors.surface.withOpacity(0.5),
        border: Border.all(
          color: config.themeColors.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
            color: config.themeColors.primary,
            size: 24 * scale,
          ),
          SizedBox(width: 16 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localization.t('settings.fullscreen.title'),
                  style: config.reviewTitleTextStyle.copyWith(
                    fontSize: config.reviewTitleTextStyle.fontSize! * textScale * 0.7,
                    color: config.themeColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4 * scale),
                Text(
                  localization.t('settings.fullscreen.description'),
                  style: config.dialogueTextStyle.copyWith(
                    fontSize: config.dialogueTextStyle.fontSize! * textScale * 0.6,
                    color: config.themeColors.primary.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 16 * scale),
          GameStyleSwitch(
            value: _isFullscreen,
            onChanged: _updateFullscreen,
            scale: scale,
            config: config,
          ),
        ],
      ),
    );
  }

  Widget _buildDarkModeToggle(SakiEngineConfig config, double scale) {
    final textScale = context.scaleFor(ComponentType.text);
    final localization = LocalizationManager();

    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: config.themeColors.surface.withOpacity(0.5),
        border: Border.all(
          color: config.themeColors.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _darkMode ? Icons.dark_mode : Icons.light_mode,
            color: config.themeColors.primary,
            size: 24 * scale,
          ),
          SizedBox(width: 16 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localization.t('settings.darkMode.title'),
                  style: config.reviewTitleTextStyle.copyWith(
                    fontSize: config.reviewTitleTextStyle.fontSize! * textScale * 0.7,
                    color: config.themeColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4 * scale),
                Text(
                  localization.t('settings.darkMode.description'),
                  style: config.dialogueTextStyle.copyWith(
                    fontSize: config.dialogueTextStyle.fontSize! * textScale * 0.6,
                    color: config.themeColors.primary.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 16 * scale),
          GameStyleSwitch(
            value: _darkMode,
            onChanged: _updateDarkMode,
            scale: scale,
            config: config,
          ),
        ],
      ),
    );
  }

  Widget _buildSpeakerAnimationToggle(SakiEngineConfig config, double scale) {
    final textScale = context.scaleFor(ComponentType.text);
    final localization = LocalizationManager();
    
    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: config.themeColors.surface.withOpacity(0.5),
        border: Border.all(
          color: config.themeColors.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _speakerAnimation ? Icons.animation : Icons.text_fields,
            color: config.themeColors.primary,
            size: 24 * scale,
          ),
          SizedBox(width: 16 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localization.t('settings.speakerAnimation.title'),
                  style: config.reviewTitleTextStyle.copyWith(
                    fontSize: config.reviewTitleTextStyle.fontSize! * textScale * 0.7,
                    color: config.themeColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4 * scale),
                Text(
                  localization.t('settings.speakerAnimation.description'),
                  style: config.dialogueTextStyle.copyWith(
                    fontSize: config.dialogueTextStyle.fontSize! * textScale * 0.6,
                    color: config.themeColors.primary.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 16 * scale),
          GameStyleSwitch(
            value: _speakerAnimation,
            onChanged: _updateSpeakerAnimation,
            scale: scale,
            config: config,
          ),
        ],
      ),
    );
  }

  Widget _buildAutoHideQuickMenuSetting(SakiEngineConfig config, double scale) {
    final textScale = context.scaleFor(ComponentType.text);
    final localization = LocalizationManager();
    
    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: config.themeColors.surface.withOpacity(0.5),
        border: Border.all(
          color: config.themeColors.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome,
            color: config.themeColors.primary,
            size: 20 * scale,
          ),
          SizedBox(width: 16 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localization.t('settings.autoHideQuickMenu.title'),
                  style: config.reviewTitleTextStyle.copyWith(
                    fontSize: config.reviewTitleTextStyle.fontSize! * textScale * 0.7,
                    color: config.themeColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4 * scale),
                Text(
                  localization.t('settings.autoHideQuickMenu.description'),
                  style: config.dialogueTextStyle.copyWith(
                    fontSize: config.dialogueTextStyle.fontSize! * textScale * 0.6,
                    color: config.themeColors.primary.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 16 * scale),
          GameStyleSwitch(
            value: _autoHideQuickMenu,
            onChanged: _updateAutoHideQuickMenu,
            scale: scale,
            config: config,
          ),
        ],
      ),
    );
  }

  Widget _buildTypewriterSpeedSlider(SakiEngineConfig config, double scale) {
    final textScale = context.scaleFor(ComponentType.text);
    final localization = LocalizationManager();
    
    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: config.themeColors.surface.withOpacity(0.5),
        border: Border.all(
          color: config.themeColors.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.speed,
                color: config.themeColors.primary,
                size: 24 * scale,
              ),
              SizedBox(width: 16 * scale),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localization.t('settings.typewriterSpeed.title'),
                      style: config.reviewTitleTextStyle.copyWith(
                        fontSize: config.reviewTitleTextStyle.fontSize! * textScale * 0.7,
                        color: config.themeColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      localization.t('settings.typewriterSpeed.description'),
                      style: config.dialogueTextStyle.copyWith(
                        fontSize: config.dialogueTextStyle.fontSize! * textScale * 0.6,
                        color: config.themeColors.primary.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16 * scale),
          GameStyleSlider(
            value: _typewriterCharsPerSecond,
            min: 10.0,
            max: 200.0,
            divisions: 19,
            onChanged: _updateTypewriterCharsPerSecond,
            config: config,
            scale: scale,
            showValue: false, // 关闭内置的值显示
          ),
          SizedBox(height: 8 * scale),
          Text(
            _typewriterCharsPerSecond >= 200.0 
              ? localization.t('settings.typewriterSpeed.instant')
              : localization.t('settings.typewriterSpeed.current', params: {
                  'value': _typewriterCharsPerSecond.round().toString(),
                }),
            style: config.dialogueTextStyle.copyWith(
              fontSize: config.dialogueTextStyle.fontSize! * textScale * 0.5,
              color: config.themeColors.primary.withOpacity(0.8),
            ),
          ),
          SizedBox(height: 16 * scale),
          // 标点符号停顿设置
          Row(
            children: [
              Expanded(
                child: Text(
                  localization.t('settings.punctuationPause.title'),
                  style: config.dialogueTextStyle.copyWith(
                    fontSize: config.dialogueTextStyle.fontSize! * textScale * 0.6,
                    color: config.themeColors.primary,
                  ),
                ),
              ),
              GameStyleSwitch(
                value: !_skipPunctuationDelay, // 注意：这里取反，因为设置是"跳过"，但UI显示为"停顿"
                onChanged: (value) => _updateSkipPunctuationDelay(!value),
                config: config,
                scale: scale * 0.8,
              ),
            ],
          ),
          Text(
            localization.t('settings.punctuationPause.description'),
            style: config.dialogueTextStyle.copyWith(
              fontSize: config.dialogueTextStyle.fontSize! * textScale * 0.5,
              color: config.themeColors.primary.withOpacity(0.6),
            ),
          ),
          // Add live preview widget
          TypewriterPreview(
            charsPerSecond: _typewriterCharsPerSecond,
            skipPunctuationDelay: _skipPunctuationDelay,
            config: config,
            scale: scale,
            previewText: _previewText, // 传入预选的文本
          ),
        ],
      ),
    );
  }

  Widget _buildMusicEnabledToggle(SakiEngineConfig config, double scale) {
    final textScale = context.scaleFor(ComponentType.text);
    final localization = LocalizationManager();
    
    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: config.themeColors.surface.withOpacity(0.5),
        border: Border.all(
          color: config.themeColors.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _musicEnabled ? Icons.music_note : Icons.music_off,
            color: config.themeColors.primary,
            size: 24 * scale,
          ),
          SizedBox(width: 16 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localization.t('settings.musicEnabled.title'),
                  style: config.reviewTitleTextStyle.copyWith(
                    fontSize: config.reviewTitleTextStyle.fontSize! * textScale * 0.7,
                    color: config.themeColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4 * scale),
                Text(
                  localization.t('settings.musicEnabled.description'),
                  style: config.dialogueTextStyle.copyWith(
                    fontSize: config.dialogueTextStyle.fontSize! * textScale * 0.6,
                    color: config.themeColors.primary.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 16 * scale),
          GameStyleSwitch(
            value: _musicEnabled,
            onChanged: _updateMusicEnabled,
            scale: scale,
            config: config,
          ),
        ],
      ),
    );
  }

  Widget _buildMusicVolumeSlider(SakiEngineConfig config, double scale) {
    final textScale = context.scaleFor(ComponentType.text);
    final localization = LocalizationManager();
    
    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: config.themeColors.surface.withOpacity(0.5),
        border: Border.all(
          color: config.themeColors.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.volume_up,
                color: config.themeColors.primary,
                size: 24 * scale,
              ),
              SizedBox(width: 16 * scale),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localization.t('settings.musicVolume.title'),
                      style: config.reviewTitleTextStyle.copyWith(
                        fontSize: config.reviewTitleTextStyle.fontSize! * textScale * 0.7,
                        color: config.themeColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      localization.t('settings.musicVolume.description'),
                      style: config.dialogueTextStyle.copyWith(
                        fontSize: config.dialogueTextStyle.fontSize! * textScale * 0.6,
                        color: config.themeColors.primary.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16 * scale),
          GameStyleSlider(
            value: _musicVolume,
            min: 0.0,
            max: 1.0,
            divisions: 10,
            scale: scale,
            config: config,
            onChanged: _updateMusicVolume,
            showValue: false,
          ),
          SizedBox(height: 8 * scale),
          Text(
            localization.t('settings.common.currentVolume', params: {
              'value': (_musicVolume * 100).round().toString(),
            }),
            style: config.dialogueTextStyle.copyWith(
              fontSize: config.dialogueTextStyle.fontSize! * textScale * 0.5,
              color: config.themeColors.primary.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoundVolumeSlider(SakiEngineConfig config, double scale) {
    final textScale = context.scaleFor(ComponentType.text);
    final localization = LocalizationManager();
    
    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: config.themeColors.surface.withOpacity(0.5),
        border: Border.all(
          color: config.themeColors.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.volume_down,
                color: config.themeColors.primary,
                size: 24 * scale,
              ),
              SizedBox(width: 16 * scale),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localization.t('settings.soundVolume.title'),
                      style: config.reviewTitleTextStyle.copyWith(
                        fontSize: config.reviewTitleTextStyle.fontSize! * textScale * 0.7,
                        color: config.themeColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      localization.t('settings.soundVolume.description'),
                      style: config.dialogueTextStyle.copyWith(
                        fontSize: config.dialogueTextStyle.fontSize! * textScale * 0.6,
                        color: config.themeColors.primary.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16 * scale),
          GameStyleSlider(
            value: _soundVolume,
            min: 0.0,
            max: 1.0,
            divisions: 10,
            scale: scale,
            config: config,
            onChanged: _updateSoundVolume,
            showValue: false,
          ),
          SizedBox(height: 8 * scale),
          Text(
            localization.t('settings.common.currentVolume', params: {
              'value': (_soundVolume * 100).round().toString(),
            }),
            style: config.dialogueTextStyle.copyWith(
              fontSize: config.dialogueTextStyle.fontSize! * textScale * 0.5,
              color: config.themeColors.primary.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuDisplayModeToggle(SakiEngineConfig config, double scale) {
    final textScale = context.scaleFor(ComponentType.text);
    final isFullscreenMode = _menuDisplayMode == 'fullscreen';
    final localization = LocalizationManager();
    
    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: config.themeColors.surface.withOpacity(0.5),
        border: Border.all(
          color: config.themeColors.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isFullscreenMode ? Icons.aspect_ratio : Icons.crop_free,
            color: config.themeColors.primary,
            size: 24 * scale,
          ),
          SizedBox(width: 16 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localization.t('settings.menuDisplay.title'),
                  style: config.reviewTitleTextStyle.copyWith(
                    fontSize: config.reviewTitleTextStyle.fontSize! * textScale * 0.7,
                    color: config.themeColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4 * scale),
                Text(
                  localization.t('settings.menuDisplay.description'),
                  style: config.dialogueTextStyle.copyWith(
                    fontSize: config.dialogueTextStyle.fontSize! * textScale * 0.6,
                    color: config.themeColors.primary.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 16 * scale),
          GameStyleSwitch(
            value: isFullscreenMode,
            onChanged: (value) => _updateMenuDisplayMode(value ? 'fullscreen' : 'windowed'),
            scale: scale,
            config: config,
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector(SakiEngineConfig config, double scale) {
    final textScale = context.scaleFor(ComponentType.text);
    final localization = LocalizationManager();
    final languages = localization.loadedLanguages;

    if (languages.isEmpty) {
      return const SizedBox.shrink();
    }

    final selectedLanguage = languages.contains(_selectedLanguage)
        ? _selectedLanguage
        : languages.first;

    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: config.themeColors.surface.withOpacity(0.5),
        border: Border.all(
          color: config.themeColors.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.language,
            color: config.themeColors.primary,
            size: 24 * scale,
          ),
          SizedBox(width: 16 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localization.t('settings.language.title'),
                  style: config.reviewTitleTextStyle.copyWith(
                    fontSize: config.reviewTitleTextStyle.fontSize! * textScale * 0.7,
                    color: config.themeColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4 * scale),
                Text(
                  localization.t('settings.language.description'),
                  style: config.dialogueTextStyle.copyWith(
                    fontSize: config.dialogueTextStyle.fontSize! * textScale * 0.6,
                    color: config.themeColors.primary.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 16 * scale),
          GameStyleDropdown<SupportedLanguage>(
            items: languages
                .map(
                  (language) => GameStyleDropdownItem<SupportedLanguage>(
                    value: language,
                    label: localization.displayName(language),
                  ),
                )
                .toList(),
            value: selectedLanguage,
            onChanged: _updateLanguage,
            scale: scale,
            textScale: textScale,
            config: config,
            width: 200 * scale,
          ),
        ],
      ),
    );
  }

  Widget _buildFastForwardModeToggle(SakiEngineConfig config, double scale) {
    final textScale = context.scaleFor(ComponentType.text);
    final isForceMode = _fastForwardMode == 'force';
    final localization = LocalizationManager();
    
    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: config.themeColors.surface.withOpacity(0.5),
        border: Border.all(
          color: config.themeColors.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isForceMode ? Icons.fast_forward : Icons.skip_next,
            color: config.themeColors.primary,
            size: 24 * scale,
          ),
          SizedBox(width: 16 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localization.t('settings.fastForward.title'),
                  style: config.reviewTitleTextStyle.copyWith(
                    fontSize: config.reviewTitleTextStyle.fontSize! * textScale * 0.7,
                    color: config.themeColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4 * scale),
                Text(
                  isForceMode
                      ? localization.t('settings.fastForward.descriptionForce')
                      : localization.t('settings.fastForward.descriptionRead'),
                  style: config.dialogueTextStyle.copyWith(
                    fontSize: config.dialogueTextStyle.fontSize! * textScale * 0.6,
                    color: config.themeColors.primary.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 16 * scale),
          GameStyleSwitch(
            value: isForceMode,
            onChanged: (value) => _updateFastForwardMode(value ? 'force' : 'read_only'),
            scale: scale,
            config: config,
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final config = SakiEngineConfig();
    final scale = context.scaleFor(ComponentType.ui);
    final localization = LocalizationManager();

    return Container(
      padding: EdgeInsets.all(24 * scale),
      decoration: BoxDecoration(
        color: config.themeColors.primary.withOpacity(0.05),
        border: Border(
          top: BorderSide(
            color: config.themeColors.primary.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _SettingsButton(
            text: localization.t('settings.action.reset'),
            icon: Icons.restore,
            onPressed: _resetToDefault,
            scale: scale,
            config: config,
            style: _SettingsButtonStyle.secondary,
          ),
          _SettingsButton(
            text: localization.t('settings.action.apply'),
            icon: Icons.check,
            onPressed: widget.onClose,
            scale: scale,
            config: config,
            style: _SettingsButtonStyle.primary,
          ),
        ],
      ),
    );
  }
}

enum _SettingsButtonStyle { primary, secondary }

class _SettingsButton extends StatefulWidget {
  final String text;
  final IconData icon;
  final VoidCallback onPressed;
  final double scale;
  final SakiEngineConfig config;
  final _SettingsButtonStyle style;

  const _SettingsButton({
    required this.text,
    required this.icon,
    required this.onPressed,
    required this.scale,
    required this.config,
    required this.style,
  });

  @override
  State<_SettingsButton> createState() => _SettingsButtonState();
}

class _SettingsButtonState extends State<_SettingsButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isPrimary = widget.style == _SettingsButtonStyle.primary;
    final textScale = context.scaleFor(ComponentType.text);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onPressed,
        onHover: (hovering) => setState(() => _isHovered = hovering),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: 24 * widget.scale,
            vertical: 12 * widget.scale,
          ),
          decoration: BoxDecoration(
            color: _isHovered 
              ? (isPrimary 
                  ? widget.config.themeColors.primary.withOpacity(0.9)
                  : widget.config.themeColors.primary.withOpacity(0.15))
              : (isPrimary 
                  ? widget.config.themeColors.primary.withOpacity(0.8)
                  : widget.config.themeColors.primary.withOpacity(0.1)),
            border: Border.all(
              color: widget.config.themeColors.primary.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                color: isPrimary 
                  ? Colors.white
                  : widget.config.themeColors.primary,
                size: 18 * widget.scale,
              ),
              SizedBox(width: 8 * widget.scale),
              Text(
                widget.text,
                style: widget.config.reviewTitleTextStyle.copyWith(
                  fontSize: widget.config.reviewTitleTextStyle.fontSize! * textScale * 0.5,
                  color: isPrimary 
                    ? Colors.white
                    : widget.config.themeColors.primary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTab extends StatefulWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final SakiEngineConfig config;
  final double scale;

  const _SettingsTab({
    required this.title,
    required this.isSelected,
    required this.onTap,
    required this.config,
    required this.scale,
  });

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _animationController;
  late Animation<double> _glowAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _colorAnimation = ColorTween(
      begin: widget.config.themeColors.primary.withOpacity(0.1),
      end: widget.config.themeColors.primary.withOpacity(0.3),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    if (widget.isSelected) {
      _animationController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_SettingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSelected != widget.isSelected) {
      if (widget.isSelected) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textScale = context.scaleFor(ComponentType.text);
    
    return Expanded(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Container(
                margin: EdgeInsets.symmetric(horizontal: 4 * widget.scale),
                padding: EdgeInsets.symmetric(
                  horizontal: 16 * widget.scale,
                  vertical: 12 * widget.scale,
                ),
                decoration: BoxDecoration(
                  color: widget.isSelected 
                    ? widget.config.themeColors.primary.withOpacity(0.15)
                    : (_isHovered 
                        ? widget.config.themeColors.primary.withOpacity(0.08) 
                        : Colors.transparent),
                  border: Border.all(
                    color: widget.isSelected
                      ? widget.config.themeColors.primary.withOpacity(0.6)
                      : (_isHovered 
                          ? widget.config.themeColors.primary.withOpacity(0.3)
                          : Colors.transparent),
                    width: widget.isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(widget.config.baseWindowBorder > 0 
                      ? widget.config.baseWindowBorder * widget.scale 
                      : 0 * widget.scale),
                  boxShadow: widget.isSelected ? [
                    BoxShadow(
                      color: widget.config.themeColors.primary.withOpacity(0.2 * _glowAnimation.value),
                      blurRadius: 8 * widget.scale * _glowAnimation.value,
                      offset: Offset(0, 2 * widget.scale),
                    ),
                  ] : null,
                ),
                child: Center(
                  child: Text(
                    widget.title,
                    style: widget.config.reviewTitleTextStyle.copyWith(
                      fontSize: widget.config.reviewTitleTextStyle.fontSize! * textScale * 0.65,
                      color: widget.isSelected 
                        ? widget.config.themeColors.primary
                        : widget.config.themeColors.primary.withOpacity(0.7),
                      fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
