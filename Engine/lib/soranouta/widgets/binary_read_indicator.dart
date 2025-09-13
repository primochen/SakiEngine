import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'dart:convert';

/// 二进制已读指示器
/// 将角色名称转换为二进制格式，然后用符号表示
/// 1 -> -    0 -> \
class BinaryReadIndicator extends StatelessWidget {
  final String? speaker;
  final double uiScale;
  final double textScale;
  final bool positioned;

  const BinaryReadIndicator({
    super.key,
    required this.speaker,
    required this.uiScale,
    required this.textScale,
    this.positioned = true,
  });

  /// 将字符串转换为二进制符号表示
  String _convertToBinarySymbols(String text) {
    final bytes = utf8.encode(text);
    final binaryString = bytes
        .map((byte) => byte.toRadixString(2).padLeft(8, '0'))
        .join();
    
    return binaryString
        .replaceAll('1', '-')
        .replaceAll('0', r'\');
  }

  /// 根据角色名称获取对应的简称
  String? _getSpeakerAlias(String speakerName) {
    // 根据 characters.sks 的映射关系
    switch (speakerName) {
      case '主角': return 'main';
      case '旁白': return 'nr';
      case '空白': return 'n';
      case '???': return 'nan';
      case '林澄母亲': return 'lm';
      case '林澄': return 'l';
      case '夏悠': return 'x';
      case '刘守真': return 'ls';
      case '李宫娜': return 'lg';
      case '老师': return 'sensei';
      case '老婆婆': return 'oba';
      default: return null;
    }
  }

  /// 根据说话人简称确定显示内容
  String _getDisplayText() {
    if (speaker == null || speaker!.isEmpty) {
      return _convertToBinarySymbols('system');
    }

    final alias = _getSpeakerAlias(speaker!);
    if (alias == null) {
      return _convertToBinarySymbols('ai'); // 未知角色默认显示ai
    }

    // 特殊处理：旁白角色不显示
    if (alias == 'nr' || alias == 'n') {
      return _convertToBinarySymbols('system');
    }

    // l (林澄) 显示 admin 转换后的符号
    if (alias == 'l') {
      return _convertToBinarySymbols('admin');
    }

    // 其他说话人显示 ai 转换后的符号
    return _convertToBinarySymbols('ai');
  }

  @override
  Widget build(BuildContext context) {
    final displayText = _getDisplayText();
    
    if (displayText.isEmpty) {
      return const SizedBox.shrink();
    }

    final config = SakiEngineConfig();
    
    final indicator = Container(
      padding: EdgeInsets.symmetric(
        horizontal: 6.0 * uiScale,
        vertical: 2.0 * uiScale,
      ),
      decoration: BoxDecoration(
        color: config.themeColors.onSurface,
        borderRadius: BorderRadius.circular(2.0 * uiScale),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            offset: Offset(1.0 * uiScale, 1.0 * uiScale),
            blurRadius: 2.0 * uiScale,
          ),
        ],
      ),
      child: Text(
        displayText,
        style: TextStyle(
          fontSize:24.0 * textScale,
          color: config.themeColors.surface,
          fontFamily: 'monospace',
          letterSpacing: -0.2,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );

    if (positioned) {
      return Positioned(
        bottom: 8.0 * uiScale,
        left: 100.0 * uiScale,
        child: indicator,
      );
    } else {
      return indicator;
    }
  }
}