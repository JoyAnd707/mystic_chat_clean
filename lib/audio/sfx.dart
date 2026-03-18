import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

class Sfx {
  Sfx._();
  static final Sfx I = Sfx._();

  bool enabled = true;

  // Small pool so SFX can overlap without stealing the BGM engine
  final int _poolSize = 4;
  final List<AudioPlayer> _pool = [];
  int _next = 0;

  Future<void> init() async {
    for (int i = 0; i < _poolSize; i++) {
      final p = AudioPlayer();
      await p.setVolume(0.9);
      _pool.add(p);
    }
  }
Future<void> playCloseImage() =>
    _playOne('assets/fx/CloseImage.mp3', volume: 0.9);

  AudioPlayer _take() {
    final p = _pool[_next];
    _next = (_next + 1) % _pool.length;
    return p;
  }

  Future<void> _playOne(String assetPath, {double volume = 0.9}) async {
    if (!enabled) return;

    final p = _take();

    try {
      await p.setVolume(volume);

      // Stop anything this player was doing, then play the new SFX
      await p.stop();
      await p.setAudioSource(AudioSource.asset(assetPath));
      await p.play();
    } catch (e) {
      debugPrint('SFX failed ($assetPath): $e');
    }
  }

  Future<void> playSend() => _playOne('assets/fx/send.mp3', volume: 0.8);
  Future<void> playSelectDm() => _playOne('assets/fx/SelectDMsfx.mp3', volume: 0.9);
  


  Future<void> playBack() => _playOne('assets/fx/back.mp3', volume: 0.8);
Future<void> playStopListeningToVoiceMessage() =>
    _playOne('assets/fx/StopListeningToVoiceMessage.mp3', volume: 0.9);



  Future<void> play707VoiceLine() =>
      _playOne('assets/fx/707VoiceLine.mp3', volume: 0.95);

  Future<void> dispose() async {
    for (final p in _pool) {
      await p.dispose();
    }
    _pool.clear();
  }

Future<void> playGlitch() => _playOne('assets/fx/GlitchSFX.mp3', volume: 0.95);

  Future<void> stopAll() async {
  try {
    for (final p in _pool) {
      await p.stop();
    }
  } catch (_) {}
}

}
