import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/config/project_info_manager.dart';
import 'package:sakiengine/src/utils/smart_asset_image.dart';

class GameTitleWidget extends StatefulWidget {
  final SakiEngineConfig config;
  final double textScale;

  const GameTitleWidget({
    super.key,
    required this.config,
    required this.textScale,
  });

  @override
  State<GameTitleWidget> createState() => _GameTitleWidgetState();
}

class _GameTitleWidgetState extends State<GameTitleWidget> {
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

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    return Positioned(
      top: widget.config.hasBottom ? null : screenSize.height * widget.config.mainMenuTitleTop,
      bottom: widget.config.hasBottom ? screenSize.height * widget.config.mainMenuTitleBottom : null,
      left: widget.config.hasLeft ? screenSize.width * widget.config.mainMenuTitleLeft : null,
      right: widget.config.hasLeft ? null : screenSize.width * widget.config.mainMenuTitleRight,
      child: widget.config.mainMenuTitle.isNotEmpty
          ? SmartAssetImage(
              assetName: widget.config.mainMenuTitle,
              height: widget.config.mainMenuTitleSize * widget.textScale,
              errorWidget: Text(
                _appTitle,
                style: TextStyle(
                  fontFamily: 'SourceHanSansCN',
                  fontSize: widget.config.mainMenuTitleSize * widget.textScale,
                  color: widget.config.themeColors.background,
                  letterSpacing: 4,
                  shadows: [
                    Shadow(
                      blurRadius: 10.0,
                      color: widget.config.themeColors.primaryDark,
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
                fontSize: widget.config.mainMenuTitleSize * widget.textScale,
                color: widget.config.themeColors.background,
                letterSpacing: 4,
                shadows: [
                  Shadow(
                    blurRadius: 10.0,
                    color: widget.config.themeColors.primaryDark,
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
            ),
    );
  }
}