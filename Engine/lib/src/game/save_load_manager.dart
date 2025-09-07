import 'dart:io';
import 'dart:typed_data';
import 'dart:convert' show utf8;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:sakiengine/src/game/game_manager.dart';
import 'package:sakiengine/src/game/screenshot_generator.dart';
import 'package:sakiengine/src/utils/binary_serializer.dart';
import 'package:sakiengine/src/utils/rich_text_parser.dart';
import 'package:sakiengine/src/config/config_models.dart';

class SaveLoadManager {
  // 获取当前游戏项目名称
  Future<String> _getCurrentProjectName() async {
    try {
      // 优先从环境变量获取游戏路径
      const fromDefine = String.fromEnvironment('SAKI_GAME_PATH', defaultValue: '');
      if (fromDefine.isNotEmpty) {
        return p.basename(fromDefine);
      }
      
      final fromEnv = Platform.environment['SAKI_GAME_PATH'];
      if (fromEnv != null && fromEnv.isNotEmpty) {
        return p.basename(fromEnv);
      }
      
      // 从assets读取default_game.txt
      final assetContent = await rootBundle.loadString('assets/default_game.txt');
      final projectName = assetContent.trim();
      
      if (projectName.isEmpty) {
        throw Exception('Project name is empty in default_game.txt');
      }
      
      return projectName;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting project name: $e');
      }
      // 如果无法获取项目名称，使用默认值
      return 'DefaultProject';
    }
  }

  Future<String> getSavesDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final projectName = await _getCurrentProjectName();
    final savesDir = Directory('${directory.path}/SakiEngine/Saves/$projectName');
    if (!await savesDir.exists()) {
      await savesDir.create(recursive: true);
    }
    return savesDir.path;
  }

  Future<void> saveGame(int slotId, String currentScript, GameStateSnapshot snapshot, Map<String, PoseConfig> poseConfigs) async {
    // 检查目标位置是否有被锁定的存档
    final existingSlot = await loadGame(slotId);
    if (existingSlot?.isLocked == true) {
      throw Exception('存档已锁定，无法覆盖');
    }
    
    final directory = await getSavesDirectory();
    final file = File('$directory/save_$slotId.sakisav');
    
    String dialoguePreview = '...';
    final currentState = snapshot.currentState;
    
    // 优先检查 NVL 模式
    if (currentState.isNvlMode && currentState.nvlDialogues.isNotEmpty) {
      // 使用最新的 NVL 对话作为预览
      final latestNvlDialogue = currentState.nvlDialogues.last;
      if (latestNvlDialogue.speaker != null && latestNvlDialogue.speaker!.isNotEmpty) {
        dialoguePreview = '【${latestNvlDialogue.speaker}】${RichTextParser.cleanText(latestNvlDialogue.dialogue)}';
      } else {
        dialoguePreview = RichTextParser.cleanText(latestNvlDialogue.dialogue);
      }
    } else if (currentState.dialogue != null && currentState.dialogue!.isNotEmpty) {
      // 普通模式的对话
      if (currentState.speaker != null && currentState.speaker!.isNotEmpty) {
        dialoguePreview = '【${currentState.speaker}】${RichTextParser.cleanText(currentState.dialogue!)}';
      } else {
        dialoguePreview = RichTextParser.cleanText(currentState.dialogue!);
      }
    }

    // 生成截图数据
    Uint8List? screenshotData;
    try {
      screenshotData = await ScreenshotGenerator.generateScreenshotData(
        currentState,
        poseConfigs,
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
      screenshotData: screenshotData,
      isLocked: existingSlot?.isLocked ?? false, // 保持原有锁定状态
    );

    final binaryData = saveSlot.toBinary();
    await file.writeAsBytes(binaryData);
  }

  Future<SaveSlot?> loadGame(int slotId) async {
    try {
      final directory = await getSavesDirectory();
      final file = File('$directory/save_$slotId.sakisav');
      if (await file.exists()) {
        final binaryData = await file.readAsBytes();
        return SaveSlot.fromBinary(binaryData);
      }
    } catch (e) {
      print('Error loading game from slot $slotId: $e');
    }
    return null;
  }

  Future<List<SaveSlot>> listSaveSlots() async {
    final directory = await getSavesDirectory();
    //print('DEBUG: 存档目录: $directory');
    
    final files = await Directory(directory).list().toList();
    //print('DEBUG: 找到 ${files.length} 个文件');
    
    final saveSlots = <SaveSlot>[];

    for (var fileEntity in files) {
      //print('DEBUG: 检查文件: ${fileEntity.path}');
      
      if (fileEntity is File && fileEntity.path.endsWith('.sakisav')) {
        //print('DEBUG: 尝试读取存档文件: ${fileEntity.path}');
        try {
          final binaryData = await fileEntity.readAsBytes();
          //print('DEBUG: 成功读取 ${binaryData.length} 字节数据');
          
          final saveSlot = SaveSlot.fromBinary(binaryData);
          //print('DEBUG: 成功解析存档，ID=${saveSlot.id}, 时间=${saveSlot.saveTime}');
          
          saveSlots.add(saveSlot);
        } catch(e, stackTrace) {
          print('ERROR: 读取存档文件失败 ${fileEntity.path}:');
          print('ERROR: 异常信息: $e');
          print('ERROR: 堆栈跟踪: $stackTrace');
        }
      } else {
        //print('DEBUG: 跳过非存档文件: ${fileEntity.path}');
      }
    }
    
    //print('DEBUG: 最终解析出 ${saveSlots.length} 个有效存档');
    saveSlots.sort((a, b) => a.id.compareTo(b.id));
    return saveSlots;
  }

  Future<void> deleteSave(int slotId) async {
    final saveSlot = await loadGame(slotId);
    if (saveSlot?.isLocked == true) {
      throw Exception('存档已锁定，无法删除');
    }
    
    final directory = await getSavesDirectory();
    final file = File('$directory/save_$slotId.sakisav');
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<bool> moveSave(int fromSlotId, int toSlotId) async {
    if (fromSlotId == toSlotId) return false;
    
    final directory = await getSavesDirectory();
    final fromFile = File('$directory/save_$fromSlotId.sakisav');
    final toFile = File('$directory/save_$toSlotId.sakisav');
    
    if (!await fromFile.exists()) {
      return false;
    }
    
    try {
      final saveSlot = await loadGame(fromSlotId);
      if (saveSlot == null) return false;
      
      // 检查源存档是否被锁定
      if (saveSlot.isLocked) return false;
      
      // 检查目标位置是否有被锁定的存档
      final targetSlot = await loadGame(toSlotId);
      if (targetSlot?.isLocked == true) return false;
      
      final updatedSaveSlot = SaveSlot(
        id: toSlotId,
        saveTime: saveSlot.saveTime,
        currentScript: saveSlot.currentScript,
        dialoguePreview: saveSlot.dialoguePreview,
        snapshot: saveSlot.snapshot,
        screenshotData: saveSlot.screenshotData,
        isLocked: saveSlot.isLocked,
      );
      
      final binaryData = updatedSaveSlot.toBinary();
      await toFile.writeAsBytes(binaryData);
      await fromFile.delete();
      
      return true;
    } catch (e) {
      print('Error moving save from slot $fromSlotId to $toSlotId: $e');
      return false;
    }
  }

  Future<bool> swapSaves(int slotId1, int slotId2) async {
    if (slotId1 == slotId2) return false;
    
    final directory = await getSavesDirectory();
    final file1 = File('$directory/save_$slotId1.sakisav');
    final file2 = File('$directory/save_$slotId2.sakisav');
    
    final exists1 = await file1.exists();
    final exists2 = await file2.exists();
    
    if (!exists1 && !exists2) return false;
    
    try {
      SaveSlot? saveSlot1;
      SaveSlot? saveSlot2;
      
      if (exists1) {
        saveSlot1 = await loadGame(slotId1);
        if (saveSlot1?.isLocked == true) return false; // 检查锁定状态
      }
      if (exists2) {
        saveSlot2 = await loadGame(slotId2);
        if (saveSlot2?.isLocked == true) return false; // 检查锁定状态
      }
      
      if (exists1) await file1.delete();
      if (exists2) await file2.delete();
      
      if (saveSlot1 != null) {
        final updatedSaveSlot1 = SaveSlot(
          id: slotId2,
          saveTime: saveSlot1.saveTime,
          currentScript: saveSlot1.currentScript,
          dialoguePreview: saveSlot1.dialoguePreview,
          snapshot: saveSlot1.snapshot,
          screenshotData: saveSlot1.screenshotData,
          isLocked: saveSlot1.isLocked,
        );
        final binaryData = updatedSaveSlot1.toBinary();
        await file2.writeAsBytes(binaryData);
      }
      
      if (saveSlot2 != null) {
        final updatedSaveSlot2 = SaveSlot(
          id: slotId1,
          saveTime: saveSlot2.saveTime,
          currentScript: saveSlot2.currentScript,
          dialoguePreview: saveSlot2.dialoguePreview,
          snapshot: saveSlot2.snapshot,
          screenshotData: saveSlot2.screenshotData,
          isLocked: saveSlot2.isLocked,
        );
        final binaryData = updatedSaveSlot2.toBinary();
        await file1.writeAsBytes(binaryData);
      }
      
      return true;
    } catch (e) {
      print('Error swapping saves between slot $slotId1 and $slotId2: $e');
      return false;
    }
  }

  Future<bool> toggleSaveLock(int slotId) async {
    final saveSlot = await loadGame(slotId);
    if (saveSlot == null) return false;
    
    final updatedSlot = SaveSlot(
      id: saveSlot.id,
      saveTime: saveSlot.saveTime,
      currentScript: saveSlot.currentScript,
      dialoguePreview: saveSlot.dialoguePreview,
      snapshot: saveSlot.snapshot,
      screenshotData: saveSlot.screenshotData,
      isLocked: !saveSlot.isLocked,
    );
    
    try {
      final directory = await getSavesDirectory();
      final file = File('$directory/save_$slotId.sakisav');
      final binaryData = updatedSlot.toBinary();
      await file.writeAsBytes(binaryData);
      return true;
    } catch (e) {
      print('Error toggling lock for slot $slotId: $e');
      return false;
    }
  }
}

class GameConfigManager {
  /// 保存游戏配置到.sakiconfig文件
  Future<void> saveConfig(GameConfig config) async {
    final directory = await getApplicationDocumentsDirectory();
    final configDir = Directory('${directory.path}/SakiEngine');
    if (!await configDir.exists()) {
      await configDir.create(recursive: true);
    }
    
    final file = File('${configDir.path}/game.sakiconfig');
    final binaryData = config.toBinary();
    await file.writeAsBytes(binaryData);
  }

  /// 从.sakiconfig文件加载游戏配置
  Future<GameConfig> loadConfig() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/SakiEngine/game.sakiconfig');
      if (await file.exists()) {
        final binaryData = await file.readAsBytes();
        return GameConfig.fromBinary(binaryData);
      }
    } catch (e) {
      print('Error loading config: $e');
    }
    return GameConfig.defaultConfig();
  }
}

