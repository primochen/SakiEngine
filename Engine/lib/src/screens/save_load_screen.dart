import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/game/game_manager.dart';
import 'package:sakiengine/src/game/save_load_manager.dart';
import 'package:sakiengine/src/screens/game_play_screen.dart';
import 'package:sakiengine/src/utils/scaling_manager.dart';
import 'package:sakiengine/src/widgets/common/notification_overlay.dart';
import 'package:sakiengine/src/widgets/common/overlay_scaffold.dart';
import 'package:sakiengine/src/widgets/screenshot_thumbnail.dart';

enum SaveLoadMode { save, load }

class SaveLoadScreen extends StatefulWidget {
  final SaveLoadMode mode;
  final GameManager? gameManager;
  final VoidCallback onClose;
  final VoidCallback? onLoadSuccess;

  const SaveLoadScreen({
    super.key,
    required this.mode,
    this.gameManager,
    required this.onClose,
    this.onLoadSuccess,
  });

  @override
  State<SaveLoadScreen> createState() => _SaveLoadScreenState();
}

class _SaveLoadScreenState extends State<SaveLoadScreen> {
  final _notificationOverlayKey = GlobalKey<NotificationOverlayState>();
  final SaveLoadManager _saveLoadManager = SaveLoadManager();
  late Future<List<SaveSlot>> _saveSlotsFuture;

  @override
  void initState() {
    super.initState();
    _loadSaveSlots();
  }

  void _loadSaveSlots() {
    if (mounted) {
      setState(() {
        _saveSlotsFuture = _saveLoadManager.listSaveSlots();
      });
    }
  }

  Future<void> _handleSave(int slotId) async {
    if (widget.gameManager == null || !mounted) return;

    final existingSlots = await _saveSlotsFuture;
    final existingSlot = existingSlots.firstWhere(
      (s) => s.id == slotId,
      orElse: () => SaveSlot(id: -1, saveTime: DateTime.now(), currentScript: '', dialoguePreview: '', snapshot: GameStateSnapshot(scriptIndex: 0, currentState: GameState.initial())),
    );
    final oldScreenshotPath = existingSlot.screenshotPath;

    final snapshot = widget.gameManager!.saveStateSnapshot();
    await _saveLoadManager.saveGame(slotId, 'start', snapshot); 

    if (oldScreenshotPath != null && oldScreenshotPath.isNotEmpty) {
      final imageProvider = FileImage(File(oldScreenshotPath));
      await imageProvider.evict();
      print('清除缓存: $oldScreenshotPath');
    }
    
    _notificationOverlayKey.currentState?.show('保存成功');
    
    _loadSaveSlots();

    Timer(const Duration(milliseconds: 550), () {
      if (mounted) {
        widget.onClose();
      }
    });
  }

