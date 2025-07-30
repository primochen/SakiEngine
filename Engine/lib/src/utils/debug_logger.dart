import 'dart:async';

class DebugLogger {
  static final DebugLogger _instance = DebugLogger._internal();
  factory DebugLogger() => _instance;
  DebugLogger._internal();

  final List<String> _logs = [];
  static const int maxLogs = 1000; // 最多保存1000条日志

  List<String> get logs => List.unmodifiable(_logs);

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
  }

  void clear() {
    _logs.clear();
  }

  String getAllLogsAsString() {
    return _logs.join('\n');
  }
}

void Function(Zone, ZoneDelegate, Zone, String)? _originalPrint;

void setupDebugLogger() {
  // 保存原始的print函数
  _originalPrint ??= Zone.current[#flutter.io.print] as void Function(Zone, ZoneDelegate, Zone, String)?;
  
  // 使用Zone.runZoned来捕获所有print输出
  runZoned(() {}, zoneSpecification: ZoneSpecification(
    print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
      // 记录到我们的日志系统
      DebugLogger().addLog(line);
      
      // 调用原始的print函数，保持正常输出
      if (_originalPrint != null) {
        _originalPrint!(self, parent, zone, line);
      } else {
        parent.print(zone, line);
      }
    },
  ));
  
  DebugLogger().addLog("调试日志系统已启动 - 所有print输出都会被自动捕获");
}