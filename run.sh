#!/bin/bash

#================================================
# SakiEngine 通用启动脚本
#================================================

# ANSI Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 切换到脚本所在的目录
cd "$(dirname "$0")"

# 项目根目录
PROJECT_ROOT=$(pwd)
SCRIPTS_DIR="$PROJECT_ROOT/scripts"
ENGINE_DIR="$PROJECT_ROOT/Engine"
DEFAULT_GAME_FILE="$PROJECT_ROOT/default_game.txt"

# 加载工具脚本
source "$SCRIPTS_DIR/platform_utils.sh"
source "$SCRIPTS_DIR/asset_utils.sh"
source "$SCRIPTS_DIR/pubspec_utils.sh"

echo -e "${BLUE}=== SakiEngine 开发环境启动器 ===${NC}"
echo ""

# 检测当前平台
PLATFORM=$(detect_platform)
PLATFORM_NAME=$(get_platform_display_name "$PLATFORM")

echo -e "${GREEN}检测到操作系统: ${PLATFORM_NAME}${NC}"

# 检查平台支持
if ! check_platform_support "$PLATFORM"; then
    echo -e "${RED}错误: 当前平台 ${PLATFORM_NAME} 不支持或缺少必要的工具 (Flutter)${NC}"
    echo -e "${YELLOW}请确保已正确安装 Flutter SDK${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Flutter 环境检测通过${NC}"
echo ""

# 游戏项目选择逻辑
if [ -f "$DEFAULT_GAME_FILE" ]; then
    current_game=$(read_default_game "$PROJECT_ROOT")
    if [ -n "$current_game" ]; then
        echo -e "${BLUE}当前默认游戏: ${GREEN}$current_game${NC}"
        echo ""
        echo -e "${YELLOW}请选择操作:${NC}"
        echo -e "${BLUE}  1. 继续使用当前游戏${NC}"
        echo -e "${BLUE}  2. 选择其他游戏${NC}"
        echo -e "${BLUE}  3. 创建新游戏项目${NC}"
        echo ""
        echo -e -n "${YELLOW}请选择 (1-3, 默认为1): ${NC}"
        read -r action_choice
        
        case "$action_choice" in
            "2")
                "$SCRIPTS_DIR/select_game.sh"
                if [ $? -ne 0 ]; then
                    echo -e "${RED}游戏选择失败，退出。${NC}"
                    exit 1
                fi
                ;;
            "3")
                "$SCRIPTS_DIR/create_new_project.sh"
                if [ $? -ne 0 ]; then
                    echo -e "${RED}项目创建失败，退出。${NC}"
                    exit 1
                fi
                ;;
            *)
                # 默认继续使用当前游戏
                ;;
        esac
    else
        echo -e "${YELLOW}default_game.txt 文件为空...${NC}"
        echo ""
        echo -e "${YELLOW}请选择操作:${NC}"
        echo -e "${BLUE}  1. 选择现有游戏项目${NC}"
        echo -e "${BLUE}  2. 创建新游戏项目${NC}"
        echo ""
        echo -e -n "${YELLOW}请选择 (1-2): ${NC}"
        read -r action_choice
        
        case "$action_choice" in
            "2")
                "$SCRIPTS_DIR/create_new_project.sh"
                if [ $? -ne 0 ]; then
                    echo -e "${RED}项目创建失败，退出。${NC}"
                    exit 1
                fi
                ;;
            *)
                "$SCRIPTS_DIR/select_game.sh"
                if [ $? -ne 0 ]; then
                    echo -e "${RED}游戏选择失败，退出。${NC}"
                    exit 1
                fi
                ;;
        esac
    fi
else
    echo -e "${YELLOW}未找到默认游戏配置...${NC}"
    echo ""
    echo -e "${YELLOW}请选择操作:${NC}"
    echo -e "${BLUE}  1. 选择现有游戏项目${NC}"
    echo -e "${BLUE}  2. 创建新游戏项目${NC}"
    echo ""
    echo -e -n "${YELLOW}请选择 (1-2): ${NC}"
    read -r action_choice
    
    case "$action_choice" in
        "2")
            "$SCRIPTS_DIR/create_new_project.sh"
            if [ $? -ne 0 ]; then
                echo -e "${RED}项目创建失败，退出。${NC}"
                exit 1
            fi
            ;;
        *)
            "$SCRIPTS_DIR/select_game.sh"
            if [ $? -ne 0 ]; then
                echo -e "${RED}游戏选择失败，退出。${NC}"
                exit 1
            fi
            ;;
    esac
