import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:sakiengine/src/game/story_flowchart_manager.dart';
import 'package:sakiengine/src/utils/binary_serializer.dart';
import 'package:sakiengine/src/widgets/common/overlay_scaffold.dart';
import 'package:sakiengine/src/utils/scaling_manager.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/widgets/common/square_icon_button.dart';
import 'package:sakiengine/src/utils/ui_sound_manager.dart';
import 'package:sakiengine/src/widgets/game_style_dropdown.dart';

/// 剧情流程图界面
class StoryFlowchartScreen extends StatefulWidget {
  final VoidCallback? onClose;
  final Function(SaveSlot)? onLoadSave;

  const StoryFlowchartScreen({
    Key? key,
    this.onClose,
    this.onLoadSave,
  }) : super(key: key);

  @override
  State<StoryFlowchartScreen> createState() => _StoryFlowchartScreenState();
}

class _StoryFlowchartScreenState extends State<StoryFlowchartScreen> {
  final StoryFlowchartManager _flowchartManager = StoryFlowchartManager();
  final TransformationController _transformController = TransformationController();
  final UISoundManager _uiSoundManager = UISoundManager();

  String? _selectedChapter; // 当前选中的章节

  @override
  void initState() {
    super.initState();
    _flowchartManager.addListener(_onFlowchartUpdate);
    // 初始化时选择第一个章节
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chapters = _getAvailableChapters();
      if (chapters.isNotEmpty && _selectedChapter == null) {
        setState(() {
          _selectedChapter = chapters.first;
        });
      }
    });
  }

  @override
  void dispose() {
    _flowchartManager.removeListener(_onFlowchartUpdate);
    _transformController.dispose();
    super.dispose();
  }

  void _onFlowchartUpdate() {
    setState(() {});
  }

  /// 获取所有可用的章节
  List<String> _getAvailableChapters() {
    final allNodes = _flowchartManager.nodes.values;
    final chapterNames = allNodes
        .where((node) => node.chapterName != null)
        .map((node) => node.chapterName!)
        .toSet()
        .toList();
    chapterNames.sort();
    return chapterNames;
  }

  /// 获取当前章节的所有节点
  List<StoryFlowNode> _getNodesForCurrentChapter() {
    if (_selectedChapter == null) return [];
    return _flowchartManager.nodes.values
        .where((node) => node.chapterName == _selectedChapter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final uiScale = context.scaleFor(ComponentType.ui);
    final textScale = context.scaleFor(ComponentType.text);

    return OverlayScaffold(
      title: '剧情流程图',
      onClose: widget.onClose ?? () => Navigator.of(context).pop(),
      content: _buildContent(uiScale, textScale),
    );
  }

  /// 构建主要内容
  Widget _buildContent(double uiScale, double textScale) {
    return Stack(
      children: [
        // 流程图主体（全屏）
        _buildFlowchartViewer(uiScale, textScale),

        // 右侧信息面板（顶对齐，毛玻璃背景）
        Positioned(
          top: 0,
          right: 0,
          bottom: 0, // 让面板上下铺满
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // 真正的毛玻璃模糊效果
              child: Container(
                width: 280 * uiScale,
                decoration: BoxDecoration(
                  color: SakiEngineConfig().themeColors.background.withOpacity(0.7), // 半透明背景
                  border: Border(
                    left: BorderSide(
                      color: SakiEngineConfig().themeColors.primary.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: _buildInfoPanel(uiScale, textScale),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 构建流程图查看器
  Widget _buildFlowchartViewer(double uiScale, double textScale) {
    final config = SakiEngineConfig();

    // 只获取当前章节的节点
    final currentChapterNodes = _getNodesForCurrentChapter();
    final rootNodes = currentChapterNodes
        .where((node) => node.type == StoryNodeType.chapter)
        .toList();

    // 计算所有节点的布局信息
    final layoutInfo = _calculateLayout(rootNodes);

    return ClipRect( // 添加裁剪，防止内容超出边界
      child: Container(
        color: Colors.transparent, // 移除黑色遮罩，改为透明
        child: InteractiveViewer(
          transformationController: _transformController,
          // 无边界限制 - 移除boundaryMargin让用户可以无限平移
          constrained: false, // 关键：允许子组件超出视图边界
          minScale: 0.1,
          maxScale: 4.0,
          clipBehavior: Clip.hardEdge, // 改为硬边缘裁剪，防止内容溢出
          child: CustomPaint(
            painter: FlowchartPainter(
              nodes: currentChapterNodes,
              currentNodeId: _flowchartManager.currentNode?.id,
              primaryColor: config.themeColors.primary,
              layoutInfo: layoutInfo, // 传递布局信息
            ),
            child: SizedBox(
              width: 20000, // 极大的宽度，支持任意多的深度
              height: 20000, // 极大的高度，支持任意多的节点
              child: _buildNodeWidgets(uiScale, textScale, layoutInfo),
            ),
          ),
        ),
      ),
    );
  }

  /// 信息面板
  Widget _buildInfoPanel(double uiScale, double textScale) {
    final currentNode = _flowchartManager.currentNode;
    final unlockedEndings = _flowchartManager.getUnlockedEndingsCount();
    final totalEndings = _flowchartManager.getTotalEndingsCount();
    final config = SakiEngineConfig();
    final availableChapters = _getAvailableChapters();

    return Container(
      padding: EdgeInsets.all(20 * uiScale),
      child: Column(
        mainAxisSize: MainAxisSize.min, // 让面板不垂直拉伸
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 章节选择下拉菜单
          if (availableChapters.isNotEmpty) ...[
            Text(
              '选择章节',
              style: TextStyle(
                color: config.themeColors.primary,
                fontSize: 18 * textScale,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12 * uiScale),
            GameStyleDropdown<String>(
              items: availableChapters.map((chapter) {
                return GameStyleDropdownItem<String>(
                  value: chapter,
                  label: chapter,
                );
              }).toList(),
              value: _selectedChapter ?? availableChapters.first,
              onChanged: (newChapter) {
                setState(() {
                  _selectedChapter = newChapter;
                  _transformController.value = Matrix4.identity(); // 重置视图
                });
              },
              scale: uiScale,
              textScale: textScale,
              config: config,
              width: 240 * uiScale, // 固定宽度，下拉列表会自动匹配
            ),
            SizedBox(height: 24 * uiScale),
          ],

          // 重置视图按钮
          SizedBox(
            width: double.infinity,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  _uiSoundManager.playButtonClick();
                  _transformController.value = Matrix4.identity();
                },
                onHover: (hovering) {
                  if (hovering) {
                    _uiSoundManager.playButtonHover();
                  }
                },
                hoverColor: config.themeColors.primary.withOpacity(0.1),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 12 * uiScale),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: config.themeColors.primary.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.refresh,
                        size: 20 * uiScale,
                        color: config.themeColors.primary,
                      ),
                      SizedBox(width: 8 * uiScale),
                      Text(
                        '重置视图',
                        style: TextStyle(
                          fontSize: 16 * textScale, // 增大字体
                          color: config.themeColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, double uiScale, double textScale, SakiEngineConfig config) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8 * uiScale),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60 * uiScale,
            child: Text(
              '$label:',
              style: TextStyle(
                color: config.themeColors.primary.withOpacity(0.5),
                fontSize: 15 * textScale, // 增大字体
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: config.themeColors.primary,
                fontSize: 15 * textScale, // 增大字体
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(String action, String description, double uiScale, double textScale, SakiEngineConfig config) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8 * uiScale),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8 * uiScale, vertical: 4 * uiScale),
            decoration: BoxDecoration(
              border: Border.all(
                color: config.themeColors.primary.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              action,
              style: TextStyle(
                color: config.themeColors.primary,
                fontSize: 13 * textScale, // 增大字体
              ),
            ),
          ),
          SizedBox(width: 8 * uiScale),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                color: config.themeColors.primary.withOpacity(0.6),
                fontSize: 13 * textScale, // 增大字体
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, double uiScale, double textScale, SakiEngineConfig config) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8 * uiScale),
      child: Row(
        children: [
          Container(
            width: 20 * uiScale, // 增大图例色块
            height: 20 * uiScale,
            decoration: BoxDecoration(
              color: color,
              border: Border.all(
                color: config.themeColors.primary.withOpacity(0.3),
                width: 1,
              ),
            ),
          ),
          SizedBox(width: 8 * uiScale),
          Text(
            label,
            style: TextStyle(
              color: config.themeColors.primary.withOpacity(0.8),
              fontSize: 15 * textScale, // 增大字体
            ),
          ),
        ],
      ),
    );
  }

  /// 构建节点组件
  Widget _buildNodeWidgets(double uiScale, double textScale, Map<String, Map<String, double>> layoutInfo) {
    return Stack(
      clipBehavior: Clip.none, // 不裁切超出边界的内容
      children: [
        for (final entry in layoutInfo.entries)
          Positioned(
            left: entry.value['x'] as double,
            top: entry.value['y'] as double,
            child: _buildNodeWidget(
              _flowchartManager.nodes[entry.key]!,
              uiScale,
              textScale,
            ),
          ),
      ],
    );
  }

  /// 计算节点布局（避免重叠）
  Map<String, Map<String, double>> _calculateLayout(List<StoryFlowNode> rootNodes) {
    final Map<String, Map<String, double>> layoutInfo = {};
    final Map<int, int> depthCounters = {}; // 每个深度的节点计数器

    // 获取当前章节的所有节点，用于查找子节点
    final currentChapterNodes = _getNodesForCurrentChapter();
    final nodesMap = {for (var n in currentChapterNodes) n.id: n};

    void layoutNode(StoryFlowNode node, int depth, int siblingIndex) {
      // 计算该深度已有多少节点
      depthCounters[depth] = (depthCounters[depth] ?? 0);
      final actualY = depthCounters[depth]!;

      // 更新深度计数器
      depthCounters[depth] = actualY + 1;

      final double x = 100 + depth * 400.0;
      final double y = 100 + actualY * 200.0;

      layoutInfo[node.id] = {'x': x, 'y': y, 'depth': depth.toDouble()};

      // 递归处理子节点（只在当前章节中查找）
      final children = node.childNodeIds
          .map((id) => nodesMap[id])
          .whereType<StoryFlowNode>()
          .toList();
      for (int i = 0; i < children.length; i++) {
        layoutNode(children[i], depth + 1, i);
      }
    }

    // 从所有根节点开始布局
    for (int i = 0; i < rootNodes.length; i++) {
      layoutNode(rootNodes[i], 0, i);
    }

    return layoutInfo;
  }

  /// 构建单个节点组件
  Widget _buildNodeWidget(StoryFlowNode node, double uiScale, double textScale) {
    final config = SakiEngineConfig();
    final color = _getNodeColor(node.type, node.isUnlocked, config);
    final isCurrentNode = _flowchartManager.currentNode?.id == node.id;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onNodeTapped(node),
        onHover: (hovering) {
          if (hovering) {
            _uiSoundManager.playButtonHover();
          }
        },
        hoverColor: config.themeColors.primary.withOpacity(0.1),
        child: Container(
          width: 280, // 节点宽度
          padding: EdgeInsets.all(16 * uiScale),
          decoration: BoxDecoration(
            // 大幅增加背景不透明度，提高对比度
            color: node.isUnlocked
                ? color.withOpacity(0.6) // 从0.15增加到0.6
                : color.withOpacity(0.3),  // 从0.05增加到0.3
            border: Border.all(
              color: isCurrentNode
                  ? config.themeColors.primary
                  : color.withOpacity(node.isUnlocked ? 0.8 : 0.5), // 增加边框不透明度
              width: isCurrentNode ? 3 : 2, // 增粗边框
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                node.displayName,
                style: TextStyle(
                  // 完全不透明的白色
                  color: Colors.white,
                  fontSize: 16 * textScale,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 6 * uiScale),
              Text(
                _getNodeTypeText(node.type),
                style: TextStyle(
                  // 完全不透明的白色
                  color: Colors.white,
                  fontSize: 14 * textScale,
                ),
              ),

              if (!node.isUnlocked)
                Container(
                  margin: EdgeInsets.only(top: 8 * uiScale),
                  padding: EdgeInsets.symmetric(horizontal: 8 * uiScale, vertical: 4 * uiScale),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3), // 添加背景色
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '未解锁',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12 * textScale,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 节点点击事件
  Future<void> _onNodeTapped(StoryFlowNode node) async {
    _uiSoundManager.playButtonClick();

    if (!node.isUnlocked) {
      // 未解锁节点，显示提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '该节点尚未解锁',
            style: TextStyle(color: SakiEngineConfig().themeColors.primary),
          ),
          backgroundColor: Colors.black.withOpacity(0.8),
        ),
      );
      return;
    }

    // TODO: 实现从自动存档加载
    // 暂时显示提示信息
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '点击了节点: ${node.displayName}',
          style: TextStyle(color: SakiEngineConfig().themeColors.primary),
        ),
        backgroundColor: Colors.black.withOpacity(0.8),
      ),
    );

    // 关闭流程图界面
    if (widget.onClose != null) {
      widget.onClose!();
    }
  }

  /// 获取节点颜色
  Color _getNodeColor(StoryNodeType type, bool isUnlocked, SakiEngineConfig config) {
    final primary = config.themeColors.primary;

    switch (type) {
      case StoryNodeType.chapter:
        return primary.withOpacity(0.8); // 章节用主题色
      case StoryNodeType.branch:
        return Color.lerp(primary, Colors.orange, 0.3)!; // 分支用橙色调
      case StoryNodeType.merge:
        return Color.lerp(primary, Colors.purple, 0.3)!; // 汇合用紫色调
      case StoryNodeType.ending:
        return isUnlocked
            ? Color.lerp(primary, Colors.green, 0.3)! // 已达成结局用绿色调
            : primary.withOpacity(0.2); // 未达成结局用灰色
    }
  }

  /// 获取节点类型文本
  String _getNodeTypeText(StoryNodeType type) {
    switch (type) {
      case StoryNodeType.chapter:
        return '章节';
      case StoryNodeType.branch:
        return '分支';
      case StoryNodeType.merge:
        return '汇合';
      case StoryNodeType.ending:
        return '结局';
    }
  }

  /// 格式化时间
  String _formatTime(DateTime time) {
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

/// 流程图画笔（绘制连接线）
class FlowchartPainter extends CustomPainter {
  final List<StoryFlowNode> nodes;
  final String? currentNodeId;
  final Color primaryColor;
  final Map<String, Map<String, double>> layoutInfo; // 新增：布局信息

  FlowchartPainter({
    required this.nodes,
    this.currentNodeId,
    required this.primaryColor,
    required this.layoutInfo, // 新增：接收布局信息
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = primaryColor.withOpacity(0.3) // 增加线条不透明度，更清晰
      ..strokeWidth = 2.5 // 增粗线条
      ..style = PaintingStyle.stroke;

    // 绘制节点间的连接线
    for (final node in nodes) {
      // 特殊处理汇合点：绘制所有分支到汇合点的连接线
      if (node.type == StoryNodeType.merge && node.metadata != null) {
        final parentIds = node.metadata!['parentIds'] as List<dynamic>?;
        if (parentIds != null && parentIds.isNotEmpty) {
          // 绘制每个父节点到汇合点的连接线
          for (final parentId in parentIds) {
            final parentNode = nodes.firstWhere(
              (n) => n.id == parentId,
              orElse: () => node,
            );
            if (parentNode.id != node.id) {
              _drawConnection(canvas, paint, parentNode, node);
            }
          }
        }
      }
      // 处理普通的父子关系（非汇合点）
      else if (node.parentNodeId != null) {
        final parentNode = nodes.firstWhere(
          (n) => n.id == node.parentNodeId,
          orElse: () => node,
        );

        if (parentNode.id != node.id) {
          _drawConnection(canvas, paint, parentNode, node);
        }
      }
    }
  }

  /// 绘制两个节点之间的连接线
  void _drawConnection(Canvas canvas, Paint paint, StoryFlowNode parentNode, StoryFlowNode childNode) {
    // 使用布局信息获取精确位置
    final parentLayout = layoutInfo[parentNode.id];
    final childLayout = layoutInfo[childNode.id];

    if (parentLayout != null && childLayout != null) {
      final double x1 = parentLayout['x']! + 280; // 父节点右边缘
      final double y1 = parentLayout['y']! + 40; // 父节点中心（节点高度的一半）
      final double x2 = childLayout['x']!; // 子节点左边缘
      final double y2 = childLayout['y']! + 40; // 子节点中心

      // 绘制贝塞尔曲线
      final path = Path();
      path.moveTo(x1, y1);
      path.cubicTo(
        x1 + 50, y1,
        x2 - 50, y2,
        x2, y2,
      );

      canvas.drawPath(path, paint);

      // 在线的终点绘制箭头
      _drawArrow(canvas, x2 - 10, y2, paint);
    }
  }

  void _drawArrow(Canvas canvas, double x, double y, Paint paint) {
    final arrowPaint = Paint()
      ..color = primaryColor.withOpacity(0.5) // 增加箭头不透明度
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(x, y);
    path.lineTo(x - 10, y - 6); // 增大箭头尺寸
    path.lineTo(x - 10, y + 6);
    path.close();

    canvas.drawPath(path, arrowPaint);
  }

  @override
  bool shouldRepaint(FlowchartPainter oldDelegate) {
    return oldDelegate.currentNodeId != currentNodeId ||
        oldDelegate.nodes.length != nodes.length;
  }
}
