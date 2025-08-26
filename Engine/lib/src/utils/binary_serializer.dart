import 'dart:convert' show utf8;
import 'dart:typed_data';
import 'package:sakiengine/src/game/game_manager.dart';

/// 二进制序列化工具类，用于将游戏数据序列化为二进制格式
class BinarySerializer {
  static const int _version = 1;
  static const String _magicNumber = 'SAKI';

  /// 将SaveSlot序列化为二进制数据
  static Uint8List serializeSaveSlot(SaveSlot saveSlot) {
    final buffer = <int>[];
    
    // 写入魔法数字和版本号
    buffer.addAll(_magicNumber.codeUnits);
    buffer.addAll(_writeInt32(_version));
    
    // 写入基本信息
    buffer.addAll(_writeInt32(saveSlot.id));
    buffer.addAll(_writeInt64(saveSlot.saveTime.millisecondsSinceEpoch));
    buffer.addAll(_writeString(saveSlot.currentScript));
    buffer.addAll(_writeString(saveSlot.dialoguePreview));
    buffer.addAll(_writeNullableBytes(saveSlot.screenshotData));
    
    // 写入游戏状态快照
    buffer.addAll(_serializeGameStateSnapshot(saveSlot.snapshot));
    
    return Uint8List.fromList(buffer);
  }

  /// 从二进制数据反序列化SaveSlot
  static SaveSlot deserializeSaveSlot(Uint8List data) {
    final reader = _BinaryReader(data);
    
    // 读取并验证魔法数字和版本号
    final magic = String.fromCharCodes(reader.readBytes(4));
    if (magic != _magicNumber) {
      throw FormatException('Invalid file format: expected $_magicNumber, got $magic');
    }
    
    final version = reader.readInt32();
    if (version != _version) {
      throw FormatException('Unsupported version: $version');
    }
    
    // 读取基本信息
    final id = reader.readInt32();
    final saveTime = DateTime.fromMillisecondsSinceEpoch(reader.readInt64());
    final currentScript = reader.readString();
    final dialoguePreview = reader.readString();
    final screenshotData = reader.readNullableBytes();
    
    // 读取游戏状态快照
    final snapshot = _deserializeGameStateSnapshot(reader);
    
    return SaveSlot(
      id: id,
      saveTime: saveTime,
      currentScript: currentScript,
      dialoguePreview: dialoguePreview,
      snapshot: snapshot,
      screenshotData: screenshotData,
    );
  }

  /// 序列化GameStateSnapshot
  static Uint8List _serializeGameStateSnapshot(GameStateSnapshot snapshot) {
    final buffer = <int>[];
    
    buffer.addAll(_writeInt32(snapshot.scriptIndex));
    buffer.addAll(_serializeGameState(snapshot.currentState));
    
    // 序列化对话历史
    buffer.addAll(_writeInt32(snapshot.dialogueHistory.length));
    for (final entry in snapshot.dialogueHistory) {
      buffer.addAll(_serializeDialogueHistoryEntry(entry));
    }
    
    // 序列化 NVL 状态
    buffer.add(snapshot.isNvlMode ? 1 : 0);
    buffer.add(snapshot.isNvlMovieMode ? 1 : 0);  // 添加电影模式状态
    buffer.addAll(_writeInt32(snapshot.nvlDialogues.length));
    for (final nvlDialogue in snapshot.nvlDialogues) {
      buffer.addAll(_serializeNvlDialogue(nvlDialogue));
    }
    
    return Uint8List.fromList(buffer);
  }

  /// 反序列化GameStateSnapshot
  static GameStateSnapshot _deserializeGameStateSnapshot(_BinaryReader reader) {
    final scriptIndex = reader.readInt32();
    final currentState = _deserializeGameState(reader);
    
    // 反序列化对话历史
    final historyLength = reader.readInt32();
    final dialogueHistory = <DialogueHistoryEntry>[];
    for (int i = 0; i < historyLength; i++) {
      dialogueHistory.add(_deserializeDialogueHistoryEntry(reader));
    }
    
    // 反序列化 NVL 状态
    final isNvlMode = reader.readByte() == 1;
    final isNvlMovieMode = reader.readByte() == 1;  // 添加电影模式状态
    final nvlDialoguesLength = reader.readInt32();
    final nvlDialogues = <NvlDialogue>[];
    for (int i = 0; i < nvlDialoguesLength; i++) {
      nvlDialogues.add(_deserializeNvlDialogue(reader));
    }
    
    return GameStateSnapshot(
      scriptIndex: scriptIndex,
      currentState: currentState,
      dialogueHistory: dialogueHistory,
      isNvlMode: isNvlMode,
      isNvlMovieMode: isNvlMovieMode,  // 添加电影模式状态
      nvlDialogues: nvlDialogues,
    );
  }

