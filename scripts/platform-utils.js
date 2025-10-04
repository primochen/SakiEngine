/**
 * 平台检测工具模块
 * 支持 Windows、macOS、Linux 全平台
 */

const os = require('os');
const { execSync } = require('child_process');

/**
 * 检测当前操作系统
 * @returns {string} 平台名称: 'windows', 'macos', 'linux', 'unknown'
 */
function detectPlatform() {
    const platform = os.platform();
    
    switch (platform) {
        case 'darwin':
            return 'macos';
        case 'linux':
            return 'linux';
        case 'win32':
            return 'windows';
        default:
            return 'unknown';
    }
}

/**
 * 检查平台是否支持开发
 * @param {string} platform 平台名称
 * @returns {boolean} 是否支持
 */
function checkPlatformSupport(platform) {
    try {
        // 检查 Flutter 是否已安装
        execSync('flutter --version', { stdio: 'pipe' });
        return ['windows', 'macos', 'linux'].includes(platform);
    } catch (error) {
        return false;
    }
}

/**
 * 获取平台显示名称
 * @param {string} platform 平台名称
 * @returns {string} 显示名称
 */
function getPlatformDisplayName(platform) {
    switch (platform) {
        case 'macos':
            return 'macOS';
        case 'linux':
            return 'Linux';
        case 'windows':
            return 'Windows';
        default:
            return 'Unknown';
    }
}

/**
 * 获取平台特定的路径分隔符
 * @returns {string} 路径分隔符
 */
function getPathSeparator() {
    return require('path').sep;
}

/**
 * 获取平台特定的行结束符
 * @returns {string} 行结束符
 */
function getLineEnding() {
    return os.EOL;
}

/**
 * 检查是否为 Windows 平台
 * @returns {boolean}
 */
function isWindows() {
    return os.platform() === 'win32';
}

/**
 * 检查是否为 macOS 平台
 * @returns {boolean}
 */
function isMacOS() {
    return os.platform() === 'darwin';
}

/**
 * 检查是否为 Linux 平台
 * @returns {boolean}
 */
function isLinux() {
    return os.platform() === 'linux';
}

module.exports = {
    detectPlatform,
    checkPlatformSupport,
    getPlatformDisplayName,
    getPathSeparator,
    getLineEnding,
    isWindows,
    isMacOS,
    isLinux
};