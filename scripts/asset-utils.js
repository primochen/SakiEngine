/**
 * 资源处理工具模块
 * 支持 Windows、macOS、Linux 全平台
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const platformUtils = require('./platform-utils.js');

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
 * 读取默认游戏名称
 * @param {string} projectRoot 项目根目录
 * @returns {string|null} 游戏名称
 */
function readDefaultGame(projectRoot) {
    const defaultGameFile = path.join(projectRoot, 'default_game.txt');
    
    if (fs.existsSync(defaultGameFile)) {
        try {
            const content = fs.readFileSync(defaultGameFile, 'utf8').trim();
            return content || null;
        } catch (error) {
            return null;
        }
    }
    
    return null;
}

/**
 * 验证游戏目录是否存在
 * @param {string} projectRoot 项目根目录
 * @param {string} gameName 游戏名称
 * @returns {string|null} 游戏目录路径，如果不存在返回null
 */
function validateGameDir(projectRoot, gameName) {
    const gameDir = path.join(projectRoot, 'Game', gameName);
    
    if (fs.existsSync(gameDir) && fs.statSync(gameDir).isDirectory()) {
        return gameDir;
    }
    
    return null;
}

/**
 * 复制游戏资源（跨平台兼容）
 * @param {string} engineDir Engine目录
 * @param {string} gameDir 游戏目录
 * @param {string} projectRoot 项目根目录
 */
function linkGameAssets(engineDir, gameDir, projectRoot) {
    colorLog('正在清理旧的资源...', 'yellow');
    
    // 删除 Engine/assets 目录下的 Assets 和 GameScript 目录
    const assetsDir = path.join(engineDir, 'assets');
    const assetsAssetsDir = path.join(assetsDir, 'Assets');
    const assetsGameScriptDir = path.join(assetsDir, 'GameScript');
    
    if (fs.existsSync(assetsAssetsDir)) {
        fs.rmSync(assetsAssetsDir, { recursive: true, force: true });
    }
    
    if (fs.existsSync(assetsGameScriptDir)) {
        fs.rmSync(assetsGameScriptDir, { recursive: true, force: true });
    }
    
    // 确保顶级 assets 目录存在
    if (!fs.existsSync(assetsDir)) {
        fs.mkdirSync(assetsDir, { recursive: true });
    }
    
    colorLog('正在复制游戏资源和脚本...', 'yellow');
    
    // 复制 Assets 目录
    const gameAssetsDir = path.join(gameDir, 'Assets');
    if (fs.existsSync(gameAssetsDir)) {
        copyDirectory(gameAssetsDir, assetsAssetsDir);
    }
    
    // 复制 GameScript 目录
    const gameScriptDir = path.join(gameDir, 'GameScript');
    if (fs.existsSync(gameScriptDir)) {
        copyDirectory(gameScriptDir, assetsGameScriptDir);
    }
    
    // 复制 default_game.txt 到 assets 目录
    colorLog('正在复制 default_game.txt 到 assets 目录...', 'yellow');
    const defaultGameFile = path.join(projectRoot, 'default_game.txt');
    if (fs.existsSync(defaultGameFile)) {
        fs.copyFileSync(defaultGameFile, path.join(assetsDir, 'default_game.txt'));
    }
    
    // 处理 icon.png 复制逻辑（优先使用游戏目录，回退到项目根目录）
    colorLog('正在处理应用图标...', 'yellow');
    const gameIconPath = path.join(gameDir, 'icon.png');
    const projectIconPath = path.join(projectRoot, 'icon.png');
    const targetIconPath = path.join(assetsDir, 'icon.png');
    
    if (fs.existsSync(gameIconPath)) {
        colorLog('使用游戏目录中的 icon.png', 'green');
        fs.copyFileSync(gameIconPath, targetIconPath);
    } else if (fs.existsSync(projectIconPath)) {
        colorLog('游戏目录未找到 icon.png，使用项目根目录的图标', 'yellow');
        fs.copyFileSync(projectIconPath, targetIconPath);
    } else {
        colorLog('警告: 未找到 icon.png 文件', 'red');
    }
    
    colorLog('资源处理完成。', 'green');
}

/**
 * 递归复制目录
 * @param {string} src 源目录
 * @param {string} dest 目标目录
 */
