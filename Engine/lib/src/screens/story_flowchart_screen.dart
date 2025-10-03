import 'package:flutter/material.dart';
import 'package:sakiengine/src/game/story_flowchart_manager.dart';
import 'package:sakiengine/src/utils/binary_serializer.dart';
import 'package:sakiengine/src/widgets/common/overlay_scaffold.dart';
import 'package:sakiengine/src/utils/scaling_manager.dart';

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

    return OverlayScaffold(
      title: '剧情流程图',
      onClose: widget.onClose ?? () => Navigator.of(context).pop(),
      content: _buildContent(uiScale),
    );
  }

  /// 构建主要内容
  Widget _buildContent(double uiScale) {
    return Row(
      children: [
        // 左侧流程图主体
        Expanded(
          child: _buildFlowchartViewer(),
        ),

        // 右侧信息面板
        Container(
          width: 280 * uiScale,
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: _buildInfoPanel(uiScale),
        ),
      ],
    );
  }

  /// 构建流程图查看器
  Widget _buildFlowchartViewer() {
    return InteractiveViewer(
      transformationController: _transformController,
      boundaryMargin: const EdgeInsets.all(100),
      minScale: 0.1,
      maxScale: 4.0,
      child: Center(
        child: CustomPaint(
          painter: FlowchartPainter(
            nodes: _flowchartManager.nodes.values.toList(),
            currentNodeId: _flowchartManager.currentNode?.id,
          ),
          child: SizedBox(
            width: 2000,
            height: 3000,
            child: _buildNodeWidgets(),
          ),
        ),
      ),
    );
  }

  /// 信息面板
  Widget _buildInfoPanel(double uiScale) {
    final currentNode = _flowchartManager.currentNode;
    final unlockedEndings = _flowchartManager.getUnlockedEndingsCount();
    final totalEndings = _flowchartManager.getTotalEndingsCount();

    return SingleChildScrollView(
      padding: EdgeInsets.all(20 * uiScale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 结局统计
          Container(
            padding: EdgeInsets.all(16 * uiScale),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8 * uiScale),
            ),
            child: Row(
              children: [
                Icon(Icons.emoji_events, color: Colors.amber, size: 24 * uiScale),
                SizedBox(width: 12 * uiScale),
                Expanded(
                  child: Text(
                    '结局达成\n$unlockedEndings / $totalEndings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16 * uiScale,
                      height: 1.4,
                    ),
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
              color: Colors.white,
              fontSize: 18 * uiScale,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12 * uiScale),

          if (currentNode != null) ...[
            _buildInfoRow('章节', currentNode.chapterName ?? '-', uiScale),
            _buildInfoRow('位置', currentNode.displayName, uiScale),
            _buildInfoRow('类型', _getNodeTypeText(currentNode.type), uiScale),

            if (currentNode.firstReachedTime != null) ...[
              SizedBox(height: 8 * uiScale),
              Text(
                '首次到达: ${_formatTime(currentNode.firstReachedTime!)}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12 * uiScale,
                ),
              ),
            ],
          ] else
            Text(
              '暂无数据',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14 * uiScale,
              ),
            ),

          SizedBox(height: 24 * uiScale),

          // 操作说明
          Text(
            '操作说明',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18 * uiScale,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12 * uiScale),
          _buildHelpItem('鼠标拖动', '移动视图', uiScale),
          _buildHelpItem('滚轮缩放', '放大/缩小', uiScale),
          _buildHelpItem('点击节点', '跳转到该位置', uiScale),

          SizedBox(height: 24 * uiScale),

          // 图例
          Text(
            '图例',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18 * uiScale,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12 * uiScale),
          _buildLegendItem(Colors.blue, '章节', uiScale),
          _buildLegendItem(Colors.orange, '分支选择', uiScale),
          _buildLegendItem(Colors.purple, '汇合点', uiScale),
          _buildLegendItem(Colors.green, '已达成结局', uiScale),
          _buildLegendItem(Colors.grey, '未达成结局', uiScale),

          SizedBox(height: 16 * uiScale),

          // 重置视图按钮
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _transformController.value = Matrix4.identity(),
              icon: Icon(Icons.refresh, size: 20 * uiScale),
              label: Text(
                '重置视图',
                style: TextStyle(fontSize: 14 * uiScale),
              ),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 12 * uiScale),
                backgroundColor: Colors.white.withOpacity(0.1),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, double uiScale) {
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
                color: Colors.white.withOpacity(0.6),
                fontSize: 14 * uiScale,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14 * uiScale,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(String action, String description, double uiScale) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8 * uiScale),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8 * uiScale, vertical: 4 * uiScale),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4 * uiScale),
            ),
            child: Text(
              action,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12 * uiScale,
              ),
            ),
          ),
          SizedBox(width: 8 * uiScale),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12 * uiScale,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, double uiScale) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8 * uiScale),
      child: Row(
        children: [
          Container(
            width: 16 * uiScale,
            height: 16 * uiScale,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4 * uiScale),
            ),
          ),
          SizedBox(width: 8 * uiScale),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14 * uiScale,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建节点组件
  Widget _buildNodeWidgets() {
    final rootNodes = _flowchartManager.rootNodes;

    return Stack(
      children: [
        for (final rootNode in rootNodes)
          _buildNodeTree(rootNode, 0, rootNodes.indexOf(rootNode)),
      ],
    );
  }

  /// 递归构建节点树
  Widget _buildNodeTree(StoryFlowNode node, int depth, int siblingIndex) {
    final children = _flowchartManager.getChildNodes(node.id);
    final double x = 100 + depth * 300.0;
    final double y = 100 + siblingIndex * 150.0;

    return Stack(
      children: [
        // 当前节点
        Positioned(
          left: x,
          top: y,
          child: _buildNodeWidget(node),
        ),

        // 子节点
        for (int i = 0; i < children.length; i++)
          _buildNodeTree(children[i], depth + 1, i),
      ],
    );
  }

  /// 构建单个节点组件
  Widget _buildNodeWidget(StoryFlowNode node) {
    final color = _getNodeColor(node);
    final isCurrentNode = _flowchartManager.currentNode?.id == node.id;

    return GestureDetector(
      onTap: () => _onNodeTapped(node),
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(node.isUnlocked ? 1.0 : 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCurrentNode ? Colors.yellow : Colors.white.withOpacity(0.3),
            width: isCurrentNode ? 3 : 1,
          ),
          boxShadow: isCurrentNode
              ? [
                  BoxShadow(
                    color: Colors.yellow.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              node.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              _getNodeTypeText(node.type),
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),

            if (!node.isUnlocked)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '未解锁',
                  style: TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 节点点击事件
  Future<void> _onNodeTapped(StoryFlowNode node) async {
    if (!node.isUnlocked) {
      // 未解锁节点，显示提示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该节点尚未解锁')),
      );
      return;
    }

    // TODO: 实现从自动存档加载
    // 暂时显示提示信息
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('点击了节点: ${node.displayName}')),
    );

    // 关闭流程图界面
    if (widget.onClose != null) {
      widget.onClose!();
    }
  }

  /// 获取节点颜色
  Color _getNodeColor(StoryFlowNode node) {
    switch (node.type) {
      case StoryNodeType.chapter:
        return Colors.blue;
      case StoryNodeType.branch:
        return Colors.orange;
      case StoryNodeType.merge:
        return Colors.purple;
      case StoryNodeType.ending:
        return node.isUnlocked ? Colors.green : Colors.grey;
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

  FlowchartPainter({
    required this.nodes,
    this.currentNodeId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 2
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
        }
      }
    }
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
