/**
 * pubspec.yaml 动态更新工具
 * 支持 Windows、macOS、Linux 全平台
 */

const fs = require('fs');
const path = require('path');

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
 * 递归获取目录下的所有子目录
 * @param {string} dir 要扫描的目录
 * @param {string} baseDir 基础目录（用于计算相对路径）
 * @returns {string[]} 所有子目录的相对路径列表
 */
function getAllDirectories(dir, baseDir) {
    const directories = [];
    
    function scanDirectory(currentDir) {
        try {
            const entries = fs.readdirSync(currentDir, { withFileTypes: true });
            
            for (const entry of entries) {
                if (entry.isDirectory()) {
                    const fullPath = path.join(currentDir, entry.name);
                    const relativePath = path.relative(baseDir, fullPath).replace(/\\/g, '/');
                    
                    // 添加相对路径（相对于Engine目录）
                    directories.push('assets/' + relativePath);
                    
                    // 递归扫描子目录
                    scanDirectory(fullPath);
                }
            }
        } catch (error) {
            // 忽略无法访问的目录
        }
    }
    
    scanDirectory(dir);
    return directories.sort(); // 排序以保持一致性
}

/**
 * 动态更新 pubspec.yaml 的 assets 部分
 * @param {string} engineDir Engine目录
 * @returns {boolean} 是否成功
 */
function updatePubspecAssets(engineDir) {
    const pubspecPath = path.join(engineDir, 'pubspec.yaml');
    
    if (!fs.existsSync(pubspecPath)) {
        colorLog('错误: 在 pubspec.yaml 中未找到文件', 'red');
        return false;
    }
    
    colorLog('正在动态生成 pubspec.yaml 资源列表...', 'yellow');
    
    try {
        let content = fs.readFileSync(pubspecPath, 'utf8');
        const lines = content.split(/\r?\n/);
        
        // 找到 assets: 的起始行 (必须是缩进2个空格的)
        let assetsStartIndex = -1;
        for (let i = 0; i < lines.length; i++) {
            if (/^  assets:/.test(lines[i])) {
                assetsStartIndex = i;
                break;
            }
        }
        
        if (assetsStartIndex === -1) {
            colorLog('错误: 在 pubspec.yaml 中未找到 "  assets:" 部分。请确保该部分存在且有两个空格的缩进。', 'red');
            return false;
        }
        
        // 找到 assets 块的结束位置
        let assetsEndIndex = assetsStartIndex;
        for (let i = assetsStartIndex + 1; i < lines.length; i++) {
            const line = lines[i];
            // 如果是 asset 项目或空行，继续
            if (/^    - assets\//.test(line) || /^    - assets\\/.test(line) || /^\s*$/.test(line)) {
                assetsEndIndex = i;
            } else if (/^  \w/.test(line)) {
                // 遇到下一个顶级配置项，停止
                break;
            } else if (line.trim() === '') {
                // 空行也可能是结束
                continue;
            } else {
                break;
            }
        }
        
        // 生成新的 assets 列表
        const newAssets = [];
        newAssets.push('  assets:');
        newAssets.push('    - assets/default_game.txt');
        
        // 添加引擎默认字体目录
        const fontsDir = path.join(engineDir, 'assets', 'fonts');
        if (fs.existsSync(fontsDir)) {
            newAssets.push('    - assets/fonts/');
        }
        
        // 动态扫描 assets 目录 - 递归扫描所有子目录
        const assetsDir = path.join(engineDir, 'assets');
        if (fs.existsSync(assetsDir)) {
            const allDirs = getAllDirectories(assetsDir, assetsDir);
            for (const dirPath of allDirs) {
                // 排除 shaders 和 fonts 目录（fonts 已经单独添加）
                if (!dirPath.includes('/shaders') && !dirPath.includes('/fonts')) {
                    newAssets.push(`    - ${dirPath}/`);
                }
            }
        }
        
        // 重构文件内容
        const beforeAssets = lines.slice(0, assetsStartIndex);
        const afterAssets = lines.slice(assetsEndIndex + 1);
        
        const newContent = [
            ...beforeAssets,
            ...newAssets,
            ...afterAssets
        ].join('\n');
        
        fs.writeFileSync(pubspecPath, newContent);
        colorLog('pubspec.yaml 更新成功。', 'green');
        return true;
        
    } catch (error) {
        colorLog(`更新 pubspec.yaml 失败: ${error.message}`, 'red');
        return false;
    }
}

/**
 * 动态更新 pubspec.yaml 的 fonts 部分
 * @param {string} engineDir Engine目录
 * @param {string} gameDir 游戏目录
 * @returns {boolean} 是否成功
 */
function updatePubspecFonts(engineDir, gameDir) {
    const pubspecPath = path.join(engineDir, 'pubspec.yaml');
    
    if (!fs.existsSync(pubspecPath)) {
        colorLog('错误: 找不到 pubspec.yaml 文件', 'red');
        return false;
    }
    
    colorLog('正在动态生成 pubspec.yaml 字体列表...', 'yellow');
    
    try {
        let content = fs.readFileSync(pubspecPath, 'utf8');
        const lines = content.split(/\r?\n/);
        
        // 找到 fonts: 的起始行
        let fontsStartIndex = -1;
        for (let i = 0; i < lines.length; i++) {
            if (/^  fonts:/.test(lines[i])) {
                fontsStartIndex = i;
                break;
            }
        }
        
        if (fontsStartIndex === -1) {
            colorLog('错误: 在 pubspec.yaml 中未找到 "  fonts:" 部分。', 'red');
            return false;
        }
        
        // 找到 fonts 块的结束位置
        let fontsEndIndex = fontsStartIndex;
        for (let i = fontsStartIndex + 1; i < lines.length; i++) {
            const line = lines[i];
            // 检查是否仍在 fonts 块内
            if (/^    - family:/.test(line) ||
                /^      fonts:/.test(line) ||
                /^        - asset:/.test(line) ||
                /^          weight:/.test(line) ||
                /^          style:/.test(line) ||
                /^\s*$/.test(line)) {
                fontsEndIndex = i;
            } else if (/^  \w/.test(line)) {
                // 遇到下一个顶级配置项，停止
                break;
            } else {
                break;
            }
        }
        
        // 生成新的 fonts 列表
        const newFonts = [];
        newFonts.push('  fonts:');
        newFonts.push('    - family: SourceHanSansCN');
        newFonts.push('      fonts:');
        newFonts.push('        - asset: assets/fonts/SourceHanSansCN-Bold.ttf');
        newFonts.push('          weight: 700');
        
        // 动态添加游戏项目的字体
        const gameFontsDir = path.join(gameDir, 'Assets', 'fonts');
        if (fs.existsSync(gameFontsDir)) {
            const fontFiles = fs.readdirSync(gameFontsDir).filter(file => 
                /\.(ttf|otf)$/i.test(file)
            );
            
            for (const fontFile of fontFiles) {
                const fontName = path.parse(fontFile).name;
                const relativePath = `assets/Assets/fonts/${fontFile}`;
                
                newFonts.push(`    - family: ${fontName}`);
                newFonts.push('      fonts:');
                newFonts.push(`        - asset: ${relativePath}`);
            }
        }
        
        // 重构文件内容
        const beforeFonts = lines.slice(0, fontsStartIndex);
        const afterFonts = lines.slice(fontsEndIndex + 1);
        
        const newContent = [
            ...beforeFonts,
            ...newFonts,
            ...afterFonts
        ].join('\n');
        
        fs.writeFileSync(pubspecPath, newContent);
        colorLog('pubspec.yaml 字体配置更新成功。', 'green');
        return true;
        
    } catch (error) {
        colorLog(`更新字体配置失败: ${error.message}`, 'red');
        return false;
    }
}

/**
 * 验证 pubspec.yaml 文件格式
 * @param {string} engineDir Engine目录
 * @returns {boolean} 是否格式正确
 */
function validatePubspecFormat(engineDir) {
    const pubspecPath = path.join(engineDir, 'pubspec.yaml');
    
    if (!fs.existsSync(pubspecPath)) {
        colorLog('错误: pubspec.yaml 文件不存在', 'red');
        return false;
    }
    
    try {
        const content = fs.readFileSync(pubspecPath, 'utf8');
        
        // 简单验证是否包含必要的部分
        if (!content.includes('flutter:')) {
            colorLog('错误: pubspec.yaml 缺少 flutter: 部分', 'red');
            return false;
        }
        
        if (!content.includes('  assets:')) {
            colorLog('警告: pubspec.yaml 缺少 assets: 部分', 'yellow');
        }
        
        if (!content.includes('  fonts:')) {
            colorLog('警告: pubspec.yaml 缺少 fonts: 部分', 'yellow');
        }
        
        return true;
        
    } catch (error) {
        colorLog(`验证 pubspec.yaml 失败: ${error.message}`, 'red');
        return false;
    }
}

/**
 * 备份 pubspec.yaml 文件
 * @param {string} engineDir Engine目录
 * @returns {boolean} 是否成功备份
 */
function backupPubspec(engineDir) {
    const pubspecPath = path.join(engineDir, 'pubspec.yaml');
    const backupPath = path.join(engineDir, 'pubspec.yaml.backup');
    
    try {
        if (fs.existsSync(pubspecPath)) {
            fs.copyFileSync(pubspecPath, backupPath);
            colorLog('pubspec.yaml 备份完成', 'green');
            return true;
        }
        return false;
    } catch (error) {
        colorLog(`备份失败: ${error.message}`, 'red');
        return false;
    }
}

/**
 * 恢复 pubspec.yaml 文件备份
 * @param {string} engineDir Engine目录
 * @returns {boolean} 是否成功恢复
 */
function restorePubspec(engineDir) {
    const pubspecPath = path.join(engineDir, 'pubspec.yaml');
    const backupPath = path.join(engineDir, 'pubspec.yaml.backup');
    
    try {
        if (fs.existsSync(backupPath)) {
            fs.copyFileSync(backupPath, pubspecPath);
            colorLog('pubspec.yaml 备份恢复完成', 'green');
            return true;
        }
        return false;
    } catch (error) {
        colorLog(`恢复失败: ${error.message}`, 'red');
        return false;
    }
}

module.exports = {
    updatePubspecAssets,
    updatePubspecFonts,
    validatePubspecFormat,
    backupPubspec,
    restorePubspec,
    colorLog
};