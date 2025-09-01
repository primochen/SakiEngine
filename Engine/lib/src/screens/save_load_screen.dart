import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/game/game_manager.dart';
import 'package:sakiengine/src/game/save_load_manager.dart';
import 'package:sakiengine/src/utils/binary_serializer.dart';
import 'package:sakiengine/src/screens/game_play_screen.dart';
import 'package:sakiengine/src/utils/scaling_manager.dart';
import 'package:sakiengine/src/widgets/common/notification_overlay.dart';
import 'package:sakiengine/src/widgets/common/overlay_scaffold.dart';
import 'package:sakiengine/src/widgets/screenshot_thumbnail.dart';
import 'package:sakiengine/src/widgets/confirm_dialog.dart';
import 'package:sakiengine/src/widgets/common/square_icon_button.dart';
import 'package:sakiengine/src/utils/rich_text_parser.dart';

enum SaveLoadMode { save, load }

class SaveLoadScreen extends StatefulWidget {
  final SaveLoadMode mode;
  final GameManager? gameManager;
  final VoidCallback onClose;
  final VoidCallback? onLoadSuccess;
  final Function(SaveSlot)? onLoadSlot;

  const SaveLoadScreen({
    super.key,
    required this.mode,
    this.gameManager,
    required this.onClose,
    this.onLoadSuccess,
    this.onLoadSlot,
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

    try {
      final snapshot = widget.gameManager!.saveStateSnapshot();
      await _saveLoadManager.saveGame(slotId, widget.gameManager!.currentScriptFile, snapshot);
      
      _notificationOverlayKey.currentState?.show('保存成功');
      
      _loadSaveSlots();

      Timer(const Duration(milliseconds: 550), () {
        if (mounted) {
          widget.onClose();
        }
      });
    } catch (e) {
      _notificationOverlayKey.currentState?.show('保存失败: $e');
    }
  }

  Future<void> _handleLoad(SaveSlot slot) async {
    if (widget.onLoadSlot != null) {
      // 使用新的回调传递存档信息
      widget.onLoadSlot!(slot);
      widget.onClose(); // 关闭对话框
    } else if (widget.onLoadSuccess != null) {
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

  Future<bool?> _showDeleteConfirmDialog(int slotId) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: '确认删除',
        content: '确定要删除档位 ${slotId.toString().padLeft(2, '0')} 的存档吗？\n此操作不可撤销。',
        onConfirm: () {},
        onCancel: () {},
        confirmResult: true,
        cancelResult: false,
      ),
    );
  }

  Future<void> _handleDelete(int slotId) async {
    try {
      await _saveLoadManager.deleteSave(slotId);
      _notificationOverlayKey.currentState?.show('存档已删除');
      _loadSaveSlots(); // 刷新存档列表
    } catch (e) {
      _notificationOverlayKey.currentState?.show('删除失败: $e');
    }
  }

  Future<void> _handleToggleLock(int slotId) async {
    try {
      final success = await _saveLoadManager.toggleSaveLock(slotId);
      if (success) {
        final existingSlots = await _saveSlotsFuture;
        final slot = existingSlots.firstWhere((s) => s.id == slotId);
        final isNowLocked = !slot.isLocked;
        _notificationOverlayKey.currentState?.show(isNowLocked ? '存档已锁定' : '存档已解锁');
        _loadSaveSlots();
      } else {
        _notificationOverlayKey.currentState?.show('操作失败');
      }
    } catch (e) {
      _notificationOverlayKey.currentState?.show('操作失败: $e');
    }
  }

