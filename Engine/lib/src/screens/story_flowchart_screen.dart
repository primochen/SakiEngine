import 'package:flutter/material.dart';
import 'package:sakiengine/src/game/story_flowchart_manager.dart';
import 'package:sakiengine/src/utils/binary_serializer.dart';
import 'package:sakiengine/src/widgets/common/overlay_scaffold.dart';
import 'package:sakiengine/src/utils/scaling_manager.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/widgets/common/square_icon_button.dart';
import 'package:sakiengine/src/utils/ui_sound_manager.dart';

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

  @override
  void initState() {
    super.initState();
    _flowchartManager.addListener(_onFlowchartUpdate);
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
    return Row(
      children: [
        // 左侧流程图主体
        Expanded(
          child: _buildFlowchartViewer(uiScale, textScale),
        ),

        // 右侧信息面板
        Container(
          width: 280 * uiScale,
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: SakiEngineConfig().themeColors.primary.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          child: _buildInfoPanel(uiScale, textScale),
        ),
      ],
    );
  }

  /// 构建流程图查看器
  Widget _buildFlowchartViewer(double uiScale, double textScale) {
    final config = SakiEngineConfig();

    return Container(
      color: Colors.black.withOpacity(0.3),
      child: InteractiveViewer(
        transformationController: _transformController,
        boundaryMargin: const EdgeInsets.all(100),
        minScale: 0.1,
        maxScale: 4.0,
        child: Center(
          child: CustomPaint(
            painter: FlowchartPainter(
              nodes: _flowchartManager.nodes.values.toList(),
              currentNodeId: _flowchartManager.currentNode?.id,
              primaryColor: config.themeColors.primary,
            ),
            child: SizedBox(
              width: 2000,
              height: 3000,
              child: _buildNodeWidgets(uiScale, textScale),
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

    return SingleChildScrollView(
      padding: EdgeInsets.all(20 * uiScale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 结局统计卡片
          Container(
            padding: EdgeInsets.all(16 * uiScale),
            decoration: BoxDecoration(
              color: config.themeColors.primary.withOpacity(0.05),
              border: Border.all(
                color: config.themeColors.primary.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.emoji_events,
                  color: config.themeColors.primary,
                  size: 24 * uiScale,
                ),
                SizedBox(width: 12 * uiScale),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '结局达成',
                        style: TextStyle(
                          color: config.themeColors.primary.withOpacity(0.7),
                          fontSize: 12 * textScale,
                        ),
                      ),
                      SizedBox(height: 4 * uiScale),
                      Text(
                        '$unlockedEndings / $totalEndings',
                        style: TextStyle(
                          color: config.themeColors.primary,
                          fontSize: 20 * textScale,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 24 * uiScale),

          // 当前位置
          Text(
            '当前位置',
            style: TextStyle(
              color: config.themeColors.primary,
              fontSize: 16 * textScale,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12 * uiScale),

          if (currentNode != null) ...[
            _buildInfoRow('章节', currentNode.chapterName ?? '-', uiScale, textScale, config),
            _buildInfoRow('位置', currentNode.displayName, uiScale, textScale, config),
            _buildInfoRow('类型', _getNodeTypeText(currentNode.type), uiScale, textScale, config),

            if (currentNode.firstReachedTime != null) ...[
              SizedBox(height: 8 * uiScale),
              Text(
                '首次到达: ${_formatTime(currentNode.firstReachedTime!)}',
                style: TextStyle(
                  color: config.themeColors.primary.withOpacity(0.5),
                  fontSize: 11 * textScale,
                ),
              ),
            ],
          ] else
            Text(
              '暂无数据',
              style: TextStyle(
                color: config.themeColors.primary.withOpacity(0.3),
                fontSize: 14 * textScale,
              ),
            ),

          SizedBox(height: 24 * uiScale),

          // 操作说明
          Text(
            '操作说明',
            style: TextStyle(
              color: config.themeColors.primary,
              fontSize: 16 * textScale,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12 * uiScale),
          _buildHelpItem('鼠标拖动', '移动视图', uiScale, textScale, config),
          _buildHelpItem('滚轮缩放', '放大/缩小', uiScale, textScale, config),
          _buildHelpItem('点击节点', '跳转到该位置', uiScale, textScale, config),

          SizedBox(height: 24 * uiScale),

          // 图例
          Text(
            '图例',
            style: TextStyle(
              color: config.themeColors.primary,
              fontSize: 16 * textScale,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12 * uiScale),
          _buildLegendItem(_getNodeColor(StoryNodeType.chapter, true, config), '章节', uiScale, textScale, config),
          _buildLegendItem(_getNodeColor(StoryNodeType.branch, true, config), '分支选择', uiScale, textScale, config),
          _buildLegendItem(_getNodeColor(StoryNodeType.merge, true, config), '汇合点', uiScale, textScale, config),
          _buildLegendItem(_getNodeColor(StoryNodeType.ending, true, config), '已达成结局', uiScale, textScale, config),
          _buildLegendItem(_getNodeColor(StoryNodeType.ending, false, config), '未达成结局', uiScale, textScale, config),

          SizedBox(height: 16 * uiScale),

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
                          fontSize: 14 * textScale,
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
                fontSize: 13 * textScale,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: config.themeColors.primary,
                fontSize: 13 * textScale,
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
                fontSize: 11 * textScale,
              ),
            ),
          ),
          SizedBox(width: 8 * uiScale),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                color: config.themeColors.primary.withOpacity(0.6),
                fontSize: 11 * textScale,
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
            width: 16 * uiScale,
            height: 16 * uiScale,
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
              fontSize: 13 * textScale,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建节点组件
  Widget _buildNodeWidgets(double uiScale, double textScale) {
    final rootNodes = _flowchartManager.rootNodes;

    return Stack(
      children: [
        for (final rootNode in rootNodes)
          _buildNodeTree(rootNode, 0, rootNodes.indexOf(rootNode), uiScale, textScale),
      ],
    );
  }

  /// 递归构建节点树
  Widget _buildNodeTree(StoryFlowNode node, int depth, int siblingIndex, double uiScale, double textScale) {
    final children = _flowchartManager.getChildNodes(node.id);
    final double x = 100 + depth * 300.0;
    final double y = 100 + siblingIndex * 150.0;

    return Stack(
      children: [
        // 当前节点
        Positioned(
          left: x,
          top: y,
          child: _buildNodeWidget(node, uiScale, textScale),
        ),

        // 子节点
        for (int i = 0; i < children.length; i++)
          _buildNodeTree(children[i], depth + 1, i, uiScale, textScale),
      ],
    );
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
          width: 200,
          padding: EdgeInsets.all(12 * uiScale),
          decoration: BoxDecoration(
            color: node.isUnlocked
                ? color.withOpacity(0.15)
                : color.withOpacity(0.05),
            border: Border.all(
              color: isCurrentNode
                  ? config.themeColors.primary
                  : color.withOpacity(node.isUnlocked ? 0.5 : 0.2),
              width: isCurrentNode ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                node.displayName,
                style: TextStyle(
                  color: node.isUnlocked
                      ? config.themeColors.primary
                      : config.themeColors.primary.withOpacity(0.3),
                  fontSize: 13 * textScale,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4 * uiScale),
              Text(
                _getNodeTypeText(node.type),
                style: TextStyle(
                  color: node.isUnlocked
                      ? color.withOpacity(0.8)
                      : color.withOpacity(0.3),
                  fontSize: 11 * textScale,
                ),
              ),

              if (!node.isUnlocked)
                Container(
                  margin: EdgeInsets.only(top: 8 * uiScale),
                  padding: EdgeInsets.symmetric(horizontal: 6 * uiScale, vertical: 3 * uiScale),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: config.themeColors.primary.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '未解锁',
                    style: TextStyle(
                      color: config.themeColors.primary.withOpacity(0.3),
                      fontSize: 10 * textScale,
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

  FlowchartPainter({
    required this.nodes,
    this.currentNodeId,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = primaryColor.withOpacity(0.2)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // 绘制节点间的连接线
    for (final node in nodes) {
      if (node.parentNodeId != null) {
        final parentNode = nodes.firstWhere(
          (n) => n.id == node.parentNodeId,
          orElse: () => node,
        );

        if (parentNode.id != node.id) {
          // 计算节点位置（需要与 _buildNodeTree 中的计算一致）
          final parentDepth = _calculateDepth(parentNode);
          final nodeDepth = _calculateDepth(node);
          final parentSiblingIndex = _calculateSiblingIndex(parentNode);
          final nodeSiblingIndex = _calculateSiblingIndex(node);

          final double x1 = 100 + parentDepth * 300.0 + 200; // 父节点右边缘
          final double y1 = 100 + parentSiblingIndex * 150.0 + 30; // 父节点中心
          final double x2 = 100 + nodeDepth * 300.0; // 子节点左边缘
          final double y2 = 100 + nodeSiblingIndex * 150.0 + 30; // 子节点中心

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
    }
  }

  void _drawArrow(Canvas canvas, double x, double y, Paint paint) {
    final arrowPaint = Paint()
      ..color = primaryColor.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(x, y);
    path.lineTo(x - 8, y - 5);
    path.lineTo(x - 8, y + 5);
    path.close();

    canvas.drawPath(path, arrowPaint);
  }

  int _calculateDepth(StoryFlowNode node) {
    // 简化计算，实际应根据父节点递归计算
    return 0;
  }

  int _calculateSiblingIndex(StoryFlowNode node) {
    // 简化计算，实际应根据兄弟节点计算
    return 0;
  }

  @override
  bool shouldRepaint(FlowchartPainter oldDelegate) {
    return oldDelegate.currentNodeId != currentNodeId ||
        oldDelegate.nodes.length != nodes.length;
  }
}
