/// Caches async results per key:
/// - concurrent callers share one in-flight load;
/// - values expire after [maxAge];
/// - failed loads are evicted, so the next call retries;
/// - `refresh: true` reloads, unless the entry is younger than
///   [minRefreshInterval] (so a burst of cache misses costs one reload).
final class AsyncCache<V> {
  AsyncCache({
    required this.maxAge,
    this.minRefreshInterval = const Duration(seconds: 5),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration maxAge;
  final Duration minRefreshInterval;
  final DateTime Function() _clock;
  final Map<String, ({Future<V> future, DateTime at})> _entries = {};

  Future<V> get(String key, Future<V> Function() load, {bool refresh = false}) {
    final now = _clock();
    final entry = _entries[key];
    if (entry != null) {
      final age = now.difference(entry.at);
      if (age < (refresh ? minRefreshInterval : maxAge)) return entry.future;
    }

    final future = Future.sync(load);
    _entries[key] = (future: future, at: now);
    future.then<void>(
      (_) {},
      onError: (Object _) {
        if (identical(_entries[key]?.future, future)) _entries.remove(key);
      },
    );
    return future;
  }

  void invalidate(String key) => _entries.remove(key);
}
