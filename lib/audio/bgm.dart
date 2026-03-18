import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

enum _BgmScope { homeDm, group }

class Bgm {
  Bgm._();
  static final Bgm I = Bgm._();

  final AudioPlayer _player = AudioPlayer();

  bool enabled = true;

  String? _currentAsset;

  String? _lastStoppedAsset;
  Duration? _lastStoppedPosition;

  bool _overrideActive = false;

  // Easter egg state
  String? _preEggAsset;
  bool _preEggOverrideActive = false;
  Duration? _preEggPosition;
  StreamSubscription<void>? _eggCompleteSub;
  bool _eggPlaying = false;

  // ✅ NEW: scope
  _BgmScope _scope = _BgmScope.homeDm;

  // ✅ Home + DMs use the same track
  static const String _homeDmAsset = 'bgm/MenuAndDmsMusic.mp3';
  // ✅ Track volume locally (because some audioplayers versions don't have getVolume())
  double _volume = 0.45;

  Future<void> _setVolume(double v) async {
    _volume = v.clamp(0.0, 1.0);
    await _player.setVolume(_volume);
  }
// ✅ NEW: resume positions only for GROUP assets
final Map<String, Duration> _groupPosByAsset = <String, Duration>{};
  // ✅ NEW: remember GROUP position when temporarily switching to Home/DM
  String? _groupResumeAsset;
  Duration? _groupResumePosition;


  Future<void> init() async {
    final bgmContext = AudioContext(
      android: AudioContextAndroid(
        isSpeakerphoneOn: false,
        stayAwake: true,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.none,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.ambient,
        options: <AVAudioSessionOptions>{
          AVAudioSessionOptions.mixWithOthers,
        },
      ),
    );

    await _player.setAudioContext(bgmContext);
    await _player.setReleaseMode(ReleaseMode.loop);

    // ✅ use our tracked volume
    await _setVolume(0.45);
  }






  Timer? _fadeTimer;

  Future<void> _fadeVolume(double from, double to, Duration duration) async {
    _fadeTimer?.cancel();
    if (!enabled) return;

    final int steps = 18; // smooth enough
    final int stepMs =
        (duration.inMilliseconds / steps).round().clamp(10, 1000);
    final double delta = (to - from) / steps;

    double v = from;
    await _setVolume(v);

    final completer = Completer<void>();

    int i = 0;
    _fadeTimer = Timer.periodic(Duration(milliseconds: stepMs), (t) async {
      i++;
      v += delta;
      await _setVolume(v);

      if (i >= steps) {
        t.cancel();
        _fadeTimer = null;
        completer.complete();
      }
    });

    return completer.future;
  }

  /// Fade current player volume (whatever is playing right now)
  Future<void> fadeTo(double target, Duration duration) async {
    // ✅ no getVolume(); use tracked _volume
    final current = _volume;
    await _fadeVolume(current, target, duration);
  }


  // ==========================
  // HOME + DMs
  // ==========================
  Future<void> playHomeDm() async {
    if (!enabled) return;
    if (_eggPlaying) return;

    _scope = _BgmScope.homeDm;

    // leaving group should cancel hourly lock
    _overrideActive = false;

    await _playLoopingAsset(_homeDmAsset);
  }

  // ==========================
  // GROUP (hourly)
  // ==========================
String assetForHour(int hour) {
  // Morning: 07:00–11:59
  if (hour >= 7 && hour <= 11) return 'bgm/MorningBGM.mp3';

  // Noon: 12:00–16:59
  if (hour >= 12 && hour <= 16) return 'bgm/NoonBGM.mp3';

  // Evening: 17:00–20:59
  if (hour >= 17 && hour <= 20) return 'bgm/EveningBGM.mp3';

  // Night: 21:00–23:59  AND  01:00–06:59
  if ((hour >= 21 && hour <= 23) || (hour >= 1 && hour <= 6)) {
    return 'bgm/NightBGM.mp3';
  }

  // Midnight: 00:00–00:59
  return 'bgm/MidnightBGM.mp3';
}


  Future<void> playForHour(int hour) async {
    if (!enabled) return;
    if (_overrideActive || _eggPlaying) return;

    _scope = _BgmScope.group;

    final next = assetForHour(hour);
    await _playLoopingAsset(next);
  }

  // ✅ call when exiting group UI to prevent "leak"
  Future<void> leaveGroupAndResumeHomeDm() async {
    if (!enabled) return;
    if (_eggPlaying) return;

    if (_scope != _BgmScope.group) return;

    // ✅ SAVE current GROUP position BEFORE we switch scope to home
    final String? prevAsset = _currentAsset;
    if (prevAsset != null && prevAsset != _homeDmAsset) {
      try {
        final pos = await _player.getCurrentPosition();
        if (pos != null) {
          _groupPosByAsset[prevAsset] = pos;
          debugPrint('🎵 Saved GROUP pos: $prevAsset -> $pos');
        }
      } catch (_) {
        // ignore
      }
    }

    await playHomeDm();
  }


