/**
 * SakiEngine 游戏项目选择脚本
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
 * 游戏选择主函数
 */
async function selectGame() {
    // 获取项目根目录
    const projectRoot = path.dirname(__dirname);
    const gameBaseDir = path.join(projectRoot, 'Game');
    const defaultGameFile = path.join(projectRoot, 'default_game.txt');
    
    colorLog('=== SakiEngine 游戏项目选择器 ===', 'blue');
    console.log();
    
    // 检查Game目录是否存在
    if (!fs.existsSync(gameBaseDir)) {
        colorLog('错误: Game目录不存在！', 'red');
        process.exit(1);
    }
    
    // 获取Game目录下的所有子目录
    colorLog('正在扫描可用的游戏项目...', 'yellow');
    const gameDirs = assetUtils.getGameDirectories(projectRoot);
    
    // 检查是否有可用的游戏项目
    if (gameDirs.length === 0) {
        colorLog('错误: Game目录下没有找到任何游戏项目！', 'red');
        process.exit(1);
    }
    
    // 显示当前默认游戏（如果存在）
    const currentGame = assetUtils.readDefaultGame(projectRoot);
    if (currentGame) {
        colorLog(`当前默认游戏: ${currentGame}`, 'blue');
        console.log();
    }
    
    // 显示可用的游戏项目列表
    colorLog('可用的游戏项目:', 'yellow');
    gameDirs.forEach((gameDir, index) => {
        colorLog(`  ${index + 1}. ${gameDir}`, 'blue');
    });
    console.log();
    
    // 用户选择
    const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout
    });
    
    const choice = await new Promise((resolve) => {
        const askChoice = () => {
            rl.question(`请选择要设置为默认的游戏项目 (1-${gameDirs.length}): `, (answer) => {
                const num = parseInt(answer.trim());
                
                if (isNaN(num) || num < 1 || num > gameDirs.length) {
                    colorLog(`无效的选择，请输入 1-${gameDirs.length} 之间的数字。`, 'red');
                    askChoice();
                } else {
                    resolve(num);
                }
            });
        };
        askChoice();
    });
    
    rl.close();
    
    const selectedGame = gameDirs[choice - 1];
    
    // 写入default_game.txt文件
    assetUtils.writeDefaultGame(projectRoot, selectedGame);
    
    console.log();
    colorLog(`✓ 已将 '${selectedGame}' 设置为默认游戏项目`, 'green');
    colorLog(`配置已保存到: ${defaultGameFile}`, 'blue');
    console.log();
    colorLog('提示: 下次运行项目时将自动使用此游戏项目', 'yellow');
    
    return selectedGame;
}

/**
 * 交互式游戏选择（用于其他脚本调用）
 */
async function selectGameInteractive() {
    return await selectGame();
}

/**
 * 获取游戏列表（不进行选择）
 */
function getAvailableGames() {
    const projectRoot = path.dirname(__dirname);
    return assetUtils.getGameDirectories(projectRoot);
}

/**
 * 验证游戏是否存在
 */
function validateGameExists(gameName) {
    const projectRoot = path.dirname(__dirname);
    return assetUtils.validateGameDir(projectRoot, gameName) !== null;
}

/**
 * 设置默认游戏（不进行交互）
 */
function setDefaultGame(gameName) {
    const projectRoot = path.dirname(__dirname);
    
    if (!validateGameExists(gameName)) {
        return false;
    }
    
    assetUtils.writeDefaultGame(projectRoot, gameName);
    return true;
}

// 如果直接运行此脚本
if (require.main === module) {
    selectGame().catch(error => {
        colorLog(`选择游戏失败: ${error.message}`, 'red');
        process.exit(1);
    });
}

module.exports = {
    selectGame,
    selectGameInteractive,
    getAvailableGames,
    validateGameExists,
    setDefaultGame,
    colorLog
};