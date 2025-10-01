import 'dart:io';
import 'package:flutter/foundation.dart';
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

    // 移动端按钮尺寸加大
    final isMobile = !kIsWeb && (Platform.isIOS || Platform.isAndroid);
    final buttonSize = isMobile ? 56.0 : 36.0;
    final iconSize = isMobile ? 32.0 : 20.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onClose,
        borderRadius: BorderRadius.circular(buttonSize * scale / 2),
        child: Container(
          width: buttonSize * scale,
          height: buttonSize * scale,
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
            size: iconSize * scale,
          ),
        ),
      ),
    );
  }
}





