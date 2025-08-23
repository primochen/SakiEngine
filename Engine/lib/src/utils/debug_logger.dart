import 'dart:async';

class DebugLogger {
  static final DebugLogger _instance = DebugLogger._internal();
  factory DebugLogger() => _instance;
  static DebugLogger get instance => _instance;
  DebugLogger._internal();

  final List<String> _logs = [];
  static const int maxLogs = 1000; // 最多保存1000条日志
  
  // Stream controller for real-time log updates
  final StreamController<List<String>> _logStreamController = 
      StreamController<List<String>>.broadcast();

  List<String> get logs => List.unmodifiable(_logs);
  Stream<List<String>> get logStream => _logStreamController.stream;

  void addLog(String message) {
    final timestamp = DateTime.now();
    final formattedTime = "${timestamp.hour.toString().padLeft(2, '0')}:"
        "${timestamp.minute.toString().padLeft(2, '0')}:"
        "${timestamp.second.toString().padLeft(2, '0')}."
        "${timestamp.millisecond.toString().padLeft(3, '0')}";
    
    final logEntry = "[$formattedTime] $message";
    _logs.add(logEntry);
    
    // 保持日志数量在限制内
    if (_logs.length > maxLogs) {
      _logs.removeAt(0);
    }
    
    // 通知监听者日志更新
    _logStreamController.add(List.unmodifiable(_logs));
  }

  void log(String message) {
    addLog(message);
  }

  void clear() {
    _logs.clear();
    _logStreamController.add(List.unmodifiable(_logs));
  }

  String getAllLogsAsString() {
    return _logs.join('\n');
  }

  void dispose() {
    _logStreamController.close();
  }
}

void setupDebugLogger() {
  // 添加初始化日志，表示日志系统已启动
  DebugLogger().addLog("调试日志系统已启动 - 所有print输出都会被自动捕获");
  
  // 添加一些测试日志来验证系统工作正常
  DebugLogger().addLog("测试日志: INFO级别消息");
  DebugLogger().addLog("测试日志: [WARN] 警告级别消息");
  DebugLogger().addLog("测试日志: [ERROR] 错误级别消息");
  DebugLogger().addLog("测试日志: [DEBUG] 调试级别消息");
}