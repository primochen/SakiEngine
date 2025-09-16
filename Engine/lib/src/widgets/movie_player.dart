import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:sakiengine/src/config/asset_manager.dart';

class MoviePlayer extends StatefulWidget {
  final String movieFile;
  final VoidCallback? onVideoEnd;
  final bool autoPlay;
  final bool looping;
  
  const MoviePlayer({
    Key? key,
    required this.movieFile,
    this.onVideoEnd,
    this.autoPlay = true,
    this.looping = false,
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
      print('[MoviePlayer] 开始初始化视频: ${widget.movieFile}');
      
      // 如果视频文件为空，直接返回
      if (widget.movieFile.isEmpty) {
        print('[MoviePlayer] 视频文件名为空，跳过初始化');
        setState(() {
          _hasError = true;
          _errorMessage = '视频文件名为空';
        });
        return;
      }
      
      // 使用AssetManager查找视频文件
      String? videoPath = await AssetManager().findAsset(widget.movieFile);
      print('[MoviePlayer] AssetManager查找结果: $videoPath');
      
      if (videoPath == null) {
        // 尝试在videos目录下查找
        videoPath = await AssetManager().findAsset('videos/${widget.movieFile}');
        print('[MoviePlayer] 在videos目录查找结果: $videoPath');
      }
      
      if (videoPath == null) {
        // 尝试在movies目录下查找
        videoPath = await AssetManager().findAsset('movies/${widget.movieFile}');
        print('[MoviePlayer] 在movies目录查找结果: $videoPath');
      }
      
      if (videoPath == null) {
        print('[MoviePlayer] 所有路径都未找到视频文件');
        setState(() {
          _hasError = true;
          _errorMessage = '找不到视频文件: ${widget.movieFile}';
        });
        return;
      }

      print('[MoviePlayer] 最终使用的视频路径: $videoPath');

      // 根据文件路径类型创建控制器
      if (videoPath.startsWith('assets/')) {
        // Assets中的视频文件
        print('[MoviePlayer] 使用AssetVideoController');
        _controller = VideoPlayerController.asset(videoPath);
      } else {
        // 外部文件系统中的视频文件
        print('[MoviePlayer] 使用FileVideoController');
        _controller = VideoPlayerController.file(File(videoPath));
      }

      // 初始化控制器
      print('[MoviePlayer] 开始初始化控制器');
      await _controller!.initialize();
      print('[MoviePlayer] 控制器初始化完成');
      
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
      print('[MoviePlayer] 初始化视频失败: $e');
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
      
      // 检查视频是否播放完成（位置达到或超过总时长且不是循环播放）
      if (position >= duration && !widget.looping && duration > Duration.zero) {
        print('[MoviePlayer] 视频播放完成: position=$position, duration=$duration');
        
        // 设置标志防止重复调用
        _hasCalledOnEnd = true;
        
        // 调用结束回调
        widget.onVideoEnd?.call();
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
            color: Colors.white,
          ),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: VideoPlayer(_controller!),
      ),
    );
  }
}