fi

# 读取最终的游戏名称
GAME_NAME=$(read_default_game "$PROJECT_ROOT")
if [ -z "$GAME_NAME" ]; then
    echo -e "${RED}错误: 无法读取游戏项目名称${NC}"
    exit 1
fi

# 验证游戏目录
GAME_DIR=$(validate_game_dir "$PROJECT_ROOT" "$GAME_NAME")
if [ $? -ne 0 ]; then
    echo -e "${RED}错误: 游戏目录不存在: $PROJECT_ROOT/Game/$GAME_NAME${NC}"
    echo -e "${YELLOW}重新启动游戏选择器...${NC}"
    "$SCRIPTS_DIR/select_game.sh"
    if [ $? -ne 0 ]; then
        echo -e "${RED}游戏选择失败，退出。${NC}"
        exit 1
    fi
    GAME_NAME=$(read_default_game "$PROJECT_ROOT")
    GAME_DIR=$(validate_game_dir "$PROJECT_ROOT" "$GAME_NAME")
fi

echo ""
echo -e "${GREEN}启动游戏项目: $GAME_NAME${NC}"
echo -e "${BLUE}游戏路径: $GAME_DIR${NC}"
echo ""

# 读取游戏配置
echo -e "${YELLOW}正在读取游戏配置...${NC}"
GAME_CONFIG=$(read_game_config "$GAME_DIR")
if [ $? -eq 0 ]; then
    APP_NAME=$(echo "$GAME_CONFIG" | cut -d'|' -f1)
    BUNDLE_ID=$(echo "$GAME_CONFIG" | cut -d'|' -f2)
    
    echo -e "${GREEN}应用名称: $APP_NAME${NC}"
    echo -e "${GREEN}包名: $BUNDLE_ID${NC}"
    
    # 设置应用身份信息
    if ! set_app_identity "$ENGINE_DIR" "$APP_NAME" "$BUNDLE_ID"; then
        echo -e "${RED}设置应用信息失败${NC}"
        exit 1
    fi
else
    echo -e "${RED}错误: 未找到有效的 game_config.txt 文件${NC}"
    echo -e "${YELLOW}请确保游戏目录中存在正确格式的 game_config.txt 文件${NC}"
    exit 1
fi

# 处理游戏资源
link_game_assets "$ENGINE_DIR" "$GAME_DIR" "$PROJECT_ROOT" "true"

# 更新 pubspec.yaml
if ! update_pubspec_assets "$ENGINE_DIR"; then
    echo -e "${RED}更新 pubspec.yaml 失败${NC}"
    exit 1
fi

# 更新字体配置
if ! update_pubspec_fonts "$ENGINE_DIR" "$GAME_DIR"; then
    echo -e "${RED}更新字体配置失败${NC}"
    exit 1
fi

# 启动Flutter项目
echo ""
echo -e "${YELLOW}正在启动 SakiEngine (${PLATFORM_NAME})...${NC}"
cd "$ENGINE_DIR" || exit

echo -e "${YELLOW}正在清理 Flutter 缓存...${NC}"
flutter clean

echo -e "${YELLOW}正在获取依赖...${NC}"
flutter pub get

echo -e "${YELLOW}正在生成应用图标...${NC}"
flutter pub run flutter_launcher_icons:main

echo ""

# 检查是否为web模式
if [ "$1" = "web" ]; then
    echo -e "${GREEN}在 Web (Chrome) 上启动项目...${NC}"
    flutter run -d chrome --dart-define=SAKI_GAME_PATH="$GAME_DIR"
else
    # 根据平台启动
    case "$PLATFORM" in
        "macos")
            echo -e "${GREEN}在 macOS 上启动项目...${NC}"
            echo "Debug: GAME_DIR=$GAME_DIR"
            flutter run -d macos --dart-define=SAKI_GAME_PATH="$GAME_DIR"
            ;;
        "linux")
            echo -e "${GREEN}在 Linux 上启动项目...${NC}"
            flutter run -d linux --dart-define=SAKI_GAME_PATH="$GAME_DIR"
            ;;
        "windows")
            echo -e "${GREEN}在 Windows 上启动项目...${NC}"
            flutter run -d windows --dart-define=SAKI_GAME_PATH="$GAME_DIR"
            ;;
        *)
            echo -e "${RED}错误: 不支持的平台 $PLATFORM${NC}"
            exit 1
            ;;
    esac
fi