  // ==========================
  // Core play logic
  // ==========================
Future<void> _playLoopingAsset(String asset) async {
  if (!enabled) return;
  if (_currentAsset == asset) return;

  // We treat ONLY the home/dm asset as "home"
  final bool switchingToHome = (asset == _homeDmAsset);

  // ✅ Save position ONLY for group tracks (never for home/dm)
  final String? prevAsset = _currentAsset;
  if (prevAsset != null && prevAsset != _homeDmAsset) {
    try {
      final pos = await _player.getCurrentPosition();
      if (pos != null) {
        _groupPosByAsset[prevAsset] = pos;
      }
    } catch (_) {
      // ignore
    }
  }

  // ✅ Decide resume position:
  // - GROUP: resume from saved position (if exists)
  // - HOME/DM: ALWAYS start from beginning (no resume)
  final Duration? resumePos = switchingToHome ? null : _groupPosByAsset[asset];


  _currentAsset = asset;

  try {
    debugPrint('🎵 BGM set source: $asset');

    await _player.setReleaseMode(ReleaseMode.loop);

    await _player.stop();
    await _player.setSource(AssetSource(asset));

    if (resumePos != null) {
      await _player.seek(resumePos);
    } else {
      // ✅ explicit start at 0 for home/dm (or group without saved pos)
      await _player.seek(Duration.zero);
    }

    await _player.resume();
  } catch (e, s) {
    debugPrint('❌ BGM failed: $e');
    debugPrint('$s');
  }
}


  // ==========================
  // Easter egg
  // ==========================
  Future<void> playEasterEgg(String asset) async {
    if (!enabled) return;
    if (_eggPlaying) return;

    await _eggCompleteSub?.cancel();
    _eggCompleteSub = null;

    _eggPlaying = true;

    try {
      _preEggAsset = _currentAsset;
      _preEggOverrideActive = _overrideActive;
      _preEggPosition = await _player.getCurrentPosition();

// fade out current bgm quickly
await fadeTo(0.0, const Duration(milliseconds: 450));
await _player.pause();

_currentAsset = asset;

await _player.setReleaseMode(ReleaseMode.stop);
await _player.stop();
await _player.setSource(AssetSource(asset));

// start creepy at 0 volume then fade in
await _setVolume(0.0);
await _player.resume();
await fadeTo(0.45, const Duration(milliseconds: 900));


_eggCompleteSub = _player.onPlayerComplete.listen((_) async {
  await fadeTo(0.0, const Duration(milliseconds: 600));
  await _restoreAfterEgg();
});

    } catch (_) {
      await _restoreAfterEgg();
    }
  }

Future<void> _restoreAfterEgg() async {
  if (!_eggPlaying) return;

  // ✅ we consider "egg is done" only after we successfully restore
  await _eggCompleteSub?.cancel();
  _eggCompleteSub = null;

  _overrideActive = _preEggOverrideActive;

  final prev = _preEggAsset;
  if (prev == null) {
    _eggPlaying = false;
    return;
  }

  try {
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.stop();
    await _player.setSource(AssetSource(prev));

    // ✅ restore from 0 volume then fade back in
    await _setVolume(0.0);

    if (_preEggPosition != null) {
      await _player.seek(_preEggPosition!);
    }

    await _player.resume();
    await fadeTo(0.45, const Duration(milliseconds: 1200));

    _currentAsset = prev;
  } catch (_) {
    // ignore
  } finally {
    _eggPlaying = false;
  }
}



  // ==========================
  // Manual override (kept)
  // ==========================
  Future<void> playAssetPermanentOverride(String asset) async {
    if (!enabled) return;
    _overrideActive = true;
    await _playLoopingAsset(asset);
  }

  Future<void> clearOverrideAndResume(int hour) async {
    _overrideActive = false;

    if (_scope == _BgmScope.group) {
      await playForHour(hour);
    } else {
      await playHomeDm();
    }
  }
Future<void> cancelEasterEggAndRestore({
  Duration fadeOut = const Duration(milliseconds: 600),
}) async {
  if (!_eggPlaying) return;

  try {
    // stop listening to "complete" (we're forcing exit)
    await _eggCompleteSub?.cancel();
    _eggCompleteSub = null;

    // fade out current (egg) audio quickly
    await fadeTo(0.0, fadeOut);

    // stop current track so it can't keep playing quietly
    await _player.stop();
  } catch (_) {
    // ignore
  }

  // restore the previous looping bgm immediately
  await _restoreAfterEgg();
}

  // ==========================
  // Lifecycle controls (kept)
  // ==========================
  Future<void> stop() async {
    try {
      await _eggCompleteSub?.cancel();
      _eggCompleteSub = null;

      _eggPlaying = false;
      _overrideActive = false;

      _lastStoppedAsset = _currentAsset;
      _lastStoppedPosition = await _player.getCurrentPosition();

      await _player.stop();
      _currentAsset = null;
    } catch (_) {}
  }

  Future<void> pause() async {
    try {
      _lastStoppedAsset = _currentAsset;
      _lastStoppedPosition = await _player.getCurrentPosition();
      await _player.pause();
    } catch (_) {}
  }

  Future<void> resumeIfPossible() async {
    try {
      if (!enabled) return;
      if (_overrideActive || _eggPlaying) return;

      if (_currentAsset != null) {
        await _player.resume();
        return;
      }

      if (_lastStoppedAsset != null) {
        final asset = _lastStoppedAsset!;
        final pos = _lastStoppedPosition;

        await _player.setReleaseMode(ReleaseMode.loop);
        await _player.stop();
        await _player.setSource(AssetSource(asset));
        if (pos != null) await _player.seek(pos);
        await _player.resume();

        _currentAsset = asset;
      }
    } catch (_) {}
  }
}