  Future<void> _handleLoad(SaveSlot slot) async {
    if (widget.onLoadSuccess != null) {
      // 如果有读档成功回调，就调用它而不是直接导航
      widget.onLoadSuccess!();
    } else {
      // 否则保持原有行为，直接导航到新的游戏界面
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => GamePlayScreen(saveSlotToLoad: slot),
        ),
        (route) => false,
      );
    }
  }
  
  String _getTitleText() {
    return widget.mode == SaveLoadMode.save ? '保存进度' : '读取进度';
  }

  @override
  Widget build(BuildContext context) {
    final uiScale = context.scaleFor(ComponentType.ui);
    final textScale = context.scaleFor(ComponentType.text);
    final config = SakiEngineConfig();

    return Stack(
      children: [
        OverlayScaffold(
          title: _getTitleText(),
          onClose: widget.onClose,
          content: _buildGridContent(uiScale, textScale, config),
          footer: _buildFooter(uiScale, textScale, config),
        ),
        NotificationOverlay(
          key: _notificationOverlayKey,
          scale: uiScale,
        ),
      ],
    );
  }

  Widget _buildGridContent(double uiScale, double textScale, SakiEngineConfig config) {
    return Container(
      padding: EdgeInsets.all(32 * uiScale),
      child: FutureBuilder<List<SaveSlot>>(
        future: _saveSlotsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('读取存档失败: ${snapshot.error}', style: TextStyle(color: config.themeColors.primary, fontSize: 16 * textScale)));
          }

          final savedSlots = snapshot.data ?? [];
          
          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.height / MediaQuery.of(context).size.width > 1.5 ? 1 : 
                              MediaQuery.of(context).size.height > MediaQuery.of(context).size.width ? 2 : 3,
              childAspectRatio: MediaQuery.of(context).size.height / MediaQuery.of(context).size.width > 1.5 ? 2.4 : 
                                 MediaQuery.of(context).size.height > MediaQuery.of(context).size.width ? 2.2 : 2.25,
              crossAxisSpacing: 20 * uiScale,
              mainAxisSpacing: 20 * uiScale,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              final slotId = index + 1;
              final saveSlot = savedSlots.firstWhere(
                (s) => s.id == slotId,
                orElse: () => SaveSlot(id: -1, saveTime: DateTime.now(), currentScript: '', dialoguePreview: '', snapshot: GameStateSnapshot(scriptIndex: 0, currentState: GameState.initial())),
              );
              final isSlotEmpty = saveSlot.id == -1;

              return _SaveSlotCard(
                slotId: slotId,
                saveSlot: isSlotEmpty ? null : saveSlot,
                config: config,
                uiScale: uiScale,
                textScale: textScale,
                onTap: () {
                  if (widget.mode == SaveLoadMode.save) {
                    _handleSave(slotId);
                  } else if (!isSlotEmpty) {
                    _handleLoad(saveSlot);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFooter(double uiScale, double textScale, SakiEngineConfig config) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 12 * uiScale),
      decoration: BoxDecoration(
        color: config.themeColors.primary.withOpacity(0.05),
        border: Border(
          top: BorderSide(
            color: config.themeColors.primary.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Center(
        child: Text(
          '选择一个栏位以${widget.mode == SaveLoadMode.save ? "覆盖" : "读取"}进度',
          style: config.reviewTitleTextStyle.copyWith(
            fontSize: config.reviewTitleTextStyle.fontSize! * textScale * 0.4,
            color: config.themeColors.primary.withOpacity(0.7),
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _SaveSlotCard extends StatefulWidget {
  final int slotId;
  final SaveSlot? saveSlot;
  final VoidCallback onTap;
  final SakiEngineConfig config;
  final double uiScale;
  final double textScale;

  const _SaveSlotCard({
    required this.slotId,
    this.saveSlot,
    required this.onTap,
    required this.config,
    required this.uiScale,
    required this.textScale,
  });

  @override
  State<_SaveSlotCard> createState() => _SaveSlotCardState();
}

class _SaveSlotCardState extends State<_SaveSlotCard> {
  bool _isHovered = false;

  @override
  void didUpdateWidget(covariant _SaveSlotCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.saveSlot?.screenshotPath != oldWidget.saveSlot?.screenshotPath ||
        widget.saveSlot?.saveTime != oldWidget.saveSlot?.saveTime) {
      if (mounted) {
        setState(() {});
      }
    }
  }

  Widget _buildScreenshot() {
    return ScreenshotThumbnail(
      key: ValueKey('${widget.saveSlot?.screenshotPath}_${widget.saveSlot?.saveTime}'),
      screenshotPath: widget.saveSlot?.screenshotPath,
      borderRadius: 4 * widget.uiScale,
      placeholderColor: widget.config.themeColors.primary.withOpacity(0.1),
      iconColor: widget.config.themeColors.primary.withOpacity(0.3),
      iconSize: 24 * widget.uiScale,
    );
  }

  @override
  Widget build(BuildContext context) {
    final uiScale = widget.uiScale;
    final config = widget.config;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(4 * uiScale),
        hoverColor: config.themeColors.primary.withOpacity(0.1),
        onHover: (hovering) {
          if (mounted) {
            setState(() {
              _isHovered = hovering;
            });
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _isHovered
                ? config.themeColors.primary.withOpacity(0.05)
                : Colors.transparent,
            border: Border.all(
              color: config.themeColors.primary.withOpacity(_isHovered ? 0.5 : 0.2),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(4 * uiScale),
          ),
          child: Padding(
            padding: EdgeInsets.all(12.0 * uiScale),
            child: widget.saveSlot != null
                ? _buildDataCard(uiScale, widget.textScale, config)
                : _buildEmptyCard(uiScale, widget.textScale, config),
          ),
        ),
      ),
    );
  }

  Widget _buildDataCard(double uiScale, double textScale, SakiEngineConfig config) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '档位 ${widget.slotId.toString().padLeft(2, '0')}',
              style: config.reviewTitleTextStyle.copyWith(
                fontSize: config.reviewTitleTextStyle.fontSize! * textScale * 0.5,
                color: config.themeColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (widget.saveSlot != null)
              Text(
                DateFormat('yyyy-MM-dd HH:mm').format(widget.saveSlot!.saveTime),
                style: config.reviewTitleTextStyle.copyWith(
                  fontSize: config.reviewTitleTextStyle.fontSize! * textScale * 0.35,
                  color: config.themeColors.primary.withOpacity(0.6),
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        SizedBox(height: 8 * uiScale),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4 * uiScale),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _buildScreenshot(),
                ),
              ),
            ),
            SizedBox(width: 12 * uiScale),
            Expanded(
              flex: 11,
              child: Text(
                widget.saveSlot!.dialoguePreview,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: config.reviewTitleTextStyle.copyWith(
                  fontSize: config.reviewTitleTextStyle.fontSize! * textScale * 0.4,
                  color: config.themeColors.onSurface.withOpacity(0.8),
                  fontWeight: FontWeight.normal,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyCard(double uiScale, double textScale, SakiEngineConfig config) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '档位 ${widget.slotId.toString().padLeft(2, '0')}',
          style: config.reviewTitleTextStyle.copyWith(
            fontSize: config.reviewTitleTextStyle.fontSize! * textScale * 0.5,
            color: config.themeColors.primary.withOpacity(0.5),
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8 * uiScale),
        Expanded(
            child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_circle_outline,
                size: 32 * uiScale,
                color: config.themeColors.primary.withOpacity(0.3),
              ),
              SizedBox(height: 8 * uiScale),
              Text(
                '空档位',
                style: config.reviewTitleTextStyle.copyWith(
                  fontSize: config.reviewTitleTextStyle.fontSize! * textScale * 0.4,
                  color: config.themeColors.primary.withOpacity(0.3),
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ))
      ],
    );
  }
}

class _CloseIntent extends Intent {
  const _CloseIntent();
}

class _CloseAction extends Action<_CloseIntent> {
  final VoidCallback onClose;

  _CloseAction(this.onClose);

  @override
  Object? invoke(_CloseIntent intent) {
    onClose();
    return null;
  }
}
