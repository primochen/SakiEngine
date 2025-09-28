import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/screens/save_load_screen.dart';
import 'package:sakiengine/src/utils/scaling_manager.dart';
import 'package:sakiengine/src/utils/binary_serializer.dart';
import 'package:sakiengine/src/utils/music_manager.dart';
import 'package:sakiengine/src/utils/settings_manager.dart';
import 'package:sakiengine/src/widgets/debug_panel_dialog.dart';
import 'package:sakiengine/src/widgets/common/exit_confirmation_dialog.dart';
import 'package:sakiengine/src/widgets/settings_screen.dart';
import 'package:sakiengine/src/widgets/common/game_title_widget.dart';
import 'package:sakiengine/src/widgets/common/game_background_widget.dart';
import 'package:sakiengine/soranouta/widgets/soranouta_menu_buttons.dart';
import 'package:sakiengine/soranouta/widgets/firefly_animation.dart';
import 'dart:math';
import 'dart:ui' as ui;

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
    final isDarkMode = SettingsManager().currentDarkMode;

    return AnimatedBuilder(
      animation: SettingsManager(), // 监听设置变化
      builder: (context, child) {
        // 当设置变化时，重新更新主题配置
        config.updateThemeForDarkMode();
        
        return Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              // 模块化背景组件 - soranouta 直接控制背景
              GameBackgroundWidget.withCustomBackground(
                config: config,
                backgroundName: 'main', // soranouta 直接传递 'main'
              ),
              
              // 萤火虫动画层 - 在背景之上，其他UI之下
              const Positioned.fill(
                child: FireflyAnimation(
                  fireflyCount: 8, // 减少数量：苍蝇变萤火虫
                  maxRadius: 3.5, // 增大最大尺寸
                  minRadius: 1.0, // 减小最小尺寸，增加变化范围
                  maxSpeed: 0.15, // 大幅降低速度
                  minSpeed: 0.08,
                ),
              ),
              
              // 模块化标题组件
              GameTitleWidget(
                config: config,
                textScale: textScale,
              ),
              
              // 按钮区域的白色模糊阴影层 - 独立层
              SoranoutaMenuButtons.createShadowWidget(
                config: config,
                scale: menuScale,
                screenSize: screenSize,
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
              
              // 版权信息阴影层
              Positioned(
                right: 20,
                bottom: 20,
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                  child: Text(
                    _copyrightText,
                    style: TextStyle(
                      fontFamily: 'ChillJinshuSongPro_Soft',
                      fontSize: 40 * textScale,
                      color: isDarkMode ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.9),
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
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
                    color: isDarkMode ? Colors.black : Colors.white,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
              
              // 深色模式切换按钮阴影层
              Positioned(
                left: 20,
                bottom: 20,
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                  child: Icon(
                    isDarkMode ? Icons.dark_mode : Icons.light_mode,
                    size: 48 * textScale,
                    color: isDarkMode ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.9),
                  ),
                ),
              ),
              
              // 深色模式切换按钮
              Positioned(
                left: 20,
                bottom: 20,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () async {
                      final newDarkMode = !isDarkMode;
                      await SettingsManager().setDarkMode(newDarkMode);
                      config.updateThemeForDarkMode();
                      // 触发重建以更新图标
                      if (mounted) {
                        setState(() {});
                      }
                    },
                    child: Icon(
                      isDarkMode ? Icons.dark_mode : Icons.light_mode,
                      size: 48 * textScale,
                      color: isDarkMode ? Colors.black : Colors.white,
                    ),
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
      },
    );
  }
}