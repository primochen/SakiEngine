import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/screens/save_load_screen.dart';
import 'package:sakiengine/src/utils/scaling_manager.dart';
import 'package:sakiengine/src/utils/binary_serializer.dart';
import 'package:sakiengine/src/utils/music_manager.dart';
import 'package:sakiengine/src/widgets/debug_panel_dialog.dart';
import 'package:sakiengine/src/widgets/common/exit_confirmation_dialog.dart';
import 'package:sakiengine/src/widgets/settings_screen.dart';
import 'package:sakiengine/src/widgets/common/game_title_widget.dart';
import 'package:sakiengine/src/widgets/common/game_background_widget.dart';
import 'package:sakiengine/src/widgets/common/debug_button_widget.dart';
import 'package:sakiengine/soranouta/widgets/soranouta_menu_buttons.dart';
import 'dart:math';

/// SoraNoUta 项目的自定义主菜单屏幕
/// 使用模块化标题组件 + 专用按钮
class SoraNoutaMainMenuScreen extends StatefulWidget {
  final VoidCallback onNewGame;
  final VoidCallback onLoadGame;
  final Function(SaveSlot)? onLoadGameWithSave;
  final bool skipMusicDelay;

  const SoraNoutaMainMenuScreen({
    Key? key,
    required this.onNewGame,
    required this.onLoadGame,
    this.onLoadGameWithSave,
    this.skipMusicDelay = false,
  }) : super(key: key);

  @override
  State<SoraNoutaMainMenuScreen> createState() => _SoraNoutaMainMenuScreenState();
}

class _SoraNoutaMainMenuScreenState extends State<SoraNoutaMainMenuScreen> {
  bool _showLoadOverlay = false;
  bool _showDebugPanel = false;
  bool _showSettings = false;
  late String _copyrightText;

  @override
  void initState() {
    super.initState();
    _generateCopyrightText();
    _startBackgroundMusic();
  }
  
  void _generateCopyrightText() {
    final random = Random();
    final randomValue = random.nextDouble();
    
    if (randomValue < 0.1) {
      _copyrightText = 'Ⓒ Copyright 950-2050 Aimes Soft';
    } else {
      _copyrightText = 'Ⓒ Copyright 2023-2025 Aimes Soft';
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _startBackgroundMusic() async {
    try {
      if (!widget.skipMusicDelay) {
        // 延时等待启动遮罩完成 (1.3秒：1秒黑屏 + 0.3秒淡出)
        await Future.delayed(const Duration(milliseconds: 1300));
      }
      await MusicManager().playBackgroundMusic('Assets/music/dream.mp3');
    } catch (e) {
      // Silently handle music loading errors
    }
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
          // 模块化背景组件
          GameBackgroundWidget(config: config),
          
          // 模块化标题组件
          GameTitleWidget(
            config: config,
            textScale: textScale,
          ),
          
          // SoraNoUta 专用按钮
          SoranoutaMenuButtons.createButtonsWidget(
            onNewGame: widget.onNewGame,
            onLoadGame: () => setState(() => _showLoadOverlay = true),
            onSettings: () => setState(() => _showSettings = true),
            onExit: () => _showExitConfirmation(context),
            config: config,
            scale: menuScale,
            screenSize: screenSize,
          ),
          
          // 模块化调试按钮
          DebugButtonWidget(
            onPressed: () => setState(() => _showDebugPanel = true),
            scale: menuScale,
            config: config,
          ),
          
          // 版权信息文本
          Positioned(
            right: 20,
            bottom: 20,
            child: Text(
              _copyrightText,
              style: TextStyle(
                fontFamily: 'ChillJinshuSongPro_Soft',
                fontSize: 40 * textScale,
                color: Colors.black,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
          
          // 覆盖层
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
}