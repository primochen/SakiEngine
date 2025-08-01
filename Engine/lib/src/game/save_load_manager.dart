import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sakiengine/src/game/game_manager.dart';
import 'package:sakiengine/src/game/screenshot_generator.dart';

class SaveLoadManager {
  Future<String> getSavesDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final savesDir = Directory('${directory.path}/SakiEngine/Saves');
    if (!await savesDir.exists()) {
      await savesDir.create(recursive: true);
    }
    return savesDir.path;
  }

  Future<void> saveGame(int slotId, String currentScript, GameStateSnapshot snapshot) async {
    final directory = await getSavesDirectory();
    final file = File('$directory/save_$slotId.json');
    
    String dialoguePreview = '...';
    final currentState = snapshot.currentState;
    if (currentState.dialogue != null && currentState.dialogue!.isNotEmpty) {
      if (currentState.speaker != null && currentState.speaker!.isNotEmpty) {
        dialoguePreview = '【${currentState.speaker}】${currentState.dialogue}';
      } else {
        dialoguePreview = currentState.dialogue!;
      }
    }

    // 先删除旧截图，然后生成新截图
    await ScreenshotGenerator.deleteScreenshot(slotId, directory);
    
    String? screenshotPath;
    try {
      screenshotPath = await ScreenshotGenerator.generateScreenshot(
        currentState,
        currentState.poseConfigs,
        directory,
        slotId,
      );
    } catch (e) {
      print('生成截图失败: $e');
    }

    final saveSlot = SaveSlot(
      id: slotId,
      saveTime: DateTime.now(),
      currentScript: currentScript,
      dialoguePreview: dialoguePreview,
      snapshot: snapshot,
      screenshotPath: screenshotPath,
    );

    await file.writeAsString(jsonEncode(saveSlot.toJson()));
  }

  Future<SaveSlot?> loadGame(int slotId) async {
    try {
      final directory = await getSavesDirectory();
      final file = File('$directory/save_$slotId.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        return SaveSlot.fromJson(jsonDecode(content));
      }
    } catch (e) {
      print('Error loading game from slot $slotId: $e');
    }
    return null;
  }

  Future<List<SaveSlot>> listSaveSlots() async {
    final directory = await getSavesDirectory();
    final files = await Directory(directory).list().toList();
    final saveSlots = <SaveSlot>[];

    for (var fileEntity in files) {
      if (fileEntity is File && fileEntity.path.endsWith('.json')) {
        try {
          final content = await fileEntity.readAsString();
          saveSlots.add(SaveSlot.fromJson(jsonDecode(content)));
        } catch(e) {
          print('Error reading save file ${fileEntity.path}: $e');
        }
      }
    }
    saveSlots.sort((a, b) => a.id.compareTo(b.id));
    return saveSlots;
  }

  Future<void> deleteSave(int slotId) async {
    final directory = await getSavesDirectory();
    final file = File('$directory/save_$slotId.json');
    if (await file.exists()) {
      await file.delete();
    }
    
    // 同时删除截图文件
    await ScreenshotGenerator.deleteScreenshot(slotId, directory);
  }
}

class SaveSlot {
  final int id;
  final DateTime saveTime;
  final String currentScript;
  final String dialoguePreview;
  final GameStateSnapshot snapshot;
  final String? screenshotPath;

  SaveSlot({
    required this.id,
    required this.saveTime,
    required this.currentScript,
    required this.dialoguePreview,
    required this.snapshot,
    this.screenshotPath,
  });

  factory SaveSlot.fromJson(Map<String, dynamic> json) {
    return SaveSlot(
      id: json['id'],
      saveTime: DateTime.parse(json['saveTime']),
      currentScript: json['currentScript'],
      dialoguePreview: json['dialoguePreview'],
      snapshot: GameStateSnapshot.fromJson(json['snapshot']),
      screenshotPath: json['screenshotPath'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'saveTime': saveTime.toIso8601String(),
      'currentScript': currentScript,
      'dialoguePreview': dialoguePreview,
      'snapshot': snapshot.toJson(),
      'screenshotPath': screenshotPath,
    };
  }
}

extension GameStateSnapshotSerialization on GameStateSnapshot {
  Map<String, dynamic> toJson() {
    return {
      'scriptIndex': scriptIndex,
      'currentState': currentState.toJson(),
      'dialogueHistory': dialogueHistory.map((e) => e.toJson()).toList(),
    };
  }
}

extension GameStateSerialization on GameState {
  Map<String, dynamic> toJson() {
    return {
      'background': background,
      'characters': characters.map((key, value) => MapEntry(key, value.toJson())),
      'dialogue': dialogue,
      'speaker': speaker,
    };
  }
}

extension CharacterStateSerialization on CharacterState {
  Map<String, dynamic> toJson() {
    return {
      'resourceId': resourceId,
      'pose': pose,
      'expression': expression,
      'positionId': positionId,
    };
  }
}

extension DialogueHistoryEntrySerialization on DialogueHistoryEntry {
    Map<String, dynamic> toJson() {
    return {
      'speaker': speaker,
      'dialogue': dialogue,
      'timestamp': timestamp.toIso8601String(),
      'scriptIndex': scriptIndex,
      'stateSnapshot': stateSnapshot.toJson(),
    };
  }
}
