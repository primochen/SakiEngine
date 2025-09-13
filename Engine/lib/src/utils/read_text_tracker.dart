import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 已读文本跟踪器
/// 
/// 记录哪些对话文本已经被用户阅读过，用于实现"跳过已读文本"功能
/// 与现有的Ctrl强制快进功能区分开来
class ReadTextTracker extends ChangeNotifier {
  static ReadTextTracker? _instance;
  static ReadTextTracker get instance => _instance ??= ReadTextTracker._();
  
  ReadTextTracker._();
  
  // 存储已读对话的标识符集合
  // 使用对话内容的哈希值作为唯一标识
  final Set<String> _readDialogues = <String>{};
  
  // 存储键名
  static const String _storageKey = 'read_dialogues';
  
  /// 初始化，从本地存储加载已读记录
  Future<void> initialize() async {
    await _loadFromStorage();
  }
  
  /// 标记对话为已读
  /// [speaker] 说话者名字（可选）
  /// [dialogue] 对话内容
  /// [scriptIndex] 脚本索引（用于更精确的标识）
  void markAsRead(String? speaker, String dialogue, int scriptIndex) {
    if (dialogue.trim().isEmpty) {
      print('[ReadTextTracker] 跳过空对话');
      return;
    }
    
    // 创建唯一标识符，结合说话者、对话内容和脚本索引
    final identifier = _createIdentifier(speaker, dialogue, scriptIndex);
    print('[ReadTextTracker] 生成标识符: $identifier');
    
    if (!_readDialogues.contains(identifier)) {
      _readDialogues.add(identifier);
      print('[ReadTextTracker] 新增已读: $identifier (总数: ${_readDialogues.length})');
      print('[ReadTextTracker] 当前实例hashCode: ${hashCode}');
      _saveToStorage();
      notifyListeners();
    } else {
      print('[ReadTextTracker] 已存在，跳过: $identifier');
    }
  }
  
  /// 检查对话是否已读
  /// [speaker] 说话者名字（可选）
  /// [dialogue] 对话内容
  /// [scriptIndex] 脚本索引
  bool isRead(String? speaker, String dialogue, int scriptIndex) {
    if (dialogue.trim().isEmpty) return false;
    
    final identifier = _createIdentifier(speaker, dialogue, scriptIndex);
    return _readDialogues.contains(identifier);
  }
  
  /// 创建对话的唯一标识符
  String _createIdentifier(String? speaker, String dialogue, int scriptIndex) {
    // 结合说话者、对话内容和脚本索引创建唯一标识
    final speakerPart = speaker ?? '';
    final content = '$speakerPart|$dialogue|$scriptIndex';
    
    // 使用简单的哈希算法减少存储空间
    return content.hashCode.toString();
  }
  
  /// 获取已读对话数量
  int get readCount => _readDialogues.length;
  
  /// 清除所有已读记录
  Future<void> clearAllReadRecords() async {
    print('[ReadTextTracker] 清除前: ${_readDialogues.length} 条已读记录');
    print('[ReadTextTracker] 当前实例hashCode: ${hashCode}');
    print('[ReadTextTracker] 清除前的前5个记录: ${_readDialogues.take(5).toList()}');
    
    _readDialogues.clear();
    await _saveToStorage();
    
    print('[ReadTextTracker] 清除后: ${_readDialogues.length} 条已读记录');
    print('[ReadTextTracker] 清除操作完成');
    
    notifyListeners();
  }
  
  /// 从本地存储加载已读记录
  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      print('[ReadTextTracker] 开始加载，存储键: $_storageKey');
      final jsonString = prefs.getString(_storageKey) ?? '';
      print('[ReadTextTracker] 从存储读取的原始字符串: "$jsonString"');
      print('[ReadTextTracker] 字符串长度: ${jsonString.length}');
      
      if (jsonString.isNotEmpty) {
        final List<dynamic> readList = jsonDecode(jsonString);
        print('[ReadTextTracker] 解析后的列表: $readList');
        _readDialogues.clear();
        _readDialogues.addAll(readList.cast<String>());
        print('[ReadTextTracker] 从存储加载: ${_readDialogues.length} 条已读记录');
      } else {
        print('[ReadTextTracker] 存储为空，无已读记录');
      }
    } catch (e) {
      print('[ReadTextTracker] 加载已读记录异常: $e');
      if (kDebugMode) {
        print('加载已读记录失败: $e');
      }
    }
  }
  
  /// 保存已读记录到本地存储
  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(_readDialogues.toList());
      print('[ReadTextTracker] 准备保存JSON: $jsonString');
      
      final success = await prefs.setString(_storageKey, jsonString);
      print('[ReadTextTracker] SharedPreferences保存结果: $success');
      print('[ReadTextTracker] 保存到存储: ${_readDialogues.length} 条已读记录');
      
      // 验证是否真的保存成功
      final verification = prefs.getString(_storageKey);
      print('[ReadTextTracker] 验证读取: ${verification?.length ?? 0} 字符');
    } catch (e) {
      print('[ReadTextTracker] 保存已读记录失败: $e');
      if (kDebugMode) {
        print('保存已读记录失败: $e');
      }
    }
  }
  
  /// 导出已读记录（用于备份）
  Map<String, dynamic> exportReadRecords() {
    return {
      'version': 1,
      'readCount': _readDialogues.length,
      'readDialogues': _readDialogues.toList(),
      'exportTime': DateTime.now().toIso8601String(),
    };
  }
  
  /// 导入已读记录（用于恢复）
  Future<void> importReadRecords(Map<String, dynamic> data) async {
    try {
      final List<dynamic> readList = data['readDialogues'] ?? [];
      _readDialogues.clear();
      _readDialogues.addAll(readList.cast<String>());
      await _saveToStorage();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('导入已读记录失败: $e');
      }
    }
  }
}