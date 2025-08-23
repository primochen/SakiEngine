#!/bin/bash

#================================================
# SakiEngine 新项目创建脚本
#================================================

# ANSI Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 切换到脚本所在的目录
cd "$(dirname "$0")"
# 获取项目根目录（scripts目录的上级目录）
PROJECT_ROOT="$(dirname "$(pwd)")"
GAME_BASE_DIR="$PROJECT_ROOT/Game"
ENGINE_LIB_DIR="$PROJECT_ROOT/Engine/lib"

echo -e "${BLUE}=== SakiEngine 新项目创建向导 ===${NC}"
echo ""

# 验证输入函数
validate_project_name() {
    local name="$1"
    # 检查是否为空
    if [ -z "$name" ]; then
        return 1
    fi
    # 检查是否只包含字母、数字、下划线和连字符
    if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        return 1
    fi
    return 0
}

validate_bundle_id() {
    local bundle_id="$1"
    # 检查是否为空
    if [ -z "$bundle_id" ]; then
        return 1
    fi
    # 检查是否符合com.xxx.xxx格式
    if [[ ! "$bundle_id" =~ ^[a-zA-Z][a-zA-Z0-9]*(\.[a-zA-Z][a-zA-Z0-9]*){2,}$ ]]; then
        return 1
    fi
    return 0
}

validate_hex_color() {
    local color="$1"
    # 检查是否为空
    if [ -z "$color" ]; then
        return 1
    fi
    # 移除可能的#前缀
    color="${color#\#}"
    # 检查是否为6位十六进制数
    if [[ ! "$color" =~ ^[0-9A-Fa-f]{6}$ ]]; then
        return 1
    fi
    return 0
}

