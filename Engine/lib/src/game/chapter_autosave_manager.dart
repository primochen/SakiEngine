import 'package:flutter/foundation.dart';
import 'package:sakiengine/src/game/save_load_manager.dart';
import 'package:sakiengine/src/game/story_flowchart_manager.dart';
import 'package:sakiengine/src/utils/binary_serializer.dart';

/// 章节自动存档管理器
///
/// 负责管理章节开头的自动存档逻辑：
/// 1. 检测章节开头的第一句对话（基于label，如 cp0_start, cp1_start）
/// 2. 为每个章节创建自动存档
/// 3. 生成符合剧情流程图结构的存档ID
class ChapterAutoSaveManager {
  /// 已经创建过存档的章节集合
  final Set<String> _savedChapters = {};

  /// 检测label是否是章节开头
  ///
  /// 检测规则：
  /// - cp{数字}_start（如 cp0_start, cp1_start）
  /// - start（特殊情况，视为第0章开头）
  bool isChapterStart(String? label) {
    if (label == null) return false;

    // 特殊情况：start label 视为第0章开头
    if (label == 'start') return true;

    // 标准格式：cp{数字}_start
    return RegExp(r'^cp\d+_start$').hasMatch(label);
  }

  /// 从label提取章节编号
  ///
  /// 例如：
  /// - cp0_start -> 0
  /// - cp1_start -> 1
  /// - start -> 0（特殊处理）
  String? extractChapterNumberFromLabel(String? label) {
    if (label == null) return null;

    // 特殊情况：start label 视为第0章
    if (label == 'start') return '0';

    final chapterMatch = RegExp(r'^cp(\d+)_').firstMatch(label);
    if (chapterMatch != null) {
      return chapterMatch.group(1);
    }

    return null;
  }

  /// 生成章节存档的节点ID
  ///
  /// 格式：chapter_{number}
  /// 例如：chapter_0, chapter_1, chapter_2
  String? generateChapterNodeId(String? label) {
    final chapterNum = extractChapterNumberFromLabel(label);
    if (chapterNum == null) return null;

    return 'chapter_$chapterNum';
  }

  /// 检查章节是否已经创建过存档
  bool hasChapterSaved(String chapterNodeId) {
    return _savedChapters.contains(chapterNodeId);
  }

  /// 标记章节已创建存档
  void markChapterSaved(String chapterNodeId) {
    _savedChapters.add(chapterNodeId);
  }

  /// 当显示对话时调用
  /// 检查是否是章节开头的第一句对话，如果是则创建存档
  Future<void> onDialogueDisplayed({
    required int scriptIndex,
    required String currentScriptFile,
    required String? currentLabel,
    required dynamic Function() saveStateSnapshot,
    required StoryFlowchartManager flowchartManager,
  }) async {
    if (kDebugMode) {
      print('[ChapterAutoSave] 📢 对话显示 - label=$currentLabel');
    }

    // 检查是否是章节开头
    if (!isChapterStart(currentLabel)) {
      return; // 不是章节开头，跳过
    }

    if (kDebugMode) {
      print('[ChapterAutoSave] ✅ 检测到章节开头label: $currentLabel');
    }

    try {
      final chapterNum = extractChapterNumberFromLabel(currentLabel);
      if (chapterNum == null) {
        if (kDebugMode) {
          print('[ChapterAutoSave] ❌ 无法从label提取章节编号: $currentLabel');
        }
        return;
      }

      final nodeId = 'chapter_$chapterNum';

      // 检查是否已经创建过存档
      if (hasChapterSaved(nodeId)) {
        if (kDebugMode) {
          print('[ChapterAutoSave] ⏭️ 章节 $chapterNum 已创建过存档，跳过');
        }
        return;
      }

      final displayName = '第${chapterNum}章';

      if (kDebugMode) {
        print('[ChapterAutoSave] 🎯 创建章节存档: $displayName (nodeId: $nodeId, scriptIndex: $scriptIndex)');
      }

      // 创建自动存档
      final saveSlot = SaveSlot(
        id: int.parse(DateTime.now().millisecondsSinceEpoch.toString().substring(0, 10)),
        saveTime: DateTime.now(),
        currentScript: currentScriptFile,
        dialoguePreview: displayName,
        snapshot: saveStateSnapshot(),
        screenshotData: null,
      );

      // 保存到流程图管理器
      final actualAutoSaveId = await flowchartManager.createAutoSaveForNode(nodeId, saveSlot);

      // 解锁节点
      await flowchartManager.unlockNode(nodeId, autoSaveId: actualAutoSaveId);

      // 标记已创建
      markChapterSaved(nodeId);

      if (kDebugMode) {
        print('[ChapterAutoSave] ✅ 章节存档创建成功: $displayName (autoSaveId: $actualAutoSaveId)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ChapterAutoSave] ❌ 创建章节存档失败: $e');
      }
    }
  }

  /// 重置管理器状态
  void reset() {
    _savedChapters.clear();
  }
}
