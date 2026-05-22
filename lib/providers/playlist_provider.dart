import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/logger_util.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../repositories/playlist_repository.dart';

class PlaylistState {
  final List<Playlist> userPlaylists;
  final Playlist? currentPlaylist;
  final bool isLoading;

  const PlaylistState({
    this.userPlaylists = const [],
    this.currentPlaylist,
    this.isLoading = false,
  });

  PlaylistState copyWith({
    List<Playlist>? userPlaylists,
    Playlist? currentPlaylist,
    bool? isLoading,
    bool clearCurrentPlaylist = false,
  }) {
    return PlaylistState(
      userPlaylists: userPlaylists ?? this.userPlaylists,
      currentPlaylist:
          clearCurrentPlaylist ? null : (currentPlaylist ?? this.currentPlaylist),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class PlaylistNotifier extends StateNotifier<PlaylistState> {
  final PlaylistRepository _repo;

  PlaylistNotifier(this._repo) : super(const PlaylistState());

  Future<void> loadPlaylists() async {
    state = state.copyWith(isLoading: true);
    try {
      final playlists = await _repo.loadUserPlaylists();
      state = state.copyWith(userPlaylists: playlists, isLoading: false);
    } catch (e) {
      AppLogger.e('[PlaylistNotifier] Failed to load playlists', e);
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> createPlaylist(String name, {String? description, String? coverUrl}) async {
    try {
      final playlist = Playlist(
        id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        coverUrl: coverUrl,
        description: description,
        isUserCreated: true,
        songCount: 0,
        songs: [],
        createDate: DateTime.now(),
        updateDate: DateTime.now(),
      );
      await _repo.createPlaylist(playlist);
      await loadPlaylists();
      AppLogger.d('[PlaylistNotifier] Created playlist: $name');
    } catch (e) {
      AppLogger.e('[PlaylistNotifier] Failed to create playlist', e);
    }
  }

  Future<void> deletePlaylist(String playlistId) async {
    try {
      await _repo.deletePlaylist(playlistId);
      await loadPlaylists();
      AppLogger.d('[PlaylistNotifier] Deleted playlist: $playlistId');
    } catch (e) {
      AppLogger.e('[PlaylistNotifier] Failed to delete playlist', e);
    }
  }

  Future<void> addSongToPlaylist(String playlistId, Song song) async {
    try {
      await _repo.addSongToPlaylist(playlistId, song);
      await loadPlaylists();
      AppLogger.d('[PlaylistNotifier] Added song to playlist: ${song.name}');
    } catch (e) {
      AppLogger.e('[PlaylistNotifier] Failed to add song to playlist', e);
    }
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    try {
      await _repo.removeSongFromPlaylist(playlistId, songId);
      await loadPlaylists();
      AppLogger.d('[PlaylistNotifier] Removed song from playlist: $songId');
    } catch (e) {
      AppLogger.e('[PlaylistNotifier] Failed to remove song from playlist', e);
    }
  }
}

final playlistProvider =
    StateNotifierProvider<PlaylistNotifier, PlaylistState>((ref) {
  final repo = ref.watch(playlistRepositoryProvider);
  return PlaylistNotifier(repo);
});