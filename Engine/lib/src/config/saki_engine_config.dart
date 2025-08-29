import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/asset_manager.dart';
import 'package:sakiengine/src/utils/color_parser.dart';

class ThemeColors {
  final Color primary;
  final Color primaryDark;
  final Color primaryLight;
  final Color background;
  final Color surface;
  final Color onSurface;
  final Color onSurfaceVariant;

  ThemeColors({
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.background,
    required this.surface,
    required this.onSurface,
    required this.onSurfaceVariant,
  });

  factory ThemeColors.fromPrimary(Color primary) {
    // 从主色生成色彩系统
    final hsl = HSLColor.fromColor(primary);
    
    return ThemeColors(
      primary: primary,
      primaryDark: HSLColor.fromAHSL(1.0, hsl.hue, hsl.saturation, (hsl.lightness - 0.2).clamp(0.0, 1.0)).toColor(),
      primaryLight: HSLColor.fromAHSL(1.0, hsl.hue, hsl.saturation, (hsl.lightness + 0.2).clamp(0.0, 1.0)).toColor(),
      background: HSLColor.fromAHSL(1.0, hsl.hue, hsl.saturation * 0.3, 0.95).toColor(),
      surface: HSLColor.fromAHSL(1.0, hsl.hue, hsl.saturation * 0.8, 0.92).toColor(),
      onSurface: HSLColor.fromAHSL(1.0, hsl.hue, hsl.saturation * 0.6, 0.3).toColor(),
      onSurfaceVariant: HSLColor.fromAHSL(1.0, hsl.hue, hsl.saturation * 0.4, 0.5).toColor(),
    );
  }
}



class SakiEngineConfig {
  static final SakiEngineConfig _instance = SakiEngineConfig._internal();
  factory SakiEngineConfig() => _instance;
  SakiEngineConfig._internal();

  double logicalWidth = 1920;
  double logicalHeight = 1080;

  // 主菜单背景配置
  String mainMenuBackground = 'sky';
  String mainMenuTitle = '';
  double mainMenuTitleSize = 72.0;
  
  // 主菜单标题位置配置
  double mainMenuTitleTop = 0.1;
  double mainMenuTitleRight = 0.05;
  double mainMenuTitleBottom = 0.0;
  double mainMenuTitleLeft = 0.0;
  
  // 记录配置中实际设置的位置参数
  bool hasBottom = false;
  bool hasLeft = false;

  // NVL 模式间距配置
  double nvlLeft = 200.0;
  double nvlRight = 40.0;
  double nvlTop = 100.0;
  double nvlBottom = 60.0;

  // 基础窗口配置
  double baseWindowBorder = 0.0;
  double baseWindowAlpha = 1.0;
  String? baseWindowBackground;
  double baseWindowXAlign = 0.5;
  double baseWindowYAlign = 0.5;
  double baseWindowBackgroundAlpha = 0.3;
  BlendMode baseWindowBackgroundBlendMode = BlendMode.multiply;
  double baseWindowBackgroundScale = 1.0;
  
  // 对话框专用背景缩放
  double dialogueBackgroundScale = 1.0;
  double dialogueBackgroundXAlign = 1.0;
  double dialogueBackgroundYAlign = 0.5;

  // SoraNoUta 说话人位置配置
  double soranoutaSpeakerXPos = 0.2;
  double soranoutaSpeakerYPos = 0.0;
  
  // SoraNoUta 对话框内部文本位置配置
  double soranoUtaTextXPos = 0.0;
  double soranoUtaTextYPos = 0.0;

