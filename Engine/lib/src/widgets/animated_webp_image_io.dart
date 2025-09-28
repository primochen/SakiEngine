import 'dart:io';

/// 获取平台环境变量 - IO平台实现
String getPlatformEnvironment(String key) {
  final value = Platform.environment[key];
  return value ?? '';
}

/// 获取当前目录路径 - IO平台实现  
String getCurrentDirectoryPath() {
  return Directory.current.path;
}

/// 创建文件对象 - IO平台实现
File? createFile(String path) {
  return File(path);
}