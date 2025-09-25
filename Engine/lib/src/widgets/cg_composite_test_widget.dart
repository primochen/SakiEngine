import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sakiengine/src/utils/cg_image_compositor.dart';

/// CG合成测试工具 - 用于验证图像合成功能
class CgCompositeTestWidget extends StatefulWidget {
  const CgCompositeTestWidget({super.key});

  @override
  State<CgCompositeTestWidget> createState() => _CgCompositeTestWidgetState();
}

class _CgCompositeTestWidgetState extends State<CgCompositeTestWidget> {
  final TextEditingController _resourceController = TextEditingController(text: 'xiayo1');
  final TextEditingController _poseController = TextEditingController(text: 'pose1');
  final TextEditingController _expressionController = TextEditingController(text: 'happy');
  
  String _lastCompositePath = '';
  String _testOutput = '';
  Map<String, dynamic> _cacheStats = {};
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _refreshCacheStats();
  }

  Future<void> _testComposition() async {
    setState(() {
      _isProcessing = true;
      _testOutput = '开始合成测试...';
    });

    try {
      final resourceId = _resourceController.text.trim();
      final pose = _poseController.text.trim();
      final expression = _expressionController.text.trim();

      if (resourceId.isEmpty || pose.isEmpty || expression.isEmpty) {
        setState(() {
          _testOutput = '❌ 请填写完整的参数';
          _isProcessing = false;
        });
        return;
      }

      print('[CgCompositeTest] 测试参数: $resourceId, $pose, $expression');
      
      final compositor = CgImageCompositor();
      final startTime = DateTime.now();
      
      final compositePath = await compositor.getCompositeImagePath(
        resourceId: resourceId,
        pose: pose,
        expression: expression,
      );

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime).inMilliseconds;

      if (compositePath != null) {
        setState(() {
          _lastCompositePath = compositePath;
          _testOutput = '''✅ 合成成功！
资源: $resourceId
姿势: $pose  
表情: $expression
耗时: ${duration}ms
路径: $compositePath''';
        });
        
        // 验证文件是否存在
        await _verifyCompositeFile(compositePath);
        await _refreshCacheStats();
      } else {
        setState(() {
          _testOutput = '''❌ 合成失败
资源: $resourceId
姿势: $pose
表情: $expression
耗时: ${duration}ms''';
        });
      }
    } catch (e) {
      setState(() {
        _testOutput = '❌ 合成过程发生错误: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _verifyCompositeFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        final stat = await file.stat();
        final sizeKB = (stat.size / 1024).round();
        
        setState(() {
          _testOutput = _testOutput + '\n验证: 文件存在，大小 ${sizeKB}KB';
        });
        
        print('[CgCompositeTest] ✅ 文件验证成功: $path (${sizeKB}KB)');
      } else {
        setState(() {
          _testOutput = _testOutput + '\n❌ 验证失败: 文件不存在';
        });
        
        print('[CgCompositeTest] ❌ 文件验证失败: $path');
      }
    } catch (e) {
      setState(() {
        _testOutput = _testOutput + '\n❌ 验证过程出错: $e';
      });
    }
  }

  Future<void> _refreshCacheStats() async {
    try {
      final stats = await CgImageCompositor().getCacheStats();
      setState(() {
        _cacheStats = stats;
      });
    } catch (e) {
      print('[CgCompositeTest] 获取缓存统计失败: $e');
    }
  }

  Future<void> _clearCache() async {
    try {
      await CgImageCompositor().clearCache();
      await _refreshCacheStats();
      setState(() {
        _testOutput = '✅ 缓存已清理';
        _lastCompositePath = '';
      });
    } catch (e) {
      setState(() {
        _testOutput = '❌ 清理缓存失败: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CG合成测试工具'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 参数输入区域
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('测试参数', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _resourceController,
                            decoration: const InputDecoration(
                              labelText: '资源ID',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _poseController,
                            decoration: const InputDecoration(
                              labelText: '姿势',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _expressionController,
                            decoration: const InputDecoration(
                              labelText: '表情',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _testComposition,
                          icon: _isProcessing 
                              ? const SizedBox(
                                  width: 16, 
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ) 
                              : const Icon(Icons.play_arrow),
                          label: Text(_isProcessing ? '合成中...' : '开始合成测试'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _clearCache,
                          icon: const Icon(Icons.clear_all),
                          label: const Text('清理缓存'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _refreshCacheStats,
                          icon: const Icon(Icons.refresh),
                          label: const Text('刷新统计'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 测试输出区域
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('测试输出', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      height: 150,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          _testOutput.isEmpty ? '等待测试...' : _testOutput,
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 缓存统计区域
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('缓存统计', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    if (_cacheStats.isNotEmpty) ...[
                      Text('缓存目录: ${_cacheStats['cache_dir'] ?? 'N/A'}'),
                      Text('目录存在: ${_cacheStats['exists'] == true ? '是' : '否'}'),
                      Text('缓存文件数: ${_cacheStats['file_count'] ?? 0}'),
                      Text('总大小: ${(_cacheStats['total_size'] ?? 0) ~/ 1024}KB'),
                      Text('内存缓存: ${_cacheStats['memory_cache_count'] ?? 0}'),
                      Text('合成任务: ${_cacheStats['compositing_tasks'] ?? 0}'),
                    ] else
                      const Text('加载中...'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}