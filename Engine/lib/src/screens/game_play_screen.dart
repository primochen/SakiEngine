import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sakiengine/src/config/asset_manager.dart';
import 'package:sakiengine/src/config/config_models.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart'; // 添加这个导入
import 'package:sakiengine/src/game/game_manager.dart';
import 'package:sakiengine/src/skr_parser/skr_ast.dart';
import 'package:sakiengine/src/widgets/choice_menu.dart';
import 'package:sakiengine/src/widgets/dialogue_box.dart';
import 'package:sakiengine/src/widgets/global_hot_reload_button.dart';
import 'package:sakiengine/src/widgets/quick_menu.dart';
import 'package:sakiengine/src/screens/review_screen.dart';
import 'package:sakiengine/src/screens/main_menu_screen.dart';
import 'package:sakiengine/src/widgets/confirm_dialog.dart'; // 添加导入

class GamePlayScreen extends StatefulWidget {
  const GamePlayScreen({super.key});

  @override
  State<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends State<GamePlayScreen> {
  late final GameManager _gameManager;
  final String _currentScript = 'start';
  bool _showReviewOverlay = false;

  // QuickMenu 的返回按钮处理
  void _handleQuickMenuBack() {
    // 显示确认对话框
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ConfirmDialog(
          title: '确认返回',
          content: '是否要返回主菜单？',
          onConfirm: () {
            // 销毁当前页面并跳转到主菜单
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => MainMenuScreen(
                  onNewGame: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => GamePlayScreen()),
                  ),
                  onLoadGame: () {
                    // TODO: 实现读取进度功能
                  },
                ),
              ),
              (Route<dynamic> route) => false, // 移除所有之前的路由
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _gameManager = GameManager(
      onReturn: () {
        if (mounted) {
          // 销毁当前页面并返回主菜单
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => MainMenuScreen(
                onNewGame: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => GamePlayScreen()),
                ),
                onLoadGame: () {
                  // TODO: 实现读取进度功能
                },
              ),
            ),
            (Route<dynamic> route) => false, // 移除所有之前的路由
          );
        }
      },
    );
    _gameManager.startGame('start');
  }

  @override
  void dispose() {
    _gameManager.dispose();
    super.dispose();
  }

  Future<void> _handleHotReload() async {
    await _gameManager.hotReload(_currentScript);
  }

  void _showReviewScreen() {
    setState(() {
      _showReviewOverlay = true;
    });
  }

  void _hideReviewScreen() {
    setState(() {
      _showReviewOverlay = false;
    });
  }

  Future<void> _jumpToHistoryEntry(DialogueHistoryEntry entry) async {
    // 首先关闭回顾界面
    _hideReviewScreen();
    
    // 然后跳转到指定位置
    await _gameManager.jumpToHistoryEntry(entry, _currentScript);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<GameState>(
        stream: _gameManager.gameStateStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final gameState = snapshot.data!;
          return Stack(
            children: [
              GestureDetector(
                onTap: gameState.currentNode is MenuNode ? null : () => _gameManager.next(),
                child: Stack(
                  children: [
                    // Background
                    if (gameState.background != null)
                      FutureBuilder<String?>(
                        future: AssetManager().findAsset('backgrounds/${gameState.background!.replaceAll(' ', '-')}')
    ,
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data != null) {
                            return Image.asset(
                              snapshot.data!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            );
                          }
                          return Container(color: Colors.black);
                        }
                      ),

                    // Characters
                    ..._buildCharacters(context, gameState.characters, gameState.poseConfigs),

                    // Dialogue
                    if (gameState.dialogue != null)
                      DialogueBox(
                        speaker: gameState.speaker,
                        dialogue: gameState.dialogue!,
                      ),

                    // Menu
                    if (gameState.currentNode is MenuNode)
                      ChoiceMenu(
                        menuNode: gameState.currentNode as MenuNode,
                        onChoiceSelected: (String targetLabel) {
                          _gameManager.jumpToLabel(targetLabel);
                        },
                      ),
                  ],
                ),
              ),
              
              // Global Hot Reload Button
              GlobalHotReloadButton(onReload: _handleHotReload),

              // Quick Menu
              QuickMenu(
                onReview: () => _showReviewScreen(),
                onBack: _handleQuickMenuBack, // 使用新的返回处理方法
              ),

              // Review Overlay
              if (_showReviewOverlay)
                ReviewOverlay(
                  dialogueHistory: _gameManager.getDialogueHistory(),
                  onClose: _hideReviewScreen,
                  onJumpToEntry: _jumpToHistoryEntry,
                ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildCharacters(BuildContext context, Map<String, CharacterState> characters, Map<String, PoseConfig> poseConfigs) {
    return characters.entries.map((entry) {
      final characterId = entry.key;
      final characterState = entry.value;
      // Use the character's positionId to get pose config, or a default one if not specified.
      final poseConfig = poseConfigs[characterState.positionId] ?? PoseConfig(id: 'default');

      final layers = <Widget>[];

      // Layer 1: Pose Image (default to 'pose1' if not specified)
      final poseImage = characterState.pose ?? 'pose1';
      final poseAssetName = 'characters/${characterState.resourceId}-$poseImage';
      layers.add(_CharacterLayer(key: ValueKey('$characterId-pose'), assetName: poseAssetName));

      // Layer 2: Expression Image (default to 'happy' if not specified)
      final expressionImage = characterState.expression ?? 'happy';
      final expressionAssetName = 'characters/${characterState.resourceId}-$expressionImage';
      layers.add(_CharacterLayer(key: ValueKey('$characterId-expression'), assetName: expressionAssetName));
      
      final characterStack = Stack(children: layers);
      
      Widget finalWidget = characterStack;
      // Apply scaling based on poseConfig
      if (poseConfig.scale > 0) {
        finalWidget = SizedBox(
          height: MediaQuery.of(context).size.height * poseConfig.scale,
          child: characterStack,
        );
      }

      return Positioned(
        left: poseConfig.xcenter * MediaQuery.of(context).size.width,
        top: poseConfig.ycenter * MediaQuery.of(context).size.height,
        child: FractionalTranslation(
          translation: _anchorToTranslation(poseConfig.anchor),
          child: finalWidget,
        ),
      );
    }).toList();
  }

  Offset _anchorToTranslation(String anchor) {
    switch (anchor) {
      case 'topCenter': return const Offset(-0.5, 0);
      case 'bottomCenter': return const Offset(-0.5, -1.0);
      case 'centerLeft': return const Offset(0, -0.5);
      case 'centerRight': return const Offset(-1.0, -0.5);
      case 'center':
      default:
        return const Offset(-0.5, -0.5);
    }
  }
}

class _CharacterLayer extends StatefulWidget {
  final String assetName;
  const _CharacterLayer({super.key, required this.assetName});

  @override
  State<_CharacterLayer> createState() => _CharacterLayerState();
}

class _CharacterLayerState extends State<_CharacterLayer>
    with SingleTickerProviderStateMixin {
  ui.Image? _currentImage;
  ui.Image? _previousImage;

  late final AnimationController _controller;
  late final Animation<double> _animation;

  static ui.FragmentProgram? _dissolveProgram;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);

    _loadImage();
    _loadShader();
  }

  Future<void> _loadShader() async {
    if (_dissolveProgram == null) {
      try {
        final program = await ui.FragmentProgram.fromAsset('assets/shaders/dissolve.frag');
        _dissolveProgram = program;
      } catch (e) {
        print('Error loading shader: $e');
      }
    }
  }

  @override
  void didUpdateWidget(covariant _CharacterLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetName != widget.assetName) {
      _previousImage = _currentImage;
      _loadImage().then((_) {
        if (mounted) {
          _controller.forward(from: 0.0);
        }
      });
    }
  }

  Future<void> _loadImage() async {
    final assetPath = await AssetManager().findAsset(widget.assetName);
    if (assetPath != null && mounted) {
      final data = await rootBundle.load(assetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _currentImage = frame.image;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _currentImage?.dispose();
    _previousImage?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentImage == null || _dissolveProgram == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        // We use a LayoutBuilder to get the final constraints from the parent,
        // which allows us to calculate the correct size for our CustomPaint
        // while maintaining the image's aspect ratio.
        return LayoutBuilder(
          builder: (context, constraints) {
            final imageSize = Size(_currentImage!.width.toDouble(), _currentImage!.height.toDouble());
            
            // Fallback for unbounded height, though it shouldn't happen in our case.
            if (!constraints.hasBoundedHeight) {
              return CustomPaint(
                size: imageSize,
                painter: _DissolvePainter(
                  program: _dissolveProgram!,
                  progress: _animation.value,
                  imageFrom: _previousImage ?? _currentImage!,
                  imageTo: _currentImage!,
                ),
              );
            }

            final imageAspectRatio = imageSize.width / imageSize.height;
            final paintHeight = constraints.maxHeight;
            final paintWidth = paintHeight * imageAspectRatio;
            final paintSize = Size(paintWidth, paintHeight);
            
            return CustomPaint(
              size: paintSize,
              painter: _DissolvePainter(
                program: _dissolveProgram!,
                progress: _animation.value,
                imageFrom: _previousImage ?? _currentImage!,
                imageTo: _currentImage!,
              ),
            );
          },
        );
      },
    );
  }
}

