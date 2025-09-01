import 'package:flutter/material.dart';

class TextSpanWithSize {
  final String text;
  final double? sizeMultiplier;
  
  TextSpanWithSize(this.text, {this.sizeMultiplier});
}

class RichTextParser {
  static String cleanText(String text) {
    return text.replaceAll(RegExp(r'\[size=[0-9.]+\]'), '').replaceAll('[/size]', '');
  }
  
  static List<TextSpanWithSize> parseText(String text) {
    final List<TextSpanWithSize> spans = [];
    final sizeRegex = RegExp(r'\[size=([0-9.]+)\](.*?)\[/size\]');
    
    int lastEnd = 0;
    
    for (final match in sizeRegex.allMatches(text)) {
      // 添加匹配前的普通文本
      if (match.start > lastEnd) {
        final normalText = text.substring(lastEnd, match.start);
        if (normalText.isNotEmpty) {
          spans.add(TextSpanWithSize(normalText));
        }
      }
      
      // 添加带size标签的文本
      final sizeValue = double.tryParse(match.group(1)!) ?? 1.0;
      final taggedText = match.group(2)!;
      spans.add(TextSpanWithSize(taggedText, sizeMultiplier: sizeValue));
      
      lastEnd = match.end;
    }
    
    // 添加剩余的普通文本
    if (lastEnd < text.length) {
      final remainingText = text.substring(lastEnd);
      if (remainingText.isNotEmpty) {
        spans.add(TextSpanWithSize(remainingText));
      }
    }
    
    return spans;
  }
  
  static List<TextSpan> createTextSpans(String text, TextStyle baseStyle) {
    final parsedSpans = parseText(text);
    return parsedSpans.map((span) {
      final style = span.sizeMultiplier != null 
          ? baseStyle.copyWith(fontSize: baseStyle.fontSize! * span.sizeMultiplier!)
          : baseStyle;
      return TextSpan(text: span.text, style: style);
    }).toList();
  }
  
  static List<TextSpan> createPartialTextSpans(String originalText, String displayedText, TextStyle baseStyle) {
    final originalSpans = parseText(originalText);
    final List<TextSpan> result = [];
    
    // 计算已显示的清理后文本长度
    int displayedCleanLength = displayedText.length;
    int currentCleanPos = 0;
    
    for (final span in originalSpans) {
      final spanCleanLength = span.text.length;
      
      if (currentCleanPos + spanCleanLength <= displayedCleanLength) {
        // 完整显示这个span
        final style = span.sizeMultiplier != null 
            ? baseStyle.copyWith(fontSize: baseStyle.fontSize! * span.sizeMultiplier!)
            : baseStyle;
        result.add(TextSpan(text: span.text, style: style));
        currentCleanPos += spanCleanLength;
      } else if (currentCleanPos < displayedCleanLength) {
        // 部分显示这个span
        final partialLength = displayedCleanLength - currentCleanPos;
        final partialText = span.text.substring(0, partialLength);
        final style = span.sizeMultiplier != null 
            ? baseStyle.copyWith(fontSize: baseStyle.fontSize! * span.sizeMultiplier!)
            : baseStyle;
        result.add(TextSpan(text: partialText, style: style));
        break;
      } else {
        break;
      }
    }
    
    return result;
  }
}