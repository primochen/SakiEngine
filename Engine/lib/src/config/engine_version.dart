// 引擎版本信息
// 此文件应与pubspec.yaml中的版本号保持同步

class EngineVersion {
  static const String version = '1.0.13';
  static const String buildNumber = '1';
  static const String fullVersion = '$version+$buildNumber';
  
  // 版本历史
  static const List<String> releaseHistory = [
    '1.0.13 - 多级图层支持、音乐系统、设置优化',
    '1.0.12 - 场景图层系统增强',
    '1.0.11 - 性能优化和bug修复',
    '1.0.10 - UI改进和新功能',
  ];
}