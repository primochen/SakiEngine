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

echo [94m=== SakiEngine 开发环境启动器 ===[0m
echo.

REM 检测当前平台
set "PLATFORM=windows"
set "PLATFORM_NAME=Windows"

echo [92m检测到操作系统: %PLATFORM_NAME%[0m

REM 检查平台支持
flutter --version >nul 2>&1
if errorlevel 1 (
    echo [91m错误: 当前平台 %PLATFORM_NAME% 不支持或缺少必要的工具 ^(Flutter^)[0m
    echo [93m请确保已正确安装 Flutter SDK[0m
    exit /b 1
)

echo [92m✓ Flutter 环境检测通过[0m
echo.

REM 游戏项目选择逻辑
if exist "%DEFAULT_GAME_FILE%" (
    REM 读取默认游戏名称
    set /p "current_game=" < "%DEFAULT_GAME_FILE%"
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
if exist "%DEFAULT_GAME_FILE%" (
    set /p "GAME_NAME=" < "%DEFAULT_GAME_FILE%"
) else (
    set "GAME_NAME="
)

if "!GAME_NAME!"=="" (
    echo [91m错误: 无法读取游戏项目名称[0m
    exit /b 1
)

REM 验证游戏目录
set "GAME_DIR=%PROJECT_ROOT%\Game\!GAME_NAME!"
if not exist "!GAME_DIR!" (
    echo [91m错误: 游戏目录不存在: %PROJECT_ROOT%\Game\!GAME_NAME![0m
    echo [93m重新启动游戏选择器...[0m
    call "%SCRIPTS_DIR%\select_game.bat"
    if errorlevel 1 (
        echo [91m游戏选择失败，退出。[0m
        exit /b 1
    )
    REM 重新读取游戏名称
    if exist "%DEFAULT_GAME_FILE%" (
        set /p "GAME_NAME=" < "%DEFAULT_GAME_FILE%"
    ) else (
        set "GAME_NAME="
    )
    set "GAME_DIR=%PROJECT_ROOT%\Game\!GAME_NAME!"
)

echo.
echo [92m启动游戏项目: !GAME_NAME![0m
echo [94m游戏路径: !GAME_DIR![0m
echo.

REM 读取游戏配置
echo [93m正在读取游戏配置...[0m
set "config_file=!GAME_DIR!\game_config.txt"
if exist "!config_file!" (
    set "line_count=0"
    for /f "usebackq delims=" %%a in ("!config_file!") do (
        set /a line_count+=1
        if !line_count!==1 set "APP_NAME=%%a"
        if !line_count!==2 set "BUNDLE_ID=%%a"
    )
    
    if defined APP_NAME if defined BUNDLE_ID (
        echo [92m应用名称: !APP_NAME![0m
        echo [92m包名: !BUNDLE_ID![0m
        
        REM 设置应用身份信息
        echo [93m正在设置应用名称: !APP_NAME![0m
        echo [93m正在设置包名: !BUNDLE_ID![0m
        
        pushd "%ENGINE_DIR%"
        dart run rename setAppName --targets android,ios,macos,linux,windows,web --value "!APP_NAME!"
        dart run rename setBundleId --targets android,ios,macos --value "!BUNDLE_ID!"
        
        REM 手动修改 Linux 和 Windows 的包名
        if exist "%ENGINE_DIR%\linux\CMakeLists.txt" (
            powershell -Command "(Get-Content '%ENGINE_DIR%\linux\CMakeLists.txt') -replace 'set\(APPLICATION_ID \".*\"\)', 'set(APPLICATION_ID \"!BUNDLE_ID!\")' | Set-Content '%ENGINE_DIR%\linux\CMakeLists.txt'" >nul 2>&1
        )
        
        if exist "%ENGINE_DIR%\windows\runner\Runner.rc" (
            for /f "tokens=1 delims=." %%a in ("!BUNDLE_ID!") do set "company_name=%%a"
            powershell -Command "(Get-Content '%ENGINE_DIR%\windows\runner\Runner.rc') -replace 'VALUE \"CompanyName\", \".*\"', 'VALUE \"CompanyName\", \"!company_name!\"' | Set-Content '%ENGINE_DIR%\windows\runner\Runner.rc'" >nul 2>&1
        )
        popd
        
    ) else (
        echo [91m错误: 未找到有效的 game_config.txt 文件[0m
        echo [93m请确保游戏目录中存在正确格式的 game_config.txt 文件[0m
        exit /b 1
    )
) else (
    echo [91m错误: 未找到有效的 game_config.txt 文件[0m
    echo [93m请确保游戏目录中存在正确格式的 game_config.txt 文件[0m
    exit /b 1
)

REM 处理游戏资源
echo [93m正在清理旧的资源...[0m
REM 删除 Engine/assets 目录下的 Assets 和 GameScript 目录
if exist "%ENGINE_DIR%\assets\Assets" rmdir /s /q "%ENGINE_DIR%\assets\Assets"
if exist "%ENGINE_DIR%\assets\GameScript" rmdir /s /q "%ENGINE_DIR%\assets\GameScript"

REM 确保顶级 assets 目录存在
if not exist "%ENGINE_DIR%\assets" mkdir "%ENGINE_DIR%\assets"

echo [93m正在复制游戏资源和脚本...[0m
REM 总是使用复制模式以确保跨平台兼容性
if exist "!GAME_DIR!\Assets" (
    xcopy "!GAME_DIR!\Assets" "%ENGINE_DIR%\assets\Assets\" /E /I /Y >nul 2>&1
)
if exist "!GAME_DIR!\GameScript" (
    xcopy "!GAME_DIR!\GameScript" "%ENGINE_DIR%\assets\GameScript\" /E /I /Y >nul 2>&1
)

REM 复制 default_game.txt 到 assets 目录
echo [93m正在复制 default_game.txt 到 assets 目录...[0m
copy "%DEFAULT_GAME_FILE%" "%ENGINE_DIR%\assets\" >nul 2>&1

REM 处理 icon.png 复制逻辑（优先使用游戏目录，回退到项目根目录）
echo [93m正在处理应用图标...[0m
if exist "!GAME_DIR!\icon.png" (
    echo [92m使用游戏目录中的 icon.png[0m
    copy "!GAME_DIR!\icon.png" "%ENGINE_DIR%\assets\" >nul 2>&1
) else if exist "%PROJECT_ROOT%\icon.png" (
    echo [93m游戏目录未找到 icon.png，使用项目根目录的图标[0m
    copy "%PROJECT_ROOT%\icon.png" "%ENGINE_DIR%\assets\" >nul 2>&1
) else (
    echo [91m警告: 未找到 icon.png 文件[0m
)

echo [92m资源处理完成。[0m

REM pubspec.yaml 已包含必要的资源配置，跳过更新
echo [93m使用现有的 pubspec.yaml 配置...[0m

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
    echo [92m在 Windows 上启动项目...[0m
    flutter run -d windows --dart-define=SAKI_GAME_PATH="!GAME_DIR!"
)