class _DissolvePainter extends CustomPainter {
  final ui.FragmentProgram program;
  final double progress;
  final ui.Image imageFrom;
  final ui.Image imageTo;

  _DissolvePainter({
    required this.program,
    required this.progress,
    required this.imageFrom,
    required this.imageTo,
  });

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    //
    // 调试输出，观察动画进度和纹理变化
    //
    // print("DissolvePainter painting: progress=${progress.toStringAsFixed(2)}, from=${imageFrom.hashCode}, to=${imageTo.hashCode}");
    
    try {
      final shader = program.fragmentShader();
      shader
        ..setFloat(0, progress)
        ..setFloat(1, size.width)
        ..setFloat(2, size.height)
        ..setFloat(3, imageFrom.width.toDouble())
        ..setFloat(4, imageFrom.height.toDouble())
        ..setFloat(5, imageTo.width.toDouble())
        ..setFloat(6, imageTo.height.toDouble())
        ..setImageSampler(0, imageFrom)
        ..setImageSampler(1, imageTo);

      final paint = ui.Paint()
        ..shader = shader
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high;
      canvas.drawRect(ui.Rect.fromLTWH(0, 0, size.width, size.height), paint);
    } catch (e) {
      print("Error painting dissolve shader: $e");
    }
  }

  @override
  bool shouldRepaint(covariant _DissolvePainter oldDelegate) {
    return progress != oldDelegate.progress ||
        imageFrom != oldDelegate.imageFrom ||
        imageTo != oldDelegate.imageTo;
  }
} 