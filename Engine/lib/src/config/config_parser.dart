import 'package:sakiengine/src/config/config_models.dart';

class ConfigParser {
  Map<String, CharacterConfig> parseCharacters(String content) {
    final configs = <String, CharacterConfig>{};
    final lines = content.split('\n');

    for (final line in lines) {
      if (line.trim().isEmpty || line.startsWith('//')) continue;
      final parts = line.split(':').map((p) => p.trim()).toList();
      if (parts.length < 3) continue;

      final id = parts[0];
      final name = parts[1].replaceAll('"', '');
      final resourceIdAndPose = parts[2].split(' ');
      final resourceId = resourceIdAndPose[0];
      String? defaultPoseId;
      if (resourceIdAndPose.length > 2 && resourceIdAndPose[1] == 'at') {
        defaultPoseId = resourceIdAndPose[2];
      }

      configs[id] = CharacterConfig(
        id: id,
        name: name,
        resourceId: resourceId,
        defaultPoseId: defaultPoseId,
      );
    }
    return configs;
  }

  Map<String, PoseConfig> parsePoses(String content) {
    final configs = <String, PoseConfig>{};
    final lines = content.split('\n');

    for (final line in lines) {
      if (line.trim().isEmpty || line.startsWith('//')) continue;

      final parts = line.split(':');
      if (parts.length != 2) continue;

      final id = parts[0].trim();
      final params = parts[1].trim().split(' ').map((p) => p.trim()).toList();

      double scale = 0;
      double xcenter = 0.5;
      double ycenter = 1.0;
      String anchor = 'bottomCenter';

      for (final param in params) {
        final kv = param.split('=');
        if (kv.length != 2) continue;

        final key = kv[0];
        final value = kv[1];

        switch (key) {
          case 'scale':
            scale = double.tryParse(value) ?? 0;
            break;
          case 'xcenter':
            xcenter = double.tryParse(value) ?? 0.5;
            break;
          case 'ycenter':
            ycenter = double.tryParse(value) ?? 1.0;
            break;
          case 'anchor':
            anchor = value;
            break;
        }
      }

      configs[id] = PoseConfig(
        id: id,
        scale: scale,
        xcenter: xcenter,
        ycenter: ycenter,
        anchor: anchor,
      );
    }
    return configs;
  }
} 