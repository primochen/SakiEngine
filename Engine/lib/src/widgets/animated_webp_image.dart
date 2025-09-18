import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:path/path.dart' as p;
import 'package:sakiengine/src/utils/webp_preload_cache.dart';

/// WebP动图播放组件
/// 支持WebP动画的播放和控制
class AnimatedWebPImage extends StatefulWidget {
  final String assetPath;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final Widget? errorWidget;
  final bool autoPlay;
  final bool loop;
  final Duration? frameDuration;
  final VoidCallback? onAnimationComplete; // 新增：动画完成回调

  const AnimatedWebPImage.asset(
    this.assetPath, {
    super.key,
    this.fit,
    this.width,
    this.height,
    this.errorWidget,
    this.autoPlay = true,
    this.loop = true,
    this.frameDuration,
    this.onAnimationComplete, // 新增
  });

  @override
  State<AnimatedWebPImage> createState() => _AnimatedWebPImageState();
}

class _AnimatedWebPImageState extends State<AnimatedWebPImage>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  List<ImageInfo> _frames = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWebPFrames();
  }

  @override
  void dispose() {
    _animationController.dispose();
    // 不清理图像资源，因为它们来自全局预加载缓存
    // 缓存的图像资源由WebPPreloadCache统一管理生命周期
    super.dispose();
  }

  /// 获取游戏路径，从dart-define或环境变量获取
  String get _debugRoot {
    const fromDefine = String.fromEnvironment('SAKI_GAME_PATH', defaultValue: '');
    if (fromDefine.isNotEmpty) return fromDefine;
    
    final fromEnv = Platform.environment['SAKI_GAME_PATH'];
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    
    return '';
  }

  /// 获取游戏路径，优先使用环境变量，如果没有则从assets读取default_game.txt
  Future<String> _getGamePath() async {
    // 如果环境变量已设置，直接使用
    if (_debugRoot.isNotEmpty) {
      return _debugRoot;
    }
    
    try {
      // 从assets读取default_game.txt
      final assetContent = await rootBundle.loadString('assets/default_game.txt');
      final defaultGame = assetContent.trim();
      
      if (defaultGame.isEmpty) {
        throw Exception('default_game.txt is empty');
      }
      
      final gamePath = p.join(Directory.current.path, 'Game', defaultGame);
      return gamePath;
    } catch (e) {
      return '';
    }
  }

  /// 加载WebP字节数据，支持外部文件系统
  Future<Uint8List?> _loadWebPBytes() async {
    try {
      // 在debug模式下，优先从外部文件系统加载
      if (kDebugMode) {
        final gamePath = await _getGamePath();
        if (gamePath.isNotEmpty) {
          final relativePath = widget.assetPath.startsWith('assets/')
              ? widget.assetPath.substring('assets/'.length)
              : widget.assetPath;
          final fileSystemPath = p.normalize(p.join(gamePath, relativePath));
          final file = File(fileSystemPath);
          
          if (await file.exists()) {
            //print('[AnimatedWebPImage] 从外部文件加载WebP: $fileSystemPath');
            return await file.readAsBytes();
          }
        }
        // 如果外部文件不存在，回退到assets加载
        //print('[AnimatedWebPImage] 外部文件不存在，回退到assets: ${widget.assetPath}');
      }
      
      // 从assets加载
      final data = await rootBundle.load(widget.assetPath);
      return data.buffer.asUint8List();
    } catch (e) {
      //print('[AnimatedWebPImage] 加载WebP字节失败: $e');
      return null;
    }
  }

  Future<void> _loadWebPFrames() async {
    try {
      // 从资源路径提取资源名称
      String assetName = widget.assetPath;
      if (assetName.startsWith('assets/')) {
        assetName = p.basenameWithoutExtension(assetName);
      } else if (assetName.contains('/')) {
        assetName = p.basename(assetName);
        if (assetName.contains('.')) {
          assetName = p.basenameWithoutExtension(assetName);
        }
      }
      
      // 首先尝试从预加载缓存获取
      final cache = WebPPreloadCache();
      if (cache.isCached(assetName)) {
        final cachedFrames = cache.getCachedFrames(assetName)!;
        final cachedDuration = cache.getCachedDuration(assetName)!;
        
        // 将ui.Image包装为ImageInfo
        _frames = cachedFrames.map((frame) => ImageInfo(image: frame)).toList();
        
        // 创建动画控制器
        if (_frames.length > 1) {
          _animationController = AnimationController(
            duration: widget.frameDuration ?? cachedDuration,
            vsync: this,
          );
          
          // 添加动画完成监听
          _animationController.addStatusListener((status) {
            if (status == AnimationStatus.completed && !widget.loop) {
              widget.onAnimationComplete?.call();
            }
          });
          
          if (widget.autoPlay) {
            if (widget.loop) {
              _animationController.repeat();
            } else {
              _animationController.forward();
            }
          }
        } else {
          _animationController = AnimationController(
            duration: const Duration(milliseconds: 100),
            vsync: this,
          );
        }
        
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }
      
      // 缓存未命中，使用原有逻辑加载
      
      // 使用新的字节加载函数
      final bytes = await _loadWebPBytes();
      if (bytes == null) {
        throw Exception('无法加载WebP字节数据');
      }
      
      // 使用Flutter的图像解码器
      final codec = await ui.instantiateImageCodec(bytes);
      final frameCount = codec.frameCount;
      
      if (frameCount > 1) {
        // 这是一个动图
        _frames.clear();
        Duration totalDuration = Duration.zero;
        
        for (int i = 0; i < frameCount; i++) {
          final frame = await codec.getNextFrame();
          _frames.add(ImageInfo(image: frame.image));
          totalDuration += frame.duration;
        }
        
        // 创建动画控制器
        _animationController = AnimationController(
          duration: widget.frameDuration ?? totalDuration,
          vsync: this,
        );
        
        // 添加动画完成监听
        _animationController.addStatusListener((status) {
          if (status == AnimationStatus.completed && !widget.loop) {
            widget.onAnimationComplete?.call();
          }
        });
        
        if (widget.autoPlay) {
          if (widget.loop) {
            _animationController.repeat();
          } else {
            _animationController.forward();
          }
        }
      } else {
        // 这是一个静态图片
        final frame = await codec.getNextFrame();
        _frames = [ImageInfo(image: frame.image)];
        
        _animationController = AnimationController(
          duration: const Duration(milliseconds: 100),
          vsync: this,
        );
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        //print('[AnimatedWebPImage] 加载WebP失败: $e');
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: Container(
          color: Colors.black, // 黑屏替代转圈加载
        ),
      );
    }

    if (_error != null) {
      return widget.errorWidget ?? 
        SizedBox(
          width: widget.width,
          height: widget.height,
          child: Center(
            child: Text(
              'WebP加载失败: $_error',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        );
    }

    if (_frames.isEmpty) {
      return widget.errorWidget ?? 
        SizedBox(
          width: widget.width,
          height: widget.height,
          child: const Center(
            child: Text(
              'WebP无帧数据',
              style: TextStyle(color: Colors.red),
            ),
          ),
        );
    }

    // 如果只有一帧，直接显示静态图片
    if (_frames.length == 1) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: RawImage(
          image: _frames[0].image,
          fit: widget.fit ?? BoxFit.contain,
          width: widget.width,
          height: widget.height,
        ),
      );
    }

    // 多帧动画
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final frameIndex = (_animationController.value * _frames.length).floor() % _frames.length;
          return RawImage(
            image: _frames[frameIndex].image,
            fit: widget.fit ?? BoxFit.contain,
            width: widget.width,
            height: widget.height,
          );
        },
      ),
    );
  }

  /// 播放动画
  void play() {
    if (!_isLoading && _frames.length > 1) {
      if (widget.loop) {
        _animationController.repeat();
      } else {
        _animationController.forward();
      }
    }
  }

  /// 暂停动画
  void pause() {
    if (!_isLoading) {
      _animationController.stop();
    }
  }

  /// 重置动画
  void reset() {
    if (!_isLoading) {
      _animationController.reset();
    }
  }
}