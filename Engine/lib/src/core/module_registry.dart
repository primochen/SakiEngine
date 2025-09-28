// 模块注册中心 - 使用自动生成的注册系统
// 🤖 完全自动化，无需手动维护！

import 'package:sakiengine/src/core/generated_module_registry.dart';
import 'package:sakiengine/src/core/auto_module_registry.dart';
import 'package:sakiengine/src/core/project_module_loader.dart';

/// 初始化所有项目模块
/// 这个函数使用自动生成的模块注册表
/// 🎯 真正的零配置模块系统！
void initializeProjectModules() {
  // 使用自动生成的注册表
  registerAllDiscoveredModules();
  
  // 显示扫描结果（用于开发调试）
  final availableModules = AutoModuleRegistry.scanForAvailableModules();
  if (availableModules.isNotEmpty) {
  }
  
}

/// 创建项目特定模块的助手函数
/// 这个函数提供了一个便捷的方式来创建符合规范的项目模块
/// 
/// 使用示例：
/// ```dart
/// // 在 lib/myproject/myproject_module.dart 中:
/// import 'package:sakiengine/src/core/game_module.dart';
/// import 'package:sakiengine/src/core/module_registry.dart';
/// 
/// class MyProjectModule extends DefaultGameModule {
///   // 覆盖需要自定义的方法
/// }
/// 
/// // 在 lib/myproject/myproject_module.dart 的末尾调用:
/// final _ = registerProjectModule('myproject', () => MyProjectModule());
/// ```
void registerProjectModule(String projectName, GameModuleFactory factory) {
  ProjectModuleLoader().registerModule(projectName, factory);
}