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
  
  // 获取游戏路径，从dart-define或环境变量获取
  static String get _debugRoot {
    const fromDefine = String.fromEnvironment('SAKI_GAME_PATH', defaultValue: '');
    if (fromDefine.isNotEmpty) return fromDefine;
    
    final fromEnv = Platform.environment['SAKI_GAME_PATH'];
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    
    return '';
  }

  // 获取游戏路径，优先使用环境变量，如果没有则从assets读取default_game.txt
  static Future<String> _getGamePath() async {
    // 如果环境变量已设置，直接使用
    if (_debugRoot.isNotEmpty) {
      return _debugRoot;
    }
    
    try {
      // 从assets读取default_game.txt
      final assetContent = await rootBundle.loadString('assets/default_game.txt');
      final defaultGame = assetContent.trim();
      
      if (defaultGame.isEmpty) {
        throw Exception('default_game.txt is empty');
      }
      
      final gamePath = p.join(Directory.current.path, 'Game', defaultGame);
      if (kDebugMode) {
        print("Using game from assets: $defaultGame");
        print("Game path resolved to: $gamePath");
      }
      
      return gamePath;
    } catch (e) {
      throw Exception('Failed to load default_game.txt from assets: $e');
    }
  }


  Future<String> loadString(String path) async {
    if (kDebugMode) {
      final gamePath = await _getGamePath();
      if (gamePath.isEmpty) {
        throw Exception('Game path is not defined. Please set SAKI_GAME_PATH environment variable or create default_game.txt');
      }
      final assetPath = path.startsWith('assets/') ? path.substring('assets/'.length) : path;
      final fileSystemPath = p.normalize(p.join(gamePath, assetPath));
      
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

  Future<List<String>> listAssets(String directory, String extension) async {
    final assets = <String>[];
    
    if (kDebugMode) {
      // 开发模式：从文件系统扫描
      final gamePath = await _getGamePath();
      if (gamePath.isEmpty) {
        print("Game path is not set, cannot list assets from file system.");
        return assets;
      }
      
      final assetPath = directory.startsWith('assets/') ? directory.substring('assets/'.length) : directory;
      final dirPath = p.join(gamePath, assetPath);
      final dir = Directory(dirPath);
      
      if (await dir.exists()) {
        await for (final file in dir.list()) {
          if (file is File && file.path.endsWith(extension)) {
            final fileName = p.basename(file.path);
            assets.add(fileName);
          }
        }
      }
    } else {
      // 发布模式：从AssetManifest扫描
      await _loadManifest();
      if (_assetManifest != null) {
        for (final assetPath in _assetManifest!.keys) {
          if (assetPath.startsWith(directory) && assetPath.endsWith(extension)) {
            final fileName = p.basename(assetPath);
            assets.add(fileName);
          }
        }
      }
    }
    
    if (kDebugMode) {
      print("Found ${assets.length} assets in $directory with extension $extension: ${assets.join(', ')}");
    }
    
    return assets;
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

    final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.avif'];
    
    // 从查询名称中提取文件名，例如 "backgrounds/sky" -> "sky"
    final targetFileName = name.split('/').last;
    
    // 提取路径部分，例如 "backgrounds/sky" -> "backgrounds"
    final pathParts = name.split('/');
    final targetPath = pathParts.length > 1 ? pathParts.sublist(0, pathParts.length - 1).join('/') : '';

    print("Searching for asset: name='$name', fileName='$targetFileName', path='$targetPath'");

    // 1. 精确匹配：路径和文件名都要匹配
    for (final key in _assetManifest!.keys) {
      final keyParts = key.split('/');
      final keyFileName = keyParts.last;
      final keyFileNameWithoutExt = keyFileName.split('.').first;
      
      // 检查文件名是否匹配
      if (keyFileNameWithoutExt.toLowerCase() == targetFileName.toLowerCase()) {
        // 如果查询有路径要求，检查路径是否匹配
        if (targetPath.isNotEmpty) {
          final keyPath = key.toLowerCase();
          if (keyPath.contains('/${targetPath.toLowerCase()}/') || 
              keyPath.contains('${targetPath.toLowerCase()}/')) {
            _imageCache[name] = key;
            print("Found asset in bundle (path + name match): $name -> $key");
            return key;
          }
        } else {
          // 没有路径要求，直接匹配文件名
          _imageCache[name] = key;
          print("Found asset in bundle (name match): $name -> $key");
          return key;
        }
      }
    }

    // 2. 宽松匹配：只匹配文件名，忽略路径
    for (final key in _assetManifest!.keys) {
      final keyParts = key.split('/');
      final keyFileName = keyParts.last;
      final keyFileNameWithoutExt = keyFileName.split('.').first;
      
      if (keyFileNameWithoutExt.toLowerCase() == targetFileName.toLowerCase()) {
        _imageCache[name] = key;
        print("Found asset in bundle (fallback name match): $name -> $key");
        return key;
      }
    }

    print("Asset not found in bundle: $name");
    print("Available assets: ${_assetManifest!.keys.take(10).join(', ')}...");
    return null;
  }

  Future<String?> _findAssetInFileSystem(String name) async {
    final gamePath = await _getGamePath();
    if (gamePath.isEmpty) {
      print("Game path is not set, cannot find assets in file system.");
      return null;
    }

    // 从资源名中提取文件名用于搜索，例如 "backgrounds/bg-school" -> "bg-school"
    final fileNameToSearch = name.split('/').last;

    final searchBase = p.join(gamePath, 'Assets', 'images');
    final searchPaths = [
      p.join(searchBase, 'backgrounds'),
      p.join(searchBase, 'characters'),
      p.join(searchBase, 'items'),
      p.join(gamePath, 'Assets', 'gui'),
    ];

    for (final dirPath in searchPaths) {
      final directory = Directory(dirPath);
      if (await directory.exists()) {
        await for (final file in directory.list(recursive: true)) {
          if (file is File) {
            final fileNameWithoutExt = p.basenameWithoutExtension(file.path);
            if (fileNameWithoutExt.toLowerCase() == fileNameToSearch.toLowerCase()) {
              final relativePath = p.relative(file.path, from: gamePath);
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