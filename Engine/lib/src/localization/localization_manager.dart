import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:sakiengine/src/game/unified_game_data_manager.dart';
import 'package:sakiengine/src/config/project_info_manager.dart';

enum SupportedLanguage { zhHans, zhHant, en, ja }

extension SupportedLanguageX on SupportedLanguage {
  String get code {
    switch (this) {
      case SupportedLanguage.zhHans:
        return 'zh-Hans';
      case SupportedLanguage.zhHant:
        return 'zh-Hant';
      case SupportedLanguage.en:
        return 'en';
      case SupportedLanguage.ja:
        return 'ja';
    }
  }

  Locale get locale {
    switch (this) {
      case SupportedLanguage.zhHans:
        return const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans');
      case SupportedLanguage.zhHant:
        return const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
      case SupportedLanguage.en:
        return const Locale('en');
      case SupportedLanguage.ja:
        return const Locale('ja');
    }
  }

  String get englishName {
    switch (this) {
      case SupportedLanguage.zhHans:
        return 'Simplified Chinese';
      case SupportedLanguage.zhHant:
        return 'Traditional Chinese';
      case SupportedLanguage.en:
        return 'English';
      case SupportedLanguage.ja:
        return 'Japanese';
    }
  }
}

SupportedLanguage? supportedLanguageFromCode(String? code) {
  if (code == null) {
    return null;
  }
  for (final language in SupportedLanguage.values) {
    if (language.code == code) {
      return language;
    }
  }
  return null;
}

class LocalizationManager extends ChangeNotifier {
  static final LocalizationManager _instance = LocalizationManager._internal();
  factory LocalizationManager() => _instance;
  LocalizationManager._internal();

  static const String _translationsAsset = 'assets/i18n/strings.json';

  final Map<SupportedLanguage, Map<String, String>> _translations = {};
  final _dataManager = UnifiedGameDataManager();
  String? _projectName;
  SupportedLanguage _currentLanguage = SupportedLanguage.zhHans;
  SupportedLanguage _fallbackLanguage = SupportedLanguage.en;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) {
      return;
    }

    // 获取项目名称
    try {
      _projectName = await ProjectInfoManager().getAppName();
    } catch (e) {
      _projectName = 'SakiEngine';
    }

    // 初始化数据管理器
    await _dataManager.init(_projectName!);

    await _loadTranslations();

    // 从统一数据管理器读取语言设置
    final savedCode = _dataManager.getStringVariable('sakiengine.language');
    final saved = supportedLanguageFromCode(savedCode);

    if (saved != null && _translations.containsKey(saved)) {
      _currentLanguage = saved;
    }

    _initialized = true;
  }

  Future<void> _loadTranslations() async {
    try {
      final raw = await rootBundle.loadString(_translationsAsset);
      final data = jsonDecode(raw) as Map<String, dynamic>;

      for (final entry in data.entries) {
        final language = supportedLanguageFromCode(entry.key);
        if (language == null) {
          continue;
        }

        final value = entry.value;
        if (value is Map<String, dynamic>) {
          _translations[language] = value.map(
            (key, dynamic v) => MapEntry(key, v.toString()),
          );
        }
      }

      if (_translations.containsKey(SupportedLanguage.en)) {
        _fallbackLanguage = SupportedLanguage.en;
      } else if (_translations.isNotEmpty) {
        _fallbackLanguage = _translations.keys.first;
      }
    } catch (error) {
      // 如果加载失败，保持空映射，返回原始key
      _translations.clear();
    }
  }

  bool get isInitialized => _initialized;

  SupportedLanguage get currentLanguage => _currentLanguage;

  Locale get currentLocale => _currentLanguage.locale;

  List<Locale> get supportedLocales {
    final locales = SupportedLanguage.values
        .where((lang) => _translations.containsKey(lang))
        .map((lang) => lang.locale)
        .toList();
    if (locales.isEmpty) {
      locales.add(SupportedLanguage.zhHans.locale);
    }
    return locales;
  }

  List<SupportedLanguage> get loadedLanguages {
    final languages = SupportedLanguage.values
        .where((lang) => _translations.containsKey(lang))
        .toList();
    if (languages.isEmpty) {
      languages.add(SupportedLanguage.zhHans);
    }
    return languages;
  }

  Future<void> switchLanguage(SupportedLanguage language) async {
    if (language == _currentLanguage || !_translations.containsKey(language)) {
      return;
    }

    _currentLanguage = language;
    await _dataManager.setStringVariable('sakiengine.language', language.code, _projectName!);
    notifyListeners();
  }

  String t(String key, {Map<String, String>? params, SupportedLanguage? language}) {
    final lang = language ?? _currentLanguage;
    String? value = _translations[lang]?[key] ?? _translations[_fallbackLanguage]?[key];

    value ??= key;

    if (params != null && params.isNotEmpty) {
      for (final entry in params.entries) {
        value = value?.replaceAll('{${entry.key}}', entry.value);
      }
    }

    return value ?? key;
  }

  String displayName(SupportedLanguage language) {
    final translated = t('language.${language.code}', language: language);
    if (translated != 'language.${language.code}') {
      return translated;
    }
    return language.englishName;
  }
}
