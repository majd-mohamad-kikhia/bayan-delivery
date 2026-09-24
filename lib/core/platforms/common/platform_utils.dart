import 'dart:async';
import 'dart:math' as math;

typedef Clock = DateTime Function();

/// Collapses concurrent calls that share a key into one in-flight future.
///
/// Used for token refreshes (one refresh however many requests hit an
/// expired token) and for identical read requests fired at the same time.
final class SingleFlight<T> {
  final Map<String, Future<T>> _inFlight = {};

  Future<T> run(String key, Future<T> Function() task) {
    final existing = _inFlight[key];
    if (existing != null) return existing;

    late final Future<T> future;
    future = Future.sync(task).whenComplete(() {
      if (identical(_inFlight[key], future)) _inFlight.remove(key);
    });
    return _inFlight[key] = future;
  }
}

/// Exponential backoff: 300ms, 900ms, 2.7s, …
Duration backoffDelay(int attempt) =>
    const Duration(milliseconds: 300) * math.pow(3, attempt);

List<List<T>> chunked<T>(List<T> items, int size) => [
  for (var i = 0; i < items.length; i += size)
    items.sublist(i, math.min(i + size, items.length)),
];

/// Runs [task] over [items] with at most [concurrency] in flight, keeping
/// result order. After the first failure no new items are started and that
/// error is rethrown.
Future<List<R>> mapConcurrent<T, R>(
  List<T> items,
  int concurrency,
  Future<R> Function(T item) task,
) async {
  if (items.isEmpty) return const [];
  if (items.length == 1) return [await task(items.single)];

  final results = List<R?>.filled(items.length, null);
  var next = 0;
  var failed = false;

  Future<void> worker() async {
    while (!failed && next < items.length) {
      final index = next++;
      try {
        results[index] = await task(items[index]);
      } catch (_) {
        failed = true;
        rethrow;
      }
    }
  }

  await Future.wait([
    for (var i = 0; i < math.min(concurrency, items.length); i++) worker(),
  ], eagerError: true);
  return [for (final result in results) result as R];
}

/// Prepares params for the wire:
/// - drops top-level `null`s — Keeta signs every key it receives, so leaving
///   a key out is safer than sending a `null` whose string form is ambiguous;
/// - turns integral doubles (`10.0`) into ints, recursively, because the
///   Node executor re-serializes them as `10`; signing `10.0` would break
///   Keeta's signature check.
Map<String, Object?> normalizeParams(Map<String, Object?> params) {
  final out = <String, Object?>{};
  params.forEach((key, value) {
    if (value != null) out[key] = _normalize(value);
  });
  return out;
}

Object? _normalize(Object? value) => switch (value) {
  final double d
      when d.isFinite &&
          d == d.truncateToDouble() &&
          d.abs() < 9007199254740992 =>
    d.toInt(),
  final Map<Object?, Object?> map => {
    for (final entry in map.entries)
      entry.key.toString(): _normalize(entry.value),
  },
  final Iterable<Object?> list => [for (final item in list) _normalize(item)],
  _ => value,
};

/// Rejects input the platform would refuse anyway, before paying for a
/// round-trip through the executor.
void checkArgument(
  bool condition,
  String name,
  String message, [
  Object? value,
]) {
  if (!condition) throw ArgumentError.value(value, name, message);
}
