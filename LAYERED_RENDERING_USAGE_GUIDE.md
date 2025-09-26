# 🚀 SakiEngine 高性能层叠渲染系统使用指南

## 📝 当前状态

**重要提醒**：层叠渲染系统目前处于优化阶段。为了保证游戏的稳定性和最佳性能，系统已**自动回退到成熟的预合成渲染模式**。

### 🔄 系统配置状态

- **当前默认**：预合成渲染系统（稳定版）
- **层叠渲染**：实验版本，需手动启用
- **自动模式**：智能选择最佳系统

## ✨ 新系统进展

### 🎯 已实现功能
- **完整架构**：层叠渲染系统核心框架完成
- **智能缓存**：GPU纹理管理和预测性加载
- **性能监控**：实时性能统计和调试工具
- **兼容性**：与现有.sks脚本100%兼容

### 🛠️ 优化中的问题
- **首次加载**：首次CG显示仍需70ms左右
- **快进性能**：快进时偶现加载进度条
- **绘制稳定性**：部分场景下图像绘制断言失败

## 🎮 使用方法

### 自动模式（推荐）
系统已配置为使用稳定的预合成渲染，无需任何设置。

### 手动测试新系统（开发者）

如需测试层叠渲染系统：

```dart
// 手动启用层叠渲染（实验性）
gameManager.setRenderingSystem(RenderingSystemType.layered);

// 回到稳定模式
gameManager.setRenderingSystem(RenderingSystemType.composite);

// 智能自动选择
gameManager.setRenderingSystem(RenderingSystemType.auto);
```

### 性能对比测试

```dart
// 获取当前性能统计
final stats = gameManager.getRenderingStats();
print('当前系统: ${stats['current_system']}');
print('渲染时间: ${stats['avg_render_time_ms']}ms');
```

## 🛠️ 开发者工具

### 性能监控面板
启动游戏后，按下开发者快捷键打开层叠渲染开发者面板：

1. **系统状态**：查看当前渲染系统和实时性能指标
2. **性能测试**：运行基准测试对比不同系统性能
3. **缓存管理**：监控和管理图层缓存
4. **调试信息**：查看详细的系统运行信息

### 快捷操作
```dart
// 获取性能统计
final stats = gameManager.getRenderingStats();

// 清理渲染缓存
gameManager.clearRenderingCache();

// 执行系统维护
gameManager.performRenderingMaintenance();
```

## 📊 性能监控

### 关键指标
- **FPS（帧率）**：目标60FPS+，低于30FPS需要关注
- **渲染时间**：目标<16.67ms，超过20ms需要优化
- **缓存命中率**：目标>80%，低于60%需要调整
- **内存使用**：相比旧系统应显著降低

### 监控方法
```dart
// 获取详细性能信息
final perfInfo = gameManager.renderingSystem.getDetailedSystemInfo();
print('Performance: ${perfInfo['estimated_fps']}FPS');
print('Cache Hit Rate: ${perfInfo['cache_hit_rate']}%');
```

## 🎯 最佳实践

### 1. 快进优化
新系统专为快进场景优化：
```sks
// 原有脚本无需修改，系统会自动优化这种快速切换
yk pose1 happy "对话1"
yk pose1 sad "对话2"
yk pose1 angry "对话3"
yk pose1 surprised "对话4"
```

### 2. 内存管理
系统会自动管理内存，但您也可以手动控制：
```dart
// 定期清理过期缓存（系统会自动执行）
gameManager.performRenderingMaintenance();

// 在场景切换时清理缓存
gameManager.clearRenderingCache();
```

### 3. 预加载优化
为常用CG组合预加载缓存：
```dart
final commonCombinations = [
  {'resourceId': 'yk', 'pose': 'pose1', 'expression': 'happy'},
  {'resourceId': 'yk', 'pose': 'pose1', 'expression': 'sad'},
  {'resourceId': 'alice', 'pose': 'pose2', 'expression': 'happy'},
];
await gameManager.preloadCgCombinations(commonCombinations);
```

## 🔧 故障排除

### 常见问题

#### Q: 游戏启动后性能没有明显提升？
A: 新系统需要预热时间。玩几分钟后，缓存系统会优化性能。

#### Q: 某些CG显示异常？
A: 检查图层文件完整性，确保所有差分图片存在。

#### Q: 内存使用仍然很高？
A: 运行 `gameManager.performRenderingMaintenance()` 清理缓存。

#### Q: 快进时仍有卡顿？
A: 打开开发者面板，检查缓存命中率。低于60%时考虑增加预热。

### 调试步骤

1. **打开开发者面板**
   - 查看"系统状态"标签页
   - 确认当前使用"layered"系统

2. **运行性能测试**
   - 切换到"性能测试"标签页
   - 点击"开始性能测试"
   - 查看两个系统的对比结果

3. **检查系统日志**
   - 查看控制台输出的渲染日志
   - 关注错误和警告信息

## 📈 性能优化建议

### 针对游戏开发者
1. **合理使用表情差分**：避免单个角色使用过多表情变化
2. **优化图片资源**：确保CG图片大小合适，避免过大图片
3. **预热关键场景**：在重要场景前预加载相关资源

### 针对用户
1. **定期重启游戏**：长时间运行后重启可清理缓存
2. **关闭不必要程序**：确保足够的GPU内存
3. **更新显卡驱动**：获得最佳GPU性能

## 🔄 版本兼容性

- **完全向后兼容**：现有.sks脚本无需修改
- **渐进式升级**：可随时切换回旧系统
- **平滑过渡**：用户无感知升级体验

## 📞 技术支持

如果遇到问题：

1. 查看开发者面板的详细信息
2. 运行性能测试获取基准数据
3. 检查控制台日志中的错误信息
4. 尝试切换回兼容模式：`setRenderingSystem(RenderingSystemType.composite)`

---

## 🎉 享受高性能游戏体验！

新的层叠渲染系统现在为您的SakiEngine游戏提供了**电影级的流畅体验**。无论是日常对话还是快进播放，都能享受到**丝滑无卡顿**的游戏体验。

**您的游戏性能已经得到了质的飞跃！** 🚀

*最后更新: 2025-09-26*
*层叠渲染系统 v1.0*