import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/asset_manager.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/screens/game_play_screen.dart';
import 'package:sakiengine/src/widgets/debug_log_panel.dart';

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
                  .toColor().withValues(alpha: 0.9)
              : widget.config.themeColors.background.withValues(alpha: 0.9),
            border: Border.all(
              color: widget.config.themeColors.primary.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Text(
            widget.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'SourceHanSansCN-Bold',
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

  const MainMenuScreen({
    super.key,
    required this.onNewGame,
    required this.onLoadGame,
  });

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  @override
  Widget build(BuildContext context) {
    final config = SakiEngineConfig();
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final scaleX = screenSize.width / config.logicalWidth;
    final scaleY = screenSize.height / config.logicalHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 背景图片
          FutureBuilder<String?>(
            future: AssetManager().findAsset('backgrounds/${config.mainMenuBackground}'),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                return Image.asset(
                  snapshot.data!,
                  fit: BoxFit.cover,
                );
              }
              return Container(color: Colors.black); // 加载失败时的默认背景
            },
          ),
          
          // 标题 - 右上角
          Positioned(
            top: screenSize.height * config.mainMenuTitleTop,
            right: screenSize.width * config.mainMenuTitleRight,
            child: Text(
              'SakiEngine',
              style: TextStyle(
                fontFamily: 'SourceHanSansCN-Bold',
                fontSize: config.mainMenuTitleSize * scale,
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
          
          // 深色矩形条块
          Positioned(
            bottom: screenSize.height * 0.04,
            right: screenSize.width * 0.01,
            child: Container(
              width: screenSize.width * 0.4,
              height: screenSize.height * 0.02,
              color: config.themeColors.primary,
            ),
          ),
          
          // 调试按钮 - 左下角
          Positioned(
            bottom: screenSize.height * 0.05,
            left: screenSize.width * 0.02,
            child: _buildDebugButton(context, scale, config),
          ),
          
          // 按钮 - 右下角
          Positioned(
            bottom: screenSize.height * 0.05,
            right: screenSize.width * 0.01,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildMenuButton(
                  context, 
                  '新游戏', 
                  () {
                    // 实际启动新游戏的逻辑
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => GamePlayScreen(),
                      ),
                      (Route<dynamic> route) => false,
                    );
                  }, 
                  scale,
                  config,
                ),
                SizedBox(width: 20 * scale),
                _buildMenuButton(
                  context, 
                  '继续游戏', 
                  widget.onLoadGame, 
                  scale,
                  config,
                ),
                SizedBox(width: 20 * scale),
                _buildMenuButton(
                  context, 
                  '退出游戏', 
                  () => exit(0), 
                  scale,
                  config,
                ),
              ],
            ),
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
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const DebugLogPanel(),
          );
        },
        child: Container(
          padding: EdgeInsets.all(12 * scale),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.orange.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bug_report,
                color: Colors.orange,
                size: 20 * scale,
              ),
              SizedBox(width: 8 * scale),
              Text(
                'DEBUG',
                style: TextStyle(
                  fontSize: 14 * scale,
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
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