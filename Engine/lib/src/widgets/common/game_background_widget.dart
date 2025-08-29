import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/asset_manager.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/widgets/smart_image.dart';

class GameBackgroundWidget extends StatelessWidget {
  final SakiEngineConfig config;

  const GameBackgroundWidget({
    super.key,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: AssetManager().findAsset('backgrounds/${config.mainMenuBackground}'),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return SmartImage.asset(
            snapshot.data!,
            fit: BoxFit.cover,
          );
        }
        return Container(color: Colors.black);
      },
    );
  }
}