/// Bellek içi, anahtar (IP) başına kayan pencere sınırlayıcı.
///
/// Tek sunucu örneği için yeterli; birden fazla örnekte sayaçlar paylaşılmaz
/// ve yeniden başlatmada sıfırlanır (README > Bilinen eksikler).
class RateLimiter {
  final int maxRequests;
  final Duration window;
  final DateTime Function() _now;
  final _hits = <String, List<DateTime>>{};

  RateLimiter({
    required this.maxRequests,
    required this.window,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// İsteğe izin verilirse true döner ve isteği sayar.
  bool allow(String key) {
    final now = _now();
    final cutoff = now.subtract(window);

    // Bellek şişmesin diye süresi geçmiş anahtarları ara ara temizle.
    if (_hits.length > 10000) {
      _hits.removeWhere((_, times) => times.last.isBefore(cutoff));
    }

    final times = _hits.putIfAbsent(key, () => [])
      ..removeWhere((t) => t.isBefore(cutoff));
    if (times.length >= maxRequests) return false;
    times.add(now);
    return true;
  }
}