# 十六进制转RGB函数
hex_to_rgb() {
    local hex="$1"
    # 移除可能的#前缀
    hex="${hex#\#}"
    
    # 提取RGB分量
    local r=$((16#${hex:0:2}))
    local g=$((16#${hex:2:2}))
    local b=$((16#${hex:4:2}))
    
    echo "rgb($r, $g, $b)"
}

# 输入项目名称
while true; do
    echo -e "${YELLOW}请输入项目名称（推荐英文，只允许字母、数字、下划线和连字符）:${NC}"
    echo -e -n "${BLUE}项目名称: ${NC}"
    read -r PROJECT_NAME
    
    if validate_project_name "$PROJECT_NAME"; then
        # 检查项目是否已存在
        if [ -d "$GAME_BASE_DIR/$PROJECT_NAME" ]; then
            echo -e "${RED}错误: 项目 '$PROJECT_NAME' 已存在！${NC}"
            continue
        fi
        break
    else
        echo -e "${RED}错误: 项目名称无效！请只使用字母、数字、下划线和连字符。${NC}"
    fi
done

# 输入Bundle ID
while true; do
    echo ""
    echo -e "${YELLOW}请输入应用包名（Bundle ID）:${NC}"
    echo -e "${BLUE}格式示例: com.yourcompany.yourapp${NC}"
    echo -e -n "${BLUE}Bundle ID: ${NC}"
    read -r BUNDLE_ID
    
    if validate_bundle_id "$BUNDLE_ID"; then
        break
    else
        echo -e "${RED}错误: Bundle ID 格式无效！请使用 com.company.app 格式。${NC}"
    fi
done

# 输入主色调
while true; do
    echo ""
    echo -e "${YELLOW}请输入主色调（十六进制颜色代码）:${NC}"
    echo -e "${BLUE}格式示例: #137B8B 或 137B8B（默认蓝绿色）${NC}"
    echo -e -n "${BLUE}主色调: ${NC}"
    read -r PRIMARY_COLOR
    
    # 如果为空，使用默认颜色
    if [ -z "$PRIMARY_COLOR" ]; then
        PRIMARY_COLOR="137B8B"
        echo -e "${YELLOW}使用默认颜色: #$PRIMARY_COLOR${NC}"
        break
    fi
    
    if validate_hex_color "$PRIMARY_COLOR"; then
        # 移除#前缀用于后续处理
        PRIMARY_COLOR="${PRIMARY_COLOR#\#}"
        break
    else
        echo -e "${RED}错误: 颜色代码无效！请输入6位十六进制颜色代码。${NC}"
    fi
done

# 转换颜色为RGB格式
RGB_COLOR=$(hex_to_rgb "$PRIMARY_COLOR")

echo ""
echo -e "${BLUE}=== 项目信息确认 ===${NC}"
echo -e "${GREEN}项目名称: $PROJECT_NAME${NC}"
echo -e "${GREEN}Bundle ID: $BUNDLE_ID${NC}"
echo -e "${GREEN}主色调: #$PRIMARY_COLOR ($RGB_COLOR)${NC}"
echo ""

# 确认创建
echo -e -n "${YELLOW}确认创建项目? (Y/n): ${NC}"
read -r confirm
if [[ "$confirm" =~ ^[Nn]$ ]]; then
    echo -e "${YELLOW}已取消项目创建。${NC}"
    exit 0
fi

# 开始创建项目
echo ""
echo -e "${BLUE}正在创建项目...${NC}"

PROJECT_DIR="$GAME_BASE_DIR/$PROJECT_NAME"

# 创建项目目录结构
echo -e "${YELLOW}创建目录结构...${NC}"
mkdir -p "$PROJECT_DIR"
mkdir -p "$PROJECT_DIR/Assets"
mkdir -p "$PROJECT_DIR/Assets/fonts"
mkdir -p "$PROJECT_DIR/Assets/images"
mkdir -p "$PROJECT_DIR/Assets/images/backgrounds"
mkdir -p "$PROJECT_DIR/Assets/images/characters"
mkdir -p "$PROJECT_DIR/Assets/images/items"
mkdir -p "$PROJECT_DIR/Assets/gui"
mkdir -p "$PROJECT_DIR/Assets/music"
mkdir -p "$PROJECT_DIR/Assets/sound"
mkdir -p "$PROJECT_DIR/Assets/voice"
mkdir -p "$PROJECT_DIR/GameScript"
mkdir -p "$PROJECT_DIR/GameScript/configs"
mkdir -p "$PROJECT_DIR/GameScript/labels"

# 创建 game_config.txt
echo -e "${YELLOW}创建游戏配置文件...${NC}"
cat > "$PROJECT_DIR/game_config.txt" << EOF
$PROJECT_NAME
$BUNDLE_ID

EOF

# 创建基础的角色配置文件
echo -e "${YELLOW}创建角色配置文件...${NC}"
cat > "$PROJECT_DIR/GameScript/configs/characters.sks" << 'EOF'
//chara// SakiEngine 角色定义文件
//格式: 别名 : "显示名称" : 资源ID

// 示例角色定义（请根据实际需要修改）
main : "主角" : narrator
nr : "旁白" : narrator
n : "空白" : narrator

// 添加你的角色定义：
// 格式: 角色别名 : "角色显示名称" : 角色资源ID
// 示例: alice : "爱丽丝" : alice at pose
EOF

# 创建基础的姿势配置文件
echo -e "${YELLOW}创建姿势配置文件...${NC}"
cat > "$PROJECT_DIR/GameScript/configs/poses.sks" << 'EOF'
//pos// SakiEngine 姿势定义文件
//
// --- 参数说明 ---
// 格式: 姿势名称: scale=<缩放> xcenter=<水平位置> ycenter=<垂直位置> anchor=<锚点>
//
// scale: 缩放系数。
//   scale=0:  特殊值，表示进行"边缘贴合 (Aspect Fit)"缩放，确保立绘完整显示在屏幕内。
//   scale>0:  表示立绘最终渲染高度为 [屏幕高度 * scale] 值。与源文件分辨率无关。
//
// xcenter / ycenter: 锚点在屏幕上的归一化位置 (0.0 到 1.0)。
//   xcenter=0.0 (最左), xcenter=0.5 (水平居中), xcenter=1.0 (最右)
//   ycenter=0.0 (最顶), ycenter=0.5 (垂直居中), ycenter=1.0 (最底)
//
// anchor: 指定用立绘自身的哪个点去对齐屏幕上的 (xcenter, ycenter) 坐标点。
//   常用锚点: center(中心), bottomCenter(底部中心), topCenter(顶部中心),
//             centerLeft(左边缘中心), centerRight(右边缘中心), 等等。

// 【常用】默认底部对齐姿势 (边缘贴合)
center: scale=0 xcenter=0.5 ycenter=1.0 anchor=bottomCenter
left: scale=0 xcenter=0.25 ycenter=1.0 anchor=bottomCenter
right: scale=0 xcenter=0.75 ycenter=1.0 anchor=bottomCenter

// 【特殊】稍微放大并居中的姿势 (固定缩放，高度为屏幕80%)
closeup: scale=0.8 xcenter=0.5 ycenter=0.8 anchor=center

// 默认姿势
pose: scale=1.5 ycenter=0.8 anchor=center
EOF

# 创建基础的系统配置文件
echo -e "${YELLOW}创建系统配置文件...${NC}"
cat > "$PROJECT_DIR/GameScript/configs/configs.sks" << EOF
//config// SakiEngine 配置文件
theme: color=$RGB_COLOR
base_textbutton: size=40
base_dialogue: size=24
base_speaker: size=35
base_choice: size=24
base_review_title: size=45
base_quick_menu: size=25
main_menu: background=sky size=200 top=0.3 right=0.05
EOF

# 创建基础的剧情脚本文件
echo -e "${YELLOW}创建基础剧情脚本...${NC}"
cat > "$PROJECT_DIR/GameScript/labels/start.sks" << 'EOF'
//label// SakiEngine 剧情标签脚本文件
label start
// 设置背景场景（请将对应的背景图片放入 Assets/images/backgrounds/ 目录）
// scene bg background_name

// 欢迎消息
nr "欢迎来到你的新项目！"
nr "这是一个使用 SakiEngine 创建的新项目。"

// 示例选择菜单
menu
"开始游戏" start_game
"查看设置" show_settings
"退出" quit_game
endmenu

label start_game
nr "游戏开始了！"
nr "请在这里编写你的故事..."
// 在这里添加你的游戏内容
return

label show_settings
nr "这里是设置界面。"
nr "你可以在这里添加各种设置选项。"
return

label quit_game
nr "感谢游玩！"
return
EOF

# 创建README.md文件
echo -e "${YELLOW}创建项目说明文件...${NC}"
cat > "$PROJECT_DIR/README.md" << EOF
# $PROJECT_NAME

使用 SakiEngine 创建的视觉小说项目。

## 项目信息
- **项目名称**: $PROJECT_NAME
- **Bundle ID**: $BUNDLE_ID
- **主色调**: #$PRIMARY_COLOR

## 文件结构

### Assets/
游戏资源文件夹
- \`fonts/\` - 字体文件
- \`images/\` - 图片资源
  - \`backgrounds/\` - 背景图片
  - \`characters/\` - 角色立绘
  - \`items/\` - 道具图片
- \`music/\` - 背景音乐
- \`sound/\` - 音效文件
- \`voice/\` - 语音文件
- \`gui/\` - UI界面素材

### GameScript/
游戏脚本文件夹
- \`configs/\` - 配置文件
  - \`characters.sks\` - 角色定义
  - \`poses.sks\` - 姿势定义
  - \`configs.sks\` - 系统配置
- \`labels/\` - 剧情脚本
  - \`start.sks\` - 开始剧情

## 开发指南

### 1. 添加角色
1. 将角色立绘放入 \`Assets/images/characters/\` 目录
2. 在 \`GameScript/configs/characters.sks\` 中定义角色
3. 在脚本中使用角色别名进行对话

### 2. 添加背景
1. 将背景图片放入 \`Assets/images/backgrounds/\` 目录
2. 在脚本中使用 \`scene bg 背景名称\` 设置背景

### 3. 编写剧情
1. 在 \`GameScript/labels/\` 目录下创建新的 .sks 文件
2. 使用 SakiEngine 脚本语法编写剧情
3. 使用 \`label\` 定义剧情标签，使用 \`call\` 或选择菜单跳转

### 4. 自定义配置
编辑 \`GameScript/configs/configs.sks\` 来修改：
- 主题颜色
- 字体大小
- 界面布局等

## 运行项目
在 SakiEngine 根目录执行：
\`\`\`bash
./run.sh
\`\`\`
然后选择本项目运行。

## 脚本语法参考
\`\`\`
// 注释
label 标签名
scene bg 背景名
角色别名 姿势 表情 "对话内容"
"旁白或主角对话"
menu
"选项1" 跳转标签1
"选项2" 跳转标签2
endmenu
\`\`\`
EOF

# 创建项目模块文件夹和文件
echo -e "${YELLOW}创建项目模块文件夹...${NC}"
PROJECT_NAME_LOWER=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]')
MODULE_DIR="$ENGINE_LIB_DIR/$PROJECT_NAME_LOWER"

# 创建模块目录结构
mkdir -p "$MODULE_DIR/screens"

# 创建模块主文件
echo -e "${YELLOW}创建模块主文件...${NC}"
cat > "$MODULE_DIR/${PROJECT_NAME_LOWER}_module.dart" << EOF
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:sakiengine/src/core/game_module.dart';
import 'package:sakiengine/src/core/module_registry.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';

/// $PROJECT_NAME 项目的自定义模块
class ${PROJECT_NAME}Module extends DefaultGameModule {
  
  @override
  ThemeData? createTheme() {
    // $PROJECT_NAME 项目的自定义主题
    return ThemeData(
      primarySwatch: Colors.blue,
      fontFamily: 'SourceHanSansCN',
      colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.blue).copyWith(
        secondary: const Color(0xFF${PRIMARY_COLOR}),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF${PRIMARY_COLOR}),
        elevation: 0,
      ),
    );
  }

  @override
  SakiEngineConfig? createCustomConfig() {
    // 可以返回项目特定的配置
    return null; // 使用默认配置
  }

  @override
  bool get enableDebugFeatures => true; // 启用调试功能

  @override
  Future<String> getAppTitle() async {
    // 自定义应用标题（可选）
    try {
      final defaultTitle = await super.getAppTitle();
      return defaultTitle; // 使用默认标题，或自定义如: '\$defaultTitle - $PROJECT_NAME'
    } catch (e) {
      return '$PROJECT_NAME'; // 项目名作为标题
    }
  }

  @override
  Future<void> initialize() async {
    if (kDebugMode) {
      print('[${PROJECT_NAME}Module] 🎯 $PROJECT_NAME 项目模块初始化完成');
    }
    // 在这里可以进行项目特定的初始化
    // 比如加载特殊的资源、设置特殊的配置等
  }
}

// 自动注册这个模块
// 当这个文件被导入时，模块会自动注册
void _registerModule() {
  registerProjectModule('$PROJECT_NAME_LOWER', () => ${PROJECT_NAME}Module());
}

// 使用顶级变量触发注册，避免编译器警告
final bool _isRegistered = (() {
  _registerModule();
  return true;
})();
EOF

# 更新模块注册表
echo -e "${YELLOW}更新模块注册表...${NC}"
cd "$PROJECT_ROOT/Engine"
if dart tool/generate_modules.dart; then
    echo -e "${GREEN}✓ 模块注册表更新成功${NC}"
else
    echo -e "${YELLOW}⚠ 模块注册表更新失败，请手动运行: dart tool/generate_modules.dart${NC}"
fi
cd - > /dev/null

echo ""
echo -e "${GREEN}✓ 项目创建完成！${NC}"
echo ""
echo -e "${BLUE}项目路径: $PROJECT_DIR${NC}"
echo -e "${BLUE}模块路径: $MODULE_DIR${NC}"
echo -e "${YELLOW}请将游戏资源（图片、音频等）放入对应的 Assets 子目录中。${NC}"
echo ""
echo -e "${GREEN}下一步操作：${NC}"
echo -e "${BLUE}1. 运行 ./run.sh 并选择新创建的项目${NC}"
echo -e "${BLUE}2. 编辑 GameScript/labels/start.sks 开始创作你的故事${NC}"
echo -e "${BLUE}3. 在 Assets 目录中添加游戏所需的图片和音频资源${NC}"
echo -e "${BLUE}4. 自定义项目模块: $MODULE_DIR/${PROJECT_NAME_LOWER}_module.dart${NC}"
echo ""

# 询问是否立即设置为默认项目
echo -e -n "${YELLOW}是否将此项目设置为默认项目? (Y/n): ${NC}"
read -r set_default
if [[ ! "$set_default" =~ ^[Nn]$ ]]; then
    echo "$PROJECT_NAME" > "$PROJECT_ROOT/default_game.txt"
    echo -e "${GREEN}✓ 已设置 '$PROJECT_NAME' 为默认项目${NC}"
fi

echo ""
echo -e "${GREEN}项目创建完成！祝你创作愉快！${NC}"