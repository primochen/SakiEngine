# SakiEngine 滤镜系统文档

## 语法格式

### 独立语法
```
fx <滤镜类型> [参数...]
```

### 内联语法
```
scene <背景名> [timer <秒数>] [fx <滤镜类型> [参数...]]
```

## 滤镜类型

### 1. dreamy - 朦胧记忆滤镜
- **效果**：白色-紫色-蓝色径向渐变，营造朦胧梦幻感
- **用途**：回忆场景、梦境、意识模糊状态
- **默认参数**：intensity:0.5 animation:pulse duration:3.0

### 2. nostalgic - 怀旧滤镜  
- **效果**：琥珀色-橙色-棕色径向渐变，营造温暖怀旧感
- **用途**：回忆杀、过去场景、温馨时光
- **默认参数**：intensity:0.5 animation:pulse duration:3.0

### 3. blur - 模糊滤镜
- **效果**：高斯模糊效果，模糊背景细节
- **用途**：梦境、意识不清、聚焦效果
- **默认参数**：intensity:0.5 animation:pulse duration:3.0

## 参数说明

### intensity:值
- **范围**：0.0 - 1.0
- **说明**：滤镜强度，0.0无效果，1.0最强效果
- **示例**：`intensity:0.8`

### animation:类型
- **pulse**：呼吸脉冲效果（默认）
- **fade**：渐变效果
- **wave**：波浪效果  
- **none**：无动画，静态滤镜
- **示例**：`animation:pulse`

### duration:秒数
- **范围**：> 0.0秒
- **说明**：动画周期长度
- **示例**：`duration:4.0`

## 使用示例

```sks
// 基础使用
fx dreamy

// 带参数
fx nostalgic intensity:0.8 animation:pulse duration:4.0

// 内联语法
scene chapter0 timer 5.0 fx dreamy intensity:0.7

// 静态滤镜
fx blur intensity:0.6 animation:none

// 波浪动画
scene sky fx nostalgic animation:wave duration:6.0
```

## 技术实现

### 文件结构
- `scene_filter.dart` - 滤镜核心模块
- `sks_ast.dart` - FxNode AST节点定义
- `sks_parser.dart` - fx语法解析器
- `game_manager.dart` - 滤镜状态管理
- `game_play_screen.dart` - 滤镜渲染集成

### 渲染流程
1. 解析fx语法为FxNode
2. 创建SceneFilter对象
3. 包装背景Widget为_FilteredBackground
4. 应用滤镜效果和动画控制器
5. 实时渲染动态效果

### 动画系统
- 每个滤镜组件有独立的AnimationController
- 支持repeat()循环动画
- 基于数学函数(sin/cos)计算动态值
- 影响透明度、渐变范围等视觉参数