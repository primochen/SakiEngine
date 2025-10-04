@echo off
setlocal enabledelayedexpansion

REM ================================================
REM pubspec.yaml 动态更新工具
REM ================================================

REM 动态更新 pubspec.yaml 的 assets 部分
:update_pubspec_assets
set "engine_dir=%~1"
set "pubspec_path=%engine_dir%\pubspec.yaml"
set "temp_pubspec_path=%engine_dir%\pubspec.yaml.temp"

echo [93m正在动态生成 pubspec.yaml 资源列表...[0m

REM 1. 找到 assets: 的起始行 (必须是缩进2个空格的)
set "assets_start_line="
set "line_num=0"
for /f "usebackq delims=" %%a in ("%pubspec_path%") do (
    set /a line_num+=1
    echo %%a | findstr /r "^  assets:" >nul 2>&1
    if not errorlevel 1 (
        set "assets_start_line=!line_num!"
        goto :found_assets_line
    )
)

:found_assets_line
if not defined assets_start_line (
    echo [91m错误: 在 pubspec.yaml 中未找到 '  assets:' 部分。请确保该部分存在且有两个空格的缩进。[0m
    set "%~2=0"
    goto :eof
)

REM 2. 复制 assets: 之前的部分到临时文件
set "line_count=0"
for /f "usebackq delims=" %%a in ("%pubspec_path%") do (
    set /a line_count+=1
    if !line_count! lss !assets_start_line! (
        echo %%a >> "%temp_pubspec_path%"
    )
)

REM 3. 写入 assets: 标签和动态生成的列表 (排除 shaders 目录)
echo   assets: >> "%temp_pubspec_path%"
echo     - assets/default_game.txt >> "%temp_pubspec_path%"

REM 添加引擎默认字体目录
if exist "%engine_dir%\assets\fonts" (
    echo     - assets/fonts/ >> "%temp_pubspec_path%"
)

REM 添加其他目录 (排除 shaders 和 fonts)
for /d %%d in ("%engine_dir%\assets\*") do (
    set "dir_name=%%~nxd"
    if not "!dir_name!"=="shaders" if not "!dir_name!"=="fonts" (
        set "relative_path=assets/!dir_name!/"
        echo     - !relative_path! >> "%temp_pubspec_path%"
    )
)

REM 4. 找到原文件中 assets: 块的结束位置
set "assets_block_end_line=%assets_start_line%"
set "line_count=0"
for /f "usebackq delims=" %%a in ("%pubspec_path%") do (
    set /a line_count+=1
    if !line_count! gtr !assets_start_line! (
        echo %%a | findstr /r "^    - assets/" >nul 2>&1
        if errorlevel 1 (
            goto :found_assets_end
        ) else (
            set "assets_block_end_line=!line_count!"
        )
    )
)

:found_assets_end
REM 5. 追加原文件中 assets: 块之后的所有内容
set "line_count=0"
for /f "usebackq delims=" %%a in ("%pubspec_path%") do (
    set /a line_count+=1
    if !line_count! gtr !assets_block_end_line! (
        echo %%a >> "%temp_pubspec_path%"
    )
)

REM 6. 替换原文件
move "%temp_pubspec_path%" "%pubspec_path%" >nul 2>&1
echo [92mpubspec.yaml 更新成功。[0m
set "%~2=1"
goto :eof

REM 动态更新 pubspec.yaml 的 fonts 部分
:update_pubspec_fonts
set "engine_dir=%~1"
set "game_dir=%~2"
set "pubspec_path=%engine_dir%\pubspec.yaml"
set "temp_pubspec_path=%engine_dir%\pubspec.yaml.temp"

echo [93m正在动态生成 pubspec.yaml 字体列表...[0m

REM 1. 找到 fonts: 的起始行
set "fonts_start_line="
set "line_num=0"
for /f "usebackq delims=" %%a in ("%pubspec_path%") do (
    set /a line_num+=1
    echo %%a | findstr /r "^  fonts:" >nul 2>&1
    if not errorlevel 1 (
        set "fonts_start_line=!line_num!"
        goto :found_fonts_line
    )
)

:found_fonts_line
if not defined fonts_start_line (
    echo [91m错误: 在 pubspec.yaml 中未找到 '  fonts:' 部分。[0m
    set "%~3=0"
    goto :eof
)

REM 2. 复制 fonts: 之前的部分到临时文件
set "line_count=0"
for /f "usebackq delims=" %%a in ("%pubspec_path%") do (
    set /a line_count+=1
    if !line_count! lss !fonts_start_line! (
        echo %%a >> "%temp_pubspec_path%"
    )
)

REM 3. 写入 fonts: 标签和动态生成的字体列表
echo   fonts: >> "%temp_pubspec_path%"
echo     - family: SourceHanSansCN >> "%temp_pubspec_path%"
echo       fonts: >> "%temp_pubspec_path%"
echo         - asset: assets/fonts/SourceHanSansCN-Bold.ttf >> "%temp_pubspec_path%"
echo           weight: 700 >> "%temp_pubspec_path%"

REM 4. 动态添加游戏项目的字体
if exist "%game_dir%\Assets\fonts" (
    for %%f in ("%game_dir%\Assets\fonts\*.ttf" "%game_dir%\Assets\fonts\*.otf") do (
        set "font_file=%%~nf"
        set "relative_path=assets/Assets/fonts/%%~nxf"
        echo     - family: !font_file! >> "%temp_pubspec_path%"
        echo       fonts: >> "%temp_pubspec_path%"
        echo         - asset: !relative_path! >> "%temp_pubspec_path%"
    )
)

REM 5. 找到原文件中 fonts: 块的结束位置并跳过
set "fonts_block_end_line=%fonts_start_line%"
set "line_count=0"
set "in_fonts_block=1"
for /f "usebackq delims=" %%a in ("%pubspec_path%") do (
    set /a line_count+=1
    if !line_count! gtr !fonts_start_line! (
        set "line_content=%%a"
        REM 检查是否仍在 fonts 块内
        echo !line_content! | findstr /r "^    - family:" >nul 2>&1
        if not errorlevel 1 set "fonts_block_end_line=!line_count!"
        echo !line_content! | findstr /r "^      fonts:" >nul 2>&1
        if not errorlevel 1 set "fonts_block_end_line=!line_count!"
        echo !line_content! | findstr /r "^        - asset:" >nul 2>&1
        if not errorlevel 1 set "fonts_block_end_line=!line_count!"
        echo !line_content! | findstr /r "^          weight:" >nul 2>&1
        if not errorlevel 1 set "fonts_block_end_line=!line_count!"
        echo !line_content! | findstr /r "^          style:" >nul 2>&1
        if not errorlevel 1 set "fonts_block_end_line=!line_count!"
        echo !line_content! | findstr /r "^[[:space:]]*$" >nul 2>&1
        if not errorlevel 1 set "fonts_block_end_line=!line_count!"
    )
)

REM 6. 追加原文件中 fonts: 块之后的所有内容
set "line_count=0"
for /f "usebackq delims=" %%a in ("%pubspec_path%") do (
    set /a line_count+=1
    if !line_count! gtr !fonts_block_end_line! (
        echo %%a >> "%temp_pubspec_path%"
    )
)

REM 7. 替换原文件
move "%temp_pubspec_path%" "%pubspec_path%" >nul 2>&1
echo [92mpubspec.yaml 字体配置更新成功。[0m
set "%~3=1"
goto :eof