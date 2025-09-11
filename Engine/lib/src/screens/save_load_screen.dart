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
  final ScrollController _scrollController = ScrollController();
  
  // 懒加载相关
  static const int _slotsPerPage = 24; // 每页24个存档位（4列x6行）
  final Map<int, SaveSlot?> _cachedSlots = {}; // 缓存已加载的存档位
  final ValueNotifier<int> _totalPages = ValueNotifier<int>(1); // 当前总页数
  bool _isLoadingMore = false;
  List<int>? _existingSlotIds; // 缓存存在的存档ID

  @override
  void initState() {
    super.initState();
    _initializeSaveSlots();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _totalPages.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMoreSlots();
    }
  }

  Future<void> _initializeSaveSlots() async {
    try {
      // 获取所有存在的存档ID
      _existingSlotIds = await _saveLoadManager.getExistingSaveSlotIds();
      
      // 计算初始页数（至少1页，如果有存档则基于最大ID计算）
      int initialPages = 1;
      if (_existingSlotIds != null && _existingSlotIds!.isNotEmpty) {
        final maxSlotId = _existingSlotIds!.last;
        initialPages = (maxSlotId / _slotsPerPage).ceil();
      }
      _totalPages.value = initialPages;
      
      // 加载所有包含存档的页面，确保现有存档都被加载
      if (_existingSlotIds != null && _existingSlotIds!.isNotEmpty) {
        final Set<int> pagesToLoad = {};
        for (final slotId in _existingSlotIds!) {
          final page = ((slotId - 1) / _slotsPerPage).floor() + 1;
          pagesToLoad.add(page);
        }
        
        // 加载所有相关页面
        for (final page in pagesToLoad) {
          await _loadSlotsForPage(page);
        }
        
        // 如果第一页没有被加载，也要加载它以显示空档位
        if (!pagesToLoad.contains(1)) {
          await _loadSlotsForPage(1);
        }
      } else {
        // 没有任何存档时，只加载第一页
        await _loadSlotsForPage(1);
      }
    } catch (e) {
      _notificationOverlayKey.currentState?.show('初始化存档列表失败: $e');
    }
  }

  Future<void> _loadSlotsForPage(int page) async {
    final startSlotId = (page - 1) * _slotsPerPage + 1;
    final endSlotId = page * _slotsPerPage;
    
    try {
      final slots = await _saveLoadManager.listSaveSlotsInRange(startSlotId, endSlotId);
      
      // 更新缓存
      for (int i = 0; i < slots.length; i++) {
        final slotId = startSlotId + i;
        _cachedSlots[slotId] = slots[i];
      }
      
      setState(() {}); // 触发重绘显示新加载的数据
    } catch (e) {
      print('加载第$page页存档失败: $e');
    }
  }

  Future<void> _loadMoreSlots() async {
    if (_isLoadingMore) return;
    
    _isLoadingMore = true;
    final nextPage = _totalPages.value + 1;
    
    await _loadSlotsForPage(nextPage);
    _totalPages.value = nextPage;
    
    _isLoadingMore = false;
  }

  int _getTotalSlotCount() {
    return _totalPages.value * _slotsPerPage;
  }

  Future<void> _updateSingleSlot(int slotId, SaveSlot? newSlotData) async {
    if (!mounted) return;
    
    // 直接更新缓存
    _cachedSlots[slotId] = newSlotData;
    
    // 如果是新存档，更新存在的存档ID列表
    if (newSlotData != null && _existingSlotIds != null) {
      if (!_existingSlotIds!.contains(slotId)) {
        _existingSlotIds!.add(slotId);
        _existingSlotIds!.sort();
      }
    } else if (newSlotData == null && _existingSlotIds != null) {
      _existingSlotIds!.remove(slotId);
    }
    
    setState(() {});
  }

  Future<void> _swapSlots(int slotId1, int slotId2) async {
    if (!mounted) return;
    
    final slot1 = _cachedSlots[slotId1];
    final slot2 = _cachedSlots[slotId2];
    
    if (slot1 != null && slot2 != null) {
      _cachedSlots[slotId1] = slot2.copyWith(id: slotId1);
      _cachedSlots[slotId2] = slot1.copyWith(id: slotId2);
    } else if (slot1 != null) {
      _cachedSlots[slotId1] = null;
      _cachedSlots[slotId2] = slot1.copyWith(id: slotId2);
    } else if (slot2 != null) {
      _cachedSlots[slotId1] = slot2.copyWith(id: slotId1);
      _cachedSlots[slotId2] = null;
    }
    
    setState(() {});
  }

  Future<void> _handleSave(int slotId) async {
    if (widget.gameManager == null || !mounted) return;

    try {
      final snapshot = widget.gameManager!.saveStateSnapshot();
      await _saveLoadManager.saveGame(slotId, widget.gameManager!.currentScriptFile, snapshot, widget.gameManager!.poseConfigs);
      
      // 只更新单个存档位，避免全局重绘
      final updatedSlots = await _saveLoadManager.listSaveSlots();
      final newSlot = updatedSlots.firstWhere((slot) => slot.id == slotId, 
        orElse: () => SaveSlot(id: -1, saveTime: DateTime.now(), currentScript: '', dialoguePreview: '', snapshot: GameStateSnapshot(scriptIndex: 0, currentState: GameState.initial())));
      
      if (newSlot.id != -1) {
        await _updateSingleSlot(slotId, newSlot);
      }
    } catch (e) {
      final message = e.toString();
      if (message.contains('存档已锁定，无法覆盖')) {
        _notificationOverlayKey.currentState?.show('存档已锁定，无法覆盖');
      } else {
        _notificationOverlayKey.currentState?.show('保存失败: $e');
      }
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
      //_notificationOverlayKey.currentState?.show('存档已删除');
      await _updateSingleSlot(slotId, null);
    } catch (e) {
      _notificationOverlayKey.currentState?.show('删除失败: $e');
    }
  }

  Future<void> _handleToggleLock(int slotId) async {
    try {
      final success = await _saveLoadManager.toggleSaveLock(slotId);
      if (success) {
        final currentSlot = _cachedSlots[slotId];
        if (currentSlot != null) {
          final isNowLocked = !currentSlot.isLocked;
          await _updateSingleSlot(slotId, currentSlot.copyWith(isLocked: isNowLocked));
        }
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
    
    if (toSlotId < 1) {
      _notificationOverlayKey.currentState?.show('无法移动到档位 ${toSlotId.toString().padLeft(2, '0')}');
      return;
    }
    
    try {
      final targetSlot = _cachedSlots[toSlotId];
      
      final bool success;
      if (targetSlot == null) {
        success = await _saveLoadManager.moveSave(fromSlotId, toSlotId);
        if (success) {
          //_notificationOverlayKey.currentState?.show('已移动到$directionText档位');
        } else {
          _notificationOverlayKey.currentState?.show('无法移动被锁定的存档');
        }
      } else {
        success = await _saveLoadManager.swapSaves(fromSlotId, toSlotId);
        if (success) {
         //_notificationOverlayKey.currentState?.show('已与$directionText档位交换');
        } else {
          _notificationOverlayKey.currentState?.show('无法移动被锁定的存档');
        }
      }
      
      if (success) {
        if (targetSlot == null) {
          final sourceSlot = _cachedSlots[fromSlotId];
          if (sourceSlot != null) {
            await _updateSingleSlot(fromSlotId, null);
            await _updateSingleSlot(toSlotId, sourceSlot.copyWith(id: toSlotId));
          }
        } else {
          await _swapSlots(fromSlotId, toSlotId);
        }
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
    return ValueListenableBuilder<int>(
      valueListenable: _totalPages,
      builder: (context, totalPages, child) {
        final totalSlotCount = _getTotalSlotCount();
        
        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: GridView.builder(
            controller: _scrollController,
            padding: EdgeInsets.all(32 * uiScale),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.height / MediaQuery.of(context).size.width > 1.5 ? 2 : 
                              MediaQuery.of(context).size.height > MediaQuery.of(context).size.width ? 3 : 4,
              childAspectRatio: MediaQuery.of(context).size.height / MediaQuery.of(context).size.width > 1.5 ? 2.4 : 
                                 MediaQuery.of(context).size.height > MediaQuery.of(context).size.width ? 2.2 : 2.25,
              crossAxisSpacing: 20 * uiScale,
              mainAxisSpacing: 20 * uiScale,
            ),
            itemCount: totalSlotCount + (_isLoadingMore ? 1 : 0), // 加载更多时显示加载指示器
            itemBuilder: (context, index) {
              // 如果是最后一个项目且正在加载，显示加载指示器
              if (index >= totalSlotCount) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(20 * uiScale),
                    child: CircularProgressIndicator(
                      color: config.themeColors.primary,
                      strokeWidth: 2 * uiScale,
                    ),
                  ),
                );
              }
              
              final slotId = index + 1;
              final saveSlot = _cachedSlots[slotId];
              final isSlotEmpty = saveSlot == null;
              
              return _SaveSlotCard(
                key: ValueKey('slot_$slotId'),
                slotId: slotId,
                saveSlot: saveSlot,
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
        color: config.themeColors.primary.withValues(alpha: 0.05),
        border: Border(
          top: BorderSide(
            color: config.themeColors.primary.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: ValueListenableBuilder<int>(
        valueListenable: _totalPages,
        builder: (context, totalPages, child) {
          final totalSlots = _getTotalSlotCount();
          final existingCount = _existingSlotIds?.length ?? 0;
          
          return Center(
            child: Text(
              widget.mode == SaveLoadMode.save 
                ? '选择一个栏位以覆盖进度 • 已显示 $totalSlots 个存档位 • 已使用 $existingCount 个'
                : '选择一个栏位以读取进度 • 已显示 $totalSlots 个存档位 • 已使用 $existingCount 个',
              style: config.reviewTitleTextStyle.copyWith(
                fontSize: config.reviewTitleTextStyle.fontSize! * textScale * 0.4,
                color: config.themeColors.primary.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.normal,
              ),
            ),
          );
        },
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
    super.key,
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

class _SaveSlotCardState extends State<_SaveSlotCard> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _animationController;
  late Animation<double> _borderAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _borderAnimation = Tween<double>(
      begin: 0.2,
      end: 0.5,
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
  void didUpdateWidget(covariant _SaveSlotCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 由于使用了 ValueKey，Flutter 会自动优化重绘
    // 只有当 saveSlot 的关键数据发生变化时才需要重绘
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
          if (_isHovered != hovering) {
            setState(() {
              _isHovered = hovering;
            });
            if (hovering) {
              _animationController.forward();
            } else {
              _animationController.reverse();
            }
          }
        },
        child: AnimatedBuilder(
          animation: _borderAnimation,
          builder: (context, child) => Container(
            decoration: BoxDecoration(
              color: _isHovered
                  ? config.themeColors.primary.withOpacity(0.05)
                  : Colors.transparent,
              border: Border.all(
                color: config.themeColors.primary.withOpacity(_borderAnimation.value),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(0 * uiScale),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.all(12.0 * uiScale),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 内容区域
                      Expanded(
                        child: widget.saveSlot != null
                            ? _buildDataCard(uiScale, widget.textScale, config)
                            : _buildEmptyCard(uiScale, widget.textScale, config),
                      ),
                    ],
                  ),
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
        // 标题行
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '档位 ${widget.slotId.toString().padLeft(2, '0')}',
              style: config.reviewTitleTextStyle.copyWith(
                fontSize: config.reviewTitleTextStyle.fontSize! * textScale * 0.45,
                color: config.themeColors.primary.withOpacity(opacity),
                fontWeight: FontWeight.bold,
              ),
            ),
            if (widget.saveSlot != null)
              Flexible(
                child: Text(
                  DateFormat('MM-dd HH:mm').format(widget.saveSlot!.saveTime),
                  style: config.reviewTitleTextStyle.copyWith(
                    fontSize: config.reviewTitleTextStyle.fontSize! * textScale * 0.32,
                    color: config.themeColors.primary.withOpacity(0.6 * opacity),
                    fontWeight: FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        SizedBox(height: 6 * uiScale),
        // 内容区域 - 使用Expanded确保不会溢出
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 截图区域 - 使用更小的宽高比
              Expanded(
                flex: 14,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(0 * uiScale),
                  child: AspectRatio(
                    aspectRatio: 16 / 10, // 从16:9改为16:10，减少高度
                    child: Opacity(
                      opacity: opacity,
                      child: _buildScreenshot(),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8 * uiScale), // 减少间距
              // 文本区域
              Expanded(
                flex: 13,
                child: Text(
                  RichTextParser.cleanText(widget.saveSlot!.dialoguePreview),
                  maxLines: 3, // 减少行数从4到3
                  overflow: TextOverflow.ellipsis,
                  style: config.reviewTitleTextStyle.copyWith(
                    fontSize: config.reviewTitleTextStyle.fontSize! * textScale * 0.36, // 稍微减小字体
                    color: config.themeColors.onSurface.withOpacity(0.8 * opacity),
                    fontWeight: FontWeight.normal,
                    height: 1.2, // 减少行高从1.4到1.2
                  ),
                ),
              ),
            ],
          ),
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
            fontSize: config.reviewTitleTextStyle.fontSize! * textScale * 0.45,
            color: config.themeColors.primary.withOpacity(0.5),
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 6 * uiScale),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min, // 防止溢出
              children: [
                Icon(
                  Icons.add_box_sharp,
                  size: 24 * uiScale, // 减小图标大小
                  color: config.themeColors.primary.withOpacity(0.3),
                ),
                SizedBox(height: 4 * uiScale), // 减少间距
                Text(
                  '空档位',
                  style: config.reviewTitleTextStyle.copyWith(
                    fontSize: config.reviewTitleTextStyle.fontSize! * textScale * 0.36,
                    color: config.themeColors.primary.withOpacity(0.3),
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
