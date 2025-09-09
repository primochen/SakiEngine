import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/config/project_info_manager.dart';
import 'package:sakiengine/src/screens/save_load_screen.dart';
import 'package:sakiengine/src/utils/scaling_manager.dart';
import 'package:sakiengine/src/utils/binary_serializer.dart';
import 'package:sakiengine/src/widgets/debug_panel_dialog.dart';
import 'package:sakiengine/src/widgets/common/black_screen_transition.dart';
import 'package:sakiengine/src/widgets/common/exit_confirmation_dialog.dart';
import 'package:sakiengine/src/widgets/settings_screen.dart';
import 'package:sakiengine/src/widgets/common/configurable_menu_button.dart';
import 'package:sakiengine/src/widgets/common/default_menu_buttons.dart';
import 'package:sakiengine/src/utils/smart_asset_image.dart';
import 'package:sakiengine/soranouta/widgets/soranouta_menu_buttons.dart';

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
    await ExitConfirmationDialog.showExitConfirmationAndDestroy(context);
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
          SmartAssetImage(
            assetName: 'backgrounds/${config.mainMenuBackground}',
            fit: BoxFit.cover,
          ),
          
          Positioned(
            top: config.hasBottom ? null : screenSize.height * config.mainMenuTitleTop,
            bottom: config.hasBottom ? screenSize.height * config.mainMenuTitleBottom : null,
            left: config.hasLeft ? screenSize.width * config.mainMenuTitleLeft : null,
            right: config.hasLeft ? null : screenSize.width * config.mainMenuTitleRight,
            child: config.mainMenuTitle.isNotEmpty
                ? SmartAssetImage(
                    assetName: config.mainMenuTitle,
                    height: config.mainMenuTitleSize * textScale,
                    errorWidget: Text(
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
                  )
                : Text(
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
          
          if (_showBottomBar())
            Positioned(
              bottom: screenSize.height * 0.04,
              right: screenSize.width * 0.01,
              child: Container(
                width: screenSize.width * 0.4,
                height: screenSize.height * 0.02,
                color: config.themeColors.primary,
              ),
            ),
          
          
          _buildMenuButtons(context, menuScale, config),

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

  bool _showBottomBar() {
    return _appTitle != 'SoraNoUta'; // SoraNoUta项目不显示底条
  }

  Widget _buildMenuButtons(
    BuildContext context,
    double scale,
    SakiEngineConfig config,
  ) {
    List<MenuButtonConfig> buttonConfigs;
    MenuButtonsLayoutConfig layoutConfig;
    
    // 根据项目选择按钮配置
    if (_appTitle == 'SoraNoUta') {
      buttonConfigs = SoranoutaMenuButtons.createConfigs(
        onNewGame: _handleNewGame,
        onLoadGame: () => setState(() => _showLoadOverlay = true),
        onSettings: () => setState(() => _showSettings = true),
        onExit: () => _showExitConfirmation(context),
        config: config,
        scale: scale,
      );
      layoutConfig = SoranoutaMenuButtons.getLayoutConfig();
    } else {
      buttonConfigs = DefaultMenuButtons.createDefaultConfigs(
        onNewGame: _handleNewGame,
        onLoadGame: () => setState(() => _showLoadOverlay = true),
        onSettings: () => setState(() => _showSettings = true),
        onExit: () => _showExitConfirmation(context),
        config: config,
        scale: scale,
      );
      layoutConfig = const MenuButtonsLayoutConfig(
        isVertical: false,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.end,
        spacing: 20,
        bottom: 0.05,
        right: 0.01,
      );
    }
    final screenSize = MediaQuery.of(context).size;

    Widget buttonsWidget;
    
    if (layoutConfig.isVertical) {
      buttonsWidget = Column(
        crossAxisAlignment: layoutConfig.crossAxisAlignment,
        mainAxisAlignment: layoutConfig.mainAxisAlignment,
        mainAxisSize: MainAxisSize.min,
        children: buttonConfigs.map((buttonConfig) {
          final index = buttonConfigs.indexOf(buttonConfig);
          return Column(
            children: [
              if (index > 0) SizedBox(height: layoutConfig.spacing),
              ConfigurableMenuButton(
                config: buttonConfig,
                scale: scale,
              ),
            ],
          );
        }).toList(),
      );
    } else {
      buttonsWidget = Row(
        mainAxisAlignment: layoutConfig.mainAxisAlignment,
        crossAxisAlignment: layoutConfig.crossAxisAlignment,
        mainAxisSize: MainAxisSize.min,
        children: buttonConfigs.map((buttonConfig) {
          final index = buttonConfigs.indexOf(buttonConfig);
          return Row(
            children: [
              if (index > 0) SizedBox(width: layoutConfig.spacing),
              ConfigurableMenuButton(
                config: buttonConfig,
                scale: scale,
              ),
            ],
          );
        }).toList(),
      );
    }

    return Positioned(
      top: layoutConfig.top != null ? screenSize.height * layoutConfig.top! : null,
      bottom: layoutConfig.bottom != null ? screenSize.height * layoutConfig.bottom! : null,
      left: layoutConfig.left != null ? screenSize.width * layoutConfig.left! : null,
      right: layoutConfig.right != null ? screenSize.width * layoutConfig.right! : null,
      child: buttonsWidget,
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

}
