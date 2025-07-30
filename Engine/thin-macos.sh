#!/bin/bash
# macOS应用瘦身脚本 - 剥离调试符号和优化包大小

if [ $# -eq 0 ]; then
    echo "用法: $0 <SakiEngine.app路径>"
    exit 1
fi

APP_PATH="$1"

if [ ! -d "$APP_PATH" ]; then
    echo "错误: 找不到应用包 $APP_PATH"
    exit 1
fi

echo "开始为 $APP_PATH 进行瘦身处理..."

# 递归处理所有二进制文件和动态库
find "$APP_PATH" -type f \( -name "*.dylib" -o -perm +111 \) | while read -r file; do
    # 检查是否为Mach-O二进制文件
    if file "$file" | grep -q "Mach-O"; then
        echo "处理: $file"
        
        # 剥离调试符号
        strip -S -x "$file" 2>/dev/null || true
        
        # 如果是通用二进制文件，只保留arm64架构
        if lipo -info "$file" 2>/dev/null | grep -q "arm64"; then
            if lipo -info "$file" 2>/dev/null | grep -q "x86_64"; then
                echo "  -> 提取arm64架构"
                lipo "$file" -thin arm64 -output "$file.tmp" 2>/dev/null || true
                if [ -f "$file.tmp" ]; then
                    mv "$file.tmp" "$file"
                fi
            fi
        fi
    fi
done

# 删除不必要的文件
echo "删除不必要的文件..."

# 删除.dSYM调试符号文件
find "$APP_PATH" -name "*.dSYM" -type d -exec rm -rf {} + 2>/dev/null || true

# 删除.framework中的无用文件
find "$APP_PATH" -name "*.framework" -type d | while read -r framework; do
    # 删除Headers目录
    rm -rf "$framework/Headers" 2>/dev/null || true
    # 删除Modules目录
    rm -rf "$framework/Modules" 2>/dev/null || true
    # 删除_CodeSignature目录(会重新生成)
    rm -rf "$framework/_CodeSignature" 2>/dev/null || true
done

# 删除Flutter相关的开发文件
rm -rf "$APP_PATH/Contents/Frameworks/App.framework/Resources/flutter_assets/AssetManifest.bin.json" 2>/dev/null || true

echo "macOS应用瘦身完成"

# 显示处理后的大小
if command -v du >/dev/null 2>&1; then
    echo "当前应用大小: $(du -sh "$APP_PATH" | cut -f1)"
fi