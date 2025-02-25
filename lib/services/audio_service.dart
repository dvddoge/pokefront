import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  final AudioPlayer _musicPlayer = AudioPlayer();
  final AudioPlayer _effectPlayer = AudioPlayer();
  bool _isMusicEnabled = true;
  bool _isSoundEnabled = true;
  double _musicVolume = 0.5;
  double _soundVolume = 0.7;
  bool _isMusicPlaying = false;
  String? _currentMusic;

  factory AudioService() {
    return _instance;
  }

  AudioService._internal();

  Future<void> playMusic(String assetPath) async {
    if (!_isMusicEnabled) return;
    
    try {
      if (_isMusicPlaying && _currentMusic == assetPath) {
        return;
      }
      
      await stopMusic();
      
      // Tenta o caminho fornecido
      try {
        await _musicPlayer.setVolume(_musicVolume);
        await _musicPlayer.play(AssetSource(assetPath));
        _isMusicPlaying = true;
        _currentMusic = assetPath;
        await _musicPlayer.setReleaseMode(ReleaseMode.loop);
        print('Música iniciada: $assetPath');
      } catch (e) {
        print('Erro ao tocar música com caminho original: $e');
        
        // Tenta um caminho alternativo (sem o prefixo 'assets/')
        if (assetPath.startsWith('assets/')) {
          final alternativePath = assetPath.replaceFirst('assets/', '');
          try {
            await _musicPlayer.setVolume(_musicVolume);
            await _musicPlayer.play(AssetSource(alternativePath));
            _isMusicPlaying = true;
            _currentMusic = alternativePath;
            await _musicPlayer.setReleaseMode(ReleaseMode.loop);
            print('Música iniciada com caminho alternativo: $alternativePath');
          } catch (e2) {
            print('Erro ao tocar música com caminho alternativo: $e2');
          }
        }
      }
    } catch (e) {
      print('Erro geral ao tocar música: $e');
    }
  }

  Future<void> stopMusic() async {
    try {
      await _musicPlayer.stop();
      _isMusicPlaying = false;
      _currentMusic = null;
      print('Música parada');
    } catch (e) {
      print('Erro ao parar música: $e');
    }
  }

  Future<void> pauseMusic() async {
    try {
      await _musicPlayer.pause();
    } catch (e) {
      print('Erro ao pausar música: $e');
    }
  }

  Future<void> resumeMusic() async {
    if (!_isMusicEnabled) return;
    try {
      await _musicPlayer.resume();
    } catch (e) {
      print('Erro ao resumir música: $e');
    }
  }

  Future<void> playSound(String assetPath) async {
    if (!_isSoundEnabled) return;
    
    try {
      // Tenta o caminho fornecido
      try {
        await _effectPlayer.setVolume(_soundVolume);
        await _effectPlayer.play(AssetSource(assetPath));
        print('Som tocado: $assetPath');
      } catch (e) {
        print('Erro ao tocar som com caminho original: $e');
        
        // Tenta um caminho alternativo (sem o prefixo 'assets/')
        if (assetPath.startsWith('assets/')) {
          final alternativePath = assetPath.replaceFirst('assets/', '');
          try {
            await _effectPlayer.setVolume(_soundVolume);
            await _effectPlayer.play(AssetSource(alternativePath));
            print('Som tocado com caminho alternativo: $alternativePath');
          } catch (e2) {
            print('Erro ao tocar som com caminho alternativo: $e2');
          }
        }
      }
    } catch (e) {
      print('Erro geral ao tocar som: $e');
    }
  }

  void setMusicEnabled(bool enabled) {
    _isMusicEnabled = enabled;
    if (!enabled) {
      stopMusic();
    } else {
      resumeMusic();
    }
  }

  void setSoundEnabled(bool enabled) {
    _isSoundEnabled = enabled;
  }

  void setMusicVolume(double volume) {
    _musicVolume = volume;
    _musicPlayer.setVolume(volume);
  }

  void setSoundVolume(double volume) {
    _soundVolume = volume;
  }

  bool get isMusicEnabled => _isMusicEnabled;
  bool get isSoundEnabled => _isSoundEnabled;
  double get musicVolume => _musicVolume;
  double get soundVolume => _soundVolume;

  void dispose() {
    _musicPlayer.dispose();
    _effectPlayer.dispose();
  }
}