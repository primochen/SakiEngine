import 'package:flutter/material.dart';

class SoranoutaTextButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final double scale;

  const SoranoutaTextButton({
    super.key,
    required this.text,
    required this.onPressed,
    required this.scale,
  });

  @override
  State<SoranoutaTextButton> createState() => _SoranoutaTextButtonState();
}

class _SoranoutaTextButtonState extends State<SoranoutaTextButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Text(
          widget.text,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontFamily: 'ChillJinshuSongPro_Soft',
            fontSize: 55 * widget.scale,
            color: _isHovered ? Colors.white : Colors.black,
            fontWeight: FontWeight.normal,
            letterSpacing: 3,
          ),
        ),
      ),
    );
  }
}