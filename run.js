#!/usr/bin/env node

/**
 * SakiEngine 通用启动脚本
 * 支持 Windows、macOS、Linux 全平台
 */

const fs = require('fs');
const path = require('path');
const { execSync, spawn } = require('child_process');
const readline = require('readline');

// ANSI 颜色代码
const colors = {
    reset: '\x1b[0m',
    red: '\x1b[31m',
    green: '\x1b[32m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    magenta: '\x1b[35m',
    cyan: '\x1b[36m',
    white: '\x1b[37m'
};

// 彩色输出函数
const colorLog = (message, color = 'reset') => {
    console.log(`${colors[color]}${message}${colors.reset}`);
};

// 项目路径配置
const PROJECT_ROOT = path.dirname(__filename);
const SCRIPTS_DIR = path.join(PROJECT_ROOT, 'scripts');
const ENGINE_DIR = path.join(PROJECT_ROOT, 'Engine');
const DEFAULT_GAME_FILE = path.join(PROJECT_ROOT, 'default_game.txt');

// 导入工具模块
const platformUtils = require('./scripts/platform-utils.js');
const assetUtils = require('./scripts/asset-utils.js');
const pubspecUtils = require('./scripts/pubspec-utils.js');

// 用户输入工具
const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

const askQuestion = (question) => {
    return new Promise((resolve) => {
        rl.question(question, resolve);
    });
};

// 主函数
async function main() {
    try {
        colorLog('=== SakiEngine 开发环境启动器 ===', 'blue');
        console.log();

        // 检测当前平台
        const platform = platformUtils.detectPlatform();
        const platformName = platformUtils.getPlatformDisplayName(platform);
        
        colorLog(`检测到操作系统: ${platformName}`, 'green');

        // 检查平台支持
        if (!platformUtils.checkPlatformSupport(platform)) {
            colorLog(`错误: 当前平台 ${platformName} 不支持或缺少必要的工具 (Flutter)`, 'red');
            colorLog('请确保已正确安装 Flutter SDK', 'yellow');
            process.exit(1);
        }

        colorLog('✓ Flutter 环境检测通过', 'green');
        console.log();

        // 游戏项目选择逻辑
        await handleGameSelection();

        // 读取最终的游戏名称
        const gameName = assetUtils.readDefaultGame(PROJECT_ROOT);
        if (!gameName) {
            colorLog('错误: 无法读取游戏项目名称', 'red');
            process.exit(1);
        }

        // 验证游戏目录
        let gameDir = assetUtils.validateGameDir(PROJECT_ROOT, gameName);
        if (!gameDir) {
            colorLog(`错误: 游戏目录不存在: ${path.join(PROJECT_ROOT, 'Game', gameName)}`, 'red');
            colorLog('重新启动游戏选择器...', 'yellow');
            
            // 重新选择游戏
            const selectGame = require('./scripts/select-game.js');
            await selectGame.selectGame();
            
            const newGameName = assetUtils.readDefaultGame(PROJECT_ROOT);
            gameDir = assetUtils.validateGameDir(PROJECT_ROOT, newGameName);
        }

        console.log();
        colorLog(`启动游戏项目: ${gameName}`, 'green');
        colorLog(`游戏路径: ${gameDir}`, 'blue');
        console.log();

        // 读取游戏配置
        colorLog('正在读取游戏配置...', 'yellow');
        const gameConfig = assetUtils.readGameConfig(gameDir);
        if (!gameConfig) {
            colorLog('错误: 未找到有效的 game_config.txt 文件', 'red');
            colorLog('请确保游戏目录中存在正确格式的 game_config.txt 文件', 'yellow');
            process.exit(1);
        }

        const { appName, bundleId } = gameConfig;
        colorLog(`应用名称: ${appName}`, 'green');
        colorLog(`包名: ${bundleId}`, 'green');

        // 设置应用身份信息
        if (!assetUtils.setAppIdentity(ENGINE_DIR, appName, bundleId)) {
            colorLog('设置应用信息失败', 'red');
            process.exit(1);
        }

        // 处理游戏资源
        assetUtils.linkGameAssets(ENGINE_DIR, gameDir, PROJECT_ROOT);

        // 更新 pubspec.yaml
        if (!pubspecUtils.updatePubspecAssets(ENGINE_DIR)) {
            colorLog('更新 pubspec.yaml 失败', 'red');
            process.exit(1);
        }

        // 更新字体配置
        if (!pubspecUtils.updatePubspecFonts(ENGINE_DIR, gameDir)) {
            colorLog('更新字体配置失败', 'red');
            process.exit(1);
        }

        // 启动Flutter项目
        console.log();
        colorLog(`正在启动 SakiEngine (${platformName})...`, 'yellow');
        
        // 切换到 Engine 目录
        process.chdir(ENGINE_DIR);

        colorLog('正在清理 Flutter 缓存...', 'yellow');
        execSync('flutter clean', { stdio: 'inherit' });

        colorLog('正在获取依赖...', 'yellow');
        execSync('flutter pub get', { stdio: 'inherit' });

        colorLog('正在生成应用图标...', 'yellow');
        try {
            execSync('flutter pub run flutter_launcher_icons:main', { stdio: 'inherit' });
        } catch (error) {
            colorLog('应用图标生成失败，继续启动...', 'yellow');
        }

        console.log();

        // 检查是否为web模式
        const isWebMode = process.argv.includes('web');
        
        if (isWebMode) {
            colorLog('在 Web (Chrome) 上启动项目...', 'green');
            execSync(`flutter run -d chrome --dart-define=SAKI_GAME_PATH="${gameDir}"`, { stdio: 'inherit' });
        } else {
            // 根据平台启动
            let targetPlatform;
            switch (platform) {
                case 'macos':
                    targetPlatform = 'macos';
                    break;
                case 'linux':
                    targetPlatform = 'linux';
                    break;
                case 'windows':
                    targetPlatform = 'windows';
                    break;
                default:
                    colorLog(`错误: 不支持的平台 ${platform}`, 'red');
                    process.exit(1);
            }

            colorLog(`在 ${platformName} 上启动项目...`, 'green');
            if (platform === 'macos') {
                console.log(`Debug: GAME_DIR=${gameDir}`);
            }
            execSync(`flutter run -d ${targetPlatform} --dart-define=SAKI_GAME_PATH="${gameDir}"`, { stdio: 'inherit' });
        }

    } catch (error) {
        colorLog(`启动失败: ${error.message}`, 'red');
        process.exit(1);
    } finally {
        rl.close();
    }
}

// 处理游戏选择逻辑
async function handleGameSelection() {
    if (fs.existsSync(DEFAULT_GAME_FILE)) {
        const currentGame = assetUtils.readDefaultGame(PROJECT_ROOT);
        
        if (currentGame) {
            colorLog(`当前默认游戏: ${currentGame}`, 'blue');
            console.log();
            colorLog('请选择操作:', 'yellow');
            colorLog('  1. 继续使用当前游戏', 'blue');
            colorLog('  2. 选择其他游戏', 'blue');
            colorLog('  3. 创建新游戏项目', 'blue');
            console.log();
            
            const choice = await askQuestion('请选择 (1-3, 默认为1): ');
            
            switch (choice.trim()) {
                case '2':
                    const selectGame = require('./scripts/select-game.js');
                    await selectGame.selectGame();
                    break;
                case '3':
                    const createProject = require('./scripts/create-new-project.js');
                    await createProject.createNewProject();
                    break;
                default:
                    // 默认继续使用当前游戏
                    break;
            }
        } else {
            colorLog('default_game.txt 文件为空...', 'yellow');
            console.log();
            await promptForGameAction();
        }
    } else {
        colorLog('未找到默认游戏配置...', 'yellow');
        console.log();
        await promptForGameAction();
    }
}

// 提示用户选择游戏操作
async function promptForGameAction() {
    colorLog('请选择操作:', 'yellow');
    colorLog('  1. 选择现有游戏项目', 'blue');
    colorLog('  2. 创建新游戏项目', 'blue');
    console.log();
    
    const choice = await askQuestion('请选择 (1-2): ');
    
    if (choice.trim() === '2') {
        const createProject = require('./scripts/create-new-project.js');
        await createProject.createNewProject();
    } else {
        const selectGame = require('./scripts/select-game.js');
        await selectGame.selectGame();
    }
}

// 启动主程序
if (require.main === module) {
    main().catch(error => {
        colorLog(`启动失败: ${error.message}`, 'red');
        process.exit(1);
    });
}

module.exports = { main, colorLog, colors };