import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/asset_manager.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/config/project_info_manager.dart';
import 'package:sakiengine/src/config/config_models.dart';
import 'package:sakiengine/src/screens/save_load_screen.dart';
import 'package:sakiengine/src/utils/scaling_manager.dart';
import 'package:sakiengine/src/utils/binary_serializer.dart';
import 'package:sakiengine/src/widgets/debug_panel_dialog.dart';
import 'package:sakiengine/src/widgets/smart_image.dart';

/// SoraNoUta 项目的自定义主菜单屏幕
/// 特色：使用圆角矩形按钮验证模块化系统
class SoraNoutaMainMenuScreen extends StatefulWidget {
  final VoidCallback onNewGame;
  final VoidCallback onLoadGame;
  final Function(SaveSlot)? onLoadGameWithSave;

  const SoraNoutaMainMenuScreen({
    Key? key,
    required this.onNewGame,
    required this.onLoadGame,
    this.onLoadGameWithSave,
  }) : super(key: key);

  @override
  State<SoraNoutaMainMenuScreen> createState() => _SoraNoutaMainMenuScreenState();
}

class _SoraNoutaMainMenuScreenState extends State<SoraNoutaMainMenuScreen> {
  bool _showLoadOverlay = false;
  bool _showDebugPanel = false;
  String _appTitle = 'SoraNoUta';

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

  @override
  Widget build(BuildContext context) {
    final config = SakiEngineConfig();
    final screenSize = MediaQuery.of(context).size;
    final menuScale = context.scaleFor(ComponentType.menu);
    final textScale = context.scaleFor(ComponentType.text);

    return Scaffold(
      body: GestureDetector(
        onTap: () {
          if (_showDebugPanel) {
            setState(() => _showDebugPanel = false);
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 背景
            FutureBuilder<String?>(
              future: AssetManager().findAsset('backgrounds/${config.mainMenuBackground}'),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return Image.asset(
                    snapshot.data!,
                    fit: BoxFit.cover,
                  );
                }
                return Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.indigo, Colors.purple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                );
              },
            ),
            
            // SoraNoUta 特色：圆角矩形按钮菜单
            Positioned(
              bottom: screenSize.height * 0.15,
              right: screenSize.width * 0.05,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '🎯 SoraNoUta 模块化验证',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14 * textScale,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SoraNoutaRoundedButton(
                    text: '新游戏',
                    onPressed: widget.onNewGame,
                    scale: menuScale,
                    textScale: textScale,
                    color: Colors.indigo,
                  ),
                  const SizedBox(height: 15),
                  _SoraNoutaRoundedButton(
                    text: '读取存档',
                    onPressed: () => setState(() => _showLoadOverlay = true),
                    scale: menuScale,
                    textScale: textScale,
                    color: Colors.purple,
                  ),
                  const SizedBox(height: 15),
                  _SoraNoutaRoundedButton(
                    text: '调试面板',
                    onPressed: () => setState(() => _showDebugPanel = true),
                    scale: menuScale,
                    textScale: textScale,
                    color: Colors.teal,
                  ),
                ],
              ),
            ),
            
            // 版权信息栏
            Positioned(
              bottom: screenSize.height * 0.04,
              right: screenSize.width * 0.01,
              child: Container(
                width: screenSize.width * 0.4,
                height: screenSize.height * 0.02,
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(10),
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
              
            if (_showDebugPanel)
              DebugPanelDialog(
                onClose: () => setState(() => _showDebugPanel = false),
              ),
          ],
        ),
      ),
    );
  }
}

/// SoraNoUta 特色圆角矩形按钮
class _SoraNoutaRoundedButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final double scale;
  final double textScale;
  final Color color;

  const _SoraNoutaRoundedButton({
    required this.text,
    required this.onPressed,
    required this.scale,
    required this.textScale,
    required this.color,
  });

  @override
  State<_SoraNoutaRoundedButton> createState() => _SoraNoutaRoundedButtonState();
}

class _SoraNoutaRoundedButtonState extends State<_SoraNoutaRoundedButton>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _animationController.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _animationController.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: GestureDetector(
              onTap: widget.onPressed,
              child: Container(
                width: 200 * widget.scale,
                height: 60 * widget.scale,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30), // 圆角矩形！
                  gradient: LinearGradient(
                    colors: _isHovered 
                      ? [widget.color.withValues(alpha: 0.8), widget.color]
                      : [widget.color.withValues(alpha: 0.9), widget.color],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.5),
                      blurRadius: _isHovered ? 15 : 10,
                      offset: Offset(0, _isHovered ? 6 : 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    widget.text,
                    style: TextStyle(
                      fontFamily: 'SourceHanSansCN',
                      fontSize: 24 * widget.textScale,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      shadows: [
                        Shadow(
                          blurRadius: 3,
                          color: Colors.black.withValues(alpha: 0.5),
                          offset: const Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}