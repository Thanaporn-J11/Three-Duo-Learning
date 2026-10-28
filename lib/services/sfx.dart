import 'dart:async';
import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// All the little sounds of the app:
///  * right / wrong answer and end of a level (games and quizzes)
///  * button tap, reward and welcome chime
///  * quiet background music on every page (the player can turn it off in
///    Settings)
///
/// Files: `assets/sounds/sfx/<name>.wav`.
///
/// Calling these never throws and never waits: if the sound cannot be played
/// (silent device, no audio, unit tests) the app simply carries on.
/// The player can turn sound effects and music off in Settings.
class Sfx {
  Sfx._();

  static const String _soundKey = 'sfx_sound_enabled';
  static const String _musicKey = 'sfx_music_enabled';
  static const double _musicVolume = 0.3;

  static bool _soundOn = true;
  static bool _musicOn = true;

  static bool get soundEnabled => _soundOn;
  static bool get musicEnabled => _musicOn;

  static final Map<String, AudioPlayer> _players = <String, AudioPlayer>{};

  /// Unit and widget tests have no audio plugin.
  static bool get _unavailable =>
      kIsWeb || Platform.environment.containsKey('FLUTTER_TEST');

  /// Read the saved on/off choices and follow the app going to the background.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _soundOn = prefs.getBool(_soundKey) ?? true;
      _musicOn = prefs.getBool(_musicKey) ?? true;
    } catch (_) {}
    if (_unavailable) return;
    WidgetsBinding.instance.addObserver(_Lifecycle());
    _syncMusic();
  }

  static Future<void> setSoundEnabled(bool value) async {
    _soundOn = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_soundKey, value);
    } catch (_) {}
  }

  static Future<void> setMusicEnabled(bool value) async {
    _musicOn = value;
    _syncMusic();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_musicKey, value);
    } catch (_) {}
  }

  // ---------------------------------------------------------------- effects

  static DateTime _lastResult = DateTime.fromMillisecondsSinceEpoch(0);

  static void correct() {
    _lastResult = DateTime.now();
    _play('correct');
  }

  static void wrong() {
    _lastResult = DateTime.now();
    _play('wrong');
  }

  static void complete() {
    _lastResult = DateTime.now();
    _play('complete');
  }

  static void reward() {
    _lastResult = DateTime.now();
    _play('reward');
  }

  static bool _welcomed = false;

  /// The welcome chime, once each time the app is opened.
  static void welcomeOnce() {
    if (_welcomed) return;
    _welcomed = true;
    _play('welcome');
  }

  /// Soft pop for a tapped button. It waits a moment and stays quiet if the
  /// tap already produced a right / wrong / reward sound, so they never pile up.
  static void tap() {
    if (!_soundOn || _unavailable) return;
    final asked = DateTime.now();
    Timer(const Duration(milliseconds: 80), () {
      if (_lastResult.isAfter(asked)) return;
      _play('tap');
    });
  }

  static Future<void> _play(String name) async {
    if (!_soundOn || _unavailable) return;
    try {
      var player = _players[name];
      if (player == null) {
        player = AudioPlayer();
        _players[name] = player;
        await player.setPlayerMode(PlayerMode.lowLatency);
        await player.setReleaseMode(ReleaseMode.stop);
        // Play together with the voice reading the words, do not cut it off.
        await player.setAudioContext(
          AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
              .build(),
        );
      }
      await player.stop();
      await player.play(AssetSource('sounds/sfx/$name.wav'));
    } catch (_) {
      // No sound is better than a broken game.
    }
  }

  // ------------------------------------------------------------------ music

  static AudioPlayer? _music;
  static bool _musicStarted = false;
  static bool _musicPlaying = false;
  static bool _appActive = true;
  static Future<void> _musicChain = Future<void>.value();

  static void _setAppActive(bool value) {
    _appActive = value;
    _syncMusic();
  }

  static void _syncMusic() {
    if (_unavailable) return;
    _musicChain = _musicChain.then((_) => _applyMusic());
  }

  static Future<void> _applyMusic() async {
    final want = _musicOn && _appActive;
    try {
      if (want && !_musicPlaying) {
        var player = _music;
        if (player == null) {
          player = AudioPlayer();
          _music = player;
          await player.setReleaseMode(ReleaseMode.loop);
          await player.setAudioContext(
            AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
                .build(),
          );
        }
        if (_musicStarted) {
          await player.resume();
        } else {
          await player.play(
            AssetSource('sounds/sfx/bgm.wav'),
            volume: _musicVolume,
          );
          _musicStarted = true;
        }
        _musicPlaying = true;
      } else if (!want && _musicPlaying) {
        await _music?.pause();
        _musicPlaying = false;
      }
    } catch (_) {
      // Music is optional.
    }
  }
}

class _Lifecycle with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    Sfx._setAppActive(state == AppLifecycleState.resumed);
  }
}
