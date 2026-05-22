import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/logger_util.dart';
import '../models/song.dart';
import '../repositories/song_repository.dart';
import '../services/audio_player_service.dart';

final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  return AudioPlayerService();
});

class MusicPlayerState {
  final Song? currentSong;
  final List<Song> playlist;
  final int currentIndex;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final PlaybackMode playbackMode;
  final bool isBuffering;
  final bool hasError;
  final String? errorMessage;

  const MusicPlayerState({
    this.currentSong,
    this.playlist = const [],
    this.currentIndex = -1,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.playbackMode = PlaybackMode.sequential,
    this.isBuffering = false,
    this.hasError = false,
    this.errorMessage,
  });

  MusicPlayerState copyWith({
    Song? currentSong,
    List<Song>? playlist,
    int? currentIndex,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    PlaybackMode? playbackMode,
    bool? isBuffering,
    bool? hasError,
    String? errorMessage,
    bool clearError = false,
    bool clearCurrentSong = false,
  }) {
    return MusicPlayerState(
      currentSong: clearCurrentSong ? null : (currentSong ?? this.currentSong),
      playlist: playlist ?? this.playlist,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      playbackMode: playbackMode ?? this.playbackMode,
      isBuffering: isBuffering ?? this.isBuffering,
      hasError: clearError ? false : (hasError ?? this.hasError),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class MusicPlayerNotifier extends StateNotifier<MusicPlayerState> {
  final AudioPlayerService _player;
  final SongRepository _songRepo;
  final Ref _ref;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<AudioPlayerState>? _playerStateSub;
  StreamSubscription<Song?>? _currentSongSub;

  MusicPlayerNotifier(this._player, this._songRepo, this._ref)
      : super(const MusicPlayerState()) {
    _listenToPlayer();
  }

  void _listenToPlayer() {
    _positionSub = _player.positionStream.listen((position) {
      if (mounted) {
        state = state.copyWith(position: position);
      }
    });

    _durationSub = _player.durationStream.listen((duration) {
      if (mounted && duration != Duration.zero) {
        state = state.copyWith(duration: duration);
      }
    });

    _playerStateSub = _player.playerStateStream.listen((playerState) {
      if (!mounted) return;
      switch (playerState) {
        case AudioPlayerState.loading:
          state = state.copyWith(
            isBuffering: true,
            isPlaying: false,
            hasError: false,
            clearError: true,
          );
          break;
        case AudioPlayerState.playing:
          state = state.copyWith(
            isPlaying: true,
            isBuffering: false,
            hasError: false,
            clearError: true,
          );
          break;
        case AudioPlayerState.paused:
          state = state.copyWith(isPlaying: false, isBuffering: false);
          break;
        case AudioPlayerState.completed:
          state = state.copyWith(isPlaying: false, isBuffering: false);
          break;
        case AudioPlayerState.stopped:
          state = state.copyWith(
            isPlaying: false,
            isBuffering: false,
            position: Duration.zero,
          );
          break;
        case AudioPlayerState.error:
          state = state.copyWith(
            isPlaying: false,
            isBuffering: false,
            hasError: true,
            errorMessage: '播放出错，请重试',
          );
          break;
        case AudioPlayerState.idle:
          break;
      }
    });

    _currentSongSub = _player.currentSongStream.listen((song) {
      if (!mounted) return;
      if (song != null) {
        state = state.copyWith(currentSong: song);
        _songRepo.addToHistory(song);
      }
    });
  }

  Future<void> playSong(Song song) async {
    try {
      final url = await _songRepo.getPlayUrl(song.id);
      final resolvedSong = url != null ? song.copyWith(playUrl: url) : song;
      await _player.play(resolvedSong);
      state = state.copyWith(hasError: false, clearError: true);
    } catch (e) {
      AppLogger.e('[PlayerNotifier] Failed to play song', e);
      state = state.copyWith(hasError: true, errorMessage: '播放失败: ${song.name}');
    }
  }

  Future<void> playPlaylist(List<Song> songs, int startIndex) async {
    try {
      if (songs.isEmpty) return;
      final resolvedSongs = <Song>[];
      for (final song in songs) {
        final url = await _songRepo.getPlayUrl(song.id);
        resolvedSongs.add(url != null ? song.copyWith(playUrl: url) : song);
      }
      _player.setPlaylist(resolvedSongs, startIndex);
      state = state.copyWith(
        playlist: resolvedSongs,
        currentIndex: startIndex,
        hasError: false,
        clearError: true,
      );
    } catch (e) {
      AppLogger.e('[PlayerNotifier] Failed to play playlist', e);
      state = state.copyWith(hasError: true, errorMessage: '播放列表加载失败');
    }
  }

  Future<void> togglePlayPause() async {
    try {
      if (state.isPlaying) {
        await _player.pause();
      } else {
        if (state.currentSong == null && state.playlist.isNotEmpty) {
          await playPlaylist(state.playlist, 0);
        } else {
          await _player.resume();
        }
      }
    } catch (e) {
      AppLogger.e('[PlayerNotifier] Toggle play/pause failed', e);
    }
  }

  Future<void> next() async {
    try {
      await _player.next();
    } catch (e) {
      AppLogger.e('[PlayerNotifier] Next failed', e);
    }
  }

  Future<void> previous() async {
    try {
      await _player.previous();
    } catch (e) {
      AppLogger.e('[PlayerNotifier] Previous failed', e);
    }
  }

  Future<void> seekTo(Duration position) async {
    try {
      await _player.seekTo(position);
      state = state.copyWith(position: position);
    } catch (e) {
      AppLogger.e('[PlayerNotifier] Seek failed', e);
    }
  }

  void setPlaybackMode(PlaybackMode mode) {
    _player.setPlaybackMode(mode);
    state = state.copyWith(playbackMode: mode);
  }

  void addToQueue(Song song) {
    _player.addToQueue(song);
    final newPlaylist = List<Song>.from(state.playlist)..add(song);
    state = state.copyWith(playlist: newPlaylist);
  }

  void removeFromQueue(int index) {
    _player.removeFromQueue(index);
    final newPlaylist = List<Song>.from(state.playlist);
    if (index >= 0 && index < newPlaylist.length) {
      newPlaylist.removeAt(index);
      state = state.copyWith(playlist: newPlaylist);
    }
  }

  void clearQueue() {
    _player.clearQueue();
    state = state.copyWith(playlist: [], currentIndex: -1, clearCurrentSong: true);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playerStateSub?.cancel();
    _currentSongSub?.cancel();
    super.dispose();
  }
}

final musicPlayerProvider =
    StateNotifierProvider<MusicPlayerNotifier, MusicPlayerState>((ref) {
  final player = ref.watch(audioPlayerServiceProvider);
  final songRepo = ref.watch(songRepositoryProvider);
  return MusicPlayerNotifier(player, songRepo, ref);
});

final positionStreamProvider = StreamProvider<Duration>((ref) {
  final player = ref.watch(audioPlayerServiceProvider);
  return player.positionStream;
});

final durationStreamProvider = StreamProvider<Duration>((ref) {
  final player = ref.watch(audioPlayerServiceProvider);
  return player.durationStream;
});

final isPlayingStreamProvider = StreamProvider<bool>((ref) {
  final player = ref.watch(audioPlayerServiceProvider);
  return player.playerStateStream.map((s) => s == AudioPlayerState.playing);
});