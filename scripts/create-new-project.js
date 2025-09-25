/**
 * SakiEngine 新项目创建脚本
 * 支持 Windows、macOS、Linux 全平台
 */

const fs = require('fs');
const path = require('path');
const readline = require('readline');
const assetUtils = require('./asset-utils.js');

// 颜色代码
const colors = {
    reset: '\x1b[0m',
    red: '\x1b[31m',
    green: '\x1b[32m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m'
};

const colorLog = (message, color = 'reset') => {
    console.log(`${colors[color]}${message}${colors.reset}`);
};

/**
 * 验证项目名称
 */
function validateProjectName(name) {
    if (!name || name.trim() === '') {
        return false;
    }
    // 检查是否只包含字母、数字、下划线和连字符
    return /^[a-zA-Z0-9_-]+$/.test(name.trim());
}

/**
 * 验证Bundle ID
 */
function validateBundleId(bundleId) {
    if (!bundleId || bundleId.trim() === '') {
        return false;
    }
    // 检查是否符合com.xxx.xxx格式
    return /^[a-zA-Z][a-zA-Z0-9]*(\.[a-zA-Z][a-zA-Z0-9]*){2,}$/.test(bundleId.trim());
}

/**
 * 验证十六进制颜色
 */
function validateHexColor(color) {
    if (!color || color.trim() === '') {
        return false;
    }
    // 移除可能的#前缀
    const cleanColor = color.replace('#', '');
    // 检查是否为6位十六进制数
    return /^[0-9A-Fa-f]{6}$/.test(cleanColor);
}

/**
 * 十六进制转RGB
 */
function hexToRgb(hex) {
    // 移除可能的#前缀
    const cleanHex = hex.replace('#', '');
    
    // 提取RGB分量
    const r = parseInt(cleanHex.substr(0, 2), 16);
    const g = parseInt(cleanHex.substr(2, 2), 16);
    const b = parseInt(cleanHex.substr(4, 2), 16);
    
    return `rgb(${r}, ${g}, ${b})`;
}

/**
 * 创建新项目主函数
 */
async function createNewProject() {
    // 获取项目根目录
    const projectRoot = path.dirname(__dirname);
    const gameBaseDir = path.join(projectRoot, 'Game');
    const engineLibDir = path.join(projectRoot, 'Engine', 'lib');
    
    colorLog('=== SakiEngine 新项目创建向导 ===', 'blue');
    console.log();
    
    const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout
    });
    
    try {
        // 输入项目名称
        const projectName = await inputProjectName(rl, gameBaseDir);
        
        // 输入Bundle ID
        const bundleId = await inputBundleId(rl);
        
        // 输入主色调
        const primaryColor = await inputPrimaryColor(rl);
        
        // 转换颜色为RGB格式
        const rgbColor = hexToRgb(primaryColor);
        
        console.log();
        colorLog('=== 项目信息确认 ===', 'blue');
        colorLog(`项目名称: ${projectName}`, 'green');
        colorLog(`Bundle ID: ${bundleId}`, 'green');
        colorLog(`主色调: #${primaryColor} (${rgbColor})`, 'green');
        console.log();
        
        // 确认创建
        const confirmCreate = await askQuestion(rl, '确认创建项目? (Y/n): ');
        if (confirmCreate.toLowerCase() === 'n') {
            colorLog('已取消项目创建。', 'yellow');
            return null;
        }
        
        // 开始创建项目
        console.log();
        colorLog('正在创建项目...', 'blue');
        
        const projectDir = path.join(gameBaseDir, projectName);
        
        // 创建项目目录结构
        await createProjectStructure(projectDir, projectName, bundleId, primaryColor, rgbColor);
        
        // 创建项目模块
        await createProjectModule(engineLibDir, projectName, primaryColor);
        
        console.log();
        colorLog('✓ 项目创建完成！', 'green');
        console.log();
        colorLog(`项目路径: ${projectDir}`, 'blue');
        colorLog(`模块路径: ${path.join(engineLibDir, projectName.toLowerCase())}`, 'blue');
        colorLog('请将游戏资源（图片、音频等）放入对应的 Assets 子目录中。', 'yellow');
        console.log();
        colorLog('下一步操作：', 'green');
        colorLog('1. 运行 node run.js 并选择新创建的项目', 'blue');
        colorLog('2. 编辑 GameScript/labels/start.sks 开始创作你的故事', 'blue');
        colorLog('3. 在 Assets 目录中添加游戏所需的图片和音频资源', 'blue');
        colorLog(`4. 自定义项目模块: ${path.join(engineLibDir, projectName.toLowerCase(), `${projectName.toLowerCase()}_module.dart`)}`, 'blue');
        console.log();
        
        // 询问是否立即设置为默认项目
        const setDefault = await askQuestion(rl, '是否将此项目设置为默认项目? (Y/n): ');
        if (setDefault.toLowerCase() !== 'n') {
            assetUtils.writeDefaultGame(projectRoot, projectName);
            colorLog(`✓ 已设置 '${projectName}' 为默认项目`, 'green');
        }
        
        console.log();
        colorLog('项目创建完成！祝你创作愉快！', 'green');
        
        return projectName;
        
    } finally {
        rl.close();
    }
}