  Future<void> _handleMove(int fromSlotId, int direction) async {
    int toSlotId;
    String directionText;
    
    switch (direction) {
      case 0: // 上
        toSlotId = fromSlotId - 3;
        directionText = '上方';
        break;
      case 1: // 下
        toSlotId = fromSlotId + 3;
        directionText = '下方';
        break;
      case 2: // 左
        toSlotId = fromSlotId - 1;
        directionText = '左侧';
        break;
      case 3: // 右
        toSlotId = fromSlotId + 1;
        directionText = '右侧';
        break;
      default:
        return;
    }
    
    if (toSlotId < 1 || toSlotId > 12) {
      _notificationOverlayKey.currentState?.show('无法移动到档位 ${toSlotId.toString().padLeft(2, '0')}');
      return;
    }
    
    try {
      final existingSlots = await _saveSlotsFuture;
      final targetSlot = existingSlots.firstWhere(
        (s) => s.id == toSlotId,
        orElse: () => SaveSlot(id: -1, saveTime: DateTime.now(), currentScript: '', dialoguePreview: '', snapshot: GameStateSnapshot(scriptIndex: 0, currentState: GameState.initial())),
      );
      
      final bool success;
      if (targetSlot.id == -1) {
        success = await _saveLoadManager.moveSave(fromSlotId, toSlotId);
        if (success) {
          _notificationOverlayKey.currentState?.show('已移动到${directionText}档位');
        } else {
          _notificationOverlayKey.currentState?.show('无法移动被锁定的存档');
        }
      } else {
        success = await _saveLoadManager.swapSaves(fromSlotId, toSlotId);
        if (success) {
          _notificationOverlayKey.currentState?.show('已与${directionText}档位交换');
        } else {
          _notificationOverlayKey.currentState?.show('无法移动被锁定的存档');
        }
      }
      
      if (success) {
        _loadSaveSlots();
      }
    } catch (e) {
      _notificationOverlayKey.currentState?.show('移动失败: $e');
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
    return FutureBuilder<List<SaveSlot>>(
      future: _saveSlotsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('读取存档失败: ${snapshot.error}', style: TextStyle(color: config.themeColors.primary, fontSize: 16 * textScale)));
        }

        final savedSlots = snapshot.data ?? [];
        
        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: GridView.builder(
            padding: EdgeInsets.all(32 * uiScale),
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
                onDelete: isSlotEmpty ? null : () async {
                  final shouldDelete = await _showDeleteConfirmDialog(slotId);
                  if (shouldDelete == true) {
                    await _handleDelete(slotId);
                  }
                },
                onToggleLock: isSlotEmpty ? null : () async {
                  await _handleToggleLock(slotId);
                },
                onMove: isSlotEmpty ? null : (direction) async {
                  await _handleMove(slotId, direction);
                },
              );
            },
          ),
        );
      },
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
  final VoidCallback? onDelete;
  final VoidCallback? onToggleLock;
  final Function(int)? onMove;
  final SakiEngineConfig config;
  final double uiScale;
  final double textScale;

  const _SaveSlotCard({
    required this.slotId,
    this.saveSlot,
    required this.onTap,
    this.onDelete,
    this.onToggleLock,
    this.onMove,
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
    if (widget.saveSlot?.screenshotData != oldWidget.saveSlot?.screenshotData ||
        widget.saveSlot?.saveTime != oldWidget.saveSlot?.saveTime) {
      if (mounted) {
        setState(() {});
      }
    }
  }

  Widget _buildScreenshot() {
    return ScreenshotThumbnail(
      key: ValueKey('${widget.saveSlot?.id}_${widget.saveSlot?.saveTime}'),
      screenshotData: widget.saveSlot?.screenshotData,
      borderRadius: 0 * widget.uiScale,
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
        borderRadius: BorderRadius.circular(0 * uiScale),
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
            borderRadius: BorderRadius.circular(0 * uiScale),
          ),
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.all(12.0 * uiScale),
                child: widget.saveSlot != null
                    ? _buildDataCard(uiScale, widget.textScale, config)
                    : _buildEmptyCard(uiScale, widget.textScale, config),
              ),
              if ((widget.onMove != null || widget.onDelete != null || widget.onToggleLock != null) && widget.saveSlot != null)
                Positioned(
                  bottom: 8 * uiScale,
                  right: 8 * uiScale,
                  child: _buildActionButtons(uiScale, config),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(double uiScale, SakiEngineConfig config) {
    final buttonSize = 26 * uiScale;
    final buttonSpacing = 3 * uiScale;
    final isLocked = widget.saveSlot?.isLocked ?? false;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.onMove != null && !isLocked) ...[
          SquareIconButton(
            icon: Icons.keyboard_arrow_up,
            size: buttonSize,
            onTap: () => widget.onMove!(0),
            ),
          SizedBox(width: buttonSpacing),
          SquareIconButton(
            icon: Icons.keyboard_arrow_down,
            size: buttonSize,
            onTap: () => widget.onMove!(1),
            ),
          SizedBox(width: buttonSpacing),
          SquareIconButton(
            icon: Icons.keyboard_arrow_left,
            size: buttonSize,
            onTap: () => widget.onMove!(2),
            ),
          SizedBox(width: buttonSpacing),
          SquareIconButton(
            icon: Icons.keyboard_arrow_right,
            size: buttonSize,
            onTap: () => widget.onMove!(3),
            ),
          SizedBox(width: buttonSpacing),
        ],
        if (widget.onToggleLock != null)
          SquareIconButton(
            icon: isLocked ? Icons.lock : Icons.lock_open,
            size: buttonSize,
            onTap: () => widget.onToggleLock!(),
            hoverBackgroundColor: config.themeColors.primary.withOpacity(0.1),
          ),
        if (widget.onDelete != null && !isLocked) ...[
          SizedBox(width: buttonSpacing),
          SquareIconButton(
            icon: Icons.close,
            size: buttonSize,
            onTap: () => widget.onDelete!(),
              hoverBackgroundColor: config.themeColors.primary.withOpacity(0.1),
          ),
        ],
      ],
    );
  }

  Widget _buildDataCard(double uiScale, double textScale, SakiEngineConfig config) {
    final isLocked = widget.saveSlot?.isLocked ?? false;
    final opacity = isLocked ? 0.6 : 1.0;
    
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
                color: config.themeColors.primary.withOpacity(opacity),
                fontWeight: FontWeight.bold,
              ),
            ),
            if (widget.saveSlot != null)
              Text(
                DateFormat('yyyy-MM-dd HH:mm').format(widget.saveSlot!.saveTime),
                style: config.reviewTitleTextStyle.copyWith(
                  fontSize: config.reviewTitleTextStyle.fontSize! * textScale * 0.35,
                  color: config.themeColors.primary.withOpacity(0.6 * opacity),
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
                borderRadius: BorderRadius.circular(0 * uiScale),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Opacity(
                    opacity: opacity,
                    child: _buildScreenshot(),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12 * uiScale),
            Expanded(
              flex: 11,
              child: Text(
                RichTextParser.cleanText(widget.saveSlot!.dialoguePreview),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: config.reviewTitleTextStyle.copyWith(
                  fontSize: config.reviewTitleTextStyle.fontSize! * textScale * 0.4,
                  color: config.themeColors.onSurface.withOpacity(0.8 * opacity),
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
