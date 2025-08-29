import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/utils/smart_asset_image.dart';

class GameBackgroundWidget extends StatelessWidget {
  final SakiEngineConfig config;

  const GameBackgroundWidget({
    super.key,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    return SmartAssetImage(
      assetName: 'backgrounds/${config.mainMenuBackground}',
      fit: BoxFit.cover,
      errorWidget: Container(color: Colors.black),
    );
  }
}