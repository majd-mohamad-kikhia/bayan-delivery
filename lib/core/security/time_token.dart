import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// The `Hash` Bayan's order endpoint expects: the current time of day as a
/// 32-symbol token with an 8-character key stamped into fixed positions.
///
/// The time is scrambled, not encrypted, and the key only decides the 8
/// marker symbols: do not rely on this for secrecy. It mirrors
/// `delivery/src/security/timeToken.js`.
///
/// Built for volume: the marker symbols are cached per key, the token is
/// assembled in one preallocated array of code units (every symbol is a
/// single UTF-16 unit), and the filler digits come from a plain [Random].
abstract final class TimeToken {
  static const int length = 32;

  /// Token positions that hold the key's marker symbols.
  static const List<int> positions = [1, 5, 9, 12, 17, 21, 26, 30];

  // `0123456789.` → one symbol each.
  static final List<int> _symbols = '⅄øđłůðþɹƛæ⍜'.codeUnits;

  // Where the 12 time characters go in the scrambled order.
  static const List<int> _order = [8, 1, 10, 4, 0, 7, 3, 11, 5, 2, 9, 6];

  static final Random _random = Random();

  static final List<bool> _isMarker = List.generate(
    length,
    positions.contains,
    growable: false,
  );

  static String? _cachedKey;
  static List<int> _cachedMarkers = const [];

  /// Whether [key] is usable: exactly 8 characters.
  static bool isValidKey(String key) => key.runes.length == 8;

  /// The 8 marker symbols derived from [key] (for tests).
  static String marker(String key) => String.fromCharCodes(_markers(key));

  static List<int> _markers(String key) {
    if (key == _cachedKey) return _cachedMarkers;
    if (!isValidKey(key)) throw ArgumentError('Key must be 8 characters');
    final bytes = sha256.convert(utf8.encode(key)).bytes;
    _cachedMarkers = List.generate(
      8,
      (i) => _symbols[bytes[i] % 11],
      growable: false,
    );
    _cachedKey = key;
    return _cachedMarkers;
  }

  /// The token for [date] (default: now, local time).
  static String encrypt(String key, [DateTime? date]) {
    final markers = _markers(key);
    final d = date ?? DateTime.now();

    // 12 characters: hours·41, minutes·16, seconds·16, each as "NN.N".
    final raw = <int>[];
    for (final (n, m) in [(d.hour, 41), (d.minute, 16), (d.second, 16)]) {
      final x = n * m;
      final tens = x ~/ 10;
      raw
        ..add(48 + (tens ~/ 10) % 10)
        ..add(48 + tens % 10)
        ..add(46)
        ..add(48 + x % 10);
    }

    // Each time character, in scrambled order, follows a random digit.
    final mixed = List<int>.filled(24, 0);
    for (var i = 0; i < 12; i++) {
      mixed[i * 2] = _symbols[_random.nextInt(10)];
      mixed[i * 2 + 1] = _symbols[_index(raw[_order[i]])];
    }

    final out = List<int>.filled(length, 0);
    var a = 0;
    var b = 0;
    for (var i = 0; i < length; i++) {
      out[i] = _isMarker[i] ? markers[a++] : mixed[b++];
    }
    return String.fromCharCodes(out);
  }

  static int _index(int code) => code == 46 ? 10 : code - 48;
}
