import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../core/utils/logger_util.dart';
import '../models/lyric.dart';
import '../models/song.dart';

class CacheEntry<T> {
  final T data;
  final DateTime cachedAt;
  final DateTime expiresAt;

  CacheEntry({
    required this.data,
    required this.cachedAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  Duration get remainingTime => expiresAt.difference(DateTime.now());
}

class MusicCacheManager {
  static MusicCacheManager? _instance;

  static const String _boxName = 'delta_music_cache';
  static const String _downloadsDirName = 'downloaded_music';
  static const Duration _defaultTtl = Duration(hours: 24);
  static const int _maxMemoryCacheSize = 50;

  late Box _cacheBox;
  String? _downloadsDir;

  final Map<String, CacheEntry<Song>> _songMemoryCache = {};
  final Map<String, CacheEntry<Lyric>> _lyricMemoryCache = {};

  Duration _ttl = _defaultTtl;
  Dio? _downloadDio;

  MusicCacheManager._();

  factory MusicCacheManager() {
    _instance ??= MusicCacheManager._();
    return _instance!;
  }

  Duration get ttl => _ttl;

  Future<void> init({Duration? ttl}) async {
    if (ttl != null) {
      _ttl = ttl;
    }

    _cacheBox = await Hive.openBox(_boxName);

    _downloadDio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 10),
    ));

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${appDir.path}/$_downloadsDirName');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      _downloadsDir = downloadsDir.path;
    } catch (e) {
      AppLogger.e('[CacheManager] Failed to create downloads dir', e);
    }

    AppLogger.i('[CacheManager] Initialized (TTL: ${_ttl.inHours}h, memory limit: $_maxMemoryCacheSize)');
  }

  Future<void> cacheSong(Song song) async {
    try {
      final now = DateTime.now();
      final expiresAt = now.add(_ttl);
      final entry = CacheEntry<Song>(data: song, cachedAt: now, expiresAt: expiresAt);

      _addToMemoryCache(_songMemoryCache, song.id, entry, _maxMemoryCacheSize);

      final cacheData = jsonEncode({
        'song': song.toJson(),
        'cachedAt': now.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
      });
      await _cacheBox.put('song_${song.id}', cacheData);

      AppLogger.d('[CacheManager] Cached song: ${song.name} (expires: ${expiresAt.toIso8601String()})');
    } catch (e) {
      AppLogger.e('[CacheManager] Failed to cache song: ${song.name}', e);
    }
  }

  Song? getCachedSong(String id) {
    try {
      final memEntry = _songMemoryCache[id];
      if (memEntry != null && !memEntry.isExpired) {
        AppLogger.d('[CacheManager] Song cache hit (memory): $id');
        return memEntry.data;
      }

      final raw = _cacheBox.get('song_$id') as String?;
      if (raw == null) {
        AppLogger.d('[CacheManager] Song cache miss: $id');
        return null;
      }

      final data = jsonDecode(raw) as Map<String, dynamic>;
      final expiresAtStr = data['expiresAt'] as String?;
      if (expiresAtStr != null) {
        final expiresAt = DateTime.parse(expiresAtStr);
        if (expiresAt.isBefore(DateTime.now())) {
          AppLogger.d('[CacheManager] Song cache expired: $id');
          _cacheBox.delete('song_$id');
          return null;
        }
      }

      final songJson = data['song'] as Map<String, dynamic>;
      final song = Song.fromJson(Map<String, dynamic>.from(songJson));

      final now = DateTime.now();
      _songMemoryCache[id] = CacheEntry<Song>(
        data: song,
        cachedAt: data['cachedAt'] != null
            ? DateTime.parse(data['cachedAt'] as String)
            : now,
        expiresAt: expiresAtStr != null
            ? DateTime.parse(expiresAtStr)
            : now.add(_ttl),
      );

      AppLogger.d('[CacheManager] Song cache hit (hive): $id');
      return song;
    } catch (e) {
      AppLogger.e('[CacheManager] Failed to get cached song: $id', e);
      return null;
    }
  }

  Future<void> cacheLyric(Lyric lyric) async {
    try {
      final now = DateTime.now();
      final expiresAt = now.add(_ttl);
      final entry = CacheEntry<Lyric>(data: lyric, cachedAt: now, expiresAt: expiresAt);

      _addToMemoryCache(_lyricMemoryCache, lyric.songId, entry, _maxMemoryCacheSize);

      final cacheData = jsonEncode({
        'songId': lyric.songId,
        'hasTranslation': lyric.hasTranslation,
        'lines': lyric.lines
            .map((l) => {
                  'timeMs': l.timeMs,
                  'text': l.text,
                  if (l.translation != null) 'translation': l.translation,
                })
            .toList(),
        'cachedAt': now.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
      });
      await _cacheBox.put('lyric_${lyric.songId}', cacheData);

      AppLogger.d('[CacheManager] Cached lyric: ${lyric.songId}');
    } catch (e) {
      AppLogger.e('[CacheManager] Failed to cache lyric: ${lyric.songId}', e);
    }
  }

  Lyric? getCachedLyric(String songId) {
    try {
      final memEntry = _lyricMemoryCache[songId];
      if (memEntry != null && !memEntry.isExpired) {
        AppLogger.d('[CacheManager] Lyric cache hit (memory): $songId');
        return memEntry.data;
      }

      final raw = _cacheBox.get('lyric_$songId') as String?;
      if (raw == null) {
        AppLogger.d('[CacheManager] Lyric cache miss: $songId');
        return null;
      }

      final data = jsonDecode(raw) as Map<String, dynamic>;
      final expiresAtStr = data['expiresAt'] as String?;
      if (expiresAtStr != null) {
        final expiresAt = DateTime.parse(expiresAtStr);
        if (expiresAt.isBefore(DateTime.now())) {
          AppLogger.d('[CacheManager] Lyric cache expired: $songId');
          _cacheBox.delete('lyric_$songId');
          return null;
        }
      }

      final lines = (data['lines'] as List<dynamic>).map((l) {
        final map = l as Map<String, dynamic>;
        return LyricLine(
          timeMs: map['timeMs'] as int,
          text: map['text'] as String,
          translation: map['translation'] as String?,
        );
      }).toList();

      final lyric = Lyric(
        songId: data['songId'] as String,
        lines: lines,
        hasTranslation: data['hasTranslation'] as bool? ?? false,
      );

      final now = DateTime.now();
      _lyricMemoryCache[songId] = CacheEntry<Lyric>(
        data: lyric,
        cachedAt: data['cachedAt'] != null
            ? DateTime.parse(data['cachedAt'] as String)
            : now,
        expiresAt: expiresAtStr != null
            ? DateTime.parse(expiresAtStr)
            : now.add(_ttl),
      );

      AppLogger.d('[CacheManager] Lyric cache hit (hive): $songId');
      return lyric;
    } catch (e) {
      AppLogger.e('[CacheManager] Failed to get cached lyric: $songId', e);
      return null;
    }
  }

  Future<void> clearExpiredCache() async {
    try {
      final now = DateTime.now();
      int removedFromMemory = 0;
      int removedFromHive = 0;

      _songMemoryCache.removeWhere((key, entry) {
        if (entry.isExpired) {
          removedFromMemory++;
          return true;
        }
        return false;
      });

      _lyricMemoryCache.removeWhere((key, entry) {
        if (entry.isExpired) {
          removedFromMemory++;
          return true;
        }
        return false;
      });

      final keysToRemove = <String>[];
      for (final key in _cacheBox.keys) {
        final raw = _cacheBox.get(key) as String?;
        if (raw == null) continue;
        try {
          final data = jsonDecode(raw) as Map<String, dynamic>;
          final expiresAtStr = data['expiresAt'] as String?;
          if (expiresAtStr != null) {
            final expiresAt = DateTime.parse(expiresAtStr);
            if (expiresAt.isBefore(now)) {
              keysToRemove.add(key);
            }
          }
        } catch (_) {
          keysToRemove.add(key);
        }
      }

      for (final key in keysToRemove) {
        await _cacheBox.delete(key);
        removedFromHive++;
      }

      AppLogger.i(
        '[CacheManager] Expired cache cleared: $removedFromMemory memory entries, $removedFromHive hive entries',
      );
    } catch (e) {
      AppLogger.e('[CacheManager] Failed to clear expired cache', e);
    }
  }

  Future<void> clearAllMemoryCache() async {
    _songMemoryCache.clear();
    _lyricMemoryCache.clear();
    AppLogger.d('[CacheManager] Memory cache cleared');
  }

  Future<void> clearAllHiveCache() async {
    await _cacheBox.clear();
    AppLogger.d('[CacheManager] Hive cache cleared');
  }

  Future<void> clearAllCache() async {
    _songMemoryCache.clear();
    _lyricMemoryCache.clear();
    await _cacheBox.clear();
    AppLogger.i('[CacheManager] All cache cleared');
  }

  Future<String?> downloadSong(String songId) async {
    if (_downloadsDir == null) {
      AppLogger.e('[CacheManager] Downloads directory not available');
      return null;
    }

    final song = getCachedSong(songId);
    if (song == null || song.playUrl == null) {
      AppLogger.e('[CacheManager] Cannot download: song not found or no play URL');
      return null;
    }

    final ext = _getFileExtension(song.playUrl!);
    final filePath = '$_downloadsDir/${song.id}$ext';

    if (await File(filePath).exists()) {
      AppLogger.d('[CacheManager] Song already downloaded: $filePath');
      return filePath;
    }

    try {
      AppLogger.i('[CacheManager] Downloading: ${song.name}');

      await _downloadDio!.download(song.playUrl!, filePath);

      final downloadEntry = jsonEncode({
        'songId': songId,
        'downloadedAt': DateTime.now().toIso8601String(),
        'filePath': filePath,
      });
      await _cacheBox.put('download_$songId', downloadEntry);

      AppLogger.i('[CacheManager] Download complete: ${song.name} -> $filePath');
      return filePath;
    } catch (e) {
      AppLogger.e('[CacheManager] Download failed: ${song.name}', e);

      try {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}

      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getDownloadedSongs() async {
    try {
      final downloaded = <Map<String, dynamic>>[];
      for (final key in _cacheBox.keys) {
        if (key is String && key.startsWith('download_')) {
          final raw = _cacheBox.get(key) as String?;
          if (raw == null) continue;
          try {
            final data = jsonDecode(raw) as Map<String, dynamic>;
            final filePath = data['filePath'] as String?;
            if (filePath != null && await File(filePath).exists()) {
              downloaded.add(data);
            } else {
              await _cacheBox.delete(key);
            }
          } catch (_) {
            await _cacheBox.delete(key);
          }
        }
      }
      AppLogger.d('[CacheManager] Found ${downloaded.length} downloaded songs');
      return downloaded;
    } catch (e) {
      AppLogger.e('[CacheManager] Failed to get downloaded songs', e);
      return [];
    }
  }

  Future<bool> deleteDownloadedSong(String songId) async {
    try {
      final raw = _cacheBox.get('download_$songId') as String?;
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final filePath = data['filePath'] as String?;
        if (filePath != null) {
          final file = File(filePath);
          if (await file.exists()) {
            await file.delete();
          }
        }
      }
      await _cacheBox.delete('download_$songId');
      AppLogger.d('[CacheManager] Deleted download: $songId');
      return true;
    } catch (e) {
      AppLogger.e('[CacheManager] Failed to delete download: $songId', e);
      return false;
    }
  }

  bool isSongDownloaded(String songId) {
    return _cacheBox.containsKey('download_$songId');
  }

  Future<String?> getDownloadedFilePath(String songId) async {
    try {
      final raw = _cacheBox.get('download_$songId') as String?;
      if (raw == null) return null;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final filePath = data['filePath'] as String?;
      if (filePath != null && await File(filePath).exists()) {
        return filePath;
      }
      return null;
    } catch (e) {
      AppLogger.e('[CacheManager] Failed to get downloaded file path: $songId', e);
      return null;
    }
  }

  Future<int> getTotalCacheSize() async {
    try {
      int totalSize = 0;
      for (final key in _cacheBox.keys) {
        final raw = _cacheBox.get(key) as String?;
        if (raw != null) {
          totalSize += raw.length;
        }
      }
      return totalSize;
    } catch (e) {
      AppLogger.e('[CacheManager] Failed to get cache size', e);
      return 0;
    }
  }

  Future<int> getDownloadedSize() async {
    if (_downloadsDir == null) return 0;

    try {
      final dir = Directory(_downloadsDir!);
      if (!await dir.exists()) return 0;

      int totalSize = 0;
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      return totalSize;
    } catch (e) {
      AppLogger.e('[CacheManager] Failed to get downloaded size', e);
      return 0;
    }
  }

  void _addToMemoryCache<T>(
    Map<String, CacheEntry<T>> cache,
    String key,
    CacheEntry<T> entry,
    int maxSize,
  ) {
    if (cache.length >= maxSize) {
      String? oldestKey;
      DateTime? oldestTime;
      for (final e in cache.entries) {
        if (oldestTime == null || e.value.cachedAt.isBefore(oldestTime)) {
          oldestTime = e.value.cachedAt;
          oldestKey = e.key;
        }
      }
      if (oldestKey != null) {
        cache.remove(oldestKey);
      }
    }
    cache[key] = entry;
  }

  String _getFileExtension(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      final path = uri.path;
      final dotIndex = path.lastIndexOf('.');
      if (dotIndex >= 0) {
        final ext = path.substring(dotIndex);
        if (ext.length <= 6) return ext;
      }
    }
    return '.mp3';
  }

  Future<void> dispose() async {
    _songMemoryCache.clear();
    _lyricMemoryCache.clear();
    _downloadDio?.close();
    await _cacheBox.close();
    AppLogger.d('[CacheManager] Disposed');
  }
}