import 'package:flutter/foundation.dart';
import 'package:sakiengine/src/game/save_load_manager.dart';
import 'package:sakiengine/src/game/story_flowchart_manager.dart';
import 'package:sakiengine/src/utils/binary_serializer.dart';

/// 章节自动存档管理器
///
/// 负责管理章节开头的自动存档逻辑：
/// 1. 检测章节开头label（cp0_001, cp1_001等）
/// 2. 在该label后的第一句对话显示后创建存档
/// 3. 生成符合剧情流程图结构的存档ID
class ChapterAutoSaveManager {
  /// 已经创建过存档的章节集合
  final Set<String> _savedChapters = {};

  /// 刚刚经过的label（用于检测下一句对话是否是章节第一句）
  String? _lastSeenLabel;

  /// 检测label是否是章节开头
  ///
  /// 检测规则：cp{数字}_001（如 cp0_001, cp1_001, cp2_001）
  bool isChapterStartLabel(String? label) {
    if (label == null) return false;
    return RegExp(r'^cp\d+_001$').hasMatch(label);
  }

  /// 当经过label时调用（在_executeScript中检测到LabelNode时调用）
  void onLabelPassed(String labelName) {
    _lastSeenLabel = labelName;

    if (kDebugMode) {
      print('[ChapterAutoSave] 📌 经过label: $labelName');
    }
  }

  /// 从label提取章节编号
  ///
  /// 例如：cp0_001 -> 0, cp1_001 -> 1
  String? extractChapterNumberFromLabel(String? label) {
    if (label == null) return null;

    final chapterMatch = RegExp(r'^cp(\d+)_001$').firstMatch(label);
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

  /// 当显示对话时调用
  /// 如果刚刚经过了章节开头label，则为该对话创建存档
  Future<void> onDialogueDisplayed({
    required int scriptIndex,
    required String currentScriptFile,
    required String? currentLabel,
    required dynamic Function() saveStateSnapshot,
    required StoryFlowchartManager flowchartManager,
  }) async {
    if (kDebugMode) {
      print('[ChapterAutoSave] 📢 对话显示 - currentLabel=$currentLabel, lastSeenLabel=$_lastSeenLabel');
    }

    // 检查刚刚经过的label是否是章节开头
    if (_lastSeenLabel == null || !isChapterStartLabel(_lastSeenLabel)) {
      return; // 不是章节开头，跳过
    }

    if (kDebugMode) {
      print('[ChapterAutoSave] ✅ 检测到章节开头label后的第一句对话: $_lastSeenLabel');
    }

    try {
      final chapterNum = extractChapterNumberFromLabel(_lastSeenLabel);
      if (chapterNum == null) {
        if (kDebugMode) {
          print('[ChapterAutoSave] ❌ 无法从label提取章节编号: $_lastSeenLabel');
        }
        _lastSeenLabel = null;
        return;
      }

      final nodeId = 'chapter_$chapterNum';

      // 检查是否已经创建过存档
      if (_savedChapters.contains(nodeId)) {
        if (kDebugMode) {
          print('[ChapterAutoSave] ⏭️ 章节 $chapterNum 已创建过存档，跳过');
        }
        _lastSeenLabel = null;
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
      _savedChapters.add(nodeId);

      if (kDebugMode) {
        print('[ChapterAutoSave] ✅ 章节存档创建成功: $displayName (autoSaveId: $actualAutoSaveId)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ChapterAutoSave] ❌ 创建章节存档失败: $e');
      }
    } finally {
      // 清除标记，避免下一句对话重复创建
      _lastSeenLabel = null;
    }
  }

  /// 重置管理器状态
  void reset() {
    _savedChapters.clear();
    _lastSeenLabel = null;
  }
}