/// 游戏配置类
class GameConfig {
  final String version;
  final String language;
  final double masterVolume;
  final double musicVolume;
  final double soundVolume;
  final double voiceVolume;
  final double textSpeed;
  final double autoplaySpeed;
  final bool enableAutoplay;
  final bool fullscreen;
  final int windowWidth;
  final int windowHeight;

  GameConfig({
    required this.version,
    required this.language,
    required this.masterVolume,
    required this.musicVolume,
    required this.soundVolume,
    required this.voiceVolume,
    required this.textSpeed,
    required this.autoplaySpeed,
    required this.enableAutoplay,
    required this.fullscreen,
    required this.windowWidth,
    required this.windowHeight,
  });

  factory GameConfig.defaultConfig() {
    return GameConfig(
      version: '1.0.0',
      language: 'zh_CN',
      masterVolume: 1.0,
      musicVolume: 0.8,
      soundVolume: 1.0,
      voiceVolume: 1.0,
      textSpeed: 0.5,
      autoplaySpeed: 3.0,
      enableAutoplay: false,
      fullscreen: false,
      windowWidth: 1280,
      windowHeight: 720,
    );
  }

  /// 从二进制数据创建配置
  factory GameConfig.fromBinary(Uint8List data) {
    final reader = _BinaryConfigReader(data);
    
    // 验证魔法数字
    final magic = String.fromCharCodes(reader.readBytes(4));
    if (magic != 'CONF') {
      throw FormatException('Invalid config file format');
    }
    
    final version = reader.readInt32();
    if (version != 1) {
      throw FormatException('Unsupported config version: $version');
    }
    
    return GameConfig(
      version: reader.readString(),
      language: reader.readString(),
      masterVolume: reader.readDouble(),
      musicVolume: reader.readDouble(),
      soundVolume: reader.readDouble(),
      voiceVolume: reader.readDouble(),
      textSpeed: reader.readDouble(),
      autoplaySpeed: reader.readDouble(),
      enableAutoplay: reader.readBool(),
      fullscreen: reader.readBool(),
      windowWidth: reader.readInt32(),
      windowHeight: reader.readInt32(),
    );
  }

