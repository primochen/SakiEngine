import 'package:flutter/material.dart';
import 'package:sakiengine/src/utils/settings_manager.dart';
import 'package:sakiengine/src/utils/ui_sound_manager.dart';

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
  bool _isPressed = false; // 添加按下状态
  final _uiSoundManager = UISoundManager();

  @override
  Widget build(BuildContext context) {
    final isDarkMode = SettingsManager().currentDarkMode;
    final normalColor = isDarkMode ? Colors.black : Colors.white;
    final hoverColor = isDarkMode ? Colors.white : Colors.black;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _uiSoundManager.playButtonHover();
      },
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          _uiSoundManager.playButtonClick();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onPressed,
        child: Container(
          margin: EdgeInsets.only(right: 20 * widget.scale),
          child: Text(
            widget.text,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'ChillJinshuSongPro_Soft',
              fontSize: 55 * widget.scale,
              color: (_isHovered || _isPressed) ? hoverColor : normalColor,
              fontWeight: FontWeight.normal,
              letterSpacing: 3,
            ),
          ),
        ),
      ),
    );
  }
}
