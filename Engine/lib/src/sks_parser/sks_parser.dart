import 'package:flutter/material.dart';
import 'sks_ast.dart';
import '../config/saki_engine_config.dart';
import '../utils/color_parser.dart';

class SksParser {
  final SakiEngineConfig _config;

  SksParser() : _config = SakiEngineConfig();

  ScreenNode parse(String content) {
    final lines = content.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    
    if (lines.isEmpty || !lines.first.startsWith('screen ')) {
      throw const FormatException('SKS script must start with a "screen" definition.');
    }

    final screenName = lines.first.substring('screen '.length).trim();
    final nodes = _parseNodes(lines.sublist(1));

    return ScreenNode(screenName, nodes);
  }

  List<SksNode> _parseNodes(List<String> lines) {
    final nodes = <SksNode>[];
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.startsWith('add ')) {
        nodes.add(_parseAdd(line));
      } else if (line.startsWith('text ')) {
        nodes.add(_parseText(line));
      } else if (line.startsWith('textbutton ')) {
        nodes.add(_parseTextButton(line));
      } else if (line == 'hbox') {
        final hboxLines = <String>[];
        i++; // Move to the line after 'hbox'
        while (i < lines.length && lines[i] != 'endhbox') {
          hboxLines.add(lines[i]);
          i++;
        }
        nodes.add(_parseHBox(hboxLines));
      }
    }
    return nodes;
  }

  AddNode _parseAdd(String line) {
    final parts = line.split(' ').where((s) => s.isNotEmpty).toList();
    return AddNode(parts[1]);
  }

  TextNode _parseText(String line) {
    final text = _getStringArgument(line);
    return TextNode(
      text: text,
      font: _getArgument(line, 'font'),
      color: _getArgument(line, 'color'),
      size: double.tryParse(_getArgument(line, 'size') ?? ''),
      left: double.tryParse(_getArgument(line, 'left') ?? ''),
      right: double.tryParse(_getArgument(line, 'right') ?? ''),
      top: double.tryParse(_getArgument(line, 'top') ?? ''),
      bottom: double.tryParse(_getArgument(line, 'bottom') ?? ''),
    );
  }

  TextButtonNode _parseTextButton(String line) {
    final text = _getStringArgument(line);
    final action = _getArgument(line, 'action') ?? '';
    
    TextStyle? style;
    final sizeStr = _getArgument(line, 'size');
    final colorStr = _getArgument(line, 'color');

    if (sizeStr != null || colorStr != null) {
      double? size = sizeStr != null ? double.tryParse(sizeStr) : null;
      Color? color = parseColor(colorStr);
      style = TextStyle(fontSize: size, color: color);
    } else {
      style = _config.textButtonDefaultStyle;
    }

    return TextButtonNode(
      text: text,
      action: action,
      style: style,
    );
  }

  HBoxNode _parseHBox(List<String> lines) {
    double? left, right, top, bottom, spacing;
    final children = <SksNode>[];

    final propertyLines = <String>[];
    final childLines = <String>[];

    for (var line in lines) {
      if (line.startsWith('left') || line.startsWith('right') || line.startsWith('top') || line.startsWith('bottom') || line.startsWith('spacing')) {
        propertyLines.add(line);
      } else {
        childLines.add(line);
      }
    }

    for (var line in propertyLines) {
       final parts = line.split(' ');
       if(parts.length < 2) continue;

        switch (parts[0]) {
          case 'left':
            left = double.tryParse(parts[1]);
            break;
          case 'right':
            right = double.tryParse(parts[1]);
            break;
          case 'top':
            top = double.tryParse(parts[1]);
            break;
          case 'bottom':
            bottom = double.tryParse(parts[1]);
            break;
          case 'spacing':
            spacing = double.tryParse(parts[1]);
            break;
        }
    }
    
    children.addAll(_parseNodes(childLines));

    return HBoxNode(
      children: children,
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      spacing: spacing,
    );
  }

  String _getStringArgument(String line) {
    final match = RegExp(r'"([^"]*)"').firstMatch(line);
    return match?.group(1) ?? '';
  }

  String? _getArgument(String line, String key) {
    final match = RegExp('$key ((".*?")|([^ ]+))').firstMatch(line);
    if (match != null) {
      final value = match.group(1);
      if (value != null) {
        return value.replaceAll("\"", "");
      }
    }
    return null;
  }
}