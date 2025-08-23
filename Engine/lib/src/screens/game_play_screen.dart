import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:sakiengine/src/config/asset_manager.dart';
import 'package:sakiengine/src/config/config_models.dart';
import 'package:sakiengine/src/game/game_manager.dart';
import 'package:sakiengine/src/utils/binary_serializer.dart';
import 'package:sakiengine/src/screens/save_load_screen.dart';
import 'package:sakiengine/src/skr_parser/skr_ast.dart';
import 'package:sakiengine/src/widgets/choice_menu.dart';
import 'package:sakiengine/src/widgets/dialogue_box.dart';
import 'package:sakiengine/src/widgets/quick_menu.dart';
import 'package:sakiengine/src/screens/review_screen.dart';
import 'package:sakiengine/src/screens/main_menu_screen.dart';
import 'package:sakiengine/src/widgets/confirm_dialog.dart';
import 'package:sakiengine/src/widgets/common/notification_overlay.dart';
import 'package:sakiengine/src/utils/scaling_manager.dart';

class GamePlayScreen extends StatefulWidget {
  final SaveSlot? saveSlotToLoad;

  const GamePlayScreen({super.key, this.saveSlotToLoad});

  @override
  State<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends State<GamePlayScreen> {
  late final GameManager _gameManager;
  final _notificationOverlayKey = GlobalKey<NotificationOverlayState>();
  String _currentScript = 'start'; 
  bool _showReviewOverlay = false;
  bool _showSaveOverlay = false;
  bool _showLoadOverlay = false;
  HotKey? _reloadHotKey;

  @override
  void initState() {
    super.initState();
    _gameManager = GameManager(
      onReturn: _returnToMainMenu,
    );

    // 注册系统级热键 Shift+R
    _setupHotkey();

    if (widget.saveSlotToLoad != null) {
      _currentScript = widget.saveSlotToLoad!.currentScript;
      _gameManager.restoreFromSnapshot(
          _currentScript, widget.saveSlotToLoad!.snapshot, shouldReExecute: false);
      
      // 延迟显示读档成功通知，确保UI已经构建完成
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showNotificationMessage('读档成功');
      });
    } else {
      _gameManager.startGame(_currentScript);
    }
  }

  void _returnToMainMenu() {
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => MainMenuScreen(
            onNewGame: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const GamePlayScreen()),
            ),
            onLoadGame: () => setState(() => _showLoadOverlay = true),
          ),
        ),
        (Route<dynamic> route) => false,
      );
    }
  }

  void _handleQuickMenuBack() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ConfirmDialog(
          title: '确认返回',
          content: '是否要返回主菜单？',
          onConfirm: _returnToMainMenu,
        );
      },
    );
  }

  @override
  void dispose() {
    // 取消注册系统热键
    if (_reloadHotKey != null) {
      hotKeyManager.unregister(_reloadHotKey!);
    }
    _gameManager.dispose();
    super.dispose();
  }

  // 设置系统级热键
  Future<void> _setupHotkey() async {
    _reloadHotKey = HotKey(
      key: PhysicalKeyboardKey.keyR,
      modifiers: [HotKeyModifier.shift],
      scope: HotKeyScope.inapp, // 先使用应用内热键，避免权限问题
    );
    
    try {
      await hotKeyManager.register(
        _reloadHotKey!,
        keyDownHandler: (hotKey) {
          print('热键触发: ${hotKey.toJson()}');
          if (mounted) {
            _handleHotReload();
          }
        },
      );
      print('快捷键 Shift+R 注册成功');
    } catch (e) {
      print('快捷键注册失败: $e');
      // 如果系统级热键失败，尝试应用内热键
      _reloadHotKey = HotKey(
        key: PhysicalKeyboardKey.keyR,
        modifiers: [HotKeyModifier.shift],
        scope: HotKeyScope.inapp,
      );
      try {
        await hotKeyManager.register(
          _reloadHotKey!,
          keyDownHandler: (hotKey) {
            print('应用内热键触发: ${hotKey.toJson()}');
            if (mounted) {
              _handleHotReload();
            }
          },
        );
        print('应用内快捷键 Shift+R 注册成功');
      } catch (e2) {
        print('应用内快捷键注册也失败: $e2');
      }
    }
  }

  // 显示通知消息
  void _showNotificationMessage(String message) {
    _notificationOverlayKey.currentState?.show(message);
  }

  Future<void> _handleHotReload() async {
    await _gameManager.hotReload(_currentScript);
    _showNotificationMessage('重载完成');
  }

  Future<void> _jumpToHistoryEntry(DialogueHistoryEntry entry) async {
    setState(() => _showReviewOverlay = false);
    await _gameManager.jumpToHistoryEntry(entry, _currentScript);
    _showNotificationMessage('跳转成功');
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      child: Scaffold(
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
                      if (gameState.background != null)
                        FutureBuilder<String?>(
                          future: AssetManager().findAsset('backgrounds/${gameState.background!.replaceAll(' ', '-')}'),
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
                          },
                        ),
                      ..._buildCharacters(context, gameState.characters, gameState.poseConfigs),
                      if (gameState.dialogue != null)
                        DialogueBox(
                          speaker: gameState.speaker,
                          dialogue: gameState.dialogue!,
                        ),
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
                QuickMenu(
                  onSave: () => setState(() => _showSaveOverlay = true),
                  onLoad: () => setState(() => _showLoadOverlay = true),
                  onReview: () => setState(() => _showReviewOverlay = true),
                  onBack: _handleQuickMenuBack,
                ),
                if (_showReviewOverlay)
                  ReviewOverlay(
                    dialogueHistory: _gameManager.getDialogueHistory(),
                    onClose: () => setState(() => _showReviewOverlay = false),
                    onJumpToEntry: _jumpToHistoryEntry,
                  ),
                if (_showSaveOverlay)
                  SaveLoadScreen(
                    mode: SaveLoadMode.save,
                    gameManager: _gameManager,
                    onClose: () => setState(() => _showSaveOverlay = false),
                  ),
                if (_showLoadOverlay)
                  SaveLoadScreen(
                    mode: SaveLoadMode.load,
                    onClose: () => setState(() => _showLoadOverlay = false),
                  ),
                NotificationOverlay(
                  key: _notificationOverlayKey,
                  scale: context.scaleFor(ComponentType.ui),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildCharacters(BuildContext context, Map<String, CharacterState> characters, Map<String, PoseConfig> poseConfigs) {
    return characters.entries.map((entry) {
      final characterId = entry.key;
      final characterState = entry.value;
      final poseConfig = poseConfigs[characterState.positionId] ?? PoseConfig(id: 'default');

      final layers = <Widget>[];

      final poseImage = characterState.pose ?? 'pose1';
      final poseAssetName = 'characters/${characterState.resourceId}-$poseImage';
      layers.add(_CharacterLayer(key: ValueKey('$characterId-pose'), assetName: poseAssetName));

      final expressionImage = characterState.expression ?? 'happy';
      final expressionAssetName = 'characters/${characterState.resourceId}-$expressionImage';
      layers.add(_CharacterLayer(key: ValueKey('$characterId-expression'), assetName: expressionAssetName));
      
      final characterStack = Stack(children: layers);
      
      Widget finalWidget = characterStack;
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
        return LayoutBuilder(
          builder: (context, constraints) {
            final imageSize = Size(_currentImage!.width.toDouble(), _currentImage!.height.toDouble());
            
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
