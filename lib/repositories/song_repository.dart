import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/music_cache_manager.dart';
import '../models/song.dart';
import '../models/lyric.dart';

final aggregatedMusicApiProvider = Provider<AggregatedMusicApi>((ref) {
  return AggregatedMusicApi();
});

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

final musicCacheManagerProvider = Provider<MusicCacheManager>((ref) {
  return MusicCacheManager();
});

final songRepositoryProvider = Provider<SongRepository>((ref) {
  return SongRepository(
    api: ref.watch(aggregatedMusicApiProvider),
    storage: ref.watch(storageServiceProvider),
    cache: ref.watch(musicCacheManagerProvider),
  );
});

class SongRepository {
  final AggregatedMusicApi _api;
  final StorageService _storage;
  final MusicCacheManager _cache;

  SongRepository({
    required AggregatedMusicApi api,
    required StorageService storage,
    required MusicCacheManager cache,
  })  : _api = api,
        _storage = storage,
        _cache = cache;

  Future<List<Song>> searchSongs(String keyword, {int limit = 30}) async {
    return _api.searchSongs(keyword, limit: limit);
  }

  Future<Song?> getSongDetail(String songId) async {
    final cached = _cache.getCachedSong(songId);
    if (cached != null) return cached;
    final song = await _api.getSongDetail(songId);
    if (song != null) _cache.cacheSong(song);
    return song;
  }

  Future<String?> getPlayUrl(String songId, {int quality = 320}) async {
    return _api.getPlayUrl(songId, quality: quality);
  }

  Future<Lyric?> getLyric(String songId) async {
    final cached = _cache.getCachedLyric(songId);
    if (cached != null) return cached;
    final lyric = await _api.getLyric(songId);
    if (lyric != null) _cache.cacheLyric(lyric);
    return lyric;
  }

  bool isLiked(String songId) => _storage.isSongLiked(songId);
  Future<void> toggleLike(Song song) => _storage.toggleLikeSong(song);
  Future<void> addToHistory(Song song) => _storage.addPlayHistory(song);
  List<Song> getPlayHistory() => _storage.loadPlayHistory();
  List<Song> getLikedSongs() => _storage.loadLikedSongs();
}