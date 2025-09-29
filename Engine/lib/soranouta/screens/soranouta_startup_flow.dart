import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sakiengine/src/utils/binary_serializer.dart';
import 'package:sakiengine/src/utils/smart_asset_image.dart';
import 'package:sakiengine/soranouta/screens/soranouta_main_menu_screen.dart';

/// soraの歌启动流程：先展示 Logo，再以纯黑淡出进入主菜单
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

enum _SplashPhase { logo, fadeOut, done }

class _SoraNoutaStartupFlowState extends State<SoraNoutaStartupFlow>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  late _SplashPhase _phase;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: widget.fadeOutDuration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _phase = _SplashPhase.done);
        }
      });

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    if (widget.skipIntro) {
      _phase = _SplashPhase.done;
      _fadeController.value = 1.0;
    } else {
      _phase = _SplashPhase.logo;
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
    if (_phase == _SplashPhase.logo && mounted) {
      setState(() => _phase = _SplashPhase.fadeOut);
      _fadeController.forward(from: 0.0);
    }
  }

  bool get _overlayVisible => _phase != _SplashPhase.done;

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
              child: AnimatedBuilder(
                animation: _fadeController,
                builder: (context, child) {
                  final opacity = switch (_phase) {
                    _SplashPhase.logo => 1.0,
                    _SplashPhase.fadeOut => 1.0,
                    _SplashPhase.done => 0.0,
                  };
                  final logoVisible = _phase == _SplashPhase.logo;
                  return _SplashOverlay(
                    assetName: widget.logoAsset,
                    showLogo: logoVisible,
                    overlayOpacity: opacity,
                    fadeOpacity: _fadeAnimation.value,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _SplashOverlay extends StatelessWidget {
  const _SplashOverlay({
    required this.assetName,
    required this.showLogo,
    required this.overlayOpacity,
    required this.fadeOpacity,
  });

  final String assetName;
  final bool showLogo;
  final double overlayOpacity; // LOGO 阶段全不透明
  final double fadeOpacity; // 淡出阶段黑幕透明度

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withOpacity(
        showLogo ? overlayOpacity : fadeOpacity,
      ),
      child: Center(
        child: showLogo
            ? FractionallySizedBox(
                widthFactor: 0.8,
                heightFactor: 0.8,
                child: SmartAssetImage(
                  assetName: assetName,
                  fit: BoxFit.contain,
                ),
              )
            : null,
      ),
    );
  }
}