  /// 序列化GameState
  static Uint8List _serializeGameState(GameState state) {
    final buffer = <int>[];
    
    buffer.addAll(_writeNullableString(state.background));
    buffer.addAll(_writeNullableString(state.dialogue));
    buffer.addAll(_writeNullableString(state.speaker));
    
    // 序列化角色状态
    buffer.addAll(_writeInt32(state.characters.length));
    for (final entry in state.characters.entries) {
      buffer.addAll(_writeString(entry.key));
      buffer.addAll(_serializeCharacterState(entry.value));
    }
    
    // 序列化 NVL 状态
    buffer.add(state.isNvlMode ? 1 : 0);
    buffer.add(state.isNvlMovieMode ? 1 : 0);
    buffer.addAll(_writeInt32(state.nvlDialogues.length));
    for (final nvlDialogue in state.nvlDialogues) {
      buffer.addAll(_serializeNvlDialogue(nvlDialogue));
    }
    
    return Uint8List.fromList(buffer);
  }

  /// 反序列化GameState
  static GameState _deserializeGameState(_BinaryReader reader) {
    final background = reader.readNullableString();
    final dialogue = reader.readNullableString();
    final speaker = reader.readNullableString();
    
    // 反序列化角色状态
    final charactersLength = reader.readInt32();
    final characters = <String, CharacterState>{};
    for (int i = 0; i < charactersLength; i++) {
      final key = reader.readString();
      final value = _deserializeCharacterState(reader);
      characters[key] = value;
    }
    
    // 反序列化 NVL 状态
    final isNvlMode = reader.readByte() == 1;
    final isNvlMovieMode = reader.readByte() == 1;
    final nvlDialoguesLength = reader.readInt32();
    final nvlDialogues = <NvlDialogue>[];
    for (int i = 0; i < nvlDialoguesLength; i++) {
      nvlDialogues.add(_deserializeNvlDialogue(reader));
    }
    
    return GameState(
      background: background,
      dialogue: dialogue,
      speaker: speaker,
      characters: characters,
      isNvlMode: isNvlMode,
      isNvlMovieMode: isNvlMovieMode,
      nvlDialogues: nvlDialogues,
    );
  }

  /// 序列化CharacterState
  static Uint8List _serializeCharacterState(CharacterState state) {
    final buffer = <int>[];
    
    buffer.addAll(_writeString(state.resourceId));
    buffer.addAll(_writeNullableString(state.pose));
    buffer.addAll(_writeNullableString(state.expression));
    buffer.addAll(_writeNullableString(state.positionId));
    
    return Uint8List.fromList(buffer);
  }

  /// 反序列化CharacterState
  static CharacterState _deserializeCharacterState(_BinaryReader reader) {
    final resourceId = reader.readString();
    final pose = reader.readNullableString();
    final expression = reader.readNullableString();
    final positionId = reader.readNullableString();
    
    return CharacterState(
      resourceId: resourceId,
      pose: pose,
      expression: expression,
      positionId: positionId,
    );
  }

  /// 序列化DialogueHistoryEntry
  static Uint8List _serializeDialogueHistoryEntry(DialogueHistoryEntry entry) {
    final buffer = <int>[];
    
    buffer.addAll(_writeNullableString(entry.speaker));
    buffer.addAll(_writeString(entry.dialogue));
    buffer.addAll(_writeInt64(entry.timestamp.millisecondsSinceEpoch));
    buffer.addAll(_writeInt32(entry.scriptIndex));
    buffer.addAll(_serializeGameStateSnapshot(entry.stateSnapshot));
    
    return Uint8List.fromList(buffer);
  }

