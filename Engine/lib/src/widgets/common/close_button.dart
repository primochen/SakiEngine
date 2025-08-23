import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';

class CommonCloseButton extends StatelessWidget {
  final VoidCallback onClose;
  final double scale;

  const CommonCloseButton({
    super.key,
    required this.onClose,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final config = SakiEngineConfig();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onClose,
        borderRadius: BorderRadius.circular(20 * scale),
        child: Container(
          width: 36 * scale,
          height: 36 * scale,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: config.themeColors.primary.withValues(alpha: 0.1),
            border: Border.all(
              color: config.themeColors.primary.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.close,
            color: config.themeColors.primary.withValues(alpha: 0.8),
            size: 20 * scale,
          ),
        ),
      ),
    );
  }
}





