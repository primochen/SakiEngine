import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sakiengine/src/config/asset_manager.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/game/game_manager.dart';
import 'package:sakiengine/src/utils/scaling_manager.dart';
import 'package:sakiengine/src/widgets/common/close_button.dart';

class DeveloperPanel extends StatefulWidget {
  final VoidCallback onClose;
  final GameManager gameManager;
  final Future<void> Function()? onReload;

  const DeveloperPanel({
    Key? key,
    required this.onClose,
    required this.gameManager,
    this.onReload,
  }) : super(key: key);

  @override
  State<DeveloperPanel> createState() => _DeveloperPanelState();
}

class _DeveloperPanelState extends State<DeveloperPanel>
    with TickerProviderStateMixin {
  bool _showScriptPreview = false;
  String _currentScriptContent = '';
  String _currentScriptPath = '';
  final TextEditingController _scriptController = TextEditingController();
  
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadCurrentScript();
    
    // 初始化动画
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scriptController.dispose();
    super.dispose();
  }

  Future<void> _handleClose() async {
    await _animationController.reverse();
    widget.onClose();
  }

  Future<void> _loadCurrentScript() async {
    try {
      // 获取当前脚本名称（从GameManager获取）
      final currentScriptName = _getCurrentScriptName();
      
      if (currentScriptName.isNotEmpty) {
        // 尝试直接加载当前脚本文件
        final gamePath = await _getGamePathFromAssetManager();
        if (gamePath != null) {
          final scriptPath = p.join(gamePath, 'GameScript', 'labels', '$currentScriptName.sks');
          final scriptFile = File(scriptPath);
          
          if (await scriptFile.exists()) {
            try {
              final content = await scriptFile.readAsString();
              _currentScriptContent = content;
              _currentScriptPath = scriptPath;
              _scriptController.text = content;
              
              if (kDebugMode) {
                print('开发者面板: 成功加载脚本 $scriptPath');
              }
            } catch (readError) {
              if (kDebugMode) {
                print('开发者面板: 读取脚本文件失败: $readError');
              }
              // 如果无法读取，提供备选方案
              _currentScriptContent = '''// 当前正在播放的脚本: $currentScriptName.sks
// 路径: $scriptPath
// 
// 无法直接读取脚本文件: $readError
// 
// 请使用"浏览脚本文件"功能手动选择文件进行编辑
''';
              _currentScriptPath = '';
              _scriptController.text = _currentScriptContent;
            }
          } else {
            _currentScriptContent = '''// 当前正在播放的脚本: $currentScriptName.sks
// 
// 脚本文件不存在: $scriptPath
// 请使用"浏览脚本文件"功能手动选择文件
''';
            _currentScriptPath = '';
            _scriptController.text = _currentScriptContent;
          }
        } else {
          _currentScriptContent = '''// 当前正在播放的脚本: $currentScriptName.sks
// 
// 无法获取游戏路径，请使用"浏览脚本文件"功能
''';
          _currentScriptPath = '';
          _scriptController.text = _currentScriptContent;
        }
      } else {
        _currentScriptContent = '// 无法获取当前脚本名称，请使用"浏览脚本文件"功能';
        _currentScriptPath = '';
        _scriptController.text = _currentScriptContent;
      }
    } catch (e) {
      _currentScriptContent = '// 加载脚本失败: $e';
      _currentScriptPath = '';
      _scriptController.text = _currentScriptContent;
    }
    setState(() {});
  }

  String _getCurrentScriptName() {
    // 从GameManager获取当前正在加载的脚本文件名
    try {
      final currentScriptFile = widget.gameManager.currentScriptFile;
      if (kDebugMode) {
        print('开发者面板: 获取到当前脚本文件名: $currentScriptFile');
      }
      return currentScriptFile;
    } catch (e) {
      if (kDebugMode) {
        print('开发者面板: 获取当前脚本名称失败: $e');
      }
      return 'start'; // 默认脚本
    }
  }

  Future<void> _browseAndLoadScript() async {
    try {
      // 生成可能的脚本目录路径
      final possibleDirs = _generatePossibleScriptDirs();
      
      Directory? scriptDir;
      for (final dirPath in possibleDirs) {
        final dir = Directory(dirPath);
        if (await dir.exists()) {
          scriptDir = dir;
          break;
        }
      }
      
      if (scriptDir == null) {
        // 如果找不到脚本目录，显示错误信息
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('找不到脚本目录，请检查项目路径配置'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      
      // 列出所有.sks文件
      final sksFiles = await scriptDir
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.sks'))
          .cast<File>()
          .toList();
      
      if (sksFiles.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('在 ${scriptDir.path} 中未找到.sks脚本文件'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      
      // 显示文件选择对话框
      final selectedFile = await _showFileSelectionDialog(sksFiles);
      if (selectedFile != null) {
        await _loadScriptFromFile(selectedFile);
        
        // 展开脚本预览
        if (!_showScriptPreview) {
          setState(() {
            _showScriptPreview = true;
          });
        }
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('浏览文件失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
  
  List<String> _generatePossibleScriptDirs() {
    final currentDir = Directory.current.path;
    final homeDir = Platform.environment['HOME'] ?? '';
    
    return [
      // 环境变量指定的路径（避免容器路径）
      if (Platform.environment['SAKI_GAME_PATH'] != null && 
          !Platform.environment['SAKI_GAME_PATH']!.contains('Containers'))
        '${Platform.environment['SAKI_GAME_PATH']}/GameScript/labels',
      
      // 用户目录中的安全位置
      '$homeDir/Documents/SakiEngine/Game/GameScript/labels',
      '$homeDir/Documents/SoraNoUta/GameScript/labels',
      '$homeDir/Downloads/SakiEngine/Game/GameScript/labels',
      '$homeDir/Downloads/SoraNoUta/GameScript/labels',
      '$homeDir/Desktop/SakiEngine/Game/GameScript/labels',
      '$homeDir/Desktop/SoraNoUta/GameScript/labels',
      '$homeDir/SakiEngine/Game/GameScript/labels',
      '$homeDir/SoraNoUta/GameScript/labels',
      
      // 相对路径（如果不在容器内）
      if (!currentDir.contains('Containers')) ...[
        '$currentDir/../Game/SoraNoUta/GameScript/labels',
        '$currentDir/../../Game/SoraNoUta/GameScript/labels',
        '$currentDir/../Game/GameScript/labels',
        '$currentDir/Game/GameScript/labels',
        '$currentDir/assets/GameScript/labels',
        '$currentDir/../assets/GameScript/labels',
      ],
    ];
  }
  
  Future<File?> _showFileSelectionDialog(List<File> files) async {
    return await showDialog<File>(
      context: context,
      builder: (BuildContext context) {
        final config = SakiEngineConfig();
        final textScale = context.scaleFor(ComponentType.text);
        
        return AlertDialog(
          backgroundColor: config.themeColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(config.baseWindowBorder),
          ),
          title: Text(
            '选择脚本文件',
            style: config.reviewTitleTextStyle.copyWith(
              fontSize: config.reviewTitleTextStyle.fontSize! * textScale * 0.8,
              color: config.themeColors.primary,
            ),
          ),
          content: Container(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index];
                final fileName = file.path.split('/').last;
                
                return ListTile(
                  title: Text(
                    fileName,
                    style: config.dialogueTextStyle.copyWith(
                      fontSize: config.dialogueTextStyle.fontSize! * textScale * 0.6,
                      color: config.themeColors.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    file.path,
                    style: config.dialogueTextStyle.copyWith(
                      fontSize: config.dialogueTextStyle.fontSize! * textScale * 0.5,
                      color: config.themeColors.onSurface.withOpacity(0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => Navigator.of(context).pop(file),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                '取消',
                style: TextStyle(color: config.themeColors.primary),
              ),
            ),
          ],
        );
      },
    );
  }
  
  Future<void> _loadScriptFromFile(File file) async {
    try {
      final content = await file.readAsString();
      setState(() {
        _currentScriptContent = content;
        _currentScriptPath = file.path;
        _scriptController.text = content;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已加载: ${file.path.split('/').last}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载文件失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // 复制AssetManager中的游戏路径获取逻辑
  Future<String?> _getGamePathFromAssetManager() async {
    // 首先检查环境变量
    const fromDefine = String.fromEnvironment('SAKI_GAME_PATH', defaultValue: '');
    if (fromDefine.isNotEmpty) return fromDefine;
    
    final fromEnv = Platform.environment['SAKI_GAME_PATH'];
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    
    try {
      // 从assets读取default_game.txt
      final assetContent = await AssetManager().loadString('assets/default_game.txt');
      final defaultGame = assetContent.trim();
      
      if (defaultGame.isEmpty) {
        throw Exception('default_game.txt is empty');
      }
      
      final gamePath = p.join(Directory.current.path, 'Game', defaultGame);
      if (kDebugMode) {
        print("开发者面板: 从default_game.txt获取游戏路径: $gamePath");
      }
      
      return gamePath;
    } catch (e) {
      if (kDebugMode) {
        print('开发者面板: 无法获取游戏路径: $e');
      }
      return null;
    }
  }

  Future<void> _saveAndReloadScript() async {
    if (_currentScriptPath.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('请先使用"浏览脚本文件"功能选择要编辑的脚本文件，或点击"脚本预览"加载当前脚本'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    try {
      bool saveSuccess = false;
      String errorMessage = '';

      // 方法1: 直接文件写入（如果沙箱被禁用）
      try {
        final file = File(_currentScriptPath);
        await file.writeAsString(_scriptController.text);
        saveSuccess = true;
        
        if (kDebugMode) {
          print('开发者面板: 直接文件写入成功 $_currentScriptPath');
        }
      } catch (directWriteError) {
        if (kDebugMode) {
          print('开发者面板: 直接文件写入失败: $directWriteError');
        }
        
        // 方法2: 使用命令行 echo 写入（绕过沙箱限制）
        try {
          final content = _scriptController.text;
          // 转义特殊字符
          final escapedContent = content
              .replaceAll('\\', '\\\\')
              .replaceAll('\$', '\\\$')
              .replaceAll('"', '\\"')
              .replaceAll('\n', '\\n');
              
          final result = await Process.run('sh', [
            '-c',
            'echo -e "$escapedContent" > "${_currentScriptPath}"'
          ]);
          
          if (result.exitCode == 0) {
            saveSuccess = true;
            if (kDebugMode) {
              print('开发者面板: 命令行写入成功 $_currentScriptPath');
            }
          } else {
            errorMessage = '命令行写入失败: ${result.stderr}';
          }
        } catch (commandError) {
          // 方法3: 使用 cp 命令
          try {
            final content = _scriptController.text;
            final tempFile = File('${Directory.systemTemp.path}/saki_temp_script.sks');
            await tempFile.writeAsString(content);
            
            final result = await Process.run('cp', [tempFile.path, _currentScriptPath]);
            await tempFile.delete();
            
            if (result.exitCode == 0) {
              saveSuccess = true;
              if (kDebugMode) {
                print('开发者面板: cp命令写入成功 $_currentScriptPath');
              }
            } else {
              errorMessage = 'cp命令失败: ${result.stderr}';
            }
          } catch (copyError) {
            errorMessage = '所有保存方法均失败: 直接写入($directWriteError), 命令行($commandError), cp($copyError)';
          }
        }
      }
      
      if (saveSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('脚本已保存: ${_currentScriptPath.split('/').last}'),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
        }
        
        // 保存成功后自动重载
        if (widget.onReload != null) {
          try {
            await widget.onReload!();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('重载完成'),
                  duration: const Duration(seconds: 2),
                  backgroundColor: Colors.blue,
                ),
              );
            }
          } catch (reloadError) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('重载失败: $reloadError'),
                  duration: const Duration(seconds: 3),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
        }
      } else {
        throw Exception(errorMessage);
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      if (kDebugMode) {
        print('开发者面板: 保存脚本失败: $e');
      }
    }
  }

  Future<bool> _showSaveConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        final config = SakiEngineConfig();
        final textScale = context.scaleFor(ComponentType.text);
        
        return AlertDialog(
          backgroundColor: config.themeColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(config.baseWindowBorder),
          ),
          title: Text(
            '确认保存',
            style: config.reviewTitleTextStyle.copyWith(
              fontSize: config.reviewTitleTextStyle.fontSize! * textScale * 0.8,
              color: config.themeColors.primary,
            ),
          ),
          content: Text(
            '确定要覆盖保存脚本文件吗？\n这将直接修改源文件，更改会立即生效。',
            style: config.dialogueTextStyle.copyWith(
              fontSize: config.dialogueTextStyle.fontSize! * textScale * 0.7,
              color: config.themeColors.onSurface,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                '取消',
                style: TextStyle(color: config.themeColors.primary.withOpacity(0.7)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                '保存',
                style: TextStyle(color: config.themeColors.primary),
              ),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final config = SakiEngineConfig();
    final uiScale = context.scaleFor(ComponentType.ui);
    final textScale = context.scaleFor(ComponentType.text);
    final panelWidth = screenSize.width / 6;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Positioned(
          right: -panelWidth * _slideAnimation.value,
          top: 0,
          bottom: 0,
          width: panelWidth,
          child: Shortcuts(
            shortcuts: <LogicalKeySet, Intent>{
              LogicalKeySet(LogicalKeyboardKey.escape): const _CloseIntent(),
            },
            child: Actions(
              actions: <Type, Action<Intent>>{
                _CloseIntent: _CloseAction(_handleClose),
              },
              child: Focus(
                autofocus: true,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20 * uiScale,
                          offset: Offset(-8 * uiScale, 0),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(config.baseWindowBorder),
                        bottomLeft: Radius.circular(config.baseWindowBorder),
                      ),
                      child: Stack(
                        children: [
                          // 底层：纯色背景
                          Container(
                            width: double.infinity,
                            height: double.infinity,
                            color: config.themeColors.background,
                          ),
                          // 中层：背景图片
                          if (config.baseWindowBackground != null && config.baseWindowBackground!.isNotEmpty)
                            Positioned.fill(
                              child: Opacity(
                                opacity: config.baseWindowBackgroundAlpha * 0.5,
                                child: ColorFiltered(
                                  colorFilter: ColorFilter.mode(
                                    Colors.transparent,
                                    config.baseWindowBackgroundBlendMode,
                                  ),
                                  child: Container(color: Colors.blue), // 临时替换 SmartAssetImage
                                ),
                              ),
                            ),
                          // 上层：半透明面板
                          Container(
                            color: config.themeColors.background.withOpacity(0.85),
                            child: Column(
                              children: [
                                _buildHeader(uiScale, textScale, config),
                                Expanded(
                                  child: _buildContent(uiScale, textScale, config),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(double uiScale, double textScale, SakiEngineConfig config) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 12 * uiScale,
        vertical: 12 * uiScale,
      ),
      decoration: BoxDecoration(
        color: config.themeColors.primary.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: config.themeColors.primary.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '开发者面板',
              style: config.reviewTitleTextStyle.copyWith(
                fontSize: (config.reviewTitleTextStyle.fontSize! - 2) * textScale,
                color: config.themeColors.primary,
                letterSpacing: 1.0,
              ),
            ),
          ),
          CommonCloseButton(
            scale: uiScale * 0.8,
            onClose: _handleClose,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(double uiScale, double textScale, SakiEngineConfig config) {
    return Padding(
      padding: EdgeInsets.all(12 * uiScale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 功能按钮
          _buildStyledButton(
            text: _showScriptPreview ? '隐藏脚本预览' : '脚本预览',
            onPressed: () {
              setState(() {
                _showScriptPreview = !_showScriptPreview;
              });
              if (_showScriptPreview) {
                _loadCurrentScript();
              }
            },
            config: config,
            uiScale: uiScale,
            textScale: textScale,
          ),
          
          SizedBox(height: 8 * uiScale),
          
          // 浏览文件按钮
          _buildStyledButton(
            text: '浏览脚本文件',
            onPressed: _browseAndLoadScript,
            config: config,
            uiScale: uiScale,
            textScale: textScale,
          ),
          
          // 脚本预览区域
          if (_showScriptPreview) ...[
            SizedBox(height: 12 * uiScale),
            Expanded(
              child: _buildScriptPreview(uiScale, textScale, config),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStyledButton({
    required String text,
    required VoidCallback onPressed,
    required SakiEngineConfig config,
    required double uiScale,
    required double textScale,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(config.baseWindowBorder),
        gradient: LinearGradient(
          colors: [
            config.themeColors.primary.withOpacity(0.8),
            config.themeColors.primary.withOpacity(0.6),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: config.themeColors.primary.withOpacity(0.3),
            blurRadius: 4 * uiScale,
            offset: Offset(0, 2 * uiScale),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(config.baseWindowBorder),
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: 8 * uiScale,
              horizontal: 16 * uiScale,
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: config.reviewTitleTextStyle.copyWith(
                fontSize: (config.reviewTitleTextStyle.fontSize! - 4) * textScale,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScriptPreview(double uiScale, double textScale, SakiEngineConfig config) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 脚本路径显示
        Container(
          padding: EdgeInsets.all(8 * uiScale),
          decoration: BoxDecoration(
            color: config.themeColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(config.baseWindowBorder),
            border: Border.all(
              color: config.themeColors.primary.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Text(
            _currentScriptPath.isNotEmpty 
              ? _currentScriptPath.split('/').last
              : '无脚本文件',
            style: config.reviewTitleTextStyle.copyWith(
              fontSize: (config.reviewTitleTextStyle.fontSize! - 6) * textScale,
              color: config.themeColors.primary.withOpacity(0.8),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        
        SizedBox(height: 8 * uiScale),
        
        // 脚本内容编辑器
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: config.themeColors.background.withOpacity(0.3),
              borderRadius: BorderRadius.circular(config.baseWindowBorder),
              border: Border.all(
                color: config.themeColors.primary.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: TextField(
              controller: _scriptController,
              maxLines: null,
              expands: true,
              style: TextStyle(
                color: config.themeColors.onSurface,
                fontSize: 10 * textScale,
                fontFamily: 'monospace',
                height: 1.4,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(12 * uiScale),
                hintText: '脚本内容...',
                hintStyle: TextStyle(
                  color: config.themeColors.onSurface.withOpacity(0.5),
                ),
              ),
            ),
          ),
        ),
        
        SizedBox(height: 8 * uiScale),
        
        // 操作按钮
        _buildActionButton(
          text: '保存并重载',
          onPressed: _saveAndReloadScript,
          color: Colors.green,
          config: config,
          uiScale: uiScale,
          textScale: textScale,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String text,
    required VoidCallback onPressed,
    required Color color,
    required SakiEngineConfig config,
    required double uiScale,
    required double textScale,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(config.baseWindowBorder),
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.8),
            color.withOpacity(0.6),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 4 * uiScale,
            offset: Offset(0, 2 * uiScale),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(config.baseWindowBorder),
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: 6 * uiScale,
              horizontal: 12 * uiScale,
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: config.reviewTitleTextStyle.copyWith(
                fontSize: (config.reviewTitleTextStyle.fontSize! - 6) * textScale,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CloseIntent extends Intent {
  const _CloseIntent();
}

class _CloseAction extends Action<_CloseIntent> {
  final VoidCallback onClose;

  _CloseAction(this.onClose);

  @override
  Object? invoke(_CloseIntent intent) {
    onClose();
    return null;
  }
}