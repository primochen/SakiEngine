import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:sakiengine/src/config/asset_manager.dart';

class MoviePlayer extends StatefulWidget {
  final String movieFile;
  final VoidCallback? onVideoEnd;
  final bool autoPlay;
  final bool looping;
  final int? repeatCount; // 新增：重复播放次数，null表示只播放一次
  
  const MoviePlayer({
    Key? key,
    required this.movieFile,
    this.onVideoEnd,
    this.autoPlay = true,
    this.looping = false,
    this.repeatCount, // 新增：重复次数参数
  }) : super(key: key);

  @override
  State<MoviePlayer> createState() => _MoviePlayerState();
}

class _MoviePlayerState extends State<MoviePlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _hasCalledOnEnd = false; // 新增：防止重复调用结束回调
  int _currentPlayCount = 0; // 新增：当前已播放次数

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void didUpdateWidget(MoviePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movieFile != widget.movieFile) {
      _disposeController();
      _initializeVideo();
    }
  }

  Future<void> _initializeVideo() async {
    try {
      ////print('[MoviePlayer] 开始初始化视频: ${widget.movieFile}');
      
      // 如果视频文件为空，直接返回
      if (widget.movieFile.isEmpty) {
        ////print('[MoviePlayer] 视频文件名为空，跳过初始化');
        setState(() {
          _hasError = true;
          _errorMessage = '视频文件名为空';
        });
        return;
      }
      
      // 使用AssetManager查找视频文件
      String? videoPath = await AssetManager().findAsset(widget.movieFile);
      ////print('[MoviePlayer] AssetManager查找结果: $videoPath');
      
      if (videoPath == null) {
        // 尝试在videos目录下查找
        videoPath = await AssetManager().findAsset('videos/${widget.movieFile}');
        ////print('[MoviePlayer] 在videos目录查找结果: $videoPath');
      }
      
      if (videoPath == null) {
        // 尝试在movies目录下查找
        videoPath = await AssetManager().findAsset('movies/${widget.movieFile}');
        ////print('[MoviePlayer] 在movies目录查找结果: $videoPath');
      }
      
      if (videoPath == null) {
        ////print('[MoviePlayer] 所有路径都未找到视频文件');
        setState(() {
          _hasError = true;
          _errorMessage = '找不到视频文件: ${widget.movieFile}';
        });
        return;
      }

      ////print('[MoviePlayer] 最终使用的视频路径: $videoPath');

      // 根据文件路径类型创建控制器
      if (videoPath.startsWith('assets/')) {
        // Assets中的视频文件
        ////print('[MoviePlayer] 使用AssetVideoController');
        _controller = VideoPlayerController.asset(videoPath);
      } else {
        // 外部文件系统中的视频文件
        ////print('[MoviePlayer] 使用FileVideoController');
        _controller = VideoPlayerController.file(File(videoPath));
      }

      // 初始化控制器
      ////print('[MoviePlayer] 开始初始化控制器');
      await _controller!.initialize();
      ////print('[MoviePlayer] 控制器初始化完成');
      
      // 设置循环播放
      _controller!.setLooping(widget.looping);
      
      // 监听播放完成事件
      _controller!.addListener(_videoListener);
      
      setState(() {
        _isInitialized = true;
      });

      // 自动播放
      if (widget.autoPlay) {
        await _controller!.play();
      }
      
    } catch (e) {
      ////print('[MoviePlayer] 初始化视频失败: $e');
      setState(() {
        _hasError = true;
        _errorMessage = '视频初始化失败: $e';
      });
    }
  }

  void _videoListener() {
    if (_controller != null && 
        _controller!.value.isInitialized &&
        !_hasCalledOnEnd) {
      
      final position = _controller!.value.position;
      final duration = _controller!.value.duration;
      final isPlaying = _controller!.value.isPlaying;
      
      // 检查视频是否播放完成
      bool isCompleted = false;
      if (kIsWeb) {
        // Web平台：使用更严格的完成检测，避免误判
        // 只有当视频真正停止播放且位置接近结尾时才认为完成
        final threshold = Duration(milliseconds: 100); // 缩小阈值
        final nearEnd = position >= duration - threshold;
        final reallyAtEnd = position >= duration;
        
        // Web平台需要同时满足：位置接近结尾 AND 视频已停止播放
        isCompleted = duration > Duration.zero && 
                     !isPlaying && 
                     (nearEnd || reallyAtEnd) &&
                     position.inMilliseconds > 0; // 确保视频确实播放过
        
        // 调试信息 - 临时启用
        if (nearEnd || reallyAtEnd) {
          print('[MoviePlayer Web Debug] position=${position.inSeconds}s, duration=${duration.inSeconds}s, isPlaying=$isPlaying, completed=$isCompleted, count=$_currentPlayCount');
        }
      } else {
        // 桌面平台：使用精确的完成检测
        isCompleted = position >= duration && duration > Duration.zero;
      }
      
      // 检查视频是否播放完成
      if (isCompleted) {
        _currentPlayCount++;
        //print('[MoviePlayer] 视频播放完成第${_currentPlayCount}次 (Web: $kIsWeb): position=$position, duration=$duration, isPlaying=$isPlaying');
        
        // 检查是否设置了looping（优先级最高）
        if (widget.looping) {
          // 如果设置了looping，永远循环播放，不调用结束回调
          //print('[MoviePlayer] 无限循环播放，重新开始');
          _controller!.seekTo(Duration.zero).then((_) {
            _controller!.play();
          });
          return;
        }
        
        // 检查是否需要重复播放
        final targetRepeatCount = widget.repeatCount ?? 1; // 如果没有设置repeatCount，默认播放1次
        //print('[MoviePlayer] 当前播放次数: $_currentPlayCount, 目标次数: $targetRepeatCount');
        
        if (_currentPlayCount < targetRepeatCount) {
          // 还需要继续播放，重置视频到开始位置
          //print('[MoviePlayer] 开始第${_currentPlayCount + 1}次播放，总共需要播放${targetRepeatCount}次');
          
          // Web平台需要稍微延迟再重新播放，避免状态冲突
          if (kIsWeb) {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (_controller != null && mounted) {
                _controller!.seekTo(Duration.zero).then((_) {
                  if (_controller != null && mounted) {
                    _controller!.play();
                  }
                });
              }
            });
          } else {
            _controller!.seekTo(Duration.zero).then((_) {
              _controller!.play();
            });
          }
        } else {
          // 播放完成所有重复次数
          //print('[MoviePlayer] 所有重复播放完成，共播放${_currentPlayCount}次，调用结束回调');
          
          // 设置标志防止重复调用
          _hasCalledOnEnd = true;
          
          // Web平台延迟调用回调，确保视频状态稳定
          if (kIsWeb) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (widget.onVideoEnd != null) {
                print('[MoviePlayer Web] 延迟调用视频结束回调');
                widget.onVideoEnd!();
              }
            });
          } else {
            // 调用结束回调
            widget.onVideoEnd?.call();
          }
        }
      }
    }
  }

  void _disposeController() {
    if (_controller != null) {
      _controller!.removeListener(_videoListener);
      _controller!.dispose();
      _controller = null;
    }
    _isInitialized = false;
    _hasError = false;
    _errorMessage = null;
    _hasCalledOnEnd = false; // 重置结束回调标志
    _currentPlayCount = 0; // 重置播放计数器
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      // 如果是空文件名错误，返回透明容器
      if (_errorMessage?.contains('视频文件名为空') == true) {
        return const SizedBox.shrink();
      }
      
      return Container(
        color: Colors.black,
        child: Center(
          child: Text(
            _errorMessage ?? '视频加载失败',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.black,
          ),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: Center(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _controller!.value.size.width,
            height: _controller!.value.size.height,
            child: VideoPlayer(_controller!),
          ),
        ),
      ),
    );
  }
}