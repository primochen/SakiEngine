#!/bin/bash

#================================================
# SakiEngine 统一构建脚本
#================================================

# ANSI Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查是否传入了平台参数
if [ -z "$1" ]; then
    echo -e "${RED}错误: 请提供一个平台参数 (macos, linux, windows, android, ios)。${NC}"
    exit 1
fi

PLATFORM=$1

# 切换到脚本所在的目录
cd "$(dirname "$0")"

# 项目根目录和游戏目录
PROJECT_ROOT=$(pwd)
ENGINE_DIR="$PROJECT_ROOT/Engine"
DEFAULT_GAME_FILE="$PROJECT_ROOT/default_game.txt"
PUBSPEC_PATH="$ENGINE_DIR/pubspec.yaml"
TEMP_PUBSPEC_PATH="$ENGINE_DIR/pubspec.yaml.temp"

# 读取默认游戏名称
if [ -f "$DEFAULT_GAME_FILE" ]; then
    # 检查并修复default_game.txt文件格式
    line_count=$(wc -l < "$DEFAULT_GAME_FILE")
    if [ "$line_count" -gt 1 ]; then
        echo -e "${YELLOW}检测到default_game.txt有多行，正在修复为单行格式...${NC}"
        # 读取第一行并重写文件
        first_line=$(head -n 1 "$DEFAULT_GAME_FILE" | tr -d '\n\r' | xargs)
        echo -n "$first_line" > "$DEFAULT_GAME_FILE"
        echo -e "${GREEN}已修复default_game.txt为单行格式${NC}"
    fi
    
    GAME_NAME=$(cat "$DEFAULT_GAME_FILE" | tr -d '\n\r' | xargs)
    if [ -z "$GAME_NAME" ]; then
        echo -e "${RED}错误: default_game.txt 文件是空的。${NC}"
        echo -e "${YELLOW}请运行 ./scripts/select_game.sh 选择默认游戏项目。${NC}"
        exit 1
    fi
else
    echo -e "${RED}错误: 未找到 default_game.txt 文件。${NC}"
    echo -e "${YELLOW}请运行 ./scripts/select_game.sh 选择默认游戏项目。${NC}"
    exit 1
fi

GAME_DIR="$PROJECT_ROOT/Game/$GAME_NAME"

# 调试输出：显示解析的游戏名称和路径
echo -e "${YELLOW}解析的游戏名称: '$GAME_NAME'${NC}"
echo -e "${YELLOW}游戏目录路径: '$GAME_DIR'${NC}"

# 验证游戏目录是否存在
if [ ! -d "$GAME_DIR" ]; then
    echo -e "${RED}错误: 游戏目录 '$GAME_DIR' 不存在。${NC}"
    echo -e "${YELLOW}请运行 ./scripts/select_game.sh 重新选择游戏项目。${NC}"
    exit 1
fi

echo -e "${GREEN}使用游戏项目: $GAME_NAME${NC}"

# --- 准备资源 ---
echo -e "${YELLOW}正在准备资源目录...${NC}"
# 清理旧的游戏资源目录，但保留引擎自带的资源（如 shaders）
rm -rf "$ENGINE_DIR/assets/Assets"
rm -rf "$ENGINE_DIR/assets/GameScript"
# 确保顶级 assets 目录存在
mkdir -p "$ENGINE_DIR/assets"

echo -e "${YELLOW}正在拷贝游戏资源和脚本...${NC}"
# 将 Assets 和 GameScript 目录完整地拷贝到 Engine/assets/ 下
cp -r "$GAME_DIR/Assets" "$ENGINE_DIR/assets/"
cp -r "$GAME_DIR/GameScript" "$ENGINE_DIR/assets/"

# 复制 default_game.txt 到 assets 目录
echo -e "${YELLOW}正在复制 default_game.txt 到 assets 目录...${NC}"
cp "$DEFAULT_GAME_FILE" "$ENGINE_DIR/assets/"

echo -e "${GREEN}资源准备完成。${NC}"


# --- 动态更新 pubspec.yaml ---
echo -e "${YELLOW}正在动态生成 pubspec.yaml 资源列表...${NC}"

# 1. 找到 assets: 的起始行 (必须是缩进2个空格的)
assets_start_line=$(grep -n -E "^\s\sassets:" "$PUBSPEC_PATH" | head -1 | cut -d: -f1)

if [ -n "$assets_start_line" ]; then
    # 2. 复制 assets: 之前的部分到临时文件
    head -n "$((assets_start_line - 1))" "$PUBSPEC_PATH" > "$TEMP_PUBSPEC_PATH"
    
    # 3. 写入 assets: 标签和动态生成的列表 (排除 shaders 目录)
    echo "  assets:" >> "$TEMP_PUBSPEC_PATH"
    echo "    - assets/default_game.txt" >> "$TEMP_PUBSPEC_PATH"
    find -L "$ENGINE_DIR/assets" -mindepth 1 -type d -not -path "$ENGINE_DIR/assets/shaders" | while read -r dir; do
        relative_path=$(echo "$dir" | sed "s|$ENGINE_DIR/||")
        echo "    - $relative_path/" >> "$TEMP_PUBSPEC_PATH"
    done

    # 4. 找到原文件中 assets: 块的结束位置
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
    exit 1
fi
# --- 动态更新结束 ---

# --- 执行构建 ---
echo -e "${YELLOW}正在为 $PLATFORM 平台执行构建...${NC}"
cd "$ENGINE_DIR" || exit

flutter pub get

echo -e "${YELLOW}🤖 正在更新模块注册表...${NC}"
# 检查并更新模块注册表
if [ -f "tool/generate_modules.dart" ]; then
    echo -e "${YELLOW}扫描并注册项目模块...${NC}"
    dart tool/generate_modules.dart
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ 模块注册表更新完成${NC}"
    else
        echo -e "${RED}⚠️ 模块注册表更新失败，继续构建...${NC}"
    fi
else
    echo -e "${YELLOW}未找到模块生成工具，跳过模块更新${NC}"
fi
echo ""

case $PLATFORM in
    macos)
        flutter build macos --release
        ;;
    linux)
        flutter build linux --release
        ;;
    windows)
        flutter build windows --release
        ;;
    android)
        flutter build apk --release --target-platform android-arm64
        ;;
    ios)
        cd ios
        pod update
        cd ..
        flutter build ios --release --no-codesign
        ;;
    *)
        echo -e "${RED}错误: 不支持的平台 '$PLATFORM'。${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}为 $PLATFORM 平台构建完成。${NC}"