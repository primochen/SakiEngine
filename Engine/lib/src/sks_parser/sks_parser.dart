import 'package:sakiengine/src/sks_parser/sks_ast.dart';
import 'package:sakiengine/src/rendering/color_background_renderer.dart';

class SksParser {
  ScriptNode parse(String content) {
    final lines = content.split('\n');
    final nodes = <SksNode>[];
    int i = 0;
    while (i < lines.length) {
      final trimmedLine = lines[i].trim();
      if (trimmedLine.isEmpty || trimmedLine.startsWith('//')) {
        i++;
        continue;
      }
      final parts = trimmedLine.split(' ');
      final command = parts[0];
      switch (command) {
        case 'label':
          nodes.add(LabelNode(parts[1]));
          break;
        case 'jump':
          nodes.add(JumpNode(parts[1]));
          break;
        case 'return':
          nodes.add(ReturnNode());
          break;
        case 'menu':
          final choiceNodes = <ChoiceOptionNode>[];
          i++; 
          while (i < lines.length) {
            final menuLine = lines[i].trim();
            if (menuLine.startsWith('endmenu')) {
              break;
            }
            if (menuLine.isNotEmpty && !menuLine.startsWith('//')) {
              final choiceMatch = RegExp(r'"([^"]*)"\s+(\w+)')
                  .firstMatch(menuLine);
              if (choiceMatch != null) {
                final text = choiceMatch.group(1)!;
                final targetLabel = choiceMatch.group(2)!;
                choiceNodes.add(ChoiceOptionNode(text, targetLabel));
              }
            }
            i++;
          }
          nodes.add(MenuNode(choiceNodes));
          break;
        case 'endmenu':
          break;
        case 'scene':
          final allParams = parts.sublist(1);
          String backgroundName = '';
          double? timerValue;
          String? fxString;
          
          // 解析参数
          int i = 0;
          while (i < allParams.length) {
            if (allParams[i] == 'timer' && i + 1 < allParams.length) {
              timerValue = double.tryParse(allParams[i + 1]);
              i += 2; // 跳过timer和值
            } else if (allParams[i] == 'fx') {
              // 收集fx后面的所有参数
              if (i + 1 < allParams.length) {
                fxString = allParams.sublist(i + 1).join(' ');
              }
              break; // fx是最后的参数
            } else {
              backgroundName += (backgroundName.isEmpty ? '' : ' ') + allParams[i];
              i++;
            }
          }
          
          // 检查是否为十六进制颜色格式
          if (ColorBackgroundRenderer.isValidHexColor(backgroundName.trim())) {
            nodes.add(BackgroundNode(backgroundName.trim(), timer: timerValue));
          } else {
            nodes.add(BackgroundNode(backgroundName, timer: timerValue));
          }
          
          // 如果有fx参数，添加FxNode
          if (fxString != null && fxString.isNotEmpty) {
            nodes.add(FxNode(fxString));
          }
          break;
        case 'show':
          final character = parts[1];
          String? pose;
          String? expression;
          for (int i = 2; i < parts.length; i++) {
            if (parts[i].startsWith('pose:')) {
              pose = parts[i].substring(5);
            } else if (parts[i].startsWith('expression:')) {
              expression = parts[i].substring(11);
            }
          }
          nodes.add(ShowNode(character, pose: pose, expression: expression));
          break;
        case 'hide':
          nodes.add(HideNode(parts[1]));
          break;
        case 'nvl':
          nodes.add(NvlNode());
          break;
        case 'endnvl':
          nodes.add(EndNvlNode());
          break;
        case 'nvlm':
          nodes.add(NvlMovieNode());
          break;
        case 'endnvlm':
          nodes.add(EndNvlMovieNode());
          break;
        case 'fx':
          final filterString = parts.sublist(1).join(' ');
          nodes.add(FxNode(filterString));
          break;
        default:
          final sayNode = _parseSay(trimmedLine);
          if (sayNode != null) {
            nodes.add(sayNode);
          }
          break;
      }
      i++;
    }
    return ScriptNode(nodes);
  }

  SayNode? _parseSay(String line) {
    // Improved regex to capture character, attributes and dialogue
    // 1: Optional character and attributes part
    // 2: Dialogue part
    final sayRegex = RegExp(r'^(.*?)\s*"([^"]*)"$');
    final match = sayRegex.firstMatch(line);

    if (match == null) {
      // Simple narration check for lines that are just "dialogue"
      final simpleNarrationRegex = RegExp(r'^"([^"]*)"$');
      final simpleMatch = simpleNarrationRegex.firstMatch(line);
      if (simpleMatch != null) {
        return SayNode(dialogue: simpleMatch.group(1)!);
      }
      return null;
    }
    
    final dialogue = match.group(2)!;
    final beforeQuote = match.group(1)!.trim();

    if (beforeQuote.isEmpty) {
      // Narration: "dialogue"
      return SayNode(dialogue: dialogue);
    }
    
    final parts = beforeQuote.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return null; // Should not happen with this regex, but for safety

    final character = parts[0];
    String? pose;
    String? expression;
    
    // This logic is a placeholder. You'll need a robust way to distinguish
    // poses from expressions, likely by checking against loaded pose/expression configs.
    if (parts.length > 1) {
        final attrs = parts.sublist(1);
        // A simple heuristic: if it contains 'pose', it's a pose.
        // This is not robust. A better way would be to check against a list of valid poses.
        pose = attrs.firstWhere((attr) => attr.contains('pose'), orElse: () => '');
        expression = attrs.firstWhere((attr) => !attr.contains('pose'), orElse: () => '');

        if(pose.isEmpty) pose = null;
        if(expression.isEmpty) expression = null;
    }
    
    return SayNode(character: character, dialogue: dialogue, pose: pose, expression: expression);
  }
} 