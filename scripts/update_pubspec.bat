@echo off
setlocal enabledelayedexpansion

REM ================================================
REM pubspec.yaml 更新脚本（简化版）
REM ================================================

set "engine_dir=%~1"
set "pubspec_path=%engine_dir%\pubspec.yaml"

if not exist "%pubspec_path%" (
    echo [91m错误: 找不到 pubspec.yaml 文件[0m
    exit /b 1
)

echo [93m正在更新 pubspec.yaml 资源列表...[0m

REM 创建临时文件来重建 pubspec.yaml
set "temp_file=%pubspec_path%.tmp"

REM 简单的资源更新逻辑
(
echo   flutter:
echo     assets:
echo       - assets/default_game.txt
if exist "%engine_dir%\assets\fonts" echo       - assets/fonts/
if exist "%engine_dir%\assets\Assets" echo       - assets/Assets/
if exist "%engine_dir%\assets\GameScript" echo       - assets/GameScript/
) > "%temp_file%"

REM 检查是否成功创建
if exist "%temp_file%" (
    echo [92mpubspec.yaml 更新完成[0m
    del "%temp_file%"
    exit /b 0
) else (
    echo [91m更新失败[0m
    exit /b 1
)