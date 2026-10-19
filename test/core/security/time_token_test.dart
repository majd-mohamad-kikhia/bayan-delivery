import 'package:bayan_desktop/core/security/time_token.dart';
import 'package:flutter_test/flutter_test.dart';

const _alphabet = '0123456789.';
final _symbols = '⅄øđłůðþɹƛæ⍜'.split('');
const _order = [8, 1, 10, 4, 0, 7, 3, 11, 5, 2, 9, 6];

/// The reverse of the scramble, only to prove the token carries the time.
({int hours, int minutes, int seconds}) _decode(String token) {
  final symbols = token.split('');
  final spots = TimeToken.positions.toSet();
  final body = [
    for (var i = 0; i < symbols.length; i++)
      if (!spots.contains(i)) _alphabet[_symbols.indexOf(symbols[i])],
  ];
  final mixed = [
    for (var i = 1; i < body.length; i += 2) body[i],
  ]; // drop the random digits
  final raw = List<String>.filled(12, '');
  for (var i = 0; i < 12; i++) {
    raw[_order[i]] = mixed[i];
  }
  final text = raw.join();
  int value(String chunk) =>
      int.parse(chunk.substring(0, 2)) * 10 + int.parse(chunk.substring(3));
  return (
    hours: value(text.substring(0, 4)) ~/ 41,
    minutes: value(text.substring(4, 8)) ~/ 16,
    seconds: value(text.substring(8, 12)) ~/ 16,
  );
}

void main() {
  final date = DateTime(2026, 10, 18, 14, 37, 52);

  test('is 32 symbols long and carries the time', () {
    final token = TimeToken.encrypt('abcd1234', date);
    expect(token.runes.length, TimeToken.length);
    final t = _decode(token);
    expect((t.hours, t.minutes, t.seconds), (14, 37, 52));
  });

  test('stamps the key-derived marker at the fixed positions', () {
    final token = TimeToken.encrypt('abcd1234', date).split('');
    expect(
      TimeToken.positions.map((p) => token[p]).join(),
      TimeToken.marker('abcd1234'),
    );
    expect(TimeToken.marker('abcd1234'), isNot(TimeToken.marker('wxyz5678')));
  });

  test('the marker is the same one the backend derives', () {
    // Pinned from delivery/src/security/timeToken.js: marker('abcd1234').
    expect(TimeToken.marker('abcd1234'), 'đƛ⅄ůæþ⅄ø');
  });

  test('changes between calls (random filler) but decodes to the same time', () {
    final tokens = {
      for (var i = 0; i < 30; i++) TimeToken.encrypt('abcd1234', date),
    };
    expect(tokens.length, greaterThan(1));
    for (final t in tokens) {
      expect(_decode(t).minutes, 37);
    }
  });

  test('works at the edges of the day', () {
    var t = _decode(TimeToken.encrypt('abcd1234', DateTime(2026, 1, 1, 0, 0, 0)));
    expect((t.hours, t.minutes, t.seconds), (0, 0, 0));
    t = _decode(TimeToken.encrypt('abcd1234', DateTime(2026, 1, 1, 23, 59, 59)));
    expect((t.hours, t.minutes, t.seconds), (23, 59, 59));
  });

  test('refuses a key that is not 8 characters', () {
    expect(() => TimeToken.encrypt('short'), throwsArgumentError);
    expect(TimeToken.isValidKey('abcd1234'), isTrue);
    expect(TimeToken.isValidKey('abcd12345'), isFalse);
  });

  test('is fast: tens of thousands of tokens per second', () {
    final watch = Stopwatch()..start();
    for (var i = 0; i < 20000; i++) {
      TimeToken.encrypt('abcd1234', date);
    }
    expect(watch.elapsedMilliseconds, lessThan(1000));
  });
}
