@echo off
REM ================================================
REM 平台检测工具脚本
REM ================================================

REM 检测当前操作系统
:detect_platform
set "%~1=windows"
goto :eof

REM 检查平台是否支持开发
:check_platform_support
flutter --version >nul 2>&1
if errorlevel 1 (
    set "%~2=0"
) else (
    set "%~2=1"
)
goto :eof

REM 获取平台显示名称
:get_platform_display_name
if "%~1"=="windows" set "%~2=Windows"
if "%~1"=="macos" set "%~2=macOS"
if "%~1"=="linux" set "%~2=Linux"
if "%~1"=="unknown" set "%~2=Unknown"
goto :eof