  /// 转换为二进制数据
  Uint8List toBinary() {
    final buffer = <int>[];
    
    // 写入魔法数字和版本
    buffer.addAll('CONF'.codeUnits);
    buffer.addAll(_writeInt32(1));
    
    // 写入配置数据
    buffer.addAll(_writeString(version));
    buffer.addAll(_writeString(language));
    buffer.addAll(_writeDouble(masterVolume));
    buffer.addAll(_writeDouble(musicVolume));
    buffer.addAll(_writeDouble(soundVolume));
    buffer.addAll(_writeDouble(voiceVolume));
    buffer.addAll(_writeDouble(textSpeed));
    buffer.addAll(_writeDouble(autoplaySpeed));
    buffer.addAll(_writeBool(enableAutoplay));
    buffer.addAll(_writeBool(fullscreen));
    buffer.addAll(_writeInt32(windowWidth));
    buffer.addAll(_writeInt32(windowHeight));
    
    return Uint8List.fromList(buffer);
  }

  // 辅助序列化方法
  static Uint8List _writeInt32(int value) {
    return Uint8List(4)..buffer.asByteData().setInt32(0, value, Endian.little);
  }

  static Uint8List _writeDouble(double value) {
    return Uint8List(8)..buffer.asByteData().setFloat64(0, value, Endian.little);
  }

