import 'dart:io';
import 'dart:typed_data';
import 'dart:convert' show utf8;
import 'package:path_provider/path_provider.dart';
import 'package:sakiengine/src/game/game_manager.dart';
import 'package:sakiengine/src/game/screenshot_generator.dart';
import 'package:sakiengine/src/utils/binary_serializer.dart';

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
    final file = File('$directory/save_$slotId.sakisav');
    
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
    final files = await Directory(directory).list().toList();
    final saveSlots = <SaveSlot>[];

    for (var fileEntity in files) {
      if (fileEntity is File && fileEntity.path.endsWith('.sakisav')) {
        try {
          final binaryData = await fileEntity.readAsBytes();
          saveSlots.add(SaveSlot.fromBinary(binaryData));
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
    final file = File('$directory/save_$slotId.sakisav');
    if (await file.exists()) {
      await file.delete();
    }
    
    // 同时删除截图文件
    await ScreenshotGenerator.deleteScreenshot(slotId, directory);
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

