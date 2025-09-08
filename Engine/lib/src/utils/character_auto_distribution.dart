import 'package:sakiengine/src/config/config_models.dart';
import 'package:sakiengine/src/game/game_manager.dart';
import 'package:sakiengine/src/utils/character_position_animator.dart';

/// 角色自动分布工具类
/// 根据视觉小说最佳实践自动分布多个角色的位置
class CharacterAutoDistribution {
  
  /// 计算需要动画的角色位置变化
  /// 比较新旧角色分布，返回需要动画过渡的角色位置变化
  /// [oldCharacters] 之前的角色状态Map
  /// [newCharacters] 新的角色状态Map
  /// [oldPoseConfigs] 之前的姿势配置Map
  /// [newPoseConfigs] 新的姿势配置Map
  /// [characterOrder] 角色出场顺序
  /// 返回需要动画的角色位置变化列表
  static List<CharacterPositionChange> calculatePositionChanges(
    Map<String, CharacterState> oldCharacters,
    Map<String, CharacterState> newCharacters,
    Map<String, PoseConfig> oldPoseConfigs,
    Map<String, PoseConfig> newPoseConfigs,
    List<String> characterOrder,
  ) {
    //print('[CharacterAutoDistribution] 计算位置变化...');
    //print('[CharacterAutoDistribution] 旧角色数量: ${oldCharacters.length}');
    //print('[CharacterAutoDistribution] 新角色数量: ${newCharacters.length}');
    
    final positionChanges = <CharacterPositionChange>[];
    
    // 计算旧的分布
    final oldDistributed = calculateAutoDistribution(
      oldCharacters, 
      oldPoseConfigs, 
      characterOrder,
    );
    
    // 计算新的分布
    final newDistributed = calculateAutoDistribution(
      newCharacters, 
      newPoseConfigs, 
      characterOrder,
    );
    
    //print('[CharacterAutoDistribution] 旧分布配置数量: ${oldDistributed.length}');
    //print('[CharacterAutoDistribution] 新分布配置数量: ${newDistributed.length}');
    
    // 比较每个角色的位置变化
    for (final characterId in newCharacters.keys) {
      final oldCharacter = oldCharacters[characterId];
      final newCharacter = newCharacters[characterId];
      
      //print('[CharacterAutoDistribution] 检查角色 $characterId');
      
      if (oldCharacter == null || newCharacter == null) {
        //print('[CharacterAutoDistribution] 角色 $characterId 旧状态或新状态为null，跳过');
        continue;
      }
      
      // 获取角色的原始pose配置（检查是否为auto anchor）
      final oldOriginalPose = oldPoseConfigs[oldCharacter.positionId];
      final newOriginalPose = newPoseConfigs[newCharacter.positionId];
      
      // 获取分布后的pose配置（获取实际位置）
      final oldAutoDistributedPoseId = '${characterId}_auto_distributed';
      final newAutoDistributedPoseId = '${characterId}_auto_distributed';
      
      final oldDistributedPose = oldDistributed[oldAutoDistributedPoseId] ?? oldOriginalPose;
      final newDistributedPose = newDistributed[newAutoDistributedPoseId] ?? newOriginalPose;
      
      //print('[CharacterAutoDistribution] 角色 $characterId 原始pose isAuto: ${oldOriginalPose?.isAutoAnchor}, ${newOriginalPose?.isAutoAnchor}');
      //print('[CharacterAutoDistribution] 角色 $characterId 分布后位置: ${oldDistributedPose?.xcenter} -> ${newDistributedPose?.xcenter}');
      
      if (oldOriginalPose == null || newOriginalPose == null || oldDistributedPose == null || newDistributedPose == null) {
        //print('[CharacterAutoDistribution] 角色 $characterId pose配置为null，跳过');
        continue;
      }
      
      // 检查原始pose是否为auto anchor，且分布后的位置是否发生变化
      if (oldOriginalPose.isAutoAnchor && newOriginalPose.isAutoAnchor && 
          (oldDistributedPose.xcenter - newDistributedPose.xcenter).abs() > 0.001) {
        //print('[CharacterAutoDistribution] 角色 $characterId 需要位置动画: ${oldDistributedPose.xcenter} -> ${newDistributedPose.xcenter}');
        positionChanges.add(CharacterPositionChange(
          characterId: characterId,
          fromX: oldDistributedPose.xcenter,
          toX: newDistributedPose.xcenter,
        ));
      } else {
        //print('[CharacterAutoDistribution] 角色 $characterId 无需位置动画');
      }
    }
    
    //print('[CharacterAutoDistribution] 总共需要动画的角色数量: ${positionChanges.length}');
    return positionChanges;
  }

  /// 计算自动分布的角色位置
  /// [characters] 当前场景中的角色状态Map
  /// [poseConfigs] 姿势配置Map
  /// [characterOrder] 角色出场顺序（按时间排序）
  /// 返回更新后的姿势配置Map
  static Map<String, PoseConfig> calculateAutoDistribution(
    Map<String, CharacterState> characters,
    Map<String, PoseConfig> poseConfigs,
    List<String> characterOrder,
  ) {
    //print('Debug: 开始自动分布计算');
    //print('Debug: 角色总数: ${characters.length}');
    //print('Debug: 角色ID列表: ${characters.keys.toList()}');
    //print('Debug: 姿势配置总数: ${poseConfigs.length}');
    
    // 复制原始配置以避免修改原数据
    final result = Map<String, PoseConfig>.from(poseConfigs);
    
    // 找出所有使用auto锚点且没有设置xcenter的角色
    final autoCharacters = <String>[];
    for (final characterId in characters.keys) {
      final character = characters[characterId]!;
      final pose = poseConfigs[character.positionId];
      
      //print('Debug: 检查角色 $characterId, positionId=${character.positionId}');
      if (pose != null) {
        //print('Debug:   pose配置: anchor=${pose.anchor}, xcenter=${pose.xcenter}, ycenter=${pose.ycenter}');
        //print('Debug:   isAutoAnchor=${pose.isAutoAnchor}');
        
        if (pose.isAutoAnchor && pose.xcenter == 0.5) {
          autoCharacters.add(characterId);
          //print('Debug:   → 添加到自动分布列表');
        } else {
          //print('Debug:   → 跳过（非auto锚点或xcenter≠0.5）');
        }
      } else {
        //print('Debug:   → 警告：找不到pose配置');
      }
    }
    
    //print('Debug: 自动分布角色列表: $autoCharacters');
    
    if (autoCharacters.isEmpty) {
      //print('Debug: 无需自动分布，返回原配置');
      return result;
    }
    
    // 按出场顺序排序自动分布的角色
    autoCharacters.sort((a, b) {
      final indexA = characterOrder.indexOf(a);
      final indexB = characterOrder.indexOf(b);
      // 如果角色不在出场顺序中，放在最后
      if (indexA == -1 && indexB == -1) return 0;
      if (indexA == -1) return 1;
      if (indexB == -1) return -1;
      return indexA.compareTo(indexB);
    });
    
    //print('Debug: 排序后的自动分布角色: $autoCharacters');
    
    // 根据角色数量计算分布位置
    final positions = _calculateDistributionPositions(autoCharacters.length);
    //print('Debug: 计算出的分布位置: $positions');
    
    // 应用自动分布
    for (int i = 0; i < autoCharacters.length; i++) {
      final characterId = autoCharacters[i];
      final character = characters[characterId]!;
      final originalPose = poseConfigs[character.positionId]!;
      final newXCenter = positions[i];
      
      //print('Debug: 处理角色 $characterId (${i + 1}/${autoCharacters.length})');
      //print('Debug:   原始xcenter: ${originalPose.xcenter} → 新xcenter: $newXCenter');
      //print('Debug:   保持ycenter: ${originalPose.ycenter}');
      //print('Debug:   anchor: ${originalPose.anchor} → ${originalPose.anchor == 'auto' ? 'center' : originalPose.anchor}');
      
      // 使用角色ID作为独立的pose配置ID，避免多个角色共享同一个positionId导致覆盖
      final uniquePoseId = '${characterId}_auto_distributed';
      //print('Debug:   为角色创建独立配置: $uniquePoseId');
      
      // 创建新的姿势配置，使用计算出的x位置
      result[uniquePoseId] = originalPose.copyWithAutoDistribution(newXCenter);
    }
    
    //print('Debug: 自动分布完成');
    return result;
  }
  
  /// 根据角色数量计算最佳分布位置
  /// 返回x轴位置数组（0.0到1.0之间的归一化坐标）
  static List<double> _calculateDistributionPositions(int characterCount) {
    switch (characterCount) {
      case 1:
        // 一个角色：居中
        return [0.5];
      case 2:
        // 两个角色：左右均匀分布
        return [0.25, 0.75];
      case 3:
        // 三个角色：左中右均匀分布
        return [0.2, 0.5, 0.8];
      case 4:
        // 四个角色：平均分布
        return [0.15, 0.38, 0.62, 0.85];
      case 5:
        // 五个角色：平均分布
        return [0.1, 0.3, 0.5, 0.7, 0.9];
      default:
        // 超过5个角色：动态平均分布
        if (characterCount <= 1) return [0.5];
        
        final positions = <double>[];
        final margin = 0.05; // 边缘留5%空间
        final availableWidth = 1.0 - (margin * 2);
        final spacing = availableWidth / (characterCount - 1);
        
        for (int i = 0; i < characterCount; i++) {
          positions.add(margin + (spacing * i));
        }
        return positions;
    }
  }
  
  /// 获取角色出场顺序的辅助方法
  /// 通过分析游戏状态历史来确定角色的出场先后顺序
  static List<String> getCharacterAppearanceOrder(List<String> currentCharacters) {
    // 在实际实现中，这里应该维护一个角色出现时间的记录
    // 暂时返回当前顺序
    return List.from(currentCharacters);
  }
  
  /// 调试方法：打印角色分布信息
  static void debugPrintDistribution(
    Map<String, CharacterState> characters,
    Map<String, PoseConfig> originalPoses,
    Map<String, PoseConfig> distributedPoses,
  ) {
    print('=== 角色自动分布调试信息 ===');
    print('总角色数: ${characters.length}');
    
    final autoCharacters = <String>[];
    for (final entry in characters.entries) {
      final characterId = entry.key;
      final character = entry.value;
      final originalPose = originalPoses[character.positionId];
      final distributedPose = distributedPoses[character.positionId];
      
      if (originalPose != null && originalPose.isAutoAnchor) {
        autoCharacters.add(characterId);
        print('角色 $characterId: ${originalPose.xcenter} -> ${distributedPose?.xcenter ?? "未分布"}');
      }
    }
    
    print('自动分布角色: ${autoCharacters.join(", ")}');
    print('========================');
  }
}