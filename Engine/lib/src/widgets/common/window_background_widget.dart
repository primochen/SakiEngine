import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/utils/smart_asset_image.dart';

class WindowBackgroundWidget extends StatelessWidget {
  final Widget child;
  final SakiEngineConfig config;

  const WindowBackgroundWidget({
    super.key,
    required this.child,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    if (config.baseWindowBackground == null || config.baseWindowBackground!.isEmpty) {
      return child;
    }

    return ClipRect(
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: config.themeColors.background.withOpacity(0.99),
                child: Align(
                  alignment: Alignment(
                    (config.baseWindowXAlign - 0.5) * 2,
                    (config.baseWindowYAlign - 0.5) * 2,
                  ),
                  child: SmartAssetImage(
                    assetName: config.baseWindowBackground!,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}