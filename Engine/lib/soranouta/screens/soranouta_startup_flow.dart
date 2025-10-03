import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sakiengine/src/utils/binary_serializer.dart';
import 'package:sakiengine/src/utils/settings_manager.dart';
import 'package:sakiengine/src/utils/smart_asset_image.dart';
import 'package:sakiengine/soranouta/screens/soranouta_main_menu_screen.dart';
import 'package:sakiengine/src/game/story_flowchart_analyzer.dart';
import 'package:flutter/foundation.dart';

/// soraの歌启动流程：先展示 Logo，再以纯黑淡出进入主菜单
class SoraNoutaStartupFlow extends StatefulWidget {
  const SoraNoutaStartupFlow({
    super.key,
    required this.onNewGame,
    required this.onLoadGame,
    required this.onLoadGameWithSave,
    this.onContinueGame, // 新增：继续游戏回调
    required this.skipMusicDelay,
    this.splashDuration = const Duration(seconds: 3),
    this.fadeOutDuration = const Duration(milliseconds: 600),
    this.logoAsset = 'gui/logo',
    this.skipIntro = false,
  });

  final VoidCallback onNewGame;
  final VoidCallback onLoadGame;
  final Function(SaveSlot)? onLoadGameWithSave;
  final VoidCallback? onContinueGame; // 新增：继续游戏回调
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

    // 后台初始化流程图分析器
    Future.microtask(() async {
      try {
        final analyzer = StoryFlowchartAnalyzer();
        await analyzer.analyzeScript();
        if (kDebugMode) {
          print('[SoraNoUta] 剧情流程图初始化完成');
        }
      } catch (e) {
        if (kDebugMode) {
          print('[SoraNoUta] 流程图初始化失败: $e');
        }
      }
    });

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
            onContinueGame: widget.onContinueGame, // 新增：传递继续游戏回调
            skipMusicDelay: widget.skipMusicDelay,
          ),
          if (_overlayVisible)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _fadeController,
                builder: (context, child) {
                  final t = _fadeController.value.clamp(0.0, 1.0);
                  double logoOpacity = 1.0;
                  double overlayOpacity = 1.0;

                  if (_phase == _SplashPhase.fadeOut) {
                    if (t < 0.5) {
                      // 先让 Logo 在黑幕中淡出
                      final progress = t / 0.5;
                      logoOpacity = 1.0 - progress;
                      overlayOpacity = 1.0;
                    } else {
                      // Logo 已消失，开始让黑幕本身淡出
                      logoOpacity = 0.0;
                      final progress = (t - 0.5) / 0.5;
                      overlayOpacity = 1.0 - progress;
                    }
                  }

                  return _SplashOverlay(
                    assetName: widget.logoAsset,
                    logoOpacity: logoOpacity,
                    overlayOpacity: overlayOpacity,
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
    required this.logoOpacity,
    required this.overlayOpacity,
  });

  final String assetName;
  final double logoOpacity;
  final double overlayOpacity;

  @override
  Widget build(BuildContext context) {
    final clampedOverlay = overlayOpacity.clamp(0.0, 1.0);
    final clampedLogo = logoOpacity.clamp(0.0, 1.0);
    final isDarkMode = SettingsManager().currentDarkMode;
    final baseColor = isDarkMode ? Colors.black : Colors.white;

    return ColoredBox(
      color: baseColor.withOpacity(clampedOverlay),
      child: Center(
        child: clampedLogo > 0
            ? Opacity(
                opacity: clampedLogo,
                child: FractionallySizedBox(
                  widthFactor: 0.8,
                  heightFactor: 0.8,
                  child: isDarkMode
                      ? SmartAssetImage(
                          assetName: assetName,
                          fit: BoxFit.contain,
                        )
                      : ColorFiltered(
                          colorFilter: const ColorFilter.matrix(<double>[
                            -1, 0, 0, 0, 255,
                            0, -1, 0, 0, 255,
                            0, 0, -1, 0, 255,
                            0, 0, 0, 1, 0,
                          ]),
                          child: SmartAssetImage(
                            assetName: assetName,
                            fit: BoxFit.contain,
                          ),
                        ),
                ),
              )
            : null,
      ),
    );
  }
}
