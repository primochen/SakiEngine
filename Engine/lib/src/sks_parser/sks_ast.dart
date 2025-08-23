abstract class SksNode {}

class ScriptNode implements SksNode {
  final List<SksNode> children;
  ScriptNode(this.children);
}

class ShowNode implements SksNode {
  final String character;
  final String? pose;
  final String? expression;
  ShowNode(this.character, {this.pose, this.expression});
}

class HideNode implements SksNode {
  final String character;
  HideNode(this.character);
}

class BackgroundNode implements SksNode {
  final String background;
  BackgroundNode(this.background);
}

class SayNode implements SksNode {
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

class MenuNode implements SksNode {
  final List<ChoiceOptionNode> choices;
  MenuNode(this.choices);
}

class LabelNode implements SksNode {
  final String name;
  LabelNode(this.name);
}

class ReturnNode implements SksNode {} 

class JumpNode implements SksNode {
  final String targetLabel;
  JumpNode(this.targetLabel);
} 