import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:sakiengine/src/config/asset_manager.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/config/project_info_manager.dart';
import 'package:sakiengine/src/screens/save_load_screen.dart';
import 'package:sakiengine/src/utils/scaling_manager.dart';
import 'package:sakiengine/src/utils/binary_serializer.dart';
import 'package:sakiengine/src/widgets/debug_panel_dialog.dart';
import 'package:sakiengine/src/widgets/common/black_screen_transition.dart';
import 'package:sakiengine/src/widgets/confirm_dialog.dart';
import 'package:sakiengine/src/widgets/settings_screen.dart';

class _HoverButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final double scale;
  final SakiEngineConfig config;

  const _HoverButton({
    required this.text,
    required this.onPressed,
    required this.scale,
    required this.config,
  });

  @override
  State<_HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<_HoverButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onPressed,
        onHover: (hovering) => setState(() => _isHovered = hovering),
        child: Container(
          width: 200 * widget.scale,
          padding: EdgeInsets.symmetric(
            horizontal: 24 * widget.scale,
            vertical: 16 * widget.scale,
          ),
          decoration: BoxDecoration(
            color: _isHovered 
              ? HSLColor.fromColor(widget.config.themeColors.background)
                  .withLightness((HSLColor.fromColor(widget.config.themeColors.background).lightness - 0.1).clamp(0.0, 1.0))
                  .toColor().withOpacity(0.9)
              : widget.config.themeColors.background.withOpacity(0.9),
            border: Border.all(
              color: widget.config.themeColors.primary.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Text(
            widget.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'SourceHanSansCN',
              fontSize: 28 * widget.scale,
              color: widget.config.themeColors.primary,
              letterSpacing: 2,
              fontWeight: _isHovered ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class MainMenuScreen extends StatefulWidget {
  final VoidCallback onNewGame;
  final VoidCallback onLoadGame;
  final Function(SaveSlot)? onLoadGameWithSave;

  const MainMenuScreen({
    super.key,
    required this.onNewGame,
    required this.onLoadGame,
    this.onLoadGameWithSave,
  });

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  bool _showLoadOverlay = false;
  bool _showDebugPanel = false;
  bool _showSettings = false;
  String _appTitle = 'SakiEngine';

  @override
  void initState() {
    super.initState();
    _loadAppTitle();
  }

  Future<void> _loadAppTitle() async {
    try {
      final appName = await ProjectInfoManager().getAppName();
      if (mounted) {
        setState(() {
          _appTitle = appName;
        });
      }
    } catch (e) {
      // 保持默认标题
    }
  }

  void _handleNewGame() {
    widget.onNewGame();
  }

  Future<void> _showExitConfirmation(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return ConfirmDialog(
          title: '退出游戏',
          content: '确定要退出游戏吗？',
          onConfirm: () async {
            Navigator.of(context).pop(); // 关闭对话框
            await windowManager.destroy(); // 真正退出程序
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = SakiEngineConfig();
    final screenSize = MediaQuery.of(context).size;
    final menuScale = context.scaleFor(ComponentType.menu);
    final textScale = context.scaleFor(ComponentType.text);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<String?>(
            future: AssetManager().findAsset('backgrounds/${config.mainMenuBackground}'),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                return Image.asset(
                  snapshot.data!,
                  fit: BoxFit.cover,
                );
              }
              return Container(color: Colors.black);
            },
          ),
          
          Positioned(
            top: screenSize.height * config.mainMenuTitleTop,
            right: screenSize.width * config.mainMenuTitleRight,
            child: Text(
              _appTitle,
              style: TextStyle(
                fontFamily: 'SourceHanSansCN',
                fontSize: config.mainMenuTitleSize * textScale,
                color: config.themeColors.background,
                letterSpacing: 4,
                shadows: [
                  Shadow(
                    blurRadius: 10.0,
                    color: config.themeColors.primaryDark,
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
            ),
          ),
          
          Positioned(
            bottom: screenSize.height * 0.04,
            right: screenSize.width * 0.01,
            child: Container(
              width: screenSize.width * 0.4,
              height: screenSize.height * 0.02,
              color: config.themeColors.primary,
            ),
          ),
          
          Positioned(
            bottom: screenSize.height * 0.05,
            left: screenSize.width * 0.02,
            child: _buildDebugButton(context, menuScale, config),
          ),
          
          Positioned(
            bottom: screenSize.height * 0.05,
            right: screenSize.width * 0.01,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildMenuButton(
                  context, 
                  '新游戏', 
                  _handleNewGame,
                  menuScale,
                  config,
                ),
                SizedBox(width: 20 * menuScale),
                _buildMenuButton(
                  context, 
                  '继续游戏', 
                  () => setState(() => _showLoadOverlay = true), 
                  menuScale,
                  config,
                ),
                SizedBox(width: 20 * menuScale),
                _buildMenuButton(
                  context, 
                  '设置', 
                  () => setState(() => _showSettings = true), 
                  menuScale,
                  config,
                ),
                SizedBox(width: 20 * menuScale),
                _buildMenuButton(
                  context, 
                  '退出游戏', 
                  () => _showExitConfirmation(context), 
                  menuScale,
                  config,
                ),
              ],
            ),
          ),

          if (_showLoadOverlay)
            SaveLoadScreen(
              mode: SaveLoadMode.load,
              onClose: () => setState(() => _showLoadOverlay = false),
              onLoadSlot: widget.onLoadGameWithSave,
            ),

          if (_showSettings)
            SettingsScreen(
              onClose: () => setState(() => _showSettings = false),
            ),

          if (_showDebugPanel)
            DebugPanelDialog(
              onClose: () => setState(() => _showDebugPanel = false),
            ),
        ],
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context, 
    String text, 
    VoidCallback onPressed, 
    double scale,
    SakiEngineConfig config,
  ) {
    return _HoverButton(
      text: text,
      onPressed: onPressed,
      scale: scale,
      config: config,
    );
  }

  Widget _buildDebugButton(
    BuildContext context,
    double scale,
    SakiEngineConfig config,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _showDebugPanel = true);
        },
        onHover: (hovering) => setState(() {}),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 16 * scale,
            vertical: 12 * scale,
          ),
          decoration: BoxDecoration(
            color: config.themeColors.background.withOpacity(0.85),
            border: Border.all(
              color: config.themeColors.primary.withOpacity(0.6),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.settings_applications,
                color: config.themeColors.primary,
                size: 18 * scale,
              ),
              SizedBox(width: 8 * scale),
              Text(
                '调试界面',
                style: TextStyle(
                  fontFamily: 'SourceHanSansCN',
                  fontSize: 14 * scale,
                  color: config.themeColors.primary,
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
