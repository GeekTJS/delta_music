import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/logger_util.dart';
import '../models/song.dart';

enum AudioPlayerState {
  idle,
  loading,
  playing,
  paused,
  stopped,
  completed,
  error,
}

class AudioPlayerService {
  static AudioPlayerService? _instance;

  final AudioPlayer _player;
  DeltaMusicAudioHandler? _audioHandler;
  List<Song> _playlist = [];
  int _currentIndex = -1;
  PlaybackMode _playbackMode = PlaybackMode.sequential;

  final _playerStateController = StreamController<AudioPlayerState>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();
  final _currentSongController = StreamController<Song?>.broadcast();
  final _queueController = StreamController<List<MediaItem>>.broadcast();

  AudioPlayerState _currentState = AudioPlayerState.idle;
  AudioPlayerState get currentState => _currentState;

  AudioPlayerService._() : _player = AudioPlayer() {
    _setupPlayerListeners();
  }

  factory AudioPlayerService() {
    _instance ??= AudioPlayerService._();
    return _instance!;
  }

  AudioPlayer get audioPlayer => _player;

  Stream<AudioPlayerState> get playerStateStream => _playerStateController.stream;
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration> get durationStream => _durationController.stream;
  Stream<Song?> get currentSongStream => _currentSongController.stream;
  Stream<List<MediaItem>> get queueStream => _queueController.stream;

  Song? get currentSong =>
      _currentIndex >= 0 && _currentIndex < _playlist.length
          ? _playlist[_currentIndex]
          : null;

  int get currentIndex => _currentIndex;
  List<Song> get playlist => List.unmodifiable(_playlist);
  PlaybackMode get playbackMode => _playbackMode;

