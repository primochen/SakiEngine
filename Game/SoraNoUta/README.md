# SoraNoUta

使用 SakiEngine 创建的视觉小说项目。

## 项目信息
- **项目名称**: SoraNoUta
- **Bundle ID**: com.aimessoft.soranouta
- **主色调**: #137B8B

## 文件结构

### Assets/
游戏资源文件夹
- `fonts/` - 字体文件
- `images/` - 图片资源
  - `backgrounds/` - 背景图片
  - `characters/` - 角色立绘
  - `items/` - 道具图片
- `music/` - 背景音乐
- `sound/` - 音效文件
- `voice/` - 语音文件
- `gui/` - UI界面素材

### GameScript/
游戏脚本文件夹
- `configs/` - 配置文件
  - `characters.sks` - 角色定义
  - `poses.sks` - 姿势定义
  - `configs.sks` - 系统配置
- `labels/` - 剧情脚本
  - `start.sks` - 开始剧情

## 开发指南

### 1. 添加角色
1. 将角色立绘放入 `Assets/images/characters/` 目录
2. 在 `GameScript/configs/characters.sks` 中定义角色
3. 在脚本中使用角色别名进行对话

### 2. 添加背景
1. 将背景图片放入 `Assets/images/backgrounds/` 目录
2. 在脚本中使用 `scene bg 背景名称` 设置背景

### 3. 编写剧情
1. 在 `GameScript/labels/` 目录下创建新的 .sks 文件
2. 使用 SakiEngine 脚本语法编写剧情
3. 使用 `label` 定义剧情标签，使用 `call` 或选择菜单跳转

### 4. 自定义配置
编辑 `GameScript/configs/configs.sks` 来修改：
- 主题颜色
- 字体大小
- 界面布局等

## 运行项目
在 SakiEngine 根目录执行：
```bash
./run.sh
```
然后选择本项目运行。

## 脚本语法参考
```
// 注释
label 标签名
scene bg 背景名
角色别名 姿势 表情 "对话内容"
"旁白或主角对话"
menu
"选项1" 跳转标签1
"选项2" 跳转标签2
endmenu
```
