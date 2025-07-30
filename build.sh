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
GAME_DIR="$PROJECT_ROOT/Game/TestGame"
PUBSPEC_PATH="$ENGINE_DIR/pubspec.yaml"
TEMP_PUBSPEC_PATH="$ENGINE_DIR/pubspec.yaml.temp"

# --- 准备资源 ---
echo -e "${YELLOW}正在清理旧的资源链接...${NC}"
# 删除 Engine/assets 目录下所有现有的符号链接或文件
if [ -d "$ENGINE_DIR/assets" ]; then
  # 为了安全，我们只删除内容，不删除assets目录本身
  find "$ENGINE_DIR/assets" -mindepth 1 -delete
fi
# 确保顶级 assets 目录存在
mkdir -p "$ENGINE_DIR/assets"

echo -e "${YELLOW}正在拷贝游戏资源和脚本...${NC}"
# 为 Game/TestGame/Assets 创建符号链接
cp -r "$GAME_DIR/Assets"/* "$ENGINE_DIR/assets/"
# 为 Game/TestGame/GameScript 创建符号链接
cp -r "$GAME_DIR/GameScript" "$ENGINE_DIR/assets/"
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
