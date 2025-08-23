#!/bin/bash

# 🤖 自动模块注册表更新脚本
# 此脚本会扫描项目中的所有模块并自动生成注册表

echo "🤖 SakiEngine 模块系统 - 自动更新注册表"
echo "=================================================="

echo "🔍 扫描项目模块..."
dart tool/generate_modules.dart

echo ""
echo "✅ 模块注册表已更新！"
echo ""
echo "📝 使用说明："
echo "   • 每当添加新的项目模块时，运行此脚本更新注册表"
echo "   • 模块目录应该位于 lib/项目名/ 下"  
echo "   • 模块文件应该命名为 项目名_module.dart"
echo ""
echo "🎯 当前已注册的模块可在控制台输出中查看"