  Future<void> init() async {
    try {
      _audioHandler = await AudioService.init(
        builder: () => DeltaMusicAudioHandler(this),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'delta_music_channel',
          androidNotificationChannelName: '三角洲音乐播放',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: false,
          androidNotificationChannelDescription: '音乐播放控制通知',
          notificationColor: 0xFF1DB954,
          androidNotificationIcon: 'drawable/ic_notification',
          androidStopOnRemoveTask: false,
          androidMediaSessionEnabled: true,
        ),
      );
      _audioHandler?.playbackState.add(const PlaybackState(
        controls: [MediaControl.play],
        systemActions: const {},
        androidCompactActionIndices: const [0],
        processingState: AudioProcessingState.idle,
        playing: false,
      ));
      AppLogger.i('[AudioPlayer] Initialized');
    } catch (e) {
      AppLogger.e('[AudioPlayer] Init failed', e);
      rethrow;
    }
  }

  void _setupPlayerListeners() {
    _player.playerStateStream.listen((state) {
      AudioPlayerState playerState;
      if (state.playing) {
        playerState = AudioPlayerState.playing;
      } else if (state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering) {
        playerState = AudioPlayerState.loading;
      } else if (state.processingState == ProcessingState.completed) {
        playerState = AudioPlayerState.completed;
        _onTrackCompleted();
      } else {
        playerState = AudioPlayerState.paused;
      }
      _updateState(playerState);
    });

    _player.positionStream.listen((position) {
      _positionController.add(position);
      _audioHandler?.mediaItem.value?.let((item) {
        _audioHandler?.playbackState.add(_audioHandler!.playbackState.value.copyWith(
              updatePosition: position,
            ));
      });
    });

    _player.durationStream.listen((duration) {
      if (duration != null) {
        _durationController.add(duration);
      }
    });

    _player.playbackEventStream.listen((event) {
      AppLogger.d(
        '[AudioPlayer] Event: buffer=${event.bufferedPosition}, processing=${event.processingState}',
      );
    });
  }

  void _updateState(AudioPlayerState state) {
    if (_currentState == state) return;
    _currentState = state;
    _playerStateController.add(state);
    _syncAudioServiceState(state);
  }

  void _syncAudioServiceState(AudioPlayerState state) {
    if (_audioHandler == null) return;

    final controls = _buildControls(state);
    final processingState = _toAudioProcessingState(state);

    _audioHandler!.playbackState.add(PlaybackState(
      controls: controls,
      systemActions: const {},
      androidCompactActionIndices: _buildCompactActionIndices(controls),
      processingState: processingState,
      playing: state == AudioPlayerState.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      repeatMode: _playbackMode == PlaybackMode.singleLoop
          ? AudioServiceRepeatMode.one
          : AudioServiceRepeatMode.none,
      shuffleMode: _playbackMode == PlaybackMode.random
          ? AudioServiceShuffleMode.all
          : AudioServiceShuffleMode.none,
    ));
  }

  List<MediaControl> _buildControls(AudioPlayerState state) {
    final controls = <MediaControl>[];
    final hasPrev = _currentIndex > 0 || _playbackMode == PlaybackMode.random;
    final hasNext = _canPlayNextInternal();

    controls.add(hasPrev ? MediaControl.skipToPrevious : MediaControl.skipToPrevious.copyWith());
    if (state == AudioPlayerState.playing) {
      controls.add(MediaControl.pause);
    } else {
      controls.add(MediaControl.play);
    }
    controls.add(hasNext ? MediaControl.skipToNext : MediaControl.skipToNext.copyWith());
    controls.add(MediaControl.stop);

    return controls;
  }

  List<int> _buildCompactActionIndices(List<MediaControl> controls) {
    return [0, 1, 2];
  }

  AudioProcessingState _toAudioProcessingState(AudioPlayerState state) {
    switch (state) {
      case AudioPlayerState.loading:
        return AudioProcessingState.buffering;
      case AudioPlayerState.playing:
        return AudioProcessingState.ready;
      case AudioPlayerState.paused:
        return AudioProcessingState.ready;
      case AudioPlayerState.completed:
        return AudioProcessingState.completed;
      case AudioPlayerState.stopped:
        return AudioProcessingState.idle;
      case AudioPlayerState.error:
        return AudioProcessingState.error;
      case AudioPlayerState.idle:
        return AudioProcessingState.idle;
    }
  }

  Future<void> play(Song song) async {
    try {
      final index = _playlist.indexWhere((s) => s.id == song.id);
      if (index >= 0) {
        _currentIndex = index;
      } else {
        _playlist = [song];
        _currentIndex = 0;
      }

      await _loadAndPlay(song);
      AppLogger.d('[AudioPlayer] Playing: ${song.name}');
    } catch (e) {
      _updateState(AudioPlayerState.error);
      AppLogger.e('[AudioPlayer] Play failed', e);
      rethrow;
    }
  }

  Future<void> _loadAndPlay(Song song) async {
    final url = song.playUrl;
    if (url == null || url.isEmpty) {
      throw Exception('No play URL for song: ${song.name}');
    }

    _updateState(AudioPlayerState.loading);

    await _player.setAudioSource(
      AudioSource.uri(Uri.parse(url), tag: _songToMediaItem(song)),
    );

    await _player.play();
    _currentSongController.add(song);

    _audioHandler?.mediaItem.add(_songToMediaItem(song));
    _audioHandler?.queue.add(_buildQueue());
  }

  Future<void> pause() async {
    await _player.pause();
    _updateState(AudioPlayerState.paused);
    AppLogger.d('[AudioPlayer] Paused');
  }

  Future<void> resume() async {
    await _player.play();
    _updateState(AudioPlayerState.playing);
    AppLogger.d('[AudioPlayer] Resumed');
  }

  Future<void> stop() async {
    await _player.stop();
    _updateState(AudioPlayerState.stopped);
    _currentIndex = -1;
    _currentSongController.add(null);
    _audioHandler?.mediaItem.add(null);
    AppLogger.d('[AudioPlayer] Stopped');
  }

  Future<void> next() async {
    if (_playlist.isEmpty) return;

    switch (_playbackMode) {
      case PlaybackMode.sequential:
        if (_currentIndex < _playlist.length - 1) {
          _currentIndex++;
        } else {
          _updateState(AudioPlayerState.completed);
          return;
        }
        break;
      case PlaybackMode.random:
        int newIndex;
        if (_playlist.length == 1) {
          _updateState(AudioPlayerState.completed);
          return;
        }
        do {
          newIndex = Random().nextInt(_playlist.length);
        } while (newIndex == _currentIndex);
        _currentIndex = newIndex;
        break;
      case PlaybackMode.singleLoop:
        break;
    }

    final song = _playlist[_currentIndex];
    await _loadAndPlay(song);
    AppLogger.d('[AudioPlayer] Next: ${song.name}');
  }

  Future<void> previous() async {
    if (_playlist.isEmpty) return;

    final position = _player.position;
    if (position > const Duration(seconds: 3)) {
      await _player.seek(Duration.zero);
      AppLogger.d('[AudioPlayer] Seeked to start');
      return;
    }

    switch (_playbackMode) {
      case PlaybackMode.sequential:
        if (_currentIndex > 0) {
          _currentIndex--;
        } else {
          await _player.seek(Duration.zero);
          return;
        }
        break;
      case PlaybackMode.random:
        if (_playlist.length <= 1) {
          await _player.seek(Duration.zero);
          return;
        }
        _currentIndex = Random().nextInt(_playlist.length);
        break;
      case PlaybackMode.singleLoop:
        await _player.seek(Duration.zero);
        AppLogger.d('[AudioPlayer] Restarted track (single loop)');
        return;
    }

    final song = _playlist[_currentIndex];
    await _loadAndPlay(song);
    AppLogger.d('[AudioPlayer] Previous: ${song.name}');
  }

  Future<void> seekTo(Duration position) async {
    await _player.seek(position);
    AppLogger.d('[AudioPlayer] Seeked to: $position');
  }

  void setPlaybackMode(PlaybackMode mode) {
    _playbackMode = mode;
    _syncAudioServiceState(_currentState);
    AppLogger.d('[AudioPlayer] Mode: ${AppConstants.playbackModeLabel(mode)}');
  }

  void setPlaylist(List<Song> songs, int startIndex) {
    _playlist = List.from(songs);
    _currentIndex = (startIndex >= 0 && startIndex < songs.length) ? startIndex : 0;

    _audioHandler?.queue.add(_buildQueue());

    if (_playlist.isNotEmpty) {
      play(_playlist[_currentIndex]);
    }

    AppLogger.d('[AudioPlayer] Playlist set: ${songs.length} songs, start=$startIndex');
  }

  void addToQueue(Song song) {
    _playlist.add(song);
    _audioHandler?.queue.add(_buildQueue());
    AppLogger.d('[AudioPlayer] Added to queue: ${song.name}');
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= _playlist.length) return;

    final removed = _playlist.removeAt(index);
    if (index < _currentIndex) {
      _currentIndex--;
    } else if (index == _currentIndex) {
      if (_playlist.isNotEmpty) {
        _currentIndex = min(_currentIndex, _playlist.length - 1);
        _loadAndPlay(_playlist[_currentIndex]);
      } else {
        stop();
      }
    }

    _audioHandler?.queue.add(_buildQueue());
    AppLogger.d('[AudioPlayer] Removed from queue: ${removed.name}');
  }

  void clearQueue() {
    _playlist.clear();
    _currentIndex = -1;
    stop();
    _audioHandler?.queue.add([]);
    AppLogger.d('[AudioPlayer] Queue cleared');
  }

  void _onTrackCompleted() {
    if (_playbackMode == PlaybackMode.singleLoop) {
      _player.seek(Duration.zero);
      _player.play();
      return;
    }
    if (_canPlayNextInternal()) {
      next();
    } else {
      _updateState(AudioPlayerState.completed);
    }
  }

  bool _canPlayNextInternal() {
    switch (_playbackMode) {
      case PlaybackMode.sequential:
        return _currentIndex < _playlist.length - 1;
      case PlaybackMode.random:
      case PlaybackMode.singleLoop:
        return _playlist.isNotEmpty;
    }
  }

  MediaItem _songToMediaItem(Song song) {
    return MediaItem(
      id: song.id,
      title: song.name,
      artist: song.artists.map((a) => a.name).join(', '),
      album: song.album?.name ?? '',
      artUri: song.coverUrl != null ? Uri.tryParse(song.coverUrl!) : null,
      duration: Duration(seconds: song.duration),
      extras: {'source': song.source, 'quality': song.quality.toString()},
    );
  }

  List<MediaItem> _buildQueue() {
    return _playlist.map(_songToMediaItem).toList();
  }

  void dispose() {
    _playerStateController.close();
    _positionController.close();
    _durationController.close();
    _currentSongController.close();
    _queueController.close();
    _player.dispose();
    AppLogger.d('[AudioPlayer] Disposed');
  }
}