  static Uint8List _writeBool(bool value) {
    return Uint8List(1)..[0] = value ? 1 : 0;
  }

  static Uint8List _writeString(String value) {
    final bytes = utf8.encode(value);
    final buffer = <int>[];
    buffer.addAll(_writeInt32(bytes.length));
    buffer.addAll(bytes);
    return Uint8List.fromList(buffer);
  }
}

/// 配置文件二进制读取器
class _BinaryConfigReader {
  final Uint8List _data;
  int _position = 0;

  _BinaryConfigReader(this._data);

  Uint8List readBytes(int length) {
    if (_position + length > _data.length) {
      throw RangeError('Not enough data to read $length bytes');
    }
    final result = _data.sublist(_position, _position + length);
    _position += length;
    return result;
  }

  int readInt32() {
    final bytes = readBytes(4);
    return bytes.buffer.asByteData().getInt32(0, Endian.little);
  }

  double readDouble() {
    final bytes = readBytes(8);
    return bytes.buffer.asByteData().getFloat64(0, Endian.little);
  }

  bool readBool() {
    final bytes = readBytes(1);
    return bytes[0] == 1;
  }

  String readString() {
    final length = readInt32();
    if (length < 0) {
      throw FormatException('Invalid string length: $length');
    }
    final bytes = readBytes(length);
    return utf8.decode(bytes);
  }
}

