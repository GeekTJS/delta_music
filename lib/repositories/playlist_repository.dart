import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'song_repository.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../models/playlist.dart';
import '../models/song.dart';

final playlistRepositoryProvider = Provider<PlaylistRepository>((ref) {
  return PlaylistRepository(
    api: ref.watch(aggregatedMusicApiProvider),
    storage: ref.watch(storageServiceProvider),
  );
});

class PlaylistRepository {
  final AggregatedMusicApi _api;
  final StorageService _storage;

  PlaylistRepository({
    required AggregatedMusicApi api,
    required StorageService storage,
  })  : _api = api,
        _storage = storage;

  Future<List<Playlist>> getRecommendPlaylists() async {
    return _api.getRecommendPlaylists();
  }

  Future<Playlist?> getPlaylistDetail(String playlistId) async {
    return _api.getPlaylistDetail(playlistId);
  }

  Future<List<Playlist>> loadUserPlaylists() async {
    return _storage.loadPlaylists();
  }

  Future<Playlist?> loadUserPlaylist(String playlistId) async {
    return _storage.loadPlaylist(playlistId);
  }

  Future<void> createPlaylist(Playlist playlist) async {
    await _storage.savePlaylist(playlist);
  }

  Future<void> deletePlaylist(String playlistId) async {
    await _storage.deletePlaylist(playlistId);
  }

  Future<void> addSongToPlaylist(String playlistId, Song song) async {
    final playlist = await _storage.loadPlaylist(playlistId);
    if (playlist == null) return;

    final existingSongs = List<Song>.from(playlist.songs ?? []);
    final alreadyExists = existingSongs.any((s) => s.id == song.id);
    if (alreadyExists) return;

    existingSongs.add(song);
    final updated = playlist.copyWith(
      songs: existingSongs,
      songCount: existingSongs.length,
      updateDate: DateTime.now(),
    );
    await _storage.savePlaylist(updated);
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final playlist = await _storage.loadPlaylist(playlistId);
    if (playlist == null) return;

    final existingSongs = List<Song>.from(playlist.songs ?? []);
    existingSongs.removeWhere((s) => s.id == songId);

    final updated = playlist.copyWith(
      songs: existingSongs,
      songCount: existingSongs.length,
      updateDate: DateTime.now(),
    );
    await _storage.savePlaylist(updated);
  }
}