// 使用条件导入来分离平台实现
export 'read_text_tracker_io.dart' if (dart.library.html) 'read_text_tracker_web.dart';