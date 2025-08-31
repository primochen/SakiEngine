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
      await _backgroundMusicPlayer.pause();
    } else if (_currentBackgroundMusic != null) {
      await playBackgroundMusic(_currentBackgroundMusic!);
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
    await _backgroundMusicPlayer.setVolume(actualVolume);
  }

  Future<void> playBackgroundMusic(String assetPath) async {
    try {
      if (_currentBackgroundMusic == assetPath && 
          _backgroundMusicPlayer.state == PlayerState.playing) {
        return;
      }

      _currentBackgroundMusic = assetPath;
      
      if (_isMusicEnabled) {
        await _backgroundMusicPlayer.stop();
        await _backgroundMusicPlayer.play(AssetSource(assetPath));
        await _updateMusicVolume();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error playing background music: $e');
      }
    }
  }

  Future<void> stopBackgroundMusic() async {
    try {
      await _backgroundMusicPlayer.stop();
      _currentBackgroundMusic = null;
    } catch (e) {
      if (kDebugMode) {
        print('Error stopping background music: $e');
      }
    }
  }

  Future<void> clearBackgroundMusic() async {
    try {
      await _backgroundMusicPlayer.stop();
      _currentBackgroundMusic = null;
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
  Future<void> forceStopBackgroundMusic() async {
    try {
      await _backgroundMusicPlayer.stop();
      _currentBackgroundMusic = null;
      if (kDebugMode) {
        print('[MusicManager] 强制停止背景音乐');
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

  void dispose() {
    _backgroundMusicPlayer.dispose();
    _soundEffectPlayer.dispose();
    super.dispose();
  }
}