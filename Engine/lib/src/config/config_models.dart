class CharacterConfig {
  final String id;
  final String name;
  final String resourceId;
  final String? defaultPoseId;

  CharacterConfig({
    required this.id,
    required this.name,
    required this.resourceId,
    this.defaultPoseId,
  });
}

class PoseConfig {
  final String id;
  final double scale;
  final double xcenter;
  final double ycenter;
  final String anchor;

  PoseConfig({
    required this.id,
    this.scale = 0,
    this.xcenter = 0.5,
    this.ycenter = 1.0,
    this.anchor = 'bottomCenter',
  });
} 