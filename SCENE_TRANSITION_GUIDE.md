# 场景转场功能使用指南

## 修复的问题
- 修复了场景切换时滤镜持续存在的bug
- 现在切换到新场景时，如果新场景没有滤镜，会正确清除之前的滤镜

## 新增的with语法转场功能

### 基本语法
```sks
scene <背景名> [with <转场类型>] [timer <时长>] [fx <滤镜>]
```

### 支持的转场类型
1. **fade** - 黑屏淡入淡出（默认）
2. **diss** - 图片直接渐变过渡

### 使用示例

#### 1. 默认转场（黑屏）
```sks
scene sky
scene bamboo
```

#### 2. 指定fade转场
```sks
scene sky with fade
```

#### 3. 图片渐变转场
```sks
scene sky with diss
```

#### 4. 带计时器的转场
```sks
scene bamboo with diss timer 1.5
```

#### 5. 转场+滤镜效果
```sks
scene sky with fade fx dreamy intensity:0.8
scene bamboo with diss fx nostalgic intensity:0.5
```

## 技术实现

### 新增文件
- `lib/src/effects/scene_transition_effects.dart` - 转场效果管理器

### 修改文件
- `lib/src/sks_parser/sks_ast.dart` - 添加transitionType支持
- `lib/src/sks_parser/sks_parser.dart` - 解析with语法
- `lib/src/game/game_manager.dart` - 集成转场系统并修复滤镜bug

### 转场效果扩展
系统设计为可扩展的，未来可以轻松添加更多转场类型：
- wipe - 擦除效果
- slide - 滑动效果
- 自定义转场动画

## 注意事项
1. **diss转场现在使用与角色相同的dissolve着色器算法！** - 提供与角色切换完全一致的平滑dissolve效果
2. 转场时长默认为800ms，可以通过timer参数调整
3. fade转场使用原有的黑屏转场系统，diss转场使用新的dissolve着色器转场系统
4. diss转场会自动加载背景图片并使用`assets/shaders/dissolve.frag`着色器进行渲染

## 技术细节
- **dissolve着色器**: diss转场使用与角色层相同的Fragment Shader进行渲染
- **图片加载**: 通过AssetManager和ImageLoader异步加载背景图片
- **平滑过渡**: 150ms到2000ms可配置的dissolve动画时长
- **内存管理**: 自动处理ui.Image的dispose和内存清理
- **BoxFit.cover实现**: 使用手动裁剪确保图片保持纵横比并填满屏幕
- **双层绘制**: 先绘制旧图片作为底层，再用dissolve着色器叠加新图片

## Bug修复记录
- **✅ 修复滤镜持续存在** - 场景切换时正确清理滤镜状态
- **✅ 修复图片压扁变形** - 实现正确的BoxFit.cover逻辑，保持图片纵横比

## 测试
可以使用 `assets/GameScript/labels/transition_test.sks` 文件测试各种转场效果。