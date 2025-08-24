import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/utils/scaling_manager.dart';
import 'package:sakiengine/src/utils/settings_manager.dart';
import 'package:sakiengine/src/widgets/confirm_dialog.dart';
import 'package:sakiengine/src/widgets/common/overlay_scaffold.dart';
import 'package:sakiengine/src/widgets/game_style_switch.dart';
import 'package:sakiengine/src/widgets/game_style_slider.dart';

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
  
  double _dialogOpacity = SettingsManager.defaultDialogOpacity;
  bool _isFullscreen = SettingsManager.defaultIsFullscreen;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    
    try {
      // 使用新的getter方法获取当前值
      _dialogOpacity = SettingsManager().currentDialogOpacity;
      _isFullscreen = SettingsManager().currentIsFullscreen;
      
      // 确保SettingsManager已初始化
      await SettingsManager().init();
      
      // 再次获取以确保是最新值
      _dialogOpacity = await SettingsManager().getDialogOpacity();
      _isFullscreen = await SettingsManager().getIsFullscreen();
      
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

  Future<void> _resetToDefault() async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return const ConfirmDialog(
          title: '恢复默认设置',
          content: '确定要恢复所有设置到默认值吗？此操作无法撤销。',
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
    return OverlayScaffold(
      title: '游戏设置',
      content: _isLoading ? _buildLoadingContent() : _buildSettingsContent(),
      footer: _isLoading ? null : _buildFooter(),
      onClose: widget.onClose,
    );
  }

  Widget _buildLoadingContent() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildSettingsContent() {
    final config = SakiEngineConfig();
    final scale = context.scaleFor(ComponentType.ui);

    return Padding(
      padding: EdgeInsets.all(32 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOpacitySlider(config, scale),
          SizedBox(height: 40 * scale),
          _buildFullscreenToggle(config, scale),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildOpacitySlider(SakiEngineConfig config, double scale) {
    final textScale = context.scaleFor(ComponentType.text);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '对话框不透明度',
              style: config.reviewTitleTextStyle.copyWith(
                fontSize: config.reviewTitleTextStyle.fontSize! * textScale * 0.7,
                color: config.themeColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${(_dialogOpacity * 100).round()}%',
              style: config.reviewTitleTextStyle.copyWith(
                fontSize: config.reviewTitleTextStyle.fontSize! * textScale * 0.6,
                color: config.themeColors.primary.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SizedBox(height: 16 * scale),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 16 * scale),
          decoration: BoxDecoration(
            color: config.themeColors.surface.withOpacity(0.5),
            border: Border.all(
              color: config.themeColors.primary.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Center(
            child: GameStyleSlider(
              value: _dialogOpacity,
              min: 0.3,
              max: 1.0,
              divisions: 7,
              scale: scale,
              config: config,
              onChanged: _updateDialogOpacity,
            ),
          ),
        ),
        SizedBox(height: 8 * scale),
        Text(
          '调整对话框的透明度，较低的值会使对话框更加透明',
          style: config.dialogueTextStyle.copyWith(
            fontSize: config.dialogueTextStyle.fontSize! * textScale * 0.6,
            color: config.themeColors.primary.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildFullscreenToggle(SakiEngineConfig config, double scale) {
    final textScale = context.scaleFor(ComponentType.text);
    
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
                  '全屏模式',
                  style: config.reviewTitleTextStyle.copyWith(
                    fontSize: config.reviewTitleTextStyle.fontSize! * textScale * 0.7,
                    color: config.themeColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4 * scale),
                Text(
                  '切换全屏或窗口模式显示游戏',
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
            trueText: '全屏',
            falseText: '窗口',
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final config = SakiEngineConfig();
    final scale = context.scaleFor(ComponentType.ui);

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
            text: '恢复默认',
            icon: Icons.restore,
            onPressed: _resetToDefault,
            scale: scale,
            config: config,
            style: _SettingsButtonStyle.secondary,
          ),
          _SettingsButton(
            text: '确定',
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