  TextStyle dialogueTextStyle = const TextStyle(fontSize: 24, color: Colors.white);
  TextStyle speakerTextStyle = const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold);
  TextStyle choiceTextStyle = const TextStyle(fontSize: 24, color: Colors.white);
  TextStyle reviewTitleTextStyle = const TextStyle(fontSize: 36, color: Color(0xFF5D4037), fontWeight: FontWeight.w300);
  TextStyle quickMenuTextStyle = const TextStyle(fontSize: 14, color: Colors.white);

  // 全局主题系统
  String currentTheme = 'brown';
  ThemeColors themeColors = ThemeColors.fromPrimary(const Color(0xFF8B4513));

  TextStyle? textButtonDefaultStyle;

  Future<void> loadConfig() async {
    try {
      final configContent =
          await AssetManager().loadString('assets/GameScript/configs/configs.sks');
      final lines = configContent.split('\n');
      for (final line in lines) {
        final trimmedLine = line.trim();
        if (trimmedLine.startsWith('theme:')) {
          final paramsString = trimmedLine.split(':')[1].trim();
          final colorMatch = RegExp(r'color\s*=\s*([#\w(),.\s]+)').firstMatch(paramsString);
          if (colorMatch != null) {
            final colorValue = colorMatch.group(1)?.trim();
            if (colorValue != null) {
              final themeColor = parseColor(colorValue);
              if (themeColor != null) {
                currentTheme = colorValue;
                themeColors = ThemeColors.fromPrimary(themeColor);
              }
            }
          }
        }
        if (trimmedLine.startsWith('main_menu:')) {
          print('Debug: parsing main_menu config line: $trimmedLine');
          final menuParams = trimmedLine.split(':')[1].trim().split(' ');
          for (final param in menuParams) {
            final keyValue = param.split('=');
            if (keyValue.length == 2) {
              print('Debug: parsing param ${keyValue[0]} = ${keyValue[1]}');
              switch (keyValue[0]) {
                case 'title':
                  mainMenuTitle = keyValue[1];
                  print('Debug: set mainMenuTitle to: $mainMenuTitle');
                  break;
                case 'background':
                  mainMenuBackground = keyValue[1];
                  break;
                case 'size':
                  mainMenuTitleSize = double.tryParse(keyValue[1]) ?? 72.0;
                  print('Debug: set mainMenuTitleSize to: $mainMenuTitleSize');
                  break;
                case 'top':
                  mainMenuTitleTop = double.tryParse(keyValue[1]) ?? 0.1;
                  break;
                case 'right':
                  mainMenuTitleRight = double.tryParse(keyValue[1]) ?? 0.05;
                  break;
                case 'bottom':
                  mainMenuTitleBottom = double.tryParse(keyValue[1]) ?? 0.0;
                  hasBottom = true;
                  print('Debug: set mainMenuTitleBottom to: $mainMenuTitleBottom');
                  break;
                case 'left':
                  mainMenuTitleLeft = double.tryParse(keyValue[1]) ?? 0.0;
                  hasLeft = true;
                  print('Debug: set mainMenuTitleLeft to: $mainMenuTitleLeft');
                  break;
              }
            }
          }
        }
        if (trimmedLine.startsWith('base_textbutton:')) {
          textButtonDefaultStyle =
              _parseTextStyle(trimmedLine.split(':')[1].trim());
        }
        if (trimmedLine.startsWith('base_dialogue:')) {
          dialogueTextStyle = _parseTextStyle(trimmedLine.split(':')[1].trim());
        }
        if (trimmedLine.startsWith('base_speaker:')) {
          speakerTextStyle = _parseTextStyle(trimmedLine.split(':')[1].trim());
        }
        if (trimmedLine.startsWith('base_choice:')) {
          choiceTextStyle = _parseTextStyle(trimmedLine.split(':')[1].trim());
        }
        if (trimmedLine.startsWith('base_review_title:')) {
          reviewTitleTextStyle = _parseTextStyle(trimmedLine.split(':')[1].trim())
              .copyWith(fontWeight: FontWeight.w300);
        }
        if (trimmedLine.startsWith('base_quick_menu:')) {
          quickMenuTextStyle = _parseTextStyle(trimmedLine.split(':')[1].trim());
        }
        if (trimmedLine.startsWith('nvl:')) {
          final nvlParams = trimmedLine.split(':')[1].trim().split(' ');
          for (final param in nvlParams) {
            final keyValue = param.split('=');
            if (keyValue.length == 2) {
              switch (keyValue[0]) {
                case 'left':
                  nvlLeft = double.tryParse(keyValue[1]) ?? 200.0;
                  break;
                case 'right':
                  nvlRight = double.tryParse(keyValue[1]) ?? 40.0;
                  break;
                case 'top':
                  nvlTop = double.tryParse(keyValue[1]) ?? 100.0;
                  break;
                case 'bottom':
                  nvlBottom = double.tryParse(keyValue[1]) ?? 60.0;
                  break;
              }
            }
          }
        }
        if (trimmedLine.startsWith('base_window:')) {
          final windowParams = trimmedLine.split(':')[1].trim().split(' ');
          for (final param in windowParams) {
            final keyValue = param.split('=');
            if (keyValue.length == 2) {
              switch (keyValue[0]) {
                case 'border':
                  baseWindowBorder = double.tryParse(keyValue[1]) ?? 0.0;
                  print('[Config] baseWindowBorder 设置为: $baseWindowBorder');
                  break;
                case 'alpha':
                  baseWindowAlpha = double.tryParse(keyValue[1]) ?? 1.0;
                  print('[Config] baseWindowAlpha 设置为: $baseWindowAlpha');
                  break;
                case 'background':
                  baseWindowBackground = keyValue[1];
                  print('[Config] baseWindowBackground 设置为: $baseWindowBackground');
                  break;
                case 'xalign':
                  baseWindowXAlign = double.tryParse(keyValue[1]) ?? 0.5;
                  print('[Config] baseWindowXAlign 设置为: $baseWindowXAlign');
                  break;
                case 'yalign':
                  baseWindowYAlign = double.tryParse(keyValue[1]) ?? 0.5;
                  print('[Config] baseWindowYAlign 设置为: $baseWindowYAlign');
                  break;
                case 'background_alpha':
                  baseWindowBackgroundAlpha = double.tryParse(keyValue[1]) ?? 0.3;
                  print('[Config] baseWindowBackgroundAlpha 设置为: $baseWindowBackgroundAlpha');
                  break;
                case 'background_blend':
                  baseWindowBackgroundBlendMode = _parseBlendMode(keyValue[1]);
                  print('[Config] baseWindowBackgroundBlendMode 设置为: $baseWindowBackgroundBlendMode');
                  break;
                case 'background_scale':
                  baseWindowBackgroundScale = double.tryParse(keyValue[1]) ?? 1.0;
                  print('[Config] baseWindowBackgroundScale 设置为: $baseWindowBackgroundScale');
                  break;
                case 'background_xalign':
                  baseWindowXAlign = (double.tryParse(keyValue[1]) ?? 0.5).clamp(0.0, 1.0);
                  print('[Config] baseWindowXAlign 设置为: $baseWindowXAlign');
                  break;
                case 'background_yalign':
                  baseWindowYAlign = (double.tryParse(keyValue[1]) ?? 0.5).clamp(0.0, 1.0);
                  print('[Config] baseWindowYAlign 设置为: $baseWindowYAlign');
                  break;
                case 'dialogue_background_scale':
                  dialogueBackgroundScale = double.tryParse(keyValue[1]) ?? 1.0;
                  print('[Config] dialogueBackgroundScale 设置为: $dialogueBackgroundScale');
                  break;
                case 'dialogue_background_xalign':
                  dialogueBackgroundXAlign = double.tryParse(keyValue[1]) ?? 1.0;
                  print('[Config] dialogueBackgroundXAlign 设置为: $dialogueBackgroundXAlign');
                  break;
                case 'dialogue_background_yalign':
                  dialogueBackgroundYAlign = double.tryParse(keyValue[1]) ?? 0.5;
                  print('[Config] dialogueBackgroundYAlign 设置为: $dialogueBackgroundYAlign');
                  break;
              }
            }
          }
        }
        if (trimmedLine.startsWith('soranouta_dialogbox:')) {
          final params = trimmedLine.split(':')[1].trim().split(' ');
          for (final param in params) {
            final keyValue = param.split('=');
            if (keyValue.length == 2) {
              switch (keyValue[0]) {
                case 'xpos':
                  soranoutaSpeakerXPos = double.tryParse(keyValue[1]) ?? 0.2;
                  print('[Config] soranoutaSpeakerXPos 设置为: $soranoutaSpeakerXPos');
                  break;
                case 'ypos':
                  soranoutaSpeakerYPos = double.tryParse(keyValue[1]) ?? 0.0;
                  print('[Config] soranoutaSpeakerYPos 设置为: $soranoutaSpeakerYPos');
                  break;
                case 'dialogue_xpos':
                  soranoUtaTextXPos = double.tryParse(keyValue[1]) ?? 0.0;
                  print('[Config] soranoUtaTextXPos 设置为: $soranoUtaTextXPos');
                  break;
                case 'dialogue_ypos':
                  soranoUtaTextYPos = double.tryParse(keyValue[1]) ?? 0.0;
                  print('[Config] soranoUtaTextYPos 设置为: $soranoUtaTextYPos');
                  break;
              }
            }
          }
        }
      }
    } catch (e) {
      // 如果配置文件读取失败，保持默认值
    }
  }

  TextStyle _parseTextStyle(String styleString) {
    double? size;
    Color? color;

    final matches = RegExp(r'(\w+)\s*=\s*([#\w(),.\s]+)').allMatches(styleString);

    for (final match in matches) {
      final key = match.group(1);
      final value = match.group(2)?.trim();

      if (key != null && value != null) {
        switch (key) {
          case 'size':
            size = double.tryParse(value);
            break;
          case 'color':
            color = parseColor(value);
            break;
        }
      }
    }
    
    return TextStyle(fontSize: size, color: color, fontFamily: 'SourceHanSansCN');
  }

  BlendMode _parseBlendMode(String blendModeString) {
    switch (blendModeString.toLowerCase()) {
      case 'multiply':
        return BlendMode.multiply;
      case 'screen':
        return BlendMode.screen;
      case 'overlay':
        return BlendMode.overlay;
      case 'darken':
        return BlendMode.darken;
      case 'lighten':
        return BlendMode.lighten;
      case 'color_dodge':
        return BlendMode.colorDodge;
      case 'color_burn':
        return BlendMode.colorBurn;
      case 'hard_light':
        return BlendMode.hardLight;
      case 'soft_light':
        return BlendMode.softLight;
      case 'difference':
        return BlendMode.difference;
      case 'exclusion':
        return BlendMode.exclusion;
      case 'src_over':
      default:
        return BlendMode.srcOver;
    }
  }


}