  /// 反序列化DialogueHistoryEntry
  static DialogueHistoryEntry _deserializeDialogueHistoryEntry(_BinaryReader reader) {
    final speaker = reader.readNullableString();
    final dialogue = reader.readString();
    final timestamp = DateTime.fromMillisecondsSinceEpoch(reader.readInt64());
    final scriptIndex = reader.readInt32();
    final stateSnapshot = _deserializeGameStateSnapshot(reader);
    
    return DialogueHistoryEntry(
      speaker: speaker,
      dialogue: dialogue,
      timestamp: timestamp,
      scriptIndex: scriptIndex,
      stateSnapshot: stateSnapshot,
    );
  }

  // 基础数据类型序列化方法
  static Uint8List _writeInt32(int value) {
    return Uint8List(4)..buffer.asByteData().setInt32(0, value, Endian.little);
  }

  static Uint8List _writeInt64(int value) {
    return Uint8List(8)..buffer.asByteData().setInt64(0, value, Endian.little);
  }

  static Uint8List _writeString(String value) {
    final bytes = utf8.encode(value);
    final buffer = <int>[];
    buffer.addAll(_writeInt32(bytes.length));
    buffer.addAll(bytes);
    return Uint8List.fromList(buffer);
  }

  static Uint8List _writeNullableBytes(Uint8List? value) {
    if (value == null) {
      return _writeInt32(-1);
    }
    final buffer = <int>[];
    buffer.addAll(_writeInt32(value.length));
    buffer.addAll(value);
    return Uint8List.fromList(buffer);
  }

  static Uint8List _writeNullableString(String? value) {
    if (value == null) {
      return _writeInt32(-1);
    }
    final bytes = utf8.encode(value);
    final buffer = <int>[];
    buffer.addAll(_writeInt32(bytes.length));
    buffer.addAll(bytes);
    return Uint8List.fromList(buffer);
  }

  /// 序列化 NvlDialogue
  static Uint8List _serializeNvlDialogue(NvlDialogue nvlDialogue) {
    final buffer = <int>[];
    buffer.addAll(_writeNullableString(nvlDialogue.speaker));
    buffer.addAll(_writeString(nvlDialogue.dialogue));
    buffer.addAll(_writeInt64(nvlDialogue.timestamp.millisecondsSinceEpoch));
    return Uint8List.fromList(buffer);
  }

  /// 反序列化 NvlDialogue
  static NvlDialogue _deserializeNvlDialogue(_BinaryReader reader) {
    final speaker = reader.readNullableString();
    final dialogue = reader.readString();
    final timestamp = DateTime.fromMillisecondsSinceEpoch(reader.readInt64());
    
    return NvlDialogue(
      speaker: speaker,
      dialogue: dialogue,
      timestamp: timestamp,
    );
  }
}

/// 二进制读取器类
class _BinaryReader {
  final Uint8List _data;
  int _position = 0;

  _BinaryReader(this._data);

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

  int readByte() {
    if (_position >= _data.length) {
      throw RangeError('Not enough data to read 1 byte');
    }
    return _data[_position++];
  }

  int readInt64() {
    final bytes = readBytes(8);
    return bytes.buffer.asByteData().getInt64(0, Endian.little);
  }

  String readString() {
    final length = readInt32();
    if (length < 0) {
      throw FormatException('Invalid string length: $length');
    }
    final bytes = readBytes(length);
    return utf8.decode(bytes);
  }

  String? readNullableString() {
    final length = readInt32();
    if (length == -1) {
      return null;
    }
    if (length < 0) {
      throw FormatException('Invalid string length: $length');
    }
    final bytes = readBytes(length);
    return utf8.decode(bytes);
  }

  Uint8List? readNullableBytes() {
    final length = readInt32();
    if (length == -1) {
      return null;
    }
    if (length < 0) {
      throw FormatException('Invalid bytes length: $length');
    }
    return readBytes(length);
  }
}

/// SaveSlot类，只支持二进制序列化
class SaveSlot {
  final int id;
  final DateTime saveTime;
  final String currentScript;
  final String dialoguePreview;
  final GameStateSnapshot snapshot;
  final Uint8List? screenshotData; // 内嵌的截图数据

  SaveSlot({
    required this.id,
    required this.saveTime,
    required this.currentScript,
    required this.dialoguePreview,
    required this.snapshot,
    this.screenshotData,
  });

  /// 从二进制数据创建SaveSlot
  factory SaveSlot.fromBinary(Uint8List data) {
    return BinarySerializer.deserializeSaveSlot(data);
  }

  /// 将SaveSlot转换为二进制数据
  Uint8List toBinary() {
    return BinarySerializer.serializeSaveSlot(this);
  }
}