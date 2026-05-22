import '../core/utils/logger_util.dart';

class ApiFailoverStrategy {
  static const _failureWindow = Duration(minutes: 5);
  static const _failureThreshold = 3;

  final Map<String, _SourceStats> _sourceStats = {};
  final Map<String, String> _songSourceMap = {};
  final List<String> _sourcePriority = ['netease', 'kugou', 'kuwo', 'qq'];
  String _activeSource = 'netease';

  String get activeSource => _activeSource;

  void recordSuccess(String source) {
    final stats = _sourceStats.putIfAbsent(source, () => _SourceStats());
    stats.successCount++;
    stats.lastSuccessTime = DateTime.now();
    _activeSource = source;
    AppLogger.d('[Failover] Recorded success for source: $source');
  }

  void recordSuccessForSong(String songId, String source) {
    _songSourceMap[songId] = source;
    recordSuccess(source);
  }

  void recordFailure(String source) {
    final stats = _sourceStats.putIfAbsent(source, () => _SourceStats());
    stats.failureCount++;
    stats.lastFailureTime = DateTime.now();

    final now = DateTime.now();
    final recentFailures = stats.getRecentFailures(now);
    AppLogger.w(
      '[Failover] Recorded failure for source: $source (${recentFailures.length}/${_failureThreshold} recent failures)',
    );

    if (recentFailures.length >= _failureThreshold && _activeSource == source) {
      _switchToBackup();
    }
  }

  String? getRecordedSource(String songId) {
    return _songSourceMap[songId];
  }

  bool isSourceActive(String source) {
    return _activeSource == source;
  }

  void _switchToBackup() {
    final currentIndex = _sourcePriority.indexOf(_activeSource);
    if (currentIndex == -1) return;

    for (int i = 1; i < _sourcePriority.length; i++) {
      final nextIndex = (currentIndex + i) % _sourcePriority.length;
      final candidate = _sourcePriority[nextIndex];

      if (candidate == _activeSource) continue;

      final stats = _sourceStats[candidate];
      if (stats == null) {
        _activeSource = candidate;
        AppLogger.i('[Failover] Switched to source: $candidate (no previous failures)');
        return;
      }

      final recentFailures = stats.getRecentFailures(DateTime.now());
      if (recentFailures.length < _failureThreshold) {
        _activeSource = candidate;
        AppLogger.i('[Failover] Switched to source: $candidate');
        return;
      }
    }

    AppLogger.e('[Failover] All sources exceeded failure threshold, keeping: $_activeSource');
  }

  void resetStats() {
    _sourceStats.clear();
    _songSourceMap.clear();
    _activeSource = 'netease';
    AppLogger.i('[Failover] All stats reset');
  }

  void resetSourceStats(String source) {
    _sourceStats.remove(source);
    if (_activeSource == source) {
      _activeSource = 'netease';
    }
  }

  Map<String, dynamic> getStats() {
    final result = <String, dynamic>{};
    for (final entry in _sourceStats.entries) {
      result[entry.key] = {
        'successCount': entry.value.successCount,
        'failureCount': entry.value.failureCount,
        'isActive': entry.key == _activeSource,
      };
    }
    return result;
  }
}

class _SourceStats {
  int successCount = 0;
  int failureCount = 0;
  DateTime? lastSuccessTime;
  DateTime? lastFailureTime;
  final List<DateTime> _failureTimestamps = [];

  List<DateTime> getRecentFailures(DateTime now) {
    final cutoff = now.subtract(ApiFailoverStrategy._failureWindow);
    _failureTimestamps.removeWhere((t) => t.isBefore(cutoff));
    return List.unmodifiable(_failureTimestamps);
  }

  set lastFailureTime(DateTime? time) {
    if (time != null) {
      _failureTimestamps.add(time);
    }
  }

  double get successRate {
    final total = successCount + failureCount;
    if (total == 0) return 1.0;
    return successCount / total;
  }
}