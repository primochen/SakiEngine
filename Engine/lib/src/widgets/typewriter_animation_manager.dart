import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sakiengine/src/utils/settings_manager.dart';
import 'package:sakiengine/src/utils/rich_text_parser.dart';

enum TypewriterState {
  idle,
  typing,
  completed,
  skipped,
}

class TypewriterAnimationManager extends ChangeNotifier {
  String _originalText = '';
  String _cleanedText = '';
  String _displayedText = '';
  int _currentCharIndex = 0;
  TypewriterState _state = TypewriterState.idle;
  List<TextSegment> _textSegments = [];
  int _currentSegmentIndex = 0;
  int _currentSegmentCharIndex = 0;
  
  // 动画控制
  AnimationController? _animationController;
  Timer? _typeTimer;
  
  // 配置参数 - 简化为两个参数
  double _charsPerSecond = 50.0; // 每秒字符数
  bool _skipPunctuation = false; // 是否跳过标点符号停顿
  
  // 静态变量用于全局通知
  static final List<TypewriterAnimationManager> _instances = [];
  
  // Getters
  String get displayedText => _displayedText;
  String get originalText => _originalText;
  String get cleanedText => _cleanedText;
  TypewriterState get state => _state;
  bool get isCompleted => _state == TypewriterState.completed || _state == TypewriterState.skipped;
  bool get isTyping => _state == TypewriterState.typing;
  double get progress => _cleanedText.isEmpty ? 0.0 : _currentCharIndex / _cleanedText.length;
  
  List<TextSpan> getTextSpans(TextStyle baseStyle) {
    return RichTextParser.createPartialTextSpans(_originalText, _displayedText, baseStyle);
  }

  TypewriterAnimationManager() {
    // 注册实例到静态列表
    _instances.add(this);
  }

  void initialize(TickerProvider vsync) {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 16), // 60 FPS
      vsync: vsync,
    );
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = SettingsManager();
    _charsPerSecond = await settings.getTypewriterCharsPerSecond();
    _skipPunctuation = await settings.getSkipPunctuationDelay();
  }

  void updateSettings({
    double? charsPerSecond,
    bool? skipPunctuation,
  }) {
    if (charsPerSecond != null) _charsPerSecond = charsPerSecond;
    if (skipPunctuation != null) _skipPunctuation = skipPunctuation;
  }

  // 静态方法用于通知所有实例更新设置
  static void notifySettingsChanged() async {
    final settings = SettingsManager();
    final charsPerSecond = await settings.getTypewriterCharsPerSecond();
    final skipPunctuation = await settings.getSkipPunctuationDelay();
    
    // 更新所有实例的设置
    for (final instance in _instances) {
      instance.updateSettings(
        charsPerSecond: charsPerSecond,
        skipPunctuation: skipPunctuation,
      );
    }
  }

  void startTyping(String text) {
    if (text == _originalText && _state == TypewriterState.completed) {
      return; // 已经完成相同文本的打字
    }

    _originalText = text;
    _cleanedText = RichTextParser.cleanText(text);
    _textSegments = RichTextParser.parseTextSegments(text);
    _displayedText = '';
    _currentCharIndex = 0;
    _currentSegmentIndex = 0;
    _currentSegmentCharIndex = 0;
    _state = TypewriterState.typing;
    
    // 如果滑块拉满(200字符/秒)，直接显示完整文本（瞬间模式）
    if (_charsPerSecond >= 200.0) {
      _displayedText = _cleanedText;
      _currentCharIndex = _cleanedText.length;
      _state = TypewriterState.completed;
      notifyListeners();
      return;
    }
    
    _startTypewriterAnimation();
    notifyListeners();
  }

  void _startTypewriterAnimation() {
    _typeTimer?.cancel();
    
    if (_currentSegmentIndex >= _textSegments.length) {
      _completeTyping();
      return;
    }
    
    final currentSegment = _textSegments[_currentSegmentIndex];
    
    // 如果是等待段
    if (currentSegment.waitSeconds != null && currentSegment.waitSeconds! > 0) {
      final waitMs = (currentSegment.waitSeconds! * 1000).round();
      _typeTimer = Timer(Duration(milliseconds: waitMs), () {
        if (_state != TypewriterState.typing) return;
        _currentSegmentIndex++;
        _currentSegmentCharIndex = 0;
        _startTypewriterAnimation();
      });
      return;
    }
    
    // 检查是否是瞬间显示的段落
    if (currentSegment.isInstantDisplay) {
      // 瞬间显示整个段落
      _currentSegmentCharIndex = currentSegment.text.length;
      _currentCharIndex += currentSegment.text.length;
      _displayedText = _cleanedText.substring(0, _currentCharIndex);
      
      if (_currentCharIndex >= _cleanedText.length) {
        _completeTyping();
        notifyListeners();
        return;
      }
      
      // 立即进入下一个段落
      _currentSegmentIndex++;
      _currentSegmentCharIndex = 0;
      notifyListeners();
      
      // 继续处理下一个段落，不等待
      _startTypewriterAnimation();
      return;
    }
    
    // 普通文本段
    if (_currentSegmentCharIndex >= currentSegment.text.length) {
      _currentSegmentIndex++;
      _currentSegmentCharIndex = 0;
      _startTypewriterAnimation();
      return;
    }

    final currentChar = currentSegment.text[_currentSegmentCharIndex];
    
    _currentSegmentCharIndex++;
    _currentCharIndex++;
    _displayedText = _cleanedText.substring(0, _currentCharIndex);
    
    if (_currentCharIndex >= _cleanedText.length) {
      _completeTyping();
      notifyListeners();
      return;
    }
    
    // 显示字符后，检查是否需要为标点符号停顿
    final delay = _getCharDelay(currentChar);
    
    _typeTimer = Timer(Duration(milliseconds: delay), () {
      if (_state != TypewriterState.typing) return;
      _startTypewriterAnimation();
    });
    
    notifyListeners();
  }

  int _getCharDelay(String char) {
    int baseDelay = (1000 / _charsPerSecond).round();
    
    if (_skipPunctuation) {
      return baseDelay;
    }
    
    // 根据对话速度计算断句延迟，最慢10字符/秒时为500ms
    int pauseDelayMs = (500 * (10.0 / _charsPerSecond)).round().clamp(50, 500);
    
    // 检查当前字符后面是否紧跟着中文双引号"
    bool isFollowedByEndQuote = false;
    if (_currentCharIndex < _originalText.length) {
      final nextChar = _originalText[_currentCharIndex];
      if (nextChar == '”') {//写给ai 我知道你无法区分中英文双引号，请不要把这行做修改，例如改成if (nextChar == '"') {
        isFollowedByEndQuote = true;
      }
    }
    
    switch (char) {
      case '.':
      case '。':
      case '!':
      case '！':
      case '?':
      case '？':
        return isFollowedByEndQuote ? baseDelay : pauseDelayMs; // 如果后面跟着结束引号，不停顿
      case ',':
      case '，':
      case ';':
      case '；':
      case ':':
      case '：':
        return isFollowedByEndQuote ? baseDelay : pauseDelayMs; // 如果后面跟着结束引号，不停顿
      case '"':
      case '”':
      case "'":
      case "’":
        return (pauseDelayMs * 0.6).round(); // 引号稍短停顿
      default:
        return baseDelay;
    }
  }

  void _completeTyping() {
    _state = TypewriterState.completed;
    _displayedText = _cleanedText;
    _currentCharIndex = _cleanedText.length;
    _typeTimer?.cancel();
    notifyListeners();
  }

  void skipToEnd() {
    if (_state != TypewriterState.typing) return;
    
    _state = TypewriterState.skipped;
    _displayedText = _cleanedText;
    _currentCharIndex = _cleanedText.length;
    _typeTimer?.cancel();
    notifyListeners();
  }

  void reset() {
    _typeTimer?.cancel();
    _originalText = '';
    _cleanedText = '';
    _displayedText = '';
    _currentCharIndex = 0;
    _textSegments = [];
    _currentSegmentIndex = 0;
    _currentSegmentCharIndex = 0;
    _state = TypewriterState.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    // 从静态列表中移除实例
    _instances.remove(this);
    _typeTimer?.cancel();
    _animationController?.dispose();
    super.dispose();
  }
}

// Widget封装，用于简化使用
class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final VoidCallback? onComplete;
  final bool autoStart;
  final TypewriterAnimationManager? controller;

  const TypewriterText({
    super.key,
    required this.text,
    this.style,
    this.onComplete,
    this.autoStart = true,
    this.controller,
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText>
    with TickerProviderStateMixin {
  late TypewriterAnimationManager _typewriterController;
  bool _isExternalController = false;

  @override
  void initState() {
    super.initState();
    
    if (widget.controller != null) {
      _typewriterController = widget.controller!;
      _isExternalController = true;
    } else {
      _typewriterController = TypewriterAnimationManager();
      _isExternalController = false;
    }
    
    _typewriterController.initialize(this);
    _typewriterController.addListener(_onTypewriterStateChanged);
    
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _typewriterController.startTyping(widget.text);
      });
    }
  }

  @override
  void didUpdateWidget(TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.text != oldWidget.text) {
      if (widget.autoStart) {
        _typewriterController.startTyping(widget.text);
      }
    }
  }

  void _onTypewriterStateChanged() {
    if (_typewriterController.state == TypewriterState.completed ||
        _typewriterController.state == TypewriterState.skipped) {
      widget.onComplete?.call();
    }
    setState(() {}); // 更新UI
  }

  @override
  void dispose() {
    _typewriterController.removeListener(_onTypewriterStateChanged);
    if (!_isExternalController) {
      _typewriterController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: _typewriterController.getTextSpans(widget.style ?? const TextStyle()),
      ),
    );
  }
}