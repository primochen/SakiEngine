#!/bin/bash

#================================================
# 平台检测工具脚本
#================================================

# 检测当前操作系统
detect_platform() {
    local os_type=""
    
    case "$(uname)" in
        "Darwin")
            os_type="macos"
            ;;
        "Linux")
            os_type="linux"
            ;;
        "MINGW"*|"MSYS"*|"CYGWIN"*)
            os_type="windows"
            ;;
        *)
            os_type="unknown"
            ;;
    esac
    
    echo "$os_type"
}

# 检查平台是否支持开发
check_platform_support() {
    local platform="$1"
    
    case "$platform" in
        "macos")
            if ! command -v flutter >/dev/null 2>&1; then
                return 1
            fi
            return 0
            ;;
        "linux")
            if ! command -v flutter >/dev/null 2>&1; then
                return 1
            fi
            return 0
            ;;
        "windows")
            if ! command -v flutter >/dev/null 2>&1; then
                return 1
            fi
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# 获取平台显示名称
get_platform_display_name() {
    local platform="$1"
    
    case "$platform" in
        "macos")
            echo "macOS"
            ;;
        "linux")
            echo "Linux"
            ;;
        "windows")
            echo "Windows"
            ;;
        *)
            echo "Unknown"
            ;;
    esac
}