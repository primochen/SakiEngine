#!/bin/bash

#================================================
# SakiEngine 游戏项目选择脚本
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
DEFAULT_GAME_FILE="$PROJECT_ROOT/default_game.txt"

echo -e "${BLUE}=== SakiEngine 游戏项目选择器 ===${NC}"
echo ""

# 检查Game目录是否存在
if [ ! -d "$GAME_BASE_DIR" ]; then
    echo -e "${RED}错误: Game目录不存在！${NC}"
    exit 1
fi

# 获取Game目录下的所有子目录
echo -e "${YELLOW}正在扫描可用的游戏项目...${NC}"
GAME_DIRS=()
while IFS= read -r -d '' dir; do
    if [ -d "$dir" ]; then
        basename_dir=$(basename "$dir")
        GAME_DIRS+=("$basename_dir")
    fi
done < <(find "$GAME_BASE_DIR" -mindepth 1 -maxdepth 1 -type d -print0)

# 检查是否有可用的游戏项目
if [ ${#GAME_DIRS[@]} -eq 0 ]; then
    echo -e "${RED}错误: Game目录下没有找到任何游戏项目！${NC}"
    exit 1
fi

# 显示当前默认游戏（如果存在）
if [ -f "$DEFAULT_GAME_FILE" ]; then
    current_game=$(cat "$DEFAULT_GAME_FILE")
    echo -e "${BLUE}当前默认游戏: ${GREEN}$current_game${NC}"
    echo ""
fi

# 显示可用的游戏项目列表
echo -e "${YELLOW}可用的游戏项目:${NC}"
for i in "${!GAME_DIRS[@]}"; do
    echo -e "${BLUE}  $((i+1)). ${GREEN}${GAME_DIRS[i]}${NC}"
done
echo ""

# 用户选择
while true; do
    echo -e -n "${YELLOW}请选择要设置为默认的游戏项目 (1-${#GAME_DIRS[@]}): ${NC}"
    read -r choice
    
    # 验证输入是否为数字
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#GAME_DIRS[@]}" ]; then
        selected_game="${GAME_DIRS[$((choice-1))]}"
        break
    else
        echo -e "${RED}无效的选择，请输入 1-${#GAME_DIRS[@]} 之间的数字。${NC}"
    fi
done

# 写入default_game.txt文件
echo "$selected_game" > "$DEFAULT_GAME_FILE"

echo ""
echo -e "${GREEN}✓ 已将 '${selected_game}' 设置为默认游戏项目${NC}"
echo -e "${BLUE}配置已保存到: ${DEFAULT_GAME_FILE}${NC}"
echo ""
echo -e "${YELLOW}提示: 下次运行项目时将自动使用此游戏项目${NC}"