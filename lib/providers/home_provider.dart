import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/logger_util.dart';
import '../models/playlist.dart';
import '../models/chart.dart';
import '../models/song.dart';
import '../repositories/playlist_repository.dart';
import '../repositories/song_repository.dart';

class HomeState {
  final List<Playlist> recommendPlaylists;
  final List<Chart> charts;
  final List<Song> newSongs;
  final bool isLoading;

  const HomeState({
    this.recommendPlaylists = const [],
    this.charts = const [],
    this.newSongs = const [],
    this.isLoading = false,
  });

  HomeState copyWith({
    List<Playlist>? recommendPlaylists,
    List<Chart>? charts,
    List<Song>? newSongs,
    bool? isLoading,
  }) {
    return HomeState(
      recommendPlaylists: recommendPlaylists ?? this.recommendPlaylists,
      charts: charts ?? this.charts,
      newSongs: newSongs ?? this.newSongs,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class HomeNotifier extends StateNotifier<HomeState> {
  final PlaylistRepository _playlistRepo;
  final SongRepository _songRepo;

  HomeNotifier(this._playlistRepo, this._songRepo) : super(const HomeState());

  Future<void> loadHomeData() async {
    state = state.copyWith(isLoading: true);
    try {
      final results = await Future.wait([
        _playlistRepo.getRecommendPlaylists(),
        _songRepo.searchSongs('热门', limit: 10),
        _songRepo.searchSongs('新歌', limit: 15),
      ]);

      final recommendPlaylists = results[0] as List<Playlist>;
      final charts = _buildMockCharts(results[1] as List<Song>);
      final newSongs = results[2] as List<Song>;

      state = state.copyWith(
        recommendPlaylists: recommendPlaylists,
        charts: charts,
        newSongs: newSongs,
        isLoading: false,
      );
    } catch (e) {
      AppLogger.e('[HomeNotifier] Failed to load home data', e);
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> refreshRecommendations() async {
    try {
      final playlists = await _playlistRepo.getRecommendPlaylists();
      state = state.copyWith(recommendPlaylists: playlists);
    } catch (e) {
      AppLogger.e('[HomeNotifier] Failed to refresh recommendations', e);
    }
  }

  Future<void> refreshCharts() async {
    try {
      final songs = await _songRepo.searchSongs('热门', limit: 10);
      final charts = _buildMockCharts(songs);
      state = state.copyWith(charts: charts);
    } catch (e) {
      AppLogger.e('[HomeNotifier] Failed to refresh charts', e);
    }
  }

  Future<void> refreshNewSongs() async {
    try {
      final songs = await _songRepo.searchSongs('新歌', limit: 15);
      state = state.copyWith(newSongs: songs);
    } catch (e) {
      AppLogger.e('[HomeNotifier] Failed to refresh new songs', e);
    }
  }

  List<Chart> _buildMockCharts(List<Song> songs) {
    final chartNames = ['热歌榜', '新歌榜', '飙升榜', '原创榜', 'MV榜'];
    final chartTypes = ['hot', 'new', 'rising', 'original', 'mv'];
    final charts = <Chart>[];

    for (int i = 0; i < chartNames.length; i++) {
      final start = (i * 2) % songs.length;
      final end = (start + 10).clamp(0, songs.length);
      final chartSongs = songs.sublist(start, end);

      charts.add(Chart(
        id: 'chart_$i',
        name: chartNames[i],
        type: chartTypes[i],
        coverUrl: chartSongs.isNotEmpty ? chartSongs.first.coverUrl : null,
        songs: chartSongs,
        updateDate: DateTime.now(),
      ));
    }

    return charts;
  }
}

final homeProvider =
    StateNotifierProvider<HomeNotifier, HomeState>((ref) {
  final playlistRepo = ref.watch(playlistRepositoryProvider);
  final songRepo = ref.watch(songRepositoryProvider);
  return HomeNotifier(playlistRepo, songRepo);
});