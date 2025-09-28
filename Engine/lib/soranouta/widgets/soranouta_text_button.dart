import 'package:flutter/material.dart';
import 'package:sakiengine/src/utils/settings_manager.dart';

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
    final isDarkMode = SettingsManager().currentDarkMode;
    final normalColor = isDarkMode ? Colors.black : Colors.white;
    final hoverColor = isDarkMode ? Colors.white : Colors.black;
    
    print('[SoranoutaTextButton] ${widget.text} - isDarkMode: $isDarkMode, normalColor: $normalColor, hoverColor: $hoverColor');
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          margin: EdgeInsets.only(right: 20 * widget.scale), // 给按钮添加右边距
          child: Text(
            widget.text,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'ChillJinshuSongPro_Soft',
              fontSize: 55 * widget.scale,
              color: _isHovered ? hoverColor : normalColor,
              fontWeight: FontWeight.normal,
              letterSpacing: 3,
            ),
          ),
        ),
      ),
    );
  }
}