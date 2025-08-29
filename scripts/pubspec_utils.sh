#!/bin/bash

#================================================
# pubspec.yaml 动态更新工具
#================================================

# ANSI Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 动态更新 pubspec.yaml 的 assets 部分
update_pubspec_assets() {
    local engine_dir="$1"
    local pubspec_path="$engine_dir/pubspec.yaml"
    local temp_pubspec_path="$engine_dir/pubspec.yaml.temp"
    
    echo -e "${YELLOW}正在动态生成 pubspec.yaml 资源列表...${NC}"
    
    # 1. 找到 assets: 的起始行 (必须是缩进2个空格的)
    local assets_start_line=$(grep -n -E "^\s\sassets:" "$pubspec_path" | head -1 | cut -d: -f1)
    
    if [ -n "$assets_start_line" ]; then
        # 2. 复制 assets: 之前的部分到临时文件
        head -n "$((assets_start_line - 1))" "$pubspec_path" > "$temp_pubspec_path"
        
        # 3. 写入 assets: 标签和动态生成的列表 (排除 shaders 目录)
        echo "  assets:" >> "$temp_pubspec_path"
        echo "    - assets/default_game.txt" >> "$temp_pubspec_path"
        # 添加引擎默认字体目录
        if [ -d "$engine_dir/assets/fonts" ]; then
            echo "    - assets/fonts/" >> "$temp_pubspec_path"
        fi
        find -L "$engine_dir/assets" -mindepth 1 -type d -not -path "$engine_dir/assets/shaders" -not -path "$engine_dir/assets/fonts" | while read -r dir; do
            local relative_path=$(echo "$dir" | sed "s|$engine_dir/||")
            echo "    - $relative_path/" >> "$temp_pubspec_path"
        done
        
        # 4. 找到原文件中 assets: 块的结束位置
        local assets_block_end_line=$((assets_start_line))
        while true; do
            local next_line_num=$((assets_block_end_line + 1))
            local line_content=$(sed "${next_line_num}q;d" "$pubspec_path")
            # 如果下一行不是 asset 或者文件结束，就停止
            if [[ ! $line_content == *"    - assets/"* ]] || [[ -z "$line_content" ]]; then
                break
            fi
            assets_block_end_line=$((assets_block_end_line + 1))
        done
        
        # 5. 追加原文件中 assets: 块之后的所有内容
        tail -n "+$((assets_block_end_line + 1))" "$pubspec_path" >> "$temp_pubspec_path"
        
        # 6. 替换原文件
        mv "$temp_pubspec_path" "$pubspec_path"
        echo -e "${GREEN}pubspec.yaml 更新成功。${NC}"
        return 0
    else
        echo -e "${RED}错误: 在 pubspec.yaml 中未找到 '  assets:' 部分。请确保该部分存在且有两个空格的缩进。${NC}"
        return 1
    fi
}

# 动态更新 pubspec.yaml 的 fonts 部分
update_pubspec_fonts() {
    local engine_dir="$1"
    local game_dir="$2"
    local pubspec_path="$engine_dir/pubspec.yaml"
    local temp_pubspec_path="$engine_dir/pubspec.yaml.temp"
    
    echo -e "${YELLOW}正在动态生成 pubspec.yaml 字体列表...${NC}"
    
    # 1. 找到 fonts: 的起始行
    local fonts_start_line=$(grep -n -E "^\s\sfonts:" "$pubspec_path" | head -1 | cut -d: -f1)
    
    if [ -n "$fonts_start_line" ]; then
        # 2. 复制 fonts: 之前的部分到临时文件
        head -n "$((fonts_start_line - 1))" "$pubspec_path" > "$temp_pubspec_path"
        
        # 3. 写入 fonts: 标签和动态生成的字体列表
        echo "  fonts:" >> "$temp_pubspec_path"
        echo "    - family: SourceHanSansCN" >> "$temp_pubspec_path"
        echo "      fonts:" >> "$temp_pubspec_path"
        echo "        - asset: assets/fonts/SourceHanSansCN-Bold.ttf" >> "$temp_pubspec_path"
        echo "          weight: 700" >> "$temp_pubspec_path"
        
        # 4. 动态添加游戏项目的字体
        if [ -d "$game_dir/Assets/fonts" ]; then
            find "$game_dir/Assets/fonts" -name "*.ttf" -o -name "*.otf" | while read -r font_file; do
                local font_name=$(basename "$font_file" | sed 's/\.[^.]*$//')
                local relative_path="assets/Assets/fonts/$(basename "$font_file")"
                echo "    - family: $font_name" >> "$temp_pubspec_path"
                echo "      fonts:" >> "$temp_pubspec_path"
                echo "        - asset: $relative_path" >> "$temp_pubspec_path"
            done
        fi
        
        # 5. 找到原文件中 fonts: 块的结束位置
        local fonts_block_end_line=$fonts_start_line
        while true; do
            local next_line_num=$((fonts_block_end_line + 1))
            local line_content=$(sed "${next_line_num}q;d" "$pubspec_path")
            # 如果下一行不是字体配置相关或者文件结束，就停止
            if [[ ! $line_content =~ ^[[:space:]]*(-[[:space:]]*family:|[[:space:]]*fonts:|[[:space:]]*-[[:space:]]*asset:|[[:space:]]*weight:|[[:space:]]*style:) ]] && [[ -n "$line_content" ]] && [[ ! $line_content =~ ^[[:space:]]*$ ]]; then
                break
            fi
            if [[ -z "$line_content" ]]; then
                break
            fi
            fonts_block_end_line=$((fonts_block_end_line + 1))
        done
        
        # 6. 追加原文件中 fonts: 块之后的所有内容
        tail -n "+$((fonts_block_end_line + 1))" "$pubspec_path" >> "$temp_pubspec_path"
        
        # 7. 替换原文件
        mv "$temp_pubspec_path" "$pubspec_path"
        echo -e "${GREEN}pubspec.yaml 字体配置更新成功。${NC}"
        return 0
    else
        echo -e "${RED}错误: 在 pubspec.yaml 中未找到 '  fonts:' 部分。${NC}"
        return 1
    fi
}