function copyDirectory(src, dest) {
    if (!fs.existsSync(dest)) {
        fs.mkdirSync(dest, { recursive: true });
    }
    
    const entries = fs.readdirSync(src, { withFileTypes: true });
    
    for (const entry of entries) {
        const srcPath = path.join(src, entry.name);
        const destPath = path.join(dest, entry.name);
        
        if (entry.isDirectory()) {
            copyDirectory(srcPath, destPath);
        } else {
            fs.copyFileSync(srcPath, destPath);
        }
    }
}

/**
 * 读取游戏配置
 * @param {string} gameDir 游戏目录
 * @returns {object|null} 配置对象 {appName, bundleId}
 */
function readGameConfig(gameDir) {
    const configFile = path.join(gameDir, 'game_config.txt');
    
    if (!fs.existsSync(configFile)) {
        return null;
    }
    
    try {
        const content = fs.readFileSync(configFile, 'utf8');
        const lines = content.split(/\r?\n/).filter(line => line.trim());
        
        if (lines.length >= 2) {
            return {
                appName: lines[0].trim(),
                bundleId: lines[1].trim()
            };
        }
    } catch (error) {
        console.error('读取游戏配置失败:', error.message);
    }
    
    return null;
}

/**
 * 设置应用名称和包名
 * @param {string} engineDir Engine目录
 * @param {string} appName 应用名称
 * @param {string} bundleId 包名
 * @returns {boolean} 是否成功
 */
function setAppIdentity(engineDir, appName, bundleId) {
    colorLog(`正在设置应用名称: ${appName}`, 'yellow');
    colorLog(`正在设置包名: ${bundleId}`, 'yellow');
    
    try {
        // 切换到 Engine 目录
        const originalCwd = process.cwd();
        process.chdir(engineDir);
        
        // 设置应用名称
        execSync(`dart run rename setAppName --targets android,ios,macos,linux,windows,web --value "${appName}"`, { stdio: 'pipe' });
        
        // 设置包名
        execSync(`dart run rename setBundleId --targets android,ios,macos --value "${bundleId}"`, { stdio: 'pipe' });
        
        // 手动修改 Linux 和 Windows 的包名
        const linuxCMakeFile = path.join(engineDir, 'linux', 'CMakeLists.txt');
        if (fs.existsSync(linuxCMakeFile)) {
            let content = fs.readFileSync(linuxCMakeFile, 'utf8');
            content = content.replace(/set\(APPLICATION_ID ".*"\)/, `set(APPLICATION_ID "${bundleId}")`);
            fs.writeFileSync(linuxCMakeFile, content);
        }
        
        const windowsRunnerFile = path.join(engineDir, 'windows', 'runner', 'Runner.rc');
        if (fs.existsSync(windowsRunnerFile)) {
            const companyName = bundleId.split('.')[0];
            let content = fs.readFileSync(windowsRunnerFile, 'utf8');
            content = content.replace(/VALUE "CompanyName", ".*"/, `VALUE "CompanyName", "${companyName}"`);
            fs.writeFileSync(windowsRunnerFile, content);
        }
        
        // 恢复原始工作目录
        process.chdir(originalCwd);
        
        return true;
    } catch (error) {
        console.error('设置应用身份信息失败:', error.message);
        
        // 确保恢复原始工作目录
        try {
            process.chdir(require('path').dirname(__filename));
        } catch (e) {
            // 忽略
        }
        
        return false;
    }
}

/**
 * 写入默认游戏名称
 * @param {string} projectRoot 项目根目录
 * @param {string} gameName 游戏名称
 */
function writeDefaultGame(projectRoot, gameName) {
    const defaultGameFile = path.join(projectRoot, 'default_game.txt');
    fs.writeFileSync(defaultGameFile, gameName + '\n');
}

/**
 * 获取游戏目录列表
 * @param {string} projectRoot 项目根目录
 * @returns {string[]} 游戏目录名称列表
 */
function getGameDirectories(projectRoot) {
    const gameBaseDir = path.join(projectRoot, 'Game');
    
    if (!fs.existsSync(gameBaseDir)) {
        return [];
    }
    
    try {
        const entries = fs.readdirSync(gameBaseDir, { withFileTypes: true });
        return entries
            .filter(entry => entry.isDirectory())
            .map(entry => entry.name)
            .sort();
    } catch (error) {
        return [];
    }
}

module.exports = {
    readDefaultGame,
    validateGameDir,
    linkGameAssets,
    readGameConfig,
    setAppIdentity,
    writeDefaultGame,
    getGameDirectories,
    copyDirectory,
    colorLog
};