import 'package:sakiengine/src/skr_parser/skr_ast.dart';

class SkrParser {
  ScriptNode parse(String content) {
    final lines = content.split('\n');
    final nodes = <SkrNode>[];
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
          nodes.add(BackgroundNode(parts.sublist(1).join(' ')));
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
        default:
          // Handles all dialogue variants: "...", yk "...", yk sad "...", yk pose1 sad "..."
          final quoteMatch = RegExp(r'"([^"]*)"').firstMatch(trimmedLine);
          if (quoteMatch == null) continue; // Not a dialogue line, skip.
          
          final dialogue = quoteMatch.group(1)!;
          final partsBeforeQuote = trimmedLine.substring(0, quoteMatch.start).trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();

          if (partsBeforeQuote.isEmpty) {
              // Narration: "dialogue"
              nodes.add(SayNode(dialogue: dialogue));
          } else {
              // Character dialogue
              final speaker = partsBeforeQuote[0];
              String? pose;
              String? expression;
              
              if (partsBeforeQuote.length > 1) {
                  final attrs = partsBeforeQuote.sublist(1);
                  attrs.forEach((attr) {
                    // Check config to see if it's a pose or expression
                    // This is a placeholder for actual config lookup
                    if(attr.contains('pose')) { 
                      pose = attr;
                    } else {
                      expression = attr;
                    }
                  });
              }
              
              nodes.add(SayNode(character: speaker, dialogue: dialogue, pose: pose, expression: expression));
          }
          break;
      }
      i++;
    }
    return ScriptNode(nodes);
  }
} 