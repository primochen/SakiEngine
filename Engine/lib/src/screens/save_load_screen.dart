import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/game/game_manager.dart';
import 'package:sakiengine/src/game/save_load_manager.dart';
import 'package:sakiengine/src/screens/game_play_screen.dart';
import 'package:sakiengine/src/widgets/common/close_button.dart';
import 'package:sakiengine/src/widgets/common/notification_overlay.dart';

enum SaveLoadMode { save, load }

class SaveLoadScreen extends StatefulWidget {
  final SaveLoadMode mode;
  final GameManager? gameManager;
  final VoidCallback onClose;

  const SaveLoadScreen({
    super.key,
    required this.mode,
    this.gameManager,
    required this.onClose,
  });

  @override
  State<SaveLoadScreen> createState() => _SaveLoadScreenState();
}

class _SaveLoadScreenState extends State<SaveLoadScreen> {
  final SaveLoadManager _saveLoadManager = SaveLoadManager();
  late Future<List<SaveSlot>> _saveSlotsFuture;
  bool _showSaveSuccess = false;

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
    
    final snapshot = widget.gameManager!.saveStateSnapshot();
    await _saveLoadManager.saveGame(slotId, 'start', snapshot); // TODO: Make script dynamic
    
    setState(() {
      _showSaveSuccess = true;
    });

    _loadSaveSlots();

    // Wait for the "Save Success" message to show, then fade out and close.
    Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _showSaveSuccess = false;
        });
        // Wait for fade out animation to complete before closing the screen
        Timer(const Duration(milliseconds: 300), () {
          if (mounted) {
            widget.onClose();
          }
        });
      }
    });
  }

  Future<void> _handleLoad(SaveSlot slot) async {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => GamePlayScreen(saveSlotToLoad: slot),
      ),
      (route) => false,
    );
  }
  
  String _getTitleText() {
    return widget.mode == SaveLoadMode.save ? '保存进度' : '读取进度';
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final config = SakiEngineConfig();
    final scaleX = screenSize.width / config.logicalWidth;
    final scaleY = screenSize.height / config.logicalHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    return Stack(
      children: [
        Shortcuts(
          shortcuts: <LogicalKeySet, Intent>{
            if (!_showSaveSuccess) LogicalKeySet(LogicalKeyboardKey.escape): const _CloseIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              _CloseIntent: _CloseAction(widget.onClose),
            },
            child: Focus(
              autofocus: true,
              child: GestureDetector(
                onTap: _showSaveSuccess ? null : widget.onClose,
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        config.themeColors.primaryDark.withValues(alpha: 0.5),
                        config.themeColors.primaryDark.withValues(alpha: 0.5),
                      ],
                    ),
                  ),
                  child: GestureDetector(
                    onTap: () {},
                    child: Center(
                      child: Container(
                        width: screenSize.width * 0.85,
                        height: screenSize.height * 0.8,
                        decoration: BoxDecoration(
                          color: config.themeColors.background.withValues(alpha: 0.95),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 20 * scale,
                              offset: Offset(0, 8 * scale),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _buildHeader(scale, config),
                            Expanded(
                              child: _buildGridContent(scale, config),
                            ),
                            _buildFooter(scale, config),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        NotificationOverlay(
          show: _showSaveSuccess,
          message: '保存成功',
          scale: scale,
        ),
      ],
    );
  }

  Widget _buildHeader(double scale, SakiEngineConfig config) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 32 * scale,
        vertical: 20 * scale,
      ),
      decoration: BoxDecoration(
        color: config.themeColors.primary.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(
            color: config.themeColors.primary.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            _getTitleText(),
            style: config.reviewTitleTextStyle.copyWith(
              fontSize: config.reviewTitleTextStyle.fontSize! * scale,
              color: config.themeColors.primary,
              letterSpacing: 2.0,
            ),
          ),
          const Spacer(),
          CommonCloseButton(
            scale: scale,
            onClose: widget.onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildGridContent(double scale, SakiEngineConfig config) {
    return Container(
      padding: EdgeInsets.all(32 * scale),
      child: FutureBuilder<List<SaveSlot>>(
        future: _saveSlotsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('读取存档失败: ${snapshot.error}', style: TextStyle(color: config.themeColors.primary)));
          }

          final savedSlots = snapshot.data ?? [];
          
          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 16 / 10,
              crossAxisSpacing: 20 * scale,
              mainAxisSpacing: 20 * scale,
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
                scale: scale,
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

  Widget _buildFooter(double scale, SakiEngineConfig config) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 12 * scale),
      decoration: BoxDecoration(
        color: config.themeColors.primary.withValues(alpha: 0.05),
        border: Border(
          top: BorderSide(
            color: config.themeColors.primary.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Center(
        child: Text(
          '选择一个栏位以${widget.mode == SaveLoadMode.save ? "覆盖" : "读取"}进度',
          style: config.reviewTitleTextStyle.copyWith(
            fontSize: config.reviewTitleTextStyle.fontSize! * scale * 0.44,
            color: config.themeColors.primary.withValues(alpha: 0.7),
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
  final double scale;

  const _SaveSlotCard({
    required this.slotId,
    this.saveSlot,
    required this.onTap,
    required this.config,
    required this.scale,
  });

  @override
  State<_SaveSlotCard> createState() => _SaveSlotCardState();
}

class _SaveSlotCardState extends State<_SaveSlotCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    final config = widget.config;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(4 * scale),
        hoverColor: config.themeColors.primary.withValues(alpha: 0.1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _isHovered ? config.themeColors.primary.withValues(alpha: 0.05) : Colors.transparent,
            border: Border.all(
              color: config.themeColors.primary.withValues(alpha: _isHovered ? 0.5 : 0.2),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(4 * scale),
          ),
          child: Padding(
            padding: EdgeInsets.all(16.0 * scale),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '档位 ${widget.slotId.toString().padLeft(2, '0')}',
                  style: config.reviewTitleTextStyle.copyWith(
                    fontSize: config.reviewTitleTextStyle.fontSize! * scale * 0.5,
                    color: config.themeColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8 * scale),
                Divider(color: config.themeColors.primary.withValues(alpha: 0.2)),
                SizedBox(height: 8 * scale),
                if (widget.saveSlot != null) ...[
                  Text(
                    DateFormat('yyyy-MM-dd HH:mm').format(widget.saveSlot!.saveTime),
                    style: config.reviewTitleTextStyle.copyWith(
                      fontSize: config.reviewTitleTextStyle.fontSize! * scale * 0.39,
                      color: config.themeColors.primary.withValues(alpha: 0.6),
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  SizedBox(height: 8 * scale),
                  Expanded(
                    child: Text(
                      widget.saveSlot!.dialoguePreview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: config.reviewTitleTextStyle.copyWith(
                        fontSize: config.reviewTitleTextStyle.fontSize! * scale * 0.44,
                        color: config.themeColors.onSurface.withValues(alpha: 0.8),
                        fontWeight: FontWeight.normal,
                        height: 1.5,
                      ),
                    ),
                  ),
                ] else
                  Expanded(
                    child: Center(
                      child: Text(
                        '--', 
                        style: config.reviewTitleTextStyle.copyWith(
                          fontSize: config.reviewTitleTextStyle.fontSize! * scale * 0.6,
                          color: config.themeColors.primary.withValues(alpha: 0.3),
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
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
