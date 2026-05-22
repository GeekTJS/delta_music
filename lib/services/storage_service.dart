import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/logger_util.dart';
import '../models/lyric.dart';
import '../models/playlist.dart';
import '../models/song.dart';

enum ThemeModeSetting {
  system,
  light,
  dark,
}

class StorageService {
  static StorageService? _instance;

  static const String _settingsBoxName = 'delta_settings';
  static const String _playlistsBoxName = 'delta_playlists';
  static const String _likedSongsBoxName = 'delta_liked_songs';
  static const String _playHistoryBoxName = 'delta_play_history';
  static const String _songCacheBoxName = 'delta_song_cache';
  static const String _lyricCacheBoxName = 'delta_lyric_cache';

  static const String _keyQuality = 'audio_quality';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyLastVolume = 'last_volume';
  static const String _keyEqualizerPreset = 'equalizer_preset';
  static const String _keyAutoPlay = 'auto_play';
  static const String _keySearchHistory = 'search_history';

  late Box _settingsBox;
  late Box _playlistsBox;
  late Box<Map> _likedSongsBox;
  late Box<Map> _playHistoryBox;
  late Box<String> _songCacheBox;
  late Box<String> _lyricCacheBox;

  StorageService._();

  factory StorageService() {
    _instance ??= StorageService._();
    return _instance!;
  }

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    await Hive.initFlutter();

    _settingsBox = await Hive.openBox(_settingsBoxName);
    _playlistsBox = await Hive.openBox(_playlistsBoxName);
    _likedSongsBox = await Hive.openBox<Map>(_likedSongsBoxName);
    _playHistoryBox = await Hive.openBox<Map>(_playHistoryBoxName);
    _songCacheBox = await Hive.openBox<String>(_songCacheBoxName);
    _lyricCacheBox = await Hive.openBox<String>(_lyricCacheBoxName);

    _initialized = true;
    AppLogger.i('[Storage] Initialized');
  }

  int get defaultQuality =>
      _settingsBox.get(_keyQuality, defaultValue: 320) as int;

  void setDefaultQuality(int quality) {
    _settingsBox.put(_keyQuality, quality);
    AppLogger.d('[Storage] Quality set: ${AppConstants.qualityLabel(quality)}');
  }

  ThemeModeSetting get themeMode {
    final index = _settingsBox.get(_keyThemeMode, defaultValue: 0) as int;
    return ThemeModeSetting.values[index.clamp(0, ThemeModeSetting.values.length - 1)];
  }

  void setThemeMode(ThemeModeSetting mode) {
    _settingsBox.put(_keyThemeMode, mode.index);
    AppLogger.d('[Storage] Theme mode set: ${mode.name}');
  }

  double get lastVolume =>
      (_settingsBox.get(_keyLastVolume, defaultValue: 0.7) as num).toDouble();

  void setLastVolume(double volume) {
    _settingsBox.put(_keyLastVolume, volume);
  }

  String? get equalizerPreset =>
      _settingsBox.get(_keyEqualizerPreset) as String?;

  void setEqualizerPreset(String? preset) {
    if (preset != null) {
      _settingsBox.put(_keyEqualizerPreset, preset);
    } else {
      _settingsBox.delete(_keyEqualizerPreset);
    }
  }

  bool get autoPlay =>
      _settingsBox.get(_keyAutoPlay, defaultValue: true) as bool;

  void setAutoPlay(bool value) {
    _settingsBox.put(_keyAutoPlay, value);
  }

  List<String> getSearchHistory() {
    try {
      final raw = _settingsBox.get(_keySearchHistory);
      if (raw == null) return [];
      if (raw is String) {
        final list = jsonDecode(raw) as List<dynamic>;
        return list.cast<String>();
      }
      return [];
    } catch (e) {
      AppLogger.e('[Storage] Failed to get search history', e);
      return [];
    }
  }

  Future<void> addSearchHistory(String keyword) async {
    try {
      final history = getSearchHistory();
      history.remove(keyword);
      history.insert(0, keyword);
      if (history.length > 50) {
        history.removeRange(50, history.length);
      }
      await _settingsBox.put(_keySearchHistory, jsonEncode(history));
    } catch (e) {
      AppLogger.e('[Storage] Failed to add search history', e);
    }
  }

  Future<void> clearSearchHistory() async {
    try {
      await _settingsBox.delete(_keySearchHistory);
      AppLogger.d('[Storage] Search history cleared');
    } catch (e) {
      AppLogger.e('[Storage] Failed to clear search history', e);
    }
  }

  Future<List<Playlist>> loadPlaylists() async {
    try {
      final playlists = <Playlist>[];
      for (final key in _playlistsBox.keys) {
        final raw = _playlistsBox.get(key);
        if (raw != null) {
          final json = raw is String ? jsonDecode(raw) : raw;
          playlists.add(Playlist.fromJson(Map<String, dynamic>.from(json)));
        }
      }
      AppLogger.d('[Storage] Loaded ${playlists.length} playlists');
      return playlists;
    } catch (e) {
      AppLogger.e('[Storage] Failed to load playlists', e);
      return [];
    }
  }

  Future<Playlist?> loadPlaylist(String playlistId) async {
    try {
      final raw = _playlistsBox.get(playlistId);
      if (raw == null) return null;
      final json = raw is String ? jsonDecode(raw) : raw;
      return Playlist.fromJson(Map<String, dynamic>.from(json));
    } catch (e) {
      AppLogger.e('[Storage] Failed to load playlist: $playlistId', e);
      return null;
    }
  }

  Future<void> savePlaylist(Playlist playlist) async {
    try {
      await _playlistsBox.put(playlist.id, playlist.toJson());
      AppLogger.d('[Storage] Saved playlist: ${playlist.name}');
    } catch (e) {
      AppLogger.e('[Storage] Failed to save playlist: ${playlist.name}', e);
    }
  }

  Future<void> savePlaylists(List<Playlist> playlists) async {
    try {
      await _playlistsBox.clear();
      for (final playlist in playlists) {
        await _playlistsBox.put(playlist.id, playlist.toJson());
      }
      AppLogger.d('[Storage] Saved ${playlists.length} playlists');
    } catch (e) {
      AppLogger.e('[Storage] Failed to save playlists', e);
    }
  }

  Future<void> deletePlaylist(String playlistId) async {
    try {
      await _playlistsBox.delete(playlistId);
      AppLogger.d('[Storage] Deleted playlist: $playlistId');
    } catch (e) {
      AppLogger.e('[Storage] Failed to delete playlist: $playlistId', e);
    }
  }

  List<Song> loadLikedSongs() {
    try {
      final songs = <Song>[];
      for (final key in _likedSongsBox.keys) {
        final raw = _likedSongsBox.get(key);
        if (raw != null) {
          final json = raw is String ? jsonDecode(raw) : raw;
          songs.add(Song.fromJson(Map<String, dynamic>.from(json)));
        }
      }
      AppLogger.d('[Storage] Loaded ${songs.length} liked songs');
      return songs;
    } catch (e) {
      AppLogger.e('[Storage] Failed to load liked songs', e);
      return [];
    }
  }

  Future<void> addLikedSong(Song song) async {
    try {
      await _likedSongsBox.put(song.id, song.toJson());
      AppLogger.d('[Storage] Liked song: ${song.name}');
    } catch (e) {
      AppLogger.e('[Storage] Failed to add liked song: ${song.name}', e);
    }
  }

  Future<void> removeLikedSong(String songId) async {
    try {
      await _likedSongsBox.delete(songId);
      AppLogger.d('[Storage] Unliked song: $songId');
    } catch (e) {
      AppLogger.e('[Storage] Failed to remove liked song: $songId', e);
    }
  }

  bool isSongLiked(String songId) {
    return _likedSongsBox.containsKey(songId);
  }

  Future<void> toggleLikeSong(Song song) async {
    if (isSongLiked(song.id)) {
      await removeLikedSong(song.id);
    } else {
      await addLikedSong(song);
    }
  }

  List<Song> loadPlayHistory() {
    try {
      final songs = <Song>[];
      final entries = _playHistoryBox.toMap().entries.toList()
        ..sort((a, b) {
          final aValue = a.value is Map ? ((a.value as Map)['playedAt'] as num?)?.toInt() ?? 0 : 0;
          final bValue = b.value is Map ? ((b.value as Map)['playedAt'] as num?)?.toInt() ?? 0 : 0;
          return bValue.compareTo(aValue);
        });

      for (final entry in entries) {
        final raw = entry.value;
        if (raw != null) {
          final songRaw = raw is Map ? (raw['song'] ?? raw) : raw;
          final json = songRaw is String ? jsonDecode(songRaw) : songRaw;
          songs.add(Song.fromJson(Map<String, dynamic>.from(json)));
        }
      }
      AppLogger.d('[Storage] Loaded ${songs.length} history entries');
      return songs;
    } catch (e) {
      AppLogger.e('[Storage] Failed to load play history', e);
      return [];
    }
  }

  Future<void> addPlayHistory(Song song) async {
    try {
      final entry = {
        'song': song.toJson(),
        'playedAt': DateTime.now().millisecondsSinceEpoch,
      };
      await _playHistoryBox.put(song.id, entry);
    } catch (e) {
      AppLogger.e('[Storage] Failed to add play history: ${song.name}', e);
    }
  }

  Future<void> clearPlayHistory() async {
    try {
      await _playHistoryBox.clear();
      AppLogger.d('[Storage] Play history cleared');
    } catch (e) {
      AppLogger.e('[Storage] Failed to clear play history', e);
    }
  }

  Future<void> cacheSongMetadata(Song song) async {
    try {
      await _songCacheBox.put(song.id, jsonEncode(song.toJson()));
    } catch (e) {
      AppLogger.e('[Storage] Failed to cache song: ${song.name}', e);
    }
  }

  Song? getCachedSongMetadata(String songId) {
    try {
      final raw = _songCacheBox.get(songId);
      if (raw == null) return null;
      return Song.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      AppLogger.e('[Storage] Failed to get cached song: $songId', e);
      return null;
    }
  }

  Future<void> cacheLyric(Lyric lyric) async {
    try {
      final data = {
        'songId': lyric.songId,
        'hasTranslation': lyric.hasTranslation,
        'lines': lyric.lines.map((l) => {
          'timeMs': l.timeMs,
          'text': l.text,
          if (l.translation != null) 'translation': l.translation,
        }).toList(),
      };
      await _lyricCacheBox.put(lyric.songId, jsonEncode(data));
    } catch (e) {
      AppLogger.e('[Storage] Failed to cache lyric: ${lyric.songId}', e);
    }
  }

  Lyric? getCachedLyric(String songId) {
    try {
      final raw = _lyricCacheBox.get(songId);
      if (raw == null) return null;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final lines = (data['lines'] as List<dynamic>).map((l) {
        final map = l as Map<String, dynamic>;
        return LyricLine(
          timeMs: map['timeMs'] as int,
          text: map['text'] as String,
          translation: map['translation'] as String?,
        );
      }).toList();
      return Lyric(
        songId: data['songId'] as String,
        lines: lines,
        hasTranslation: data['hasTranslation'] as bool? ?? false,
      );
    } catch (e) {
      AppLogger.e('[Storage] Failed to get cached lyric: $songId', e);
      return null;
    }
  }

  Future<void> clearCache() async {
    try {
      await _songCacheBox.clear();
      await _lyricCacheBox.clear();
      AppLogger.d('[Storage] Cache cleared');
    } catch (e) {
      AppLogger.e('[Storage] Failed to clear cache', e);
    }
  }

  Future<void> clearAll() async {
    try {
      await _settingsBox.clear();
      await _playlistsBox.clear();
      await _likedSongsBox.clear();
      await _playHistoryBox.clear();
      await _songCacheBox.clear();
      await _lyricCacheBox.clear();
      AppLogger.d('[Storage] All data cleared');
    } catch (e) {
      AppLogger.e('[Storage] Failed to clear all data', e);
    }
  }

  Future<void> dispose() async {
    await _settingsBox.close();
    await _playlistsBox.close();
    await _likedSongsBox.close();
    await _playHistoryBox.close();
    await _songCacheBox.close();
    await _lyricCacheBox.close();
    AppLogger.d('[Storage] Disposed');
  }
}