/**
 * 输入项目名称
 */
async function inputProjectName(rl, gameBaseDir) {
    while (true) {
        colorLog('请输入项目名称（推荐英文，只允许字母、数字、下划线和连字符）:', 'yellow');
        const projectName = await askQuestion(rl, '项目名称: ');
        
        if (validateProjectName(projectName)) {
            // 检查项目是否已存在
            const projectDir = path.join(gameBaseDir, projectName.trim());
            if (fs.existsSync(projectDir)) {
                colorLog(`错误: 项目 '${projectName.trim()}' 已存在！`, 'red');
                continue;
            }
            return projectName.trim();
        } else {
            colorLog('错误: 项目名称无效！请只使用字母、数字、下划线和连字符。', 'red');
        }
    }
}

/**
 * 输入Bundle ID
 */
async function inputBundleId(rl) {
    while (true) {
        console.log();
        colorLog('请输入应用包名（Bundle ID）:', 'yellow');
        colorLog('格式示例: com.yourcompany.yourapp', 'blue');
        const bundleId = await askQuestion(rl, 'Bundle ID: ');
        
        if (validateBundleId(bundleId)) {
            return bundleId.trim();
        } else {
            colorLog('错误: Bundle ID 格式无效！请使用 com.company.app 格式。', 'red');
        }
    }
}

/**
 * 输入主色调
 */
async function inputPrimaryColor(rl) {
    while (true) {
        console.log();
        colorLog('请输入主色调（十六进制颜色代码）:', 'yellow');
        colorLog('格式示例: #137B8B 或 137B8B（默认蓝绿色）', 'blue');
        const primaryColor = await askQuestion(rl, '主色调: ');
        
        // 如果为空，使用默认颜色
        if (!primaryColor || primaryColor.trim() === '') {
            colorLog('使用默认颜色: #137B8B', 'yellow');
            return '137B8B';
        }
        
        if (validateHexColor(primaryColor)) {
            // 移除#前缀用于后续处理
            return primaryColor.replace('#', '');
        } else {
            colorLog('错误: 颜色代码无效！请输入6位十六进制颜色代码。', 'red');
        }
    }
}

/**
 * 创建项目目录结构
 */
async function createProjectStructure(projectDir, projectName, bundleId, primaryColor, rgbColor) {
    colorLog('创建目录结构...', 'yellow');
    
    // 创建项目目录结构
    const dirs = [
        projectDir,
        path.join(projectDir, 'Assets'),
        path.join(projectDir, 'Assets', 'fonts'),
        path.join(projectDir, 'Assets', 'images'),
        path.join(projectDir, 'Assets', 'images', 'backgrounds'),
        path.join(projectDir, 'Assets', 'images', 'characters'),
        path.join(projectDir, 'Assets', 'images', 'items'),
        path.join(projectDir, 'Assets', 'gui'),
        path.join(projectDir, 'Assets', 'music'),
        path.join(projectDir, 'Assets', 'sound'),
        path.join(projectDir, 'Assets', 'voice'),
        path.join(projectDir, 'GameScript'),
        path.join(projectDir, 'GameScript', 'configs'),
        path.join(projectDir, 'GameScript', 'labels')
    ];
    
    dirs.forEach(dir => {
        if (!fs.existsSync(dir)) {
            fs.mkdirSync(dir, { recursive: true });
        }
    });
    
    // 创建 game_config.txt
    colorLog('创建游戏配置文件...', 'yellow');
    const gameConfigContent = `${projectName}\n${bundleId}\n\n`;
    fs.writeFileSync(path.join(projectDir, 'game_config.txt'), gameConfigContent);
    
    // 创建基础的角色配置文件
    colorLog('创建角色配置文件...', 'yellow');
    const charactersConfig = `//chara// SakiEngine 角色定义文件
//格式: 别名 : "显示名称" : 资源ID

// 示例角色定义（请根据实际需要修改）
main : "主角" : narrator
nr : "旁白" : narrator
n : "空白" : narrator

// 添加你的角色定义：
// 格式: 角色别名 : "角色显示名称" : 角色资源ID
// 示例: alice : "爱丽丝" : alice at pose
`;
    fs.writeFileSync(path.join(projectDir, 'GameScript', 'configs', 'characters.sks'), charactersConfig);
    
    // 创建基础的姿势配置文件
    colorLog('创建姿势配置文件...', 'yellow');
    const posesConfig = `//pos// SakiEngine 姿势定义文件
//
// --- 参数说明 ---
// 格式: 姿势名称: scale=<缩放> xcenter=<水平位置> ycenter=<垂直位置> anchor=<锚点>
//
// scale: 缩放系数。
//   scale=0:  特殊值，表示进行"边缘贴合 (Aspect Fit)"缩放，确保立绘完整显示在屏幕内。
//   scale>0:  表示立绘最终渲染高度为 [屏幕高度 * scale] 值。与源文件分辨率无关。
//
// xcenter / ycenter: 锚点在屏幕上的归一化位置 (0.0 到 1.0)。
//   xcenter=0.0 (最左), xcenter=0.5 (水平居中), xcenter=1.0 (最右)
//   ycenter=0.0 (最顶), ycenter=0.5 (垂直居中), ycenter=1.0 (最底)
//
// anchor: 指定用立绘自身的哪个点去对齐屏幕上的 (xcenter, ycenter) 坐标点。
//   常用锚点: center(中心), bottomCenter(底部中心), topCenter(顶部中心),
//             centerLeft(左边缘中心), centerRight(右边缘中心), 等等。

// 【常用】默认底部对齐姿势 (边缘贴合)
center: scale=0 xcenter=0.5 ycenter=1.0 anchor=bottomCenter
left: scale=0 xcenter=0.25 ycenter=1.0 anchor=bottomCenter
right: scale=0 xcenter=0.75 ycenter=1.0 anchor=bottomCenter

// 【特殊】稍微放大并居中的姿势 (固定缩放，高度为屏幕80%)
closeup: scale=0.8 xcenter=0.5 ycenter=0.8 anchor=center

// 默认姿势
pose: scale=1.5 ycenter=0.8 anchor=center
`;
    fs.writeFileSync(path.join(projectDir, 'GameScript', 'configs', 'poses.sks'), posesConfig);
    
    // 创建基础的系统配置文件
    colorLog('创建系统配置文件...', 'yellow');
    const systemConfig = `//config// SakiEngine 配置文件
theme: color=${rgbColor}
base_textbutton: size=40
base_dialogue: size=24
base_speaker: size=35
base_choice: size=24
base_review_title: size=45
base_quick_menu: size=25
main_menu: background=sky size=200 top=0.3 right=0.05
`;
    fs.writeFileSync(path.join(projectDir, 'GameScript', 'configs', 'configs.sks'), systemConfig);
    
    // 创建基础的剧情脚本文件
    colorLog('创建基础剧情脚本...', 'yellow');
    const startScript = `//label// SakiEngine 剧情标签脚本文件
label start
// 设置背景场景（请将对应的背景图片放入 Assets/images/backgrounds/ 目录）
// scene bg background_name

// 欢迎消息
nr "欢迎来到你的新项目！"
nr "这是一个使用 SakiEngine 创建的新项目。"

// 示例选择菜单
menu
"开始游戏" start_game
"查看设置" show_settings
"退出" quit_game
endmenu

label start_game
nr "游戏开始了！"
nr "请在这里编写你的故事..."
// 在这里添加你的游戏内容
return

label show_settings
nr "这里是设置界面。"
nr "你可以在这里添加各种设置选项。"
return

label quit_game
nr "感谢游玩！"
return
`;
    fs.writeFileSync(path.join(projectDir, 'GameScript', 'labels', 'start.sks'), startScript);
    
    // 创建README.md文件
    const readmeContent = `# ${projectName}

使用 SakiEngine 创建的视觉小说项目。

## 项目信息
- **项目名称**: ${projectName}
- **Bundle ID**: ${bundleId}
- **主色调**: #${primaryColor}

## 文件结构

### Assets/
游戏资源文件夹
- \`fonts/\` - 字体文件
- \`images/\` - 图片资源
  - \`backgrounds/\` - 背景图片
  - \`characters/\` - 角色立绘
  - \`items/\` - 道具图片
- \`music/\` - 背景音乐
- \`sound/\` - 音效文件
- \`voice/\` - 语音文件
- \`gui/\` - UI界面素材

### GameScript/
游戏脚本文件夹
- \`configs/\` - 配置文件
  - \`characters.sks\` - 角色定义
  - \`poses.sks\` - 姿势定义
  - \`configs.sks\` - 系统配置
- \`labels/\` - 剧情脚本
  - \`start.sks\` - 开始剧情

## 开发指南

### 1. 添加角色
1. 将角色立绘放入 \`Assets/images/characters/\` 目录
2. 在 \`GameScript/configs/characters.sks\` 中定义角色
3. 在脚本中使用角色别名进行对话

### 2. 添加背景
1. 将背景图片放入 \`Assets/images/backgrounds/\` 目录
2. 在脚本中使用 \`scene bg 背景名称\` 设置背景

### 3. 编写剧情
1. 在 \`GameScript/labels/\` 目录下创建新的 .sks 文件
2. 使用 SakiEngine 脚本语法编写剧情
3. 使用 \`label\` 定义剧情标签，使用 \`call\` 或选择菜单跳转

### 4. 自定义配置
编辑 \`GameScript/configs/configs.sks\` 来修改：
- 主题颜色
- 字体大小
- 界面布局等

## 运行项目
在 SakiEngine 根目录执行：
\`\`\`bash
node run.js
\`\`\`
然后选择本项目运行。

## 脚本语法参考
\`\`\`
// 注释
label 标签名
scene bg 背景名
角色别名 姿势 表情 "对话内容"
"旁白或主角对话"
menu
"选项1" 跳转标签1
"选项2" 跳转标签2
endmenu
\`\`\`
`;
    fs.writeFileSync(path.join(projectDir, 'README.md'), readmeContent);
}

/**
 * 创建项目模块文件
 */
async function createProjectModule(engineLibDir, projectName, primaryColor) {
    colorLog('创建项目模块文件夹...', 'yellow');
    
    const projectNameLower = projectName.toLowerCase();
    const moduleDir = path.join(engineLibDir, projectNameLower);
    
    // 创建模块目录结构
    if (!fs.existsSync(moduleDir)) {
        fs.mkdirSync(moduleDir, { recursive: true });
    }
    
    const screensDir = path.join(moduleDir, 'screens');
    if (!fs.existsSync(screensDir)) {
        fs.mkdirSync(screensDir, { recursive: true });
    }
    
    // 创建模块主文件
    colorLog('创建模块主文件...', 'yellow');
    const moduleContent = `import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:sakiengine/src/core/game_module.dart';
import 'package:sakiengine/src/core/module_registry.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';

/// ${projectName} 项目的自定义模块
class ${projectName}Module extends DefaultGameModule {
  
  @override
  ThemeData? createTheme() {
    // ${projectName} 项目的自定义主题
    return ThemeData(
      primarySwatch: Colors.blue,
      fontFamily: 'SourceHanSansCN',
      colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.blue).copyWith(
        secondary: const Color(0xFF${primaryColor}),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF${primaryColor}),
        elevation: 0,
      ),
    );
  }

  @override
  SakiEngineConfig? createCustomConfig() {
    // 可以返回项目特定的配置
    return null; // 使用默认配置
  }

  @override
  bool get enableDebugFeatures => true; // 启用调试功能

  @override
  Future<String> getAppTitle() async {
    // 自定义应用标题（可选）
    try {
      final defaultTitle = await super.getAppTitle();
      return defaultTitle; // 使用默认标题，或自定义如: '\$defaultTitle - ${projectName}'
    } catch (e) {
      return '${projectName}'; // 项目名作为标题
    }
  }

  @override
  Future<void> initialize() async {
    if (kDebugMode) {
      print('[${projectName}Module] 🎯 ${projectName} 项目模块初始化完成');
    }
    // 在这里可以进行项目特定的初始化
    // 比如加载特殊的资源、设置特殊的配置等
  }
}

// 自动注册这个模块
// 当这个文件被导入时，模块会自动注册
void _registerModule() {
  registerProjectModule('${projectNameLower}', () => ${projectName}Module());
}

// 使用顶级变量触发注册，避免编译器警告
final bool _isRegistered = (() {
  _registerModule();
  return true;
})();
`;
    
    fs.writeFileSync(path.join(moduleDir, `${projectNameLower}_module.dart`), moduleContent);
}

/**
 * 询问问题的辅助函数
 */
function askQuestion(rl, question) {
    return new Promise((resolve) => {
        rl.question(question, resolve);
    });
}

// 如果直接运行此脚本
if (require.main === module) {
    createNewProject().catch(error => {
        colorLog(`创建项目失败: ${error.message}`, 'red');
        process.exit(1);
    });
}

module.exports = {
    createNewProject,
    validateProjectName,
    validateBundleId,
    validateHexColor,
    hexToRgb,
    colorLog
};