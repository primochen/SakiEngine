@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM ================================================
REM SakiEngine 游戏项目选择脚本
REM ================================================

REM 切换到脚本所在的目录
cd /d "%~dp0"
REM 获取项目根目录（scripts目录的上级目录）
for %%i in ("%cd%\..") do set "PROJECT_ROOT=%%~fi"
set "GAME_BASE_DIR=%PROJECT_ROOT%\Game"
set "DEFAULT_GAME_FILE=%PROJECT_ROOT%\default_game.txt"

echo [94m=== SakiEngine 游戏项目选择器 ===[0m
echo.

REM 检查Game目录是否存在
if not exist "%GAME_BASE_DIR%" (
    echo [91m错误: Game目录不存在！[0m
    exit /b 1
)

REM 获取Game目录下的所有子目录
echo [93m正在扫描可用的游戏项目...[0m
set "game_count=0"
for /d %%d in ("%GAME_BASE_DIR%\*") do (
    set /a game_count+=1
    set "game_!game_count!=%%~nxd"
)

REM 检查是否有可用的游戏项目
if !game_count! equ 0 (
    echo [91m错误: Game目录下没有找到任何游戏项目！[0m
    exit /b 1
)

REM 显示当前默认游戏（如果存在）
if exist "%DEFAULT_GAME_FILE%" (
    set /p "current_game=" < "%DEFAULT_GAME_FILE%"
    echo [94m当前默认游戏: [92m!current_game![0m
    echo.
)

REM 显示可用的游戏项目列表
echo [93m可用的游戏项目:[0m
for /l %%i in (1,1,!game_count!) do (
    echo [94m  %%i. [92m!game_%%i![0m
)
echo.

REM 用户选择
:user_choice
set /p "choice=[93m请选择要设置为默认的游戏项目 (1-!game_count!): [0m"

REM 验证输入是否为数字且在有效范围内
echo !choice! | findstr /r "^[0-9][0-9]*$" >nul
if errorlevel 1 (
    echo [91m无效的选择，请输入 1-!game_count! 之间的数字。[0m
    goto user_choice
)

if !choice! lss 1 (
    echo [91m无效的选择，请输入 1-!game_count! 之间的数字。[0m
    goto user_choice
)

if !choice! gtr !game_count! (
    echo [91m无效的选择，请输入 1-!game_count! 之间的数字。[0m
    goto user_choice
)

REM 获取选中的游戏名称
set "selected_game=!game_%choice%!"

REM 写入default_game.txt文件
echo !selected_game! > "%DEFAULT_GAME_FILE%"

echo.
echo [92m✓ 已将 '!selected_game!' 设置为默认游戏项目[0m
echo [94m配置已保存到: %DEFAULT_GAME_FILE%[0m
echo.
echo [93m提示: 下次运行项目时将自动使用此游戏项目[0m