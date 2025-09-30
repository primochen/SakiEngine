#!/bin/bash

#================================================
# 资源处理工具脚本
#================================================

# ANSI Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 获取项目根目录（脚本所在目录的上级）
get_project_root() {
    echo "$(dirname "$(dirname "$(realpath "$0")")")"
}

# 读取默认游戏名称
read_default_game() {
    local project_root="$1"
    local default_game_file="$project_root/default_game.txt"
    
    if [ -f "$default_game_file" ]; then
        cat "$default_game_file" | tr -d '\n'
    else
        echo ""
    fi
}

# 验证游戏目录是否存在
validate_game_dir() {
    local project_root="$1"
    local game_name="$2"
    local game_dir="$project_root/Game/$game_name"
    
    if [ -d "$game_dir" ]; then
        echo "$game_dir"
        return 0
    else
        return 1
    fi
}

# 复制游戏资源（跨平台兼容）
link_game_assets() {
    local engine_dir="$1"
    local game_dir="$2"
    local project_root="$3"
    local use_symlink="$4"  # 忽略此参数，总是使用复制模式
    
    echo -e "${YELLOW}正在清理旧的资源...${NC}"
    # 删除 Engine/assets 目录下的 Assets 和 GameScript* 目录
    rm -rf "$engine_dir/assets/Assets"
    rm -rf "$engine_dir"/assets/GameScript*
    
    # 确保顶级 assets 目录存在
    mkdir -p "$engine_dir/assets"
    
    echo -e "${YELLOW}正在复制游戏资源和脚本...${NC}"
    # 总是使用复制模式以确保跨平台兼容性
    cp -r "$game_dir/Assets" "$engine_dir/assets/"
    for script_dir in "$game_dir"/GameScript*; do
        if [ -d "$script_dir" ]; then
            cp -r "$script_dir" "$engine_dir/assets/"
        fi
    done
    
    # 复制 default_game.txt 到 assets 目录
    echo -e "${YELLOW}正在复制 default_game.txt 到 assets 目录...${NC}"
    cp "$project_root/default_game.txt" "$engine_dir/assets/"
    
    # 处理 icon.png 复制逻辑（优先使用游戏目录，回退到项目根目录）
    echo -e "${YELLOW}正在处理应用图标...${NC}"
    if [ -f "$game_dir/icon.png" ]; then
        echo -e "${GREEN}使用游戏目录中的 icon.png${NC}"
        cp "$game_dir/icon.png" "$engine_dir/assets/"
    elif [ -f "$project_root/icon.png" ]; then
        echo -e "${YELLOW}游戏目录未找到 icon.png，使用项目根目录的图标${NC}"
        cp "$project_root/icon.png" "$engine_dir/assets/"
    else
        echo -e "${RED}警告: 未找到 icon.png 文件${NC}"
    fi
    
    echo -e "${GREEN}资源处理完成。${NC}"
}

# 读取游戏配置
read_game_config() {
    local game_dir="$1"
    local config_file="$game_dir/game_config.txt"
    
    if [ -f "$config_file" ]; then
        local app_name=$(sed -n '1p' "$config_file")
        local bundle_id=$(sed -n '2p' "$config_file")
        
        if [ -n "$app_name" ] && [ -n "$bundle_id" ]; then
            echo "$app_name|$bundle_id"
            return 0
        fi
    fi
    
    return 1
}

# 设置应用名称和包名
set_app_identity() {
    local engine_dir="$1"
    local app_name="$2"
    local bundle_id="$3"
    
    echo -e "${YELLOW}正在设置应用名称: $app_name${NC}"
    echo -e "${YELLOW}正在设置包名: $bundle_id${NC}"
    
    cd "$engine_dir" || return 1
    
    # 设置应用名称
    dart run rename setAppName --targets android,ios,macos,linux,windows,web --value "$app_name"
    
    # 设置包名
    dart run rename setBundleId --targets android,ios,macos --value "$bundle_id"
    
    # 手动修改 Linux 和 Windows 的包名
    if [ -f "$engine_dir/linux/CMakeLists.txt" ]; then
        sed -i.bak "s/set(APPLICATION_ID \".*\")/set(APPLICATION_ID \"$bundle_id\")/" "$engine_dir/linux/CMakeLists.txt"
        rm -f "$engine_dir/linux/CMakeLists.txt.bak"
    fi
    
    if [ -f "$engine_dir/windows/runner/Runner.rc" ]; then
        sed -i.bak "s/VALUE \"CompanyName\", \".*\"/VALUE \"CompanyName\", \"${bundle_id%.*}\"/" "$engine_dir/windows/runner/Runner.rc"
        rm -f "$engine_dir/windows/runner/Runner.rc.bak"
    fi
    
    return 0
}
