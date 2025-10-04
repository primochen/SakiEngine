import 'package:sakiengine/src/game/unified_game_data_manager.dart';
import 'package:sakiengine/src/config/project_info_manager.dart';

class GlobalVariableManager {
  static final GlobalVariableManager _instance = GlobalVariableManager._internal();
  factory GlobalVariableManager() => _instance;
  GlobalVariableManager._internal();

  final _dataManager = UnifiedGameDataManager();
  String? _projectName;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    // 获取项目名称
    try {
      _projectName = await ProjectInfoManager().getAppName();
    } catch (e) {
      _projectName = 'SakiEngine';
    }

    // 初始化数据管理器
    await _dataManager.init(_projectName!);

    _isInitialized = true;
  }

  Future<void> setBoolVariable(String name, bool value) async {
    await init();
    await _dataManager.setBoolVariable(name, value, _projectName!);
    print('[GlobalVariableManager] 设置变量 $name = $value');
  }

  Future<bool> getBoolVariable(String name, {bool defaultValue = false}) async {
    await init();
    return _dataManager.getBoolVariable(name, defaultValue: defaultValue);
  }

  bool getBoolVariableSync(String name, {bool defaultValue = false}) {
    return _dataManager.getBoolVariable(name, defaultValue: defaultValue);
  }

  Future<void> setIntVariable(String name, int value) async {
    await init();
    await _dataManager.setIntVariable(name, value, _projectName!);
    print('[GlobalVariableManager] 设置整数变量 $name = $value');
  }

  Future<int> getIntVariable(String name, {int defaultValue = 0}) async {
    await init();
    return _dataManager.getIntVariable(name, defaultValue: defaultValue);
  }

  int getIntVariableSync(String name, {int defaultValue = 0}) {
    return _dataManager.getIntVariable(name, defaultValue: defaultValue);
  }

  Future<void> setDoubleVariable(String name, double value) async {
    await init();
    await _dataManager.setDoubleVariable(name, value, _projectName!);
    print('[GlobalVariableManager] 设置浮点变量 $name = $value');
  }

  Future<double> getDoubleVariable(String name, {double defaultValue = 0.0}) async {
    await init();
    return _dataManager.getDoubleVariable(name, defaultValue: defaultValue);
  }

  double getDoubleVariableSync(String name, {double defaultValue = 0.0}) {
    return _dataManager.getDoubleVariable(name, defaultValue: defaultValue);
  }

  Future<void> setStringVariable(String name, String value) async {
    await init();
    await _dataManager.setStringVariable(name, value, _projectName!);
    print('[GlobalVariableManager] 设置字符串变量 $name = $value');
  }

  Future<String> getStringVariable(String name, {String defaultValue = ''}) async {
    await init();
    return _dataManager.getStringVariable(name, defaultValue: defaultValue);
  }

  String getStringVariableSync(String name, {String defaultValue = ''}) {
    return _dataManager.getStringVariable(name, defaultValue: defaultValue);
  }

  Map<String, bool> getAllVariables() {
    return _dataManager.getAllBoolVariables();
  }

  Future<void> clearAllVariables() async {
    await init();
    await _dataManager.clearAllVariables(_projectName!);
  }
}