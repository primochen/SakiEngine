import 'package:flutter/material.dart';

/// 卷帘动画包装器
/// 从上到下展开的卷帘效果
class AnimatedRollerBlind extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final bool startAnimation; // 控制动画是否开始

  const AnimatedRollerBlind({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 800),
    this.curve = Curves.easeOutCubic,
    this.startAnimation = true, // 默认立即开始
  });

  @override
  State<AnimatedRollerBlind> createState() => _AnimatedRollerBlindState();
}

class _AnimatedRollerBlindState extends State<AnimatedRollerBlind>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );

    // 只有当 startAnimation 为 true 时才开始动画
    if (widget.startAnimation) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(AnimatedRollerBlind oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 当 startAnimation 从 false 变为 true 时，启动动画
    if (!oldWidget.startAnimation && widget.startAnimation) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ClipRect(
          clipper: _RollerBlindClipper(_animation.value),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// 卷帘效果裁剪器
class _RollerBlindClipper extends CustomClipper<Rect> {
  final double progress;

  _RollerBlindClipper(this.progress);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width, size.height * progress);
  }

  @override
  bool shouldReclip(_RollerBlindClipper oldClipper) {
    return oldClipper.progress != progress;
  }
}
