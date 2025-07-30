#!/bin/bash

#================================================
# SakiEngine macOS 启动脚本
#================================================
# ANSI Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 切换到脚本所在的目录
cd "$(dirname "$0")"

# 项目根目录
PROJECT_ROOT=$(pwd)
ENGINE_DIR="$PROJECT_ROOT/Engine"
PUBSPEC_PATH="$ENGINE_DIR/pubspec.yaml"
TEMP_PUBSPEC_PATH="$ENGINE_DIR/pubspec.yaml.temp"

# 游戏目录
GAME_DIR="$PROJECT_ROOT/Game/TestGame"

# --- 动态设置应用名称和包名 ---
echo -e "${YELLOW}正在从 game_config.txt 读取配置...${NC}"
CONFIG_FILE="$PROJECT_ROOT/Game/TestGame/game_config.txt"

if [ -f "$CONFIG_FILE" ]; then
    APP_NAME=$(sed -n '1p' "$CONFIG_FILE")
    BUNDLE_ID=$(sed -n '2p' "$CONFIG_FILE")

    if [ -n "$APP_NAME" ] && [ -n "$BUNDLE_ID" ]; then
        echo -e "${GREEN}读取到应用名称: $APP_NAME${NC}"
        echo -e "${GREEN}读取到包名: $BUNDLE_ID${NC}"
        
        cd "$ENGINE_DIR" || exit
        
        echo -e "${YELLOW}正在设置应用名称...${NC}"
        dart run rename setAppName --targets android,ios,macos,linux,windows,web --value "$APP_NAME"
        
        echo -e "${YELLOW}正在设置包名...${NC}"
        dart run rename setBundleId --targets android,ios,macos --value "$BUNDLE_ID"
        
        # 手动修改 Linux 和 Windows 的包名
        echo -e "${YELLOW}正在手动修改 Linux 和 Windows 的包名...${NC}"
        sed -i '' "s/set(APPLICATION_ID \".*\")/set(APPLICATION_ID \"$BUNDLE_ID\")/" "$ENGINE_DIR/linux/CMakeLists.txt"
        sed -i '' "s/VALUE \"CompanyName\", \".*\"/VALUE \"CompanyName\", \"${BUNDLE_ID%.*}\" \"\\0\"/" "$ENGINE_DIR/windows/runner/Runner.rc"
        
        cd "$PROJECT_ROOT" || exit
    else
        echo -e "${RED}错误: game_config.txt 文件格式不正确。${NC}"
        exit 1
    fi
else
    echo -e "${RED}错误: 未找到 game_config.txt 文件。${NC}"
    exit 1
fi
# --- 动态设置结束 ---

echo -e "${YELLOW}正在清理旧的资源链接...${NC}"
# 删除 Engine/assets 目录下所有现有的符号链接
if [ -d "$ENGINE_DIR/assets" ]; then
  find "$ENGINE_DIR/assets" -type l -delete
fi
# 删除空目录
find "$ENGINE_DIR/assets" -type d -empty -delete
# 确保顶级 assets 目录存在
mkdir -p "$ENGINE_DIR/assets"

echo -e "${YELLOW}正在链接游戏资源和脚本...${NC}"
# 为 Game/TestGame/Assets 创建符号链接
ln -shf "$GAME_DIR/Assets" "$ENGINE_DIR/assets/Assets"
# 为 Game/TestGame/GameScript 创建符号链接
ln -shf "$GAME_DIR/GameScript" "$ENGINE_DIR/assets/GameScript"

echo -e "${GREEN}资源链接完成。${NC}"

# --- 动态更新 pubspec.yaml ---
echo -e "${YELLOW}正在动态生成 pubspec.yaml 资源列表...${NC}"

# 1. 找到 assets: 的起始行 (必须是缩进2个空格的)
assets_start_line=$(grep -n -E "^\s\sassets:" "$PUBSPEC_PATH" | head -1 | cut -d: -f1)

if [ -n "$assets_start_line" ]; then
    # 2. 复制 assets: 之前的部分到临时文件
    head -n "$((assets_start_line - 1))" "$PUBSPEC_PATH" > "$TEMP_PUBSPEC_PATH"
    
    # 3. 写入 assets: 标签和动态生成的列表 (排除 shaders 目录)
    echo "  assets:" >> "$TEMP_PUBSPEC_PATH"
    find -L "$ENGINE_DIR/assets" -mindepth 1 -type d -not -path "$ENGINE_DIR/assets/shaders" | while read -r dir; do
        relative_path=$(echo "$dir" | sed "s|$ENGINE_DIR/||")
        echo "    - $relative_path/" >> "$TEMP_PUBSPEC_PATH"
    done

    # 4. 找到原文件中 assets: 块的结束位置
    # 我们从 assets: 的下一行开始，找到第一个不属于 assets 列表的行
    assets_block_end_line=$((assets_start_line))
    while true; do
        next_line_num=$((assets_block_end_line + 1))
        line_content=$(sed "${next_line_num}q;d" "$PUBSPEC_PATH")
        # 如果下一行不是 asset 或者文件结束，就停止
        if [[ ! $line_content == *"    - assets/"* ]] || [[ -z "$line_content" ]]; then
            break
        fi
        assets_block_end_line=$((assets_block_end_line + 1))
    done

    # 5. 追加原文件中 assets: 块之后的所有内容
    tail -n "+$((assets_block_end_line + 1))" "$PUBSPEC_PATH" >> "$TEMP_PUBSPEC_PATH"
    
    # 6. 替换原文件
    mv "$TEMP_PUBSPEC_PATH" "$PUBSPEC_PATH"
    echo -e "${GREEN}pubspec.yaml 更新成功。${NC}"
else
    echo -e "${RED}错误: 在 pubspec.yaml 中未找到 '  assets:' 部分。请确保该部分存在且有两个空格的缩进。${NC}"
fi
# --- 动态更新结束 ---


echo -e "${YELLOW}正在 macOS 上启动 SakiEngine...${NC}"
# 切换到引擎目录并明确指定在 macOS 上运行 Flutter
cd "$ENGINE_DIR" || exit
echo -e "${YELLOW}正在清理 Flutter 缓存...${NC}"
flutter clean
echo -e "${YELLOW}正在获取依赖...${NC}"
flutter pub get
# 运行应用，并传入游戏目录的绝对路径
flutter run -d macos --dart-define=SAKI_GAME_PATH="$PROJECT_ROOT/Game/TestGame" 