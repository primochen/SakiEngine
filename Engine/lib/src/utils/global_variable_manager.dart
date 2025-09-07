import 'package:shared_preferences/shared_preferences.dart';

class GlobalVariableManager {
  static final GlobalVariableManager _instance = GlobalVariableManager._internal();
  factory GlobalVariableManager() => _instance;
  GlobalVariableManager._internal();

  SharedPreferences? _prefs;
  final Map<String, bool> _variables = {};
  
  static const String _variablePrefix = 'game_bool_var_';

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _loadAllVariables();
  }

  Future<void> _loadAllVariables() async {
    if (_prefs == null) return;
    
    final keys = _prefs!.getKeys();
    for (final key in keys) {
      if (key.startsWith(_variablePrefix)) {
        final variableName = key.substring(_variablePrefix.length);
        final value = _prefs!.getBool(key) ?? false;
        _variables[variableName] = value;
      }
    }
  }

  Future<void> setBoolVariable(String name, bool value) async {
    await init();
    _variables[name] = value;
    await _prefs?.setBool('$_variablePrefix$name', value);
    print('[GlobalVariableManager] 设置变量 $name = $value');
  }

  Future<bool> getBoolVariable(String name, {bool defaultValue = false}) async {
    await init();
    return _variables[name] ?? defaultValue;
  }

  bool getBoolVariableSync(String name, {bool defaultValue = false}) {
    return _variables[name] ?? defaultValue;
  }

  Map<String, bool> getAllVariables() {
    return Map.unmodifiable(_variables);
  }

  Future<void> clearAllVariables() async {
    await init();
    if (_prefs == null) return;
    
    final keys = _prefs!.getKeys().where((key) => key.startsWith(_variablePrefix));
    for (final key in keys) {
      await _prefs!.remove(key);
    }
    _variables.clear();
  }
}