@echo off
chcp 65001 >nul

REM ================================================
REM SakiEngine 通用启动脚本
REM ================================================

setlocal enabledelayedexpansion

REM 切换到脚本所在的目录
cd /d "%~dp0"

REM 项目根目录
set "PROJECT_ROOT=%cd%"
set "SCRIPTS_DIR=%PROJECT_ROOT%\scripts"
set "ENGINE_DIR=%PROJECT_ROOT%\Engine"
set "DEFAULT_GAME_FILE=%PROJECT_ROOT%\default_game.txt"

REM 加载工具脚本
call "%SCRIPTS_DIR%\platform_utils.bat"
call "%SCRIPTS_DIR%\asset_utils.bat"
call "%SCRIPTS_DIR%\pubspec_utils.bat"

echo [94m=== SakiEngine 开发环境启动器 ===[0m
echo.

REM 检测当前平台
call :detect_platform PLATFORM
call :get_platform_display_name "%PLATFORM%" PLATFORM_NAME

echo [92m检测到操作系统: %PLATFORM_NAME%[0m

REM 检查平台支持
call :check_platform_support "%PLATFORM%" PLATFORM_SUPPORTED
if not "!PLATFORM_SUPPORTED!"=="1" (
    echo [91m错误: 当前平台 %PLATFORM_NAME% 不支持或缺少必要的工具 ^(Flutter^)[0m
    echo [93m请确保已正确安装 Flutter SDK[0m
    exit /b 1
)

echo [92m✓ Flutter 环境检测通过[0m
echo.

REM 游戏项目选择逻辑
if exist "%DEFAULT_GAME_FILE%" (
    call :read_default_game "%PROJECT_ROOT%" current_game
    if not "!current_game!"=="" (
        echo [94m当前默认游戏: [92m!current_game![0m
        echo.
        echo [93m请选择操作:[0m
        echo [94m  1. 继续使用当前游戏[0m
        echo [94m  2. 选择其他游戏[0m
        echo [94m  3. 创建新游戏项目[0m
        echo.
        set /p "action_choice=[93m请选择 (1-3, 默认为1): [0m"
        
        if "!action_choice!"=="2" (
            call "%SCRIPTS_DIR%\select_game.bat"
            if errorlevel 1 (
                echo [91m游戏选择失败，退出。[0m
                exit /b 1
            )
        ) else if "!action_choice!"=="3" (
            call "%SCRIPTS_DIR%\create_new_project.bat"
            if errorlevel 1 (
                echo [91m项目创建失败，退出。[0m
                exit /b 1
            )
        )
        REM 默认继续使用当前游戏
    ) else (
        echo [93mdefault_game.txt 文件为空...[0m
        echo.
        echo [93m请选择操作:[0m
        echo [94m  1. 选择现有游戏项目[0m
        echo [94m  2. 创建新游戏项目[0m
        echo.
        set /p "action_choice=[93m请选择 (1-2): [0m"
        
        if "!action_choice!"=="2" (
            call "%SCRIPTS_DIR%\create_new_project.bat"
            if errorlevel 1 (
                echo [91m项目创建失败，退出。[0m
                exit /b 1
            )
        ) else (
            call "%SCRIPTS_DIR%\select_game.bat"
            if errorlevel 1 (
                echo [91m游戏选择失败，退出。[0m
                exit /b 1
            )
        )
    )
) else (
    echo [93m未找到默认游戏配置...[0m
    echo.
    echo [93m请选择操作:[0m
    echo [94m  1. 选择现有游戏项目[0m
    echo [94m  2. 创建新游戏项目[0m
    echo.
    set /p "action_choice=[93m请选择 (1-2): [0m"
    
    if "!action_choice!"=="2" (
        call "%SCRIPTS_DIR%\create_new_project.bat"
        if errorlevel 1 (
            echo [91m项目创建失败，退出。[0m
            exit /b 1
        )
    ) else (
        call "%SCRIPTS_DIR%\select_game.bat"
        if errorlevel 1 (
            echo [91m游戏选择失败，退出。[0m
            exit /b 1
        )
    )
)

REM 读取最终的游戏名称
call :read_default_game "%PROJECT_ROOT%" GAME_NAME
if "!GAME_NAME!"=="" (
    echo [91m错误: 无法读取游戏项目名称[0m
    exit /b 1
)

REM 验证游戏目录
call :validate_game_dir "%PROJECT_ROOT%" "!GAME_NAME!" GAME_DIR GAME_DIR_VALID
if not "!GAME_DIR_VALID!"=="1" (
    echo [91m错误: 游戏目录不存在: %PROJECT_ROOT%\Game\!GAME_NAME![0m
    echo [93m重新启动游戏选择器...[0m
    call "%SCRIPTS_DIR%\select_game.bat"
    if errorlevel 1 (
        echo [91m游戏选择失败，退出。[0m
        exit /b 1
    )
    call :read_default_game "%PROJECT_ROOT%" GAME_NAME
    call :validate_game_dir "%PROJECT_ROOT%" "!GAME_NAME!" GAME_DIR GAME_DIR_VALID
)

echo.
echo [92m启动游戏项目: !GAME_NAME![0m
echo [94m游戏路径: !GAME_DIR![0m
echo.

REM 读取游戏配置
echo [93m正在读取游戏配置...[0m
call :read_game_config "!GAME_DIR!" GAME_CONFIG CONFIG_VALID
if "!CONFIG_VALID!"=="1" (
    for /f "tokens=1,2 delims=|" %%a in ("!GAME_CONFIG!") do (
        set "APP_NAME=%%a"
        set "BUNDLE_ID=%%b"
    )
    
    echo [92m应用名称: !APP_NAME![0m
    echo [92m包名: !BUNDLE_ID![0m
    
    REM 设置应用身份信息
    call :set_app_identity "%ENGINE_DIR%" "!APP_NAME!" "!BUNDLE_ID!" APP_IDENTITY_SET
    if not "!APP_IDENTITY_SET!"=="1" (
        echo [91m设置应用信息失败[0m
        exit /b 1
    )
) else (
    echo [91m错误: 未找到有效的 game_config.txt 文件[0m
    echo [93m请确保游戏目录中存在正确格式的 game_config.txt 文件[0m
    exit /b 1
)

REM 处理游戏资源
call :link_game_assets "%ENGINE_DIR%" "!GAME_DIR!" "%PROJECT_ROOT%" "true"

REM 更新 pubspec.yaml
call :update_pubspec_assets "%ENGINE_DIR%" PUBSPEC_UPDATED
if not "!PUBSPEC_UPDATED!"=="1" (
    echo [91m更新 pubspec.yaml 失败[0m
    exit /b 1
)

REM 更新字体配置
call :update_pubspec_fonts "%ENGINE_DIR%" "!GAME_DIR!" FONTS_UPDATED
if not "!FONTS_UPDATED!"=="1" (
    echo [91m更新字体配置失败[0m
    exit /b 1
)

REM 启动Flutter项目
echo.
echo [93m正在启动 SakiEngine ^(%PLATFORM_NAME%^)...[0m
cd /d "%ENGINE_DIR%" || exit /b 1

echo [93m正在清理 Flutter 缓存...[0m
flutter clean

echo [93m正在获取依赖...[0m
flutter pub get

echo [93m正在生成应用图标...[0m
flutter pub run flutter_launcher_icons:main

echo.

REM 检查是否为web模式
if "%1"=="web" (
    echo [92m在 Web ^(Chrome^) 上启动项目...[0m
    flutter run -d chrome --dart-define=SAKI_GAME_PATH="!GAME_DIR!"
) else (
    REM 根据平台启动
    if "%PLATFORM%"=="macos" (
        echo [92m在 macOS 上启动项目...[0m
        echo Debug: GAME_DIR=!GAME_DIR!
        flutter run -d macos --dart-define=SAKI_GAME_PATH="!GAME_DIR!"
    ) else if "%PLATFORM%"=="linux" (
        echo [92m在 Linux 上启动项目...[0m
        flutter run -d linux --dart-define=SAKI_GAME_PATH="!GAME_DIR!"
    ) else if "%PLATFORM%"=="windows" (
        echo [92m在 Windows 上启动项目...[0m
        flutter run -d windows --dart-define=SAKI_GAME_PATH="!GAME_DIR!"
    ) else (
        echo [91m错误: 不支持的平台 %PLATFORM%[0m
        exit /b 1
    )
)

goto :eof

REM ================================================
REM 工具函数定义
REM ================================================

:detect_platform
set "%~1=windows"
goto :eof

:get_platform_display_name
if "%~1"=="windows" set "%~2=Windows"
if "%~1"=="macos" set "%~2=macOS"
if "%~1"=="linux" set "%~2=Linux"
goto :eof

:check_platform_support
flutter --version >nul 2>&1
if errorlevel 1 (
    set "%~2=0"
) else (
    set "%~2=1"
)
goto :eof

:read_default_game
if exist "%~1\default_game.txt" (
    set /p "game_name=" < "%~1\default_game.txt"
    set "%~2=!game_name!"
) else (
    set "%~2="
)
goto :eof

:validate_game_dir
set "game_path=%~1\Game\%~2"
if exist "!game_path!" (
    set "%~3=!game_path!"
    set "%~4=1"
) else (
    set "%~3="
    set "%~4=0"
)
goto :eof

:read_game_config
if exist "%~1\game_config.txt" (
    set /p "config_line=" < "%~1\game_config.txt"
    set "%~2=!config_line!"
    set "%~3=1"
) else (
    set "%~2="
    set "%~3=0"
)
goto :eof

:set_app_identity
REM 这里应该调用相应的工具函数来设置应用信息
REM 暂时返回成功状态
set "%~4=1"
goto :eof

:link_game_assets
REM 这里应该调用相应的工具函数来链接游戏资源
REM 暂时返回成功状态
goto :eof

:update_pubspec_assets
REM 这里应该调用相应的工具函数来更新pubspec.yaml
REM 暂时返回成功状态
set "%~2=1"
goto :eof

:update_pubspec_fonts
REM 这里应该调用相应的工具函数来更新字体配置
REM 暂时返回成功状态
set "%~3=1"
goto :eof