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
- [x] 存档和读档系统
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

#### 快速开始

##### 开发环境启动（推荐）
```bash
# macOS/Linux
./run.sh

# Windows（使用 Git Bash、WSL 或其他 bash 环境）
./run.sh
```

**首次运行时会自动：**
- 检测您的操作系统（macOS/Linux/Windows）
- 扫描可用的游戏项目
- 让您选择默认游戏项目
- 自动配置并启动项目

##### 传统方式（手动步骤）
1. 选择游戏项目
```bash
./scripts/select_game.sh
```

2. 运行对应平台的传统脚本
```bash
# macOS（传统方式）
./scripts/run_legacy_macos.sh

# 或使用 Flutter 命令（需要先处理资源）
cd Engine
flutter run -d macos --dart-define=SAKI_GAME_PATH="$PWD/../Game/YourGameName"
```

#### 构建发布版

```bash
# 构建不同平台（GitHub Action 使用）
./build.sh macos
./build.sh linux  
./build.sh windows
./build.sh android
./build.sh ios
```

**注意：** 构建前请确保已使用 `./run.sh` 或 `./scripts/select_game.sh` 选择了默认游戏项目。

#### Windows 用户注意事项

Windows 用户需要使用以下方式之一来运行 shell 脚本：

1. **Git Bash**（推荐）
   - 安装 Git for Windows 后自带
   - 右键选择 "Git Bash Here" 然后运行 `./run.sh`

2. **WSL (Windows Subsystem for Linux)**
   - 在 Microsoft Store 安装 Ubuntu 或其他 Linux 发行版
   - 在 WSL 终端中运行脚本

3. **PowerShell + bash**
   - 如果安装了 Git Bash，可在 PowerShell 中运行：`bash ./run.sh`

#### 项目结构

```
SakiEngine/
├── run.sh              # 统一启动脚本（跨平台）
├── build.sh             # 构建脚本（GitHub Action）
├── default_game.txt     # 默认游戏配置文件
├── scripts/             # 工具脚本目录
│   ├── select_game.sh   # 游戏项目选择器
│   ├── run_legacy_macos.sh # 传统macOS启动脚本
│   └── ...              # 其他工具脚本
├── Engine/              # Flutter引擎主目录
└── Game/                # 游戏项目目录
    ├── TestGame/        # 示例游戏项目
    └── YourGame/        # 您的游戏项目
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
