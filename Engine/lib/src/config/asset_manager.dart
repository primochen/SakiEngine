import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

class AssetManager {
  static final AssetManager _instance = AssetManager._internal();
  factory AssetManager() => _instance;
  AssetManager._internal() {
    // Print the CWD at initialization
    if (kDebugMode) {
      print("AssetManager CWD: ${Directory.current.path}");
      print("Game path from environment: $_debugRoot");
    }
  }

  Map<String, dynamic>? _assetManifest;
  final Map<String, String> _imageCache = {};
  static const String _debugRoot = String.fromEnvironment('SAKI_GAME_PATH', defaultValue: '');


  Future<String> loadString(String path) async {
    if (kDebugMode) {
      if (_debugRoot.isEmpty) {
        throw Exception('SAKI_GAME_PATH is not defined. Please run with --dart-define=SAKI_GAME_PATH=/path/to/your/Game/TestGame');
      }
      final assetPath = path.startsWith('assets/') ? path.substring('assets/'.length) : path;
      final fileSystemPath = p.normalize(p.join(_debugRoot, assetPath));
      
      try {
        print("Attempting to load from file system: $fileSystemPath");
        return await File(fileSystemPath).readAsString();
      } catch (e) {
        print("Failed to load asset from file system: $e");
        throw Exception('Failed to load asset from file system: $fileSystemPath');
      }
    } else {
      return await rootBundle.loadString(path, cache: false);
    }
  }

  Future<void> _loadManifest() async {
    if (_assetManifest != null) return;
    final manifestJson = await rootBundle.loadString('AssetManifest.json');
    _assetManifest = json.decode(manifestJson);
  }

  Future<String?> findAsset(String name) async {
    if (_imageCache.containsKey(name)) {
      return _imageCache[name];
    }

    if (kDebugMode) {
      return _findAssetInFileSystem(name);
    } else {
      return _findAssetInBundle(name);
    }
  }

  Future<String?> _findAssetInBundle(String name) async {
    await _loadManifest();
    if (_assetManifest == null) {
      print("AssetManifest is null - cannot find assets");
      return null;
    }

    final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'];

    // Prioritize direct match
    for (final key in _assetManifest!.keys) {
      for (final ext in imageExtensions) {
        final fileName = key.split('/').last;
        if (fileName.toLowerCase() == '$name$ext'.toLowerCase()) {
          _imageCache[name] = key;
          print("Found asset in bundle: $name -> $key");
          return key;
        }
      }
    }

    // Try partial matching for more flexible asset finding
    for (final key in _assetManifest!.keys) {
      final fileName = key.split('/').last;
      final nameWithoutExt = fileName.split('.').first;
      if (nameWithoutExt.toLowerCase() == name.toLowerCase()) {
        _imageCache[name] = key;
        print("Found asset in bundle (partial match): $name -> $key");
        return key;
      }
    }

    print("Asset not found in bundle: $name");
    print("Available assets: ${_assetManifest!.keys.take(10).join(', ')}...");
    return null;
  }

  Future<String?> _findAssetInFileSystem(String name) async {
    if (_debugRoot.isEmpty) {
      print("SAKI_GAME_PATH is not set, cannot find assets in file system.");
      return null;
    }

    // 从资源名中提取文件名用于搜索，例如 "backgrounds/bg-school" -> "bg-school"
    final fileNameToSearch = name.split('/').last;

    final searchBase = p.join(_debugRoot, 'Assets', 'images');
    final searchPaths = [
      p.join(searchBase, 'backgrounds'),
      p.join(searchBase, 'characters'),
      p.join(searchBase, 'items'),
      p.join(_debugRoot, 'Assets', 'gui'),
    ];

    for (final dirPath in searchPaths) {
      final directory = Directory(dirPath);
      if (await directory.exists()) {
        await for (final file in directory.list(recursive: true)) {
          if (file is File) {
            final fileNameWithoutExt = p.basenameWithoutExtension(file.path);
            if (fileNameWithoutExt.toLowerCase() == fileNameToSearch.toLowerCase()) {
              final relativePath = p.relative(file.path, from: _debugRoot);
              // 在发布模式下，Flutter 需要 'assets/' 前缀
              final assetPath = p.join('assets', relativePath).replaceAll('\\', '/');
              _imageCache[name] = assetPath; // 使用原始名称作为缓存的键
              print("Found asset in file system: $name -> $assetPath");
              return assetPath;
            }
          }
        }
      }
    }

    print("Asset not found in file system: $name");
    return null;
  }
} 