import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sakiengine/src/core/game_module.dart';
import 'package:sakiengine/src/config/project_info_manager.dart';

// 自动模块发现系统 - 无需手动注册

/// 项目模块工厂函数类型
typedef GameModuleFactory = GameModule Function();

/// 项目模块加载器 - 核心中转层
class ProjectModuleLoader {
  static final ProjectModuleLoader _instance = ProjectModuleLoader._internal();
  factory ProjectModuleLoader() => _instance;
  ProjectModuleLoader._internal();

  /// 注册的项目模块工厂
  final Map<String, GameModuleFactory> _registeredModules = {};
  
  /// 当前加载的模块
  GameModule? _currentModule;
  String? _currentProjectName;

  /// 注册项目模块
  /// [projectName] 项目名称（不区分大小写）
  /// [factory] 模块工厂函数
  void registerModule(String projectName, GameModuleFactory factory) {
    final normalizedName = projectName.toLowerCase();
    _registeredModules[normalizedName] = factory;
    if (kDebugMode) {
      print('[ProjectModuleLoader] 注册项目模块: $normalizedName');
    }
  }

  /// 自动发现并加载项目模块
  Future<GameModule?> _discoverAndLoadModule(String projectName) async {
    final normalizedProjectName = projectName.toLowerCase();
    
    try {
      // 尝试动态导入项目模块
      final modulePackage = 'package:sakiengine/$normalizedProjectName/${normalizedProjectName}_module.dart';
      
      if (kDebugMode) {
        print('[ProjectModuleLoader] 尝试加载模块: $modulePackage');
      }
      
      // 检查模块文件是否存在
      final moduleFile = File('lib/$normalizedProjectName/${normalizedProjectName}_module.dart');
      if (await moduleFile.exists()) {
        if (kDebugMode) {
          print('[ProjectModuleLoader] 发现项目模块文件: ${moduleFile.path}');
        }
        
        // 尝试通过反射或已知模块映射加载
        final module = await _tryLoadKnownModule(normalizedProjectName);
        if (module != null) {
          await module.initialize();
          if (kDebugMode) {
            print('[ProjectModuleLoader] 成功加载项目特定模块: $projectName');
          }
          return module;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ProjectModuleLoader] 自动发现模块失败: $projectName, 错误: $e');
      }
    }
    
    return null;
  }

  /// 尝试加载已知的模块
  Future<GameModule?> _tryLoadKnownModule(String projectName) async {
    // 动态加载已知模块
    switch (projectName.toLowerCase()) {
      case 'soranouta':
        try {
          // 动态导入 SoraNoutaModule
          final module = await _loadSoraNoutaModule();
          return module;
        } catch (e) {
          if (kDebugMode) {
            print('[ProjectModuleLoader] 加载 SoraNoutaModule 失败: $e');
          }
        }
        break;
      // 可以在这里添加其他已知模块
    }
    return null;
  }

  /// 动态加载 SoraNoUta 模块
  Future<GameModule?> _loadSoraNoutaModule() async {
    try {
      // 尝试通过反射或导入加载
      final module = await _createSoraNoutaModule();
      return module;
    } catch (e) {
      if (kDebugMode) {
        print('[ProjectModuleLoader] 创建 SoraNoutaModule 失败: $e');
      }
    }
    return null;
  }

  /// 创建 SoraNoutaModule 实例
  Future<GameModule?> _createSoraNoutaModule() async {
    // 由于 Dart 没有运行时反射，我们需要使用导入的方式
    // 这里将在 module_registry.dart 中自动处理
    return null;
  }

  /// 获取当前项目的模块
  Future<GameModule> getCurrentModule() async {
    final projectName = await ProjectInfoManager().getProjectName();
    
    // 如果项目没有变化，返回缓存的模块
    if (_currentModule != null && _currentProjectName == projectName) {
      return _currentModule!;
    }

    // 清理之前的模块
    _currentModule = null;
    _currentProjectName = projectName;

    // 首先尝试从注册的模块加载
    final normalizedProjectName = projectName.toLowerCase();
    if (_registeredModules.containsKey(normalizedProjectName)) {
      try {
        _currentModule = _registeredModules[normalizedProjectName]!();
        await _currentModule!.initialize();
        
        if (kDebugMode) {
          print('[ProjectModuleLoader] 加载已注册模块: $projectName');
        }
        
        return _currentModule!;
      } catch (e) {
        if (kDebugMode) {
          print('[ProjectModuleLoader] 加载已注册模块失败: $projectName, 错误: $e');
        }
      }
    }

    // 尝试自动发现和加载模块
    final discoveredModule = await _discoverAndLoadModule(projectName);
    if (discoveredModule != null) {
      _currentModule = discoveredModule;
      return _currentModule!;
    }

    // 回退到默认模块
    _currentModule = DefaultGameModule();
    await _currentModule!.initialize();
    
    if (kDebugMode) {
      print('[ProjectModuleLoader] 使用默认模块: $projectName');
    }
    
    return _currentModule!;
  }

  /// 重新加载模块（用于项目切换时）
  Future<void> reloadModule() async {
    _currentModule = null;
    _currentProjectName = null;
    ProjectInfoManager().clearCache();
  }

  /// 获取已注册的模块列表
  List<String> getRegisteredModules() {
    return _registeredModules.keys.toList();
  }

  /// 检查项目是否有自定义模块
  bool hasCustomModule(String projectName) {
    final normalizedName = projectName.toLowerCase();
    return _registeredModules.containsKey(normalizedName);
  }
}

/// 全局模块加载器实例
final moduleLoader = ProjectModuleLoader();