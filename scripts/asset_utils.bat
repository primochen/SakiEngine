@echo off
setlocal enabledelayedexpansion

REM ================================================
REM 资源处理工具脚本
REM ================================================

REM 获取项目根目录（脚本所在目录的上级）
:get_project_root
for %%i in ("%~dp0..") do set "%~1=%%~fi"
goto :eof

REM 读取默认游戏名称
:read_default_game
set "default_game_file=%~1\default_game.txt"
if exist "!default_game_file!" (
    set /p "game_name=" < "!default_game_file!"
    set "%~2=!game_name!"
) else (
    set "%~2="
)
goto :eof

REM 验证游戏目录是否存在
:validate_game_dir
set "game_dir=%~1\Game\%~2"
if exist "!game_dir!" (
    set "%~3=!game_dir!"
    set "%~4=1"
) else (
    set "%~3="
    set "%~4=0"
)
goto :eof

REM 复制游戏资源（跨平台兼容）
:link_game_assets
set "engine_dir=%~1"
set "game_dir=%~2"
set "project_root=%~3"
set "use_symlink=%~4"

echo [93m正在清理旧的资源...[0m
REM 删除 Engine/assets 目录下的 Assets 和 GameScript* 目录
if exist "%engine_dir%\assets\Assets" rmdir /s /q "%engine_dir%\assets\Assets"
for /d %%G in ("%engine_dir%\assets\GameScript*") do (
    if exist "%%G" rmdir /s /q "%%G"
)

REM 确保顶级 assets 目录存在
if not exist "%engine_dir%\assets" mkdir "%engine_dir%\assets"

echo [93m正在复制游戏资源和脚本...[0m
REM 总是使用复制模式以确保跨平台兼容性
xcopy "%game_dir%\Assets" "%engine_dir%\assets\Assets\" /E /I /Y >nul 2>&1
REM 复制 GameScript* 目录
for /d %%G in ("%game_dir%\GameScript*") do (
    if exist "%%G" xcopy "%%G" "%engine_dir%\assets\%%~nG\" /E /I /Y >nul 2>&1
)

REM 复制 default_game.txt 到 assets 目录
echo [93m正在复制 default_game.txt 到 assets 目录...[0m
copy "%project_root%\default_game.txt" "%engine_dir%\assets\" >nul 2>&1

REM 处理 icon.png 复制逻辑（优先使用游戏目录，回退到项目根目录）
echo [93m正在处理应用图标...[0m
if exist "%game_dir%\icon.png" (
    echo [92m使用游戏目录中的 icon.png[0m
    copy "%game_dir%\icon.png" "%engine_dir%\assets\" >nul 2>&1
) else if exist "%project_root%\icon.png" (
    echo [93m游戏目录未找到 icon.png，使用项目根目录的图标[0m
    copy "%project_root%\icon.png" "%engine_dir%\assets\" >nul 2>&1
) else (
    echo [91m警告: 未找到 icon.png 文件[0m
)

echo [92m资源处理完成。[0m
goto :eof

REM 读取游戏配置
:read_game_config
set "config_file=%~1\game_config.txt"
if exist "!config_file!" (
    set line_count=0
    for /f "usebackq delims=" %%a in ("!config_file!") do (
        set /a line_count+=1
        if !line_count!==1 set "app_name=%%a"
        if !line_count!==2 set "bundle_id=%%a"
    )
    
    if defined app_name if defined bundle_id (
        set "%~2=!app_name!|!bundle_id!"
        set "%~3=1"
    ) else (
        set "%~2="
        set "%~3=0"
    )
) else (
    set "%~2="
    set "%~3=0"
)
goto :eof

REM 设置应用名称和包名
:set_app_identity
set "engine_dir=%~1"
set "app_name=%~2"
set "bundle_id=%~3"

echo [93m正在设置应用名称: %app_name%[0m
echo [93m正在设置包名: %bundle_id%[0m

pushd "%engine_dir%"

REM 设置应用名称
dart run rename setAppName --targets android,ios,macos,linux,windows,web --value "%app_name%"

REM 设置包名
dart run rename setBundleId --targets android,ios,macos --value "%bundle_id%"

REM 手动修改 Linux 和 Windows 的包名
if exist "%engine_dir%\linux\CMakeLists.txt" (
    powershell -Command "(Get-Content '%engine_dir%\linux\CMakeLists.txt') -replace 'set\(APPLICATION_ID \".*\"\)', 'set(APPLICATION_ID \"%bundle_id%\")' | Set-Content '%engine_dir%\linux\CMakeLists.txt'" >nul 2>&1
)

if exist "%engine_dir%\windows\runner\Runner.rc" (
    for /f "tokens=1 delims=." %%a in ("%bundle_id%") do set "company_name=%%a"
    powershell -Command "(Get-Content '%engine_dir%\windows\runner\Runner.rc') -replace 'VALUE \"CompanyName\", \".*\"', 'VALUE \"CompanyName\", \"!company_name!\"' | Set-Content '%engine_dir%\windows\runner\Runner.rc'" >nul 2>&1
)

popd
set "%~4=1"
goto :eof
