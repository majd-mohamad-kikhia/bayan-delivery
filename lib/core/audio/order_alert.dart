import 'dart:io';

import 'package:flutter/foundation.dart';

/// Plays a loud alert when a new order arrives.
///
/// Uses the OS's own player (no plugin): `afplay` on macOS at max gain,
/// PowerShell system sounds on Windows.
class OrderAlert {
  const OrderAlert._();

  static bool _playing = false;

  static Future<void> play() async {
    // Tests must stay silent.
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    if (_playing) return;
    _playing = true;
    try {
      if (Platform.isMacOS) {
        await Process.run('afplay', ['-v', '10', '/System/Library/Sounds/Hero.aiff']);
      } else if (Platform.isWindows) {
        await Process.run('powershell', [
          '-NoProfile',
          '-Command',
          '[System.Media.SystemSounds]::Asterisk.Play(); Start-Sleep -Milliseconds 800',
        ]);
      }
    } catch (e) {
      debugPrint('OrderAlert failed: $e');
    } finally {
      _playing = false;
    }
  }
}
