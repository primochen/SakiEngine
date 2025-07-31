# SakiEngine
## 基于Flutter开发的视觉小说游戏引擎

### 项目截图

#### 主界面
![主界面](Git/main.png)

#### 对话系统
![对话系统](Git/dialog.png)

#### 历史记录
![历史记录](Git/history.png)

#### 对话场景
![对话场景](Git/say.png)

### 项目简介

SakiEngine 是一个基于 Flutter 的现代化视觉小说游戏引擎，专为跨平台游戏开发而设计。

### 主要特性

- **类Renpy语法**：使用类似Renpy的脚本语法，降低游戏开发门槛
- **自适应窗口**：游戏窗口可以自由拉伸，画面智能适配
- **低性能占用**：轻量级引擎，确保流畅的游戏体验
- **强大的UI系统**：丰富的界面控件和交互支持
- **真正的跨平台**：支持多个主流平台
  - Windows
  - Linux
  - macOS
  - Android
  - iOS

### 开发状态

项目目前处于积极开发中。主要功能已经实现，正在持续优化和完善：
- [x] 基础对话系统
- [x] 角色立绘支持
- [x] 场景管理
- [x] 多平台适配
- [x] 对话记录系统
- [x] 回滚系统
- [x] 选择分支系统
- [ ] 存档和读档系统
- [ ] 音乐、音效和语音系统
- [ ] 场景切换效果
- [ ] 转场动画
- [ ] 脚本内持久化变量设置
- [ ] 更多高级脚本特性
- [ ] 性能进一步优化
- [ ] 更多平台细节适配

### 部署指南

#### 前提条件
- 安装 Flutter SDK（建议使用最新稳定版）
- 配置相应平台的开发环境（Android Studio、Xcode等）

#### 部署步骤
1. 安装 Flutter
```bash
# 参考 Flutter 官方网站获取最新安装方法
flutter doctor  # 检查环境
```

2. 克隆项目
```bash
git clone https://github.com/MCDFsteve/SakiEngine.git
cd SakiEngine
```

3. 运行项目（以macOS为例）
```bash
# 直接运行根目录下的启动脚本
./run_macos.sh
```

### VSCode 语法高亮插件

项目根目录包含一个专门为 SakiEngine 开发的 VSCode 语法高亮插件 `vscode-sakiengine-syntax`，支持以下文件类型的语法高亮：

- `.skr` - 剧本文件 (Script Files)
- `.skc` - 配置文件 (Configuration Files)
- `.skp` - 坐标管理文件 (Position Management Files)
- `.skn` - 角色定义文件 (Character Definition Files)

#### 安装方法

1. 在 VSCode 中打开扩展视图
2. 选择 "从 VSIX 安装"
3. 导航到项目根目录下的 `vscode-sakiengine-syntax` 文件夹
4. 选择最新版本的 `.vsix` 文件进行安装

通过这个插件，你可以获得更好的代码编辑体验，包括语法高亮、代码着色等功能，让脚本编写更加直观和高效。

### 脚本语法示例

SakiEngine 的脚本语法简单直观，类似 Renpy，但更加简洁：

```skr
// 开始标签
label start
// 设置背景场景
scene bg school 

// 角色对话（角色标识 姿势 表情 对话）
yk pose2 happy "欢迎来到SakiEngine！"

// 选择菜单
menu
"给她巧克力" choice_chocolate
"保持沉默" choice_silence
"表情测试" choice_expressions
endmenu

// 巧克力选项
label choice_chocolate
yk "呀，谢谢！"
"嘿嘿，喜欢吗？"
yk happy "当然喜欢！"
return

// 沉默选项
label choice_silence
yk sad "你怎么不说话？"
yk "不理你了。"
return

// 表情变化
label choice_expressions
yk pose1 "这是不同的姿势和表情"
yk happy "开心的表情"
yk sad "难过的表情"
return
```

特点：
- 无需缩进
- 使用 `//` 注释
- 简单的角色对话语法
- 灵活的场景和表情切换
- 直观的选择菜单系统

### 许可证

本项目使用开源许可证。详细信息请参见 LICENSE 文件。

### 贡献

欢迎提交 Issues 和 Pull Requests！
