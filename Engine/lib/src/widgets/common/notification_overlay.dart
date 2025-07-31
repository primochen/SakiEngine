import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';

class NotificationOverlay extends StatelessWidget {
  final bool show;
  final String message;
  final double scale;

  const NotificationOverlay({
    super.key,
    required this.show,
    required this.message,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final config = SakiEngineConfig();
    return IgnorePointer(
      ignoring: !show,
      child: AnimatedOpacity(
        opacity: show ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          color: Colors.black.withOpacity(0.5),
          child: Center(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 48 * scale, vertical: 32 * scale),
              decoration: BoxDecoration(
                color: config.themeColors.background.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(8 * scale),
                border: Border.all(color: config.themeColors.primary.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 15 * scale,
                  ),
                ],
              ),
              child: Text(
                message,
                style: config.reviewTitleTextStyle.copyWith(
                  fontSize: config.reviewTitleTextStyle.fontSize! * scale * 0.8,
                  color: config.themeColors.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

