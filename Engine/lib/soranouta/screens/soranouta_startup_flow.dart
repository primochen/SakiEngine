import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sakiengine/src/utils/binary_serializer.dart';
import 'package:sakiengine/src/utils/smart_asset_image.dart';
import 'package:sakiengine/soranouta/screens/soranouta_main_menu_screen.dart';

/// soraの歌启动流程：先播放Logo再进入主菜单
class SoraNoutaStartupFlow extends StatefulWidget {
  const SoraNoutaStartupFlow({
    super.key,
    required this.onNewGame,
    required this.onLoadGame,
    required this.onLoadGameWithSave,
    required this.skipMusicDelay,
    this.splashDuration = const Duration(seconds: 3),
    this.fadeOutDuration = const Duration(milliseconds: 600),
    this.logoAsset = 'gui/logo',
    this.skipIntro = false,
  });

  final VoidCallback onNewGame;
  final VoidCallback onLoadGame;
  final Function(SaveSlot)? onLoadGameWithSave;
  final bool skipMusicDelay;
  final Duration splashDuration;
  final Duration fadeOutDuration;
  final String logoAsset;
  final bool skipIntro;

  @override
  State<SoraNoutaStartupFlow> createState() => _SoraNoutaStartupFlowState();
}

class _SoraNoutaStartupFlowState extends State<SoraNoutaStartupFlow>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: widget.fadeOutDuration,
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    if (widget.skipIntro) {
      _fadeController.value = 1.0; // 直接跳过闪屏
    } else {
      _timer = Timer(widget.splashDuration, _startFadeOut);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  void _startFadeOut() {
    if (!_fadeController.isAnimating && mounted) {
      _fadeController.forward();
    }
  }

  bool get _overlayVisible => _fadeController.value < 1.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SoraNoutaMainMenuScreen(
            onNewGame: widget.onNewGame,
            onLoadGame: widget.onLoadGame,
            onLoadGameWithSave: widget.onLoadGameWithSave,
            skipMusicDelay: widget.skipMusicDelay,
          ),
          if (_overlayVisible)
            IgnorePointer(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _SplashOverlay(assetName: widget.logoAsset),
              ),
            ),
        ],
      ),
    );
  }
}

class _SplashOverlay extends StatelessWidget {
  const _SplashOverlay({required this.assetName});

  final String assetName;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.8,
          heightFactor: 0.8,
          child: SmartAssetImage(
            assetName: assetName,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
