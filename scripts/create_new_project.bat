@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM ================================================
REM SakiEngine 新项目创建脚本
REM ================================================

REM 切换到脚本所在的目录
cd /d "%~dp0"
REM 获取项目根目录（scripts目录的上级目录）
for %%i in ("%cd%\..") do set "PROJECT_ROOT=%%~fi"
set "GAME_BASE_DIR=%PROJECT_ROOT%\Game"
set "ENGINE_LIB_DIR=%PROJECT_ROOT%\Engine\lib"

echo [94m=== SakiEngine 新项目创建向导 ===[0m
echo.

REM 验证项目名称函数
:validate_project_name
set "name=%~1"
if "%name%"=="" exit /b 1
echo %name% | findstr /r "^[a-zA-Z0-9_-][a-zA-Z0-9_-]*$" >nul
if errorlevel 1 exit /b 1
exit /b 0

REM 验证Bundle ID函数
:validate_bundle_id
set "bundle_id=%~1"
if "%bundle_id%"=="" exit /b 1
echo %bundle_id% | findstr /r "^[a-zA-Z][a-zA-Z0-9]*\(\.[a-zA-Z][a-zA-Z0-9]*\)*\.[a-zA-Z][a-zA-Z0-9]*$" >nul
if errorlevel 1 exit /b 1
exit /b 0

REM 验证十六进制颜色函数
:validate_hex_color
set "color=%~1"
if "%color%"=="" exit /b 1
REM 移除可能的#前缀
set "color=!color:#=!"
echo !color! | findstr /r "^[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]$" >nul
if errorlevel 1 exit /b 1
exit /b 0

REM 十六进制转RGB函数
:hex_to_rgb
set "hex=%~1"
set "hex=!hex:#=!"
set /a "r=0x!hex:~0,2!"
set /a "g=0x!hex:~2,2!"
set /a "b=0x!hex:~4,2!"
set "rgb_result=rgb(!r!, !g!, !b!)"
exit /b 0

REM 输入项目名称
:input_project_name
echo [93m请输入项目名称（推荐英文，只允许字母、数字、下划线和连字符）:[0m
set /p "PROJECT_NAME=[94m项目名称: [0m"

call :validate_project_name "%PROJECT_NAME%"
if errorlevel 1 (
    echo [91m错误: 项目名称无效！请只使用字母、数字、下划线和连字符。[0m
    goto input_project_name
)

REM 检查项目是否已存在
if exist "%GAME_BASE_DIR%\%PROJECT_NAME%" (
    echo [91m错误: 项目 '%PROJECT_NAME%' 已存在！[0m
    goto input_project_name
)

REM 输入Bundle ID
:input_bundle_id
echo.
echo [93m请输入应用包名（Bundle ID）:[0m
echo [94m格式示例: com.yourcompany.yourapp[0m
set /p "BUNDLE_ID=[94mBundle ID: [0m"

call :validate_bundle_id "%BUNDLE_ID%"
if errorlevel 1 (
    echo [91m错误: Bundle ID 格式无效！请使用 com.company.app 格式。[0m
    goto input_bundle_id
)

REM 输入主色调
:input_primary_color
echo.
echo [93m请输入主色调（十六进制颜色代码）:[0m
echo [94m格式示例: #137B8B 或 137B8B（默认蓝绿色）[0m
set /p "PRIMARY_COLOR=[94m主色调: [0m"

REM 如果为空，使用默认颜色
if "%PRIMARY_COLOR%"=="" (
    set "PRIMARY_COLOR=137B8B"
    echo [93m使用默认颜色: #!PRIMARY_COLOR![0m
    goto validate_color_done
)

call :validate_hex_color "%PRIMARY_COLOR%"
if errorlevel 1 (
    echo [91m错误: 颜色代码无效！请输入6位十六进制颜色代码。[0m
    goto input_primary_color
)

:validate_color_done
REM 移除#前缀用于后续处理
set "PRIMARY_COLOR=!PRIMARY_COLOR:#=!"

REM 转换颜色为RGB格式
call :hex_to_rgb "!PRIMARY_COLOR!"
set "RGB_COLOR=!rgb_result!"

echo.
echo [94m=== 项目信息确认 ===[0m
echo [92m项目名称: %PROJECT_NAME%[0m
echo [92mBundle ID: %BUNDLE_ID%[0m
echo [92m主色调: #%PRIMARY_COLOR% (!RGB_COLOR!)[0m
echo.

REM 确认创建
set /p "confirm=[93m确认创建项目? (Y/n): [0m"
if /i "%confirm%"=="n" (
    echo [93m已取消项目创建。[0m
    exit /b 0
)

REM 开始创建项目
echo.
echo [94m正在创建项目...[0m

set "PROJECT_DIR=%GAME_BASE_DIR%\%PROJECT_NAME%"

REM 创建项目目录结构
echo [93m创建目录结构...[0m
mkdir "%PROJECT_DIR%" 2>nul
mkdir "%PROJECT_DIR%\Assets" 2>nul
mkdir "%PROJECT_DIR%\Assets\fonts" 2>nul
mkdir "%PROJECT_DIR%\Assets\images" 2>nul
mkdir "%PROJECT_DIR%\Assets\images\backgrounds" 2>nul
mkdir "%PROJECT_DIR%\Assets\images\characters" 2>nul
mkdir "%PROJECT_DIR%\Assets\images\items" 2>nul
mkdir "%PROJECT_DIR%\Assets\gui" 2>nul
mkdir "%PROJECT_DIR%\Assets\music" 2>nul
mkdir "%PROJECT_DIR%\Assets\sound" 2>nul
mkdir "%PROJECT_DIR%\Assets\voice" 2>nul
mkdir "%PROJECT_DIR%\GameScript" 2>nul
mkdir "%PROJECT_DIR%\GameScript\configs" 2>nul
mkdir "%PROJECT_DIR%\GameScript\labels" 2>nul

REM 创建 game_config.txt
echo [93m创建游戏配置文件...[0m
(
echo %PROJECT_NAME%
echo %BUNDLE_ID%
echo.
) > "%PROJECT_DIR%\game_config.txt"

REM 创建基础的角色配置文件
echo [93m创建角色配置文件...[0m
(
echo //chara// SakiEngine 角色定义文件
echo //格式: 别名 : "显示名称" : 资源ID
echo.
echo // 示例角色定义（请根据实际需要修改）
echo main : "主角" : narrator
echo nr : "旁白" : narrator
echo n : "空白" : narrator
echo.
echo // 添加你的角色定义：
echo // 格式: 角色别名 : "角色显示名称" : 角色资源ID
echo // 示例: alice : "爱丽丝" : alice at pose
) > "%PROJECT_DIR%\GameScript\configs\characters.sks"

REM 创建基础的姿势配置文件
echo [93m创建姿势配置文件...[0m
(
echo //pos// SakiEngine 姿势定义文件
echo //
echo // --- 参数说明 ---
echo // 格式: 姿势名称: scale=^<缩放^> xcenter=^<水平位置^> ycenter=^<垂直位置^> anchor=^<锚点^>
echo //
echo // scale: 缩放系数。
echo //   scale=0:  特殊值，表示进行"边缘贴合 ^(Aspect Fit^)"缩放，确保立绘完整显示在屏幕内。
echo //   scale^>0:  表示立绘最终渲染高度为 [屏幕高度 * scale] 值。与源文件分辨率无关。
echo //
echo // xcenter / ycenter: 锚点在屏幕上的归一化位置 ^(0.0 到 1.0^)。
echo //   xcenter=0.0 ^(最左^), xcenter=0.5 ^(水平居中^), xcenter=1.0 ^(最右^)
echo //   ycenter=0.0 ^(最顶^), ycenter=0.5 ^(垂直居中^), ycenter=1.0 ^(最底^)
echo //
echo // anchor: 指定用立绘自身的哪个点去对齐屏幕上的 ^(xcenter, ycenter^) 坐标点。
echo //   常用锚点: center^(中心^), bottomCenter^(底部中心^), topCenter^(顶部中心^),
echo //             centerLeft^(左边缘中心^), centerRight^(右边缘中心^), 等等。
echo.
echo // 【常用】默认底部对齐姿势 ^(边缘贴合^)
echo center: scale=0 xcenter=0.5 ycenter=1.0 anchor=bottomCenter
echo left: scale=0 xcenter=0.25 ycenter=1.0 anchor=bottomCenter
echo right: scale=0 xcenter=0.75 ycenter=1.0 anchor=bottomCenter
echo.
echo // 【特殊】稍微放大并居中的姿势 ^(固定缩放，高度为屏幕80%%^)
echo closeup: scale=0.8 xcenter=0.5 ycenter=0.8 anchor=center
echo.
echo // 默认姿势
echo pose: scale=1.5 ycenter=0.8 anchor=center
) > "%PROJECT_DIR%\GameScript\configs\poses.sks"

REM 创建基础的系统配置文件
echo [93m创建系统配置文件...[0m
(
echo //config// SakiEngine 配置文件
echo theme: color=!RGB_COLOR!
echo base_textbutton: size=40
echo base_dialogue: size=24
echo base_speaker: size=35
echo base_choice: size=24
echo base_review_title: size=45
echo base_quick_menu: size=25
echo main_menu: background=sky size=200 top=0.3 right=0.05
) > "%PROJECT_DIR%\GameScript\configs\configs.sks"

REM 创建基础的剧情脚本文件
echo [93m创建基础剧情脚本...[0m
(
echo //label// SakiEngine 剧情标签脚本文件
echo label start
echo // 设置背景场景（请将对应的背景图片放入 Assets/images/backgrounds/ 目录）
echo // scene bg background_name
echo.
echo // 欢迎消息
echo nr "欢迎来到你的新项目！"
echo nr "这是一个使用 SakiEngine 创建的新项目。"
echo.
echo // 示例选择菜单
echo menu
echo "开始游戏" start_game
echo "查看设置" show_settings
echo "退出" quit_game
echo endmenu
echo.
echo label start_game
echo nr "游戏开始了！"
echo nr "请在这里编写你的故事..."
echo // 在这里添加你的游戏内容
echo return
echo.
echo label show_settings
echo nr "这里是设置界面。"
echo nr "你可以在这里添加各种设置选项。"
echo return
echo.
echo label quit_game
echo nr "感谢游玩！"
echo return
) > "%PROJECT_DIR%\GameScript\labels\start.sks"

REM 创建项目模块文件夹和文件
echo [93m创建项目模块文件夹...[0m
for %%a in (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z) do call set "PROJECT_NAME_LOWER=%%PROJECT_NAME:%%a=%%a%%"
for %%a in (a b c d e f g h i j k l m n o p q r s t u v w x y z) do call set "PROJECT_NAME_LOWER=%%PROJECT_NAME_LOWER:%%a=%%a%%"
call :tolower PROJECT_NAME_LOWER "%PROJECT_NAME%"

set "MODULE_DIR=%ENGINE_LIB_DIR%\!PROJECT_NAME_LOWER!"

REM 创建模块目录结构
mkdir "!MODULE_DIR!" 2>nul
mkdir "!MODULE_DIR!\screens" 2>nul

REM 创建模块主文件
echo [93m创建模块主文件...[0m
(
echo import 'package:flutter/material.dart';
echo import 'package:flutter/foundation.dart';
echo import 'package:sakiengine/src/core/game_module.dart';
echo import 'package:sakiengine/src/core/module_registry.dart';
echo import 'package:sakiengine/src/config/saki_engine_config.dart';
echo.
echo /// %PROJECT_NAME% 项目的自定义模块
echo class %PROJECT_NAME%Module extends DefaultGameModule {
echo   
echo   @override
echo   ThemeData? createTheme^(^) {
echo     // %PROJECT_NAME% 项目的自定义主题
echo     return ThemeData^(
echo       primarySwatch: Colors.blue,
echo       fontFamily: 'SourceHanSansCN',
echo       colorScheme: ColorScheme.fromSwatch^(primarySwatch: Colors.blue^).copyWith^(
echo         secondary: const Color^(0xFF%PRIMARY_COLOR%^),
echo       ^),
echo       appBarTheme: const AppBarTheme^(
echo         backgroundColor: Color^(0xFF%PRIMARY_COLOR%^),
echo         elevation: 0,
echo       ^),
echo     ^);
echo   }
echo.
echo   @override
echo   SakiEngineConfig? createCustomConfig^(^) {
echo     // 可以返回项目特定的配置
echo     return null; // 使用默认配置
echo   }
echo.
echo   @override
echo   bool get enableDebugFeatures =^> true; // 启用调试功能
echo.
echo   @override
echo   Future^<String^> getAppTitle^(^) async {
echo     // 自定义应用标题（可选）
echo     try {
echo       final defaultTitle = await super.getAppTitle^(^);
echo       return defaultTitle; // 使用默认标题，或自定义如: '$defaultTitle - %PROJECT_NAME%'
echo     } catch ^(e^) {
echo       return '%PROJECT_NAME%'; // 项目名作为标题
echo     }
echo   }
echo.
echo   @override
echo   Future^<void^> initialize^(^) async {
echo     if ^(kDebugMode^) {
echo       print^('[%PROJECT_NAME%Module] 🎯 %PROJECT_NAME% 项目模块初始化完成'^);
echo     }
echo     // 在这里可以进行项目特定的初始化
echo     // 比如加载特殊的资源、设置特殊的配置等
echo   }
echo }
echo.
echo // 自动注册这个模块
echo // 当这个文件被导入时，模块会自动注册
echo void _registerModule^(^) {
echo   registerProjectModule^('!PROJECT_NAME_LOWER!', ^(^) =^> %PROJECT_NAME%Module^(^)^);
echo }
echo.
echo // 使用顶级变量触发注册，避免编译器警告
echo final bool _isRegistered = ^(^(^) {
echo   _registerModule^(^);
echo   return true;
echo }^)^(^);
) > "!MODULE_DIR!\!PROJECT_NAME_LOWER!_module.dart"

echo.
echo [92m✓ 项目创建完成！[0m
echo.
echo [94m项目路径: %PROJECT_DIR%[0m
echo [94m模块路径: !MODULE_DIR![0m
echo [93m请将游戏资源（图片、音频等）放入对应的 Assets 子目录中。[0m
echo.
echo [92m下一步操作：[0m
echo [94m1. 运行 run.bat 并选择新创建的项目[0m
echo [94m2. 编辑 GameScript\labels\start.sks 开始创作你的故事[0m
echo [94m3. 在 Assets 目录中添加游戏所需的图片和音频资源[0m
echo [94m4. 自定义项目模块: !MODULE_DIR!\!PROJECT_NAME_LOWER!_module.dart[0m
echo.

REM 询问是否立即设置为默认项目
set /p "set_default=[93m是否将此项目设置为默认项目? (Y/n): [0m"
if /i not "%set_default%"=="n" (
    echo %PROJECT_NAME% > "%PROJECT_ROOT%\default_game.txt"
    echo [92m✓ 已设置 '%PROJECT_NAME%' 为默认项目[0m
)

echo.
echo [92m项目创建完成！祝你创作愉快！[0m
goto :eof

REM 转换为小写的辅助函数
:tolower
setlocal enabledelayedexpansion
set "str=%~2"
set "result="
for /l %%i in (0,1,25) do (
    for %%j in (%%i) do (
        set "upper=!ABCDEFGHIJKLMNOPQRSTUVWXYZ:~%%j,1!"
        set "lower=!abcdefghijklmnopqrstuvwxyz:~%%j,1!"
        if defined upper (
            call set "str=%%str:!upper!=!lower!%%"
        )
    )
)
endlocal & set "%~1=%str%"
goto :eof