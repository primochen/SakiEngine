import 'package:sakiengine/src/widgets/typewriter_animation_manager.dart';
import 'package:sakiengine/src/game/game_manager.dart';

/// 对话推进管理器
/// 
/// 统一管理所有对话推进逻辑，确保打字机动画的正确处理：
/// - 如果打字机正在播放，先完成当前动画再推进
/// - 如果打字机已完成，直接推进到下一句
class DialogueProgressionManager {
  final GameManager gameManager;
  TypewriterAnimationManager? _currentTypewriter;
  
  DialogueProgressionManager({required this.gameManager});
  
  /// 注册当前活跃的打字机动画管理器
  void registerTypewriter(TypewriterAnimationManager? typewriter) {
    _currentTypewriter = typewriter;
  }
  
  /// 统一的对话推进方法
  /// 
  /// 所有推进对话的操作都应该调用这个方法，而不是直接调用 gameManager.next()
  void progressDialogue() {
    // 检查是否有活跃的打字机动画
    if (_currentTypewriter != null && _currentTypewriter!.isTyping) {
      // 如果正在打字，先跳过动画显示完整文本
      _currentTypewriter!.skipToEnd();
    } else {
      // 如果没有打字机动画或动画已完成，推进到下一句对话
      gameManager.next();
    }
  }
  
  /// 检查是否可以直接推进对话（用于UI状态判断）
  bool get canProgressDirectly {
    return _currentTypewriter == null || !_currentTypewriter!.isTyping;
  }
  
  /// 检查当前是否有打字机动画正在播放
  bool get isTypewriterActive {
    return _currentTypewriter != null && _currentTypewriter!.isTyping;
  }
}