abstract class SkrNode {}

class ScriptNode implements SkrNode {
  final List<SkrNode> children;
  ScriptNode(this.children);
}

class ShowNode implements SkrNode {
  final String character;
  final String? pose;
  final String? expression;
  ShowNode(this.character, {this.pose, this.expression});
}

class HideNode implements SkrNode {
  final String character;
  HideNode(this.character);
}

class BackgroundNode implements SkrNode {
  final String background;
  BackgroundNode(this.background);
}

class SayNode implements SkrNode {
  final String? character;
  final String dialogue;
  final String? pose;
  final String? expression;
  SayNode({this.character, required this.dialogue, this.pose, this.expression});
}

class ChoiceOptionNode {
  final String text;
  final String targetLabel;
  ChoiceOptionNode(this.text, this.targetLabel);
}

class MenuNode implements SkrNode {
  final List<ChoiceOptionNode> choices;
  MenuNode(this.choices);
}

class LabelNode implements SkrNode {
  final String name;
  LabelNode(this.name);
}

class ReturnNode implements SkrNode {} 