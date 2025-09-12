import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 右键隐藏UI管理器
/// 视觉小说标配功能，右键可以隐藏/显示所有UI元素，左键推进剧情
class RightClickUIManager extends StatefulWidget {
  /// 子组件 - 包含所有UI元素
  final Widget child;
  
  /// 背景组件 - 不会被隐藏的背景内容（角色、背景等）
  final Widget backgroundChild;
  
  /// UI隐藏状态改变回调
  final Function(bool isUIHidden)? onUIVisibilityChanged;
  
  /// 左键点击回调（用于推进剧情）
  final VoidCallback? onLeftClick;

  const RightClickUIManager({
    super.key,
    required this.child,
    required this.backgroundChild,
    this.onUIVisibilityChanged,
    this.onLeftClick,
  });

  @override
  State<RightClickUIManager> createState() => _RightClickUIManagerState();
}

class _RightClickUIManagerState extends State<RightClickUIManager>
    with TickerProviderStateMixin {
  
  /// UI是否被隐藏
  bool _isUIHidden = false;
  
  /// 动画控制器
  late AnimationController _animationController;
  
  /// 淡出动画
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // 初始化动画控制器
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    // 初始化淡出动画
    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    // 设置初始值
    _animationController.value = 1.0;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// 切换UI显示状态
  void _toggleUIVisibility() {
    setState(() {
      _isUIHidden = !_isUIHidden;
    });
    
    // 播放动画
    if (_isUIHidden) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
    
    // 通知回调
    widget.onUIVisibilityChanged?.call(_isUIHidden);
    
    // 提供触觉反馈
    HapticFeedback.lightImpact();
  }

  /// 处理右键点击
  void _handleRightClick(TapUpDetails details) {
    _toggleUIVisibility();
  }

  /// 处理键盘事件（ESC键也可以切换UI）
  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
      _toggleUIVisibility();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: _handleKeyEvent,
      child: Stack(
        children: [
          // 背景层 - 不会被隐藏
          widget.backgroundChild,
          
          // 右键检测层 - 放在背景上面，UI下面
          Positioned.fill(
            child: Listener(
              onPointerDown: (event) {
                if (event.buttons == 2) { // 右键按下
                  _toggleUIVisibility();
                } else if (event.buttons == 1) { // 左键按下
                  if (_isUIHidden) {
                    // UI隐藏状态下，左键取消隐藏
                    _toggleUIVisibility();
                  } else {
                    // UI显示状态下，左键推进剧情
                    widget.onLeftClick?.call();
                  }
                }
              },
              behavior: HitTestBehavior.translucent,
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
          
          // UI层 - 可以被隐藏，在最上面
          AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _isUIHidden ? _fadeAnimation.value : 1.0,
                child: IgnorePointer(
                  ignoring: _isUIHidden,
                  child: widget.child,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 全局右键UI管理器状态
class GlobalRightClickUIManager extends ChangeNotifier {
  static final GlobalRightClickUIManager _instance = GlobalRightClickUIManager._internal();
  factory GlobalRightClickUIManager() => _instance;
  GlobalRightClickUIManager._internal();

  /// 当前UI是否被隐藏
  bool _isUIHidden = false;
  bool get isUIHidden => _isUIHidden;

  /// 设置UI隐藏状态
  void setUIHidden(bool hidden) {
    if (_isUIHidden != hidden) {
      _isUIHidden = hidden;
      notifyListeners();
    }
  }

  /// 切换UI显示状态
  void toggleUIVisibility() {
    setUIHidden(!_isUIHidden);
  }
}

/// 右键UI管理Mixin，方便其他组件使用
mixin RightClickUIManagerMixin<T extends StatefulWidget> on State<T> {
  final GlobalRightClickUIManager _globalManager = GlobalRightClickUIManager();
  
  bool get isUIHidden => _globalManager.isUIHidden;
  
  @override
  void initState() {
    super.initState();
    _globalManager.addListener(_onUIVisibilityChanged);
  }
  
  @override
  void dispose() {
    _globalManager.removeListener(_onUIVisibilityChanged);
    super.dispose();
  }
  
  void _onUIVisibilityChanged() {
    if (mounted) {
      setState(() {});
    }
  }
  
  /// 子类可以重写此方法来处理UI隐藏状态变化
  void onUIVisibilityChanged(bool isHidden) {}
}

/// 可隐藏的UI组件包装器
class HideableUI extends StatelessWidget {
  final Widget child;
  final bool hideWhenUIHidden;
  final double hiddenOpacity;
  final Duration animationDuration;

  const HideableUI({
    super.key,
    required this.child,
    this.hideWhenUIHidden = true,
    this.hiddenOpacity = 0.0,
    this.animationDuration = const Duration(milliseconds: 200),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: GlobalRightClickUIManager(),
      builder: (context, child) {
        final isHidden = GlobalRightClickUIManager().isUIHidden;
        final shouldHide = hideWhenUIHidden && isHidden;
        
        return AnimatedOpacity(
          opacity: shouldHide ? hiddenOpacity : 1.0,
          duration: animationDuration,
          child: IgnorePointer(
            ignoring: shouldHide,
            child: this.child,
          ),
        );
      },
    );
  }
}