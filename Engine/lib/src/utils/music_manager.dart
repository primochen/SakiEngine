import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MusicManager extends ChangeNotifier {
  static final MusicManager _instance = MusicManager._internal();
  factory MusicManager() => _instance;
  MusicManager._internal();

  final AudioPlayer _backgroundMusicPlayer = AudioPlayer();
  final AudioPlayer _soundEffectPlayer = AudioPlayer();
  
  bool _isMusicEnabled = true;
  double _musicVolume = 0.8;
  double _soundVolume = 0.8;
  String? _currentBackgroundMusic;
  
  // 淡入淡出相关
  Timer? _fadeTimer;
  bool _isFading = false;
  double _currentFadeVolume = 0.0;
  
  bool get isMusicEnabled => _isMusicEnabled;
  double get musicVolume => _musicVolume;
  double get soundVolume => _soundVolume;
  String? get currentBackgroundMusic => _currentBackgroundMusic;

  Future<void> initialize() async {
    await _loadSettings();
    await _backgroundMusicPlayer.setReleaseMode(ReleaseMode.loop);
    await _updateMusicVolume();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isMusicEnabled = prefs.getBool('music_enabled') ?? true;
      _musicVolume = prefs.getDouble('music_volume') ?? 0.8;
      _soundVolume = prefs.getDouble('sound_volume') ?? 0.8;
    } catch (e) {
      if (kDebugMode) {
        print('Error loading music settings: $e');
      }
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('music_enabled', _isMusicEnabled);
      await prefs.setDouble('music_volume', _musicVolume);
      await prefs.setDouble('sound_volume', _soundVolume);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving music settings: $e');
      }
    }
  }

  Future<void> setMusicEnabled(bool enabled) async {
    _isMusicEnabled = enabled;
    await _saveSettings();
    
    if (!enabled) {
      _cancelFade(); // 取消淡化
      await _backgroundMusicPlayer.pause();
    } else if (_currentBackgroundMusic != null) {
      await playBackgroundMusic(
        _currentBackgroundMusic!,
        fadeTransition: true,
        fadeDuration: const Duration(milliseconds: 500),
      );
    }
    
    notifyListeners();
  }

  Future<void> setMusicVolume(double volume) async {
    _musicVolume = volume.clamp(0.0, 1.0);
    await _saveSettings();
    await _updateMusicVolume();
    notifyListeners();
  }

  Future<void> setSoundVolume(double volume) async {
    _soundVolume = volume.clamp(0.0, 1.0);
    await _saveSettings();
    await _soundEffectPlayer.setVolume(_soundVolume);
    notifyListeners();
  }

  Future<void> _updateMusicVolume() async {
    final actualVolume = _isMusicEnabled ? _musicVolume : 0.0;
    final fadeVolume = _isFading ? _currentFadeVolume : actualVolume;
    await _backgroundMusicPlayer.setVolume(fadeVolume);
  }
  
  /// 淡出当前音乐
  /// [duration] 淡出时长，默认1秒
  /// [onComplete] 淡出完成后的回调
  Future<void> _fadeOut({
    Duration duration = const Duration(milliseconds: 1000),
    VoidCallback? onComplete,
  }) async {
    if (!_isMusicEnabled || _currentBackgroundMusic == null) {
      onComplete?.call();
      return;
    }
    
    _cancelFade(); // 取消之前的淡化效果
    _isFading = true;
    _currentFadeVolume = _musicVolume;
    
    const steps = 20; // 分20步进行淡出
    final stepDuration = Duration(milliseconds: duration.inMilliseconds ~/ steps);
    final volumeStep = _musicVolume / steps;
    
    int currentStep = 0;
    _fadeTimer = Timer.periodic(stepDuration, (timer) async {
      currentStep++;
      _currentFadeVolume = _musicVolume - (volumeStep * currentStep);
      _currentFadeVolume = _currentFadeVolume.clamp(0.0, 1.0);
      
      await _updateMusicVolume();
      
      if (currentStep >= steps || _currentFadeVolume <= 0.0) {
        timer.cancel();
        _isFading = false;
        _currentFadeVolume = 0.0;
        onComplete?.call();
      }
    });
  }
  
  /// 淡入音乐
  /// [duration] 淡入时长，默认1秒
  /// [onComplete] 淡入完成后的回调
  Future<void> _fadeIn({
    Duration duration = const Duration(milliseconds: 1000),
    VoidCallback? onComplete,
  }) async {
    if (!_isMusicEnabled || _currentBackgroundMusic == null) {
      onComplete?.call();
      return;
    }
    
    _cancelFade(); // 取消之前的淡化效果
    _isFading = true;
    _currentFadeVolume = 0.0;
    await _updateMusicVolume(); // 先设置为0音量
    
    const steps = 20; // 分20步进行淡入
    final stepDuration = Duration(milliseconds: duration.inMilliseconds ~/ steps);
    final volumeStep = _musicVolume / steps;
    
    int currentStep = 0;
    _fadeTimer = Timer.periodic(stepDuration, (timer) async {
      currentStep++;
      _currentFadeVolume = volumeStep * currentStep;
      _currentFadeVolume = _currentFadeVolume.clamp(0.0, _musicVolume);
      
      await _updateMusicVolume();
      
      if (currentStep >= steps || _currentFadeVolume >= _musicVolume) {
        timer.cancel();
        _isFading = false;
        _currentFadeVolume = _musicVolume;
        await _updateMusicVolume();
        onComplete?.call();
      }
    });
  }
  
  /// 取消当前的淡化效果
  void _cancelFade() {
    _fadeTimer?.cancel();
    _fadeTimer = null;
    _isFading = false;
  }

  Future<void> playBackgroundMusic(String assetPath, {
    bool fadeTransition = true,
    Duration fadeDuration = const Duration(milliseconds: 1000),
  }) async {
    try {
      if (_currentBackgroundMusic == assetPath && 
          _backgroundMusicPlayer.state == PlayerState.playing) {
        return;
      }

      if (!_isMusicEnabled) {
        _currentBackgroundMusic = assetPath;
        return;
      }

      final oldMusicPath = _currentBackgroundMusic;
      _currentBackgroundMusic = assetPath;
      
      if (oldMusicPath != null && fadeTransition) {
        // 有旧音乐且需要淡入淡出过渡
        if (kDebugMode) {
          print('[MusicManager] 平滑切换音乐: $oldMusicPath -> $assetPath');
        }
        
        // 先淡出旧音乐
        await _fadeOut(
          duration: Duration(milliseconds: fadeDuration.inMilliseconds ~/ 2),
          onComplete: () async {
            // 淡出完成后切换音乐并淡入
            await _backgroundMusicPlayer.stop();
            await _backgroundMusicPlayer.play(AssetSource(assetPath));
            await _fadeIn(duration: Duration(milliseconds: fadeDuration.inMilliseconds ~/ 2));
          },
        );
      } else {
        // 没有旧音乐或不需要过渡，直接播放
        await _backgroundMusicPlayer.stop();
        await _backgroundMusicPlayer.play(AssetSource(assetPath));
        
        if (fadeTransition) {
          // 淡入新音乐
          await _fadeIn(duration: fadeDuration);
        } else {
          // 直接设置音量
          await _updateMusicVolume();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error playing background music: $e');
      }
    }
  }

  Future<void> stopBackgroundMusic({
    bool fadeOut = true,
    Duration fadeDuration = const Duration(milliseconds: 800),
  }) async {
    try {
      if (_currentBackgroundMusic == null) return;
      
      if (fadeOut && _isMusicEnabled) {
        if (kDebugMode) {
          print('[MusicManager] 淡出停止音乐: $_currentBackgroundMusic');
        }
        
        await _fadeOut(
          duration: fadeDuration,
          onComplete: () async {
            await _backgroundMusicPlayer.stop();
            _currentBackgroundMusic = null;
          },
        );
      } else {
        await _backgroundMusicPlayer.stop();
        _currentBackgroundMusic = null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error stopping background music: $e');
      }
    }
  }

  Future<void> clearBackgroundMusic({
    bool fadeOut = true,
    Duration fadeDuration = const Duration(milliseconds: 800),
  }) async {
    try {
      if (_currentBackgroundMusic == null) return;
      
      if (fadeOut && _isMusicEnabled) {
        if (kDebugMode) {
          print('[MusicManager] 淡出清除音乐: $_currentBackgroundMusic');
        }
        
        await _fadeOut(
          duration: fadeDuration,
          onComplete: () async {
            await _backgroundMusicPlayer.stop();
            _currentBackgroundMusic = null;
          },
        );
      } else {
        _cancelFade(); // 取消任何正在进行的淡化
        await _backgroundMusicPlayer.stop();
        _currentBackgroundMusic = null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing background music: $e');
      }
    }
  }
  
  /// 检查指定音乐是否正在播放
  bool isPlayingMusic(String assetPath) {
    return _currentBackgroundMusic == assetPath && 
           _backgroundMusicPlayer.state == PlayerState.playing;
  }
  
  /// 强制停止背景音乐（用于音乐区间系统）
  Future<void> forceStopBackgroundMusic({
    bool fadeOut = true,
    Duration fadeDuration = const Duration(milliseconds: 600),
  }) async {
    try {
      if (_currentBackgroundMusic == null) return;
      
      if (fadeOut && _isMusicEnabled) {
        if (kDebugMode) {
          print('[MusicManager] 淡出强制停止音乐: $_currentBackgroundMusic');
        }
        
        await _fadeOut(
          duration: fadeDuration,
          onComplete: () async {
            await _backgroundMusicPlayer.stop();
            _currentBackgroundMusic = null;
          },
        );
      } else {
        _cancelFade(); // 取消任何正在进行的淡化
        await _backgroundMusicPlayer.stop();
        _currentBackgroundMusic = null;
        if (kDebugMode) {
          print('[MusicManager] 强制停止背景音乐');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error force stopping background music: $e');
      }
    }
  }

  Future<void> pauseBackgroundMusic() async {
    try {
      await _backgroundMusicPlayer.pause();
    } catch (e) {
      if (kDebugMode) {
        print('Error pausing background music: $e');
      }
    }
  }

  Future<void> resumeBackgroundMusic() async {
    try {
      if (_isMusicEnabled && _currentBackgroundMusic != null) {
        await _backgroundMusicPlayer.resume();
        // 恢复播放时淡入
        await _fadeIn(duration: const Duration(milliseconds: 500));
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error resuming background music: $e');
      }
    }
  }

  Future<void> playSoundEffect(String assetPath) async {
    try {
      if (_isMusicEnabled) {
        await _soundEffectPlayer.stop();
        await _soundEffectPlayer.play(AssetSource(assetPath));
        await _soundEffectPlayer.setVolume(_soundVolume);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error playing sound effect: $e');
      }
    }
  }

  @override
  void dispose() {
    _cancelFade(); // 取消任何正在进行的淡化
    _backgroundMusicPlayer.dispose();
    _soundEffectPlayer.dispose();
    super.dispose();
  }
}