class DeltaMusicAudioHandler extends BaseAudioHandler {
  final AudioPlayerService _service;

  DeltaMusicAudioHandler(this._service);

  @override
  Future<void> play() async {
    await _service.resume();
  }

  @override
  Future<void> pause() async {
    await _service.pause();
  }

  @override
  Future<void> stop() async {
    await _service.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _service.seekTo(position);
  }

  @override
  Future<void> skipToNext() async {
    await _service.next();
  }

  @override
  Future<void> skipToPrevious() async {
    await _service.previous();
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.one:
        _service.setPlaybackMode(PlaybackMode.singleLoop);
        break;
      case AudioServiceRepeatMode.none:
        _service.setPlaybackMode(PlaybackMode.sequential);
        break;
      case AudioServiceRepeatMode.group:
      case AudioServiceRepeatMode.all:
        _service.setPlaybackMode(PlaybackMode.sequential);
        break;
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    switch (shuffleMode) {
      case AudioServiceShuffleMode.all:
        _service.setPlaybackMode(PlaybackMode.random);
        break;
      case AudioServiceShuffleMode.none:
        _service.setPlaybackMode(PlaybackMode.sequential);
        break;
      case AudioServiceShuffleMode.group:
        _service.setPlaybackMode(PlaybackMode.sequential);
        break;
    }
  }

  @override
  Future<void> customAction(String name, Map<String, dynamic>? extras) async {
    AppLogger.d('[AudioHandler] Custom action: $name');
  }

  @override
  Future<void> onTaskRemoved() async {
    AppLogger.d('[AudioHandler] Task removed');
  }

  @override
  Future<void> androidOnChannelIgnored() async {
    AppLogger.d('[AudioHandler] Channel ignored');
  }
}