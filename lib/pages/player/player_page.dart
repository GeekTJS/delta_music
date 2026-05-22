import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../models/song.dart';
import '../../models/lyric.dart';
import '../../providers/player_provider.dart';
import '../../repositories/song_repository.dart';

class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({super.key});

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotateController;
  late final Animation<double> _rotateAnimation;

  final ScrollController _lyricScrollController = ScrollController();
  int _currentLyricIndex = -1;
  Timer? _lyricCheckTimer;
  Lyric? _currentLyric;

  @override
  void initState() {
    super.initState();
    _rotateController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );
    _rotateAnimation = Tween<double>(begin: 0, end: 2 * pi).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _rotateController.dispose();
    _lyricScrollController.dispose();
    _lyricCheckTimer?.cancel();
    super.dispose();
  }

  void _updateRotation(bool isPlaying) {
    if (isPlaying) {
      if (!_rotateController.isAnimating) {
        _rotateController.repeat();
      }
    } else {
      _rotateController.stop();
    }
  }

  Future<void> _loadLyric(String songId) async {
    final songRepo = ref.read(songRepositoryProvider);
    final lyric = await songRepo.getLyric(songId);
    if (mounted) {
      setState(() {
        _currentLyric = lyric;
        _currentLyricIndex = -1;
      });
      _lyricCheckTimer?.cancel();
      _lyricCheckTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        _syncLyricPosition();
      });
    }
  }

  void _syncLyricPosition() {
    if (_currentLyric == null || _currentLyric!.lines.isEmpty) return;

    final state = ref.read(musicPlayerProvider);
    final positionMs = state.position.inMilliseconds;
    final lines = _currentLyric!.lines;

    int newIndex = -1;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].timeMs <= positionMs) {
        newIndex = i;
      } else {
        break;
      }
    }

    if (newIndex != _currentLyricIndex) {
      setState(() {
        _currentLyricIndex = newIndex;
      });
      _scrollToLyricLine(newIndex);
    }
  }

  void _scrollToLyricLine(int index) {
    if (!_lyricScrollController.hasClients) return;
    final itemHeight = 48.0;
    final offset = (index * itemHeight) - 160;
    _lyricScrollController.animateTo(
      offset.clamp(0.0, _lyricScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  String _formatDuration(Duration d) {
    final min = d.inMinutes.toString().padLeft(2, '0');
    final sec = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  String _artistNames(Song song) {
    return song.artists.map((a) => a.name).join(' / ');
  }

  IconData _playbackModeIcon(PlaybackMode mode) {
    switch (mode) {
      case PlaybackMode.sequential:
        return Icons.repeat;
      case PlaybackMode.random:
        return Icons.shuffle;
      case PlaybackMode.singleLoop:
        return Icons.repeat_one;
    }
  }

  Color _playbackModeColor(PlaybackMode mode) {
    switch (mode) {
      case PlaybackMode.sequential:
        return AppColors.textSecondaryDark;
      case PlaybackMode.random:
        return AppColors.primary;
      case PlaybackMode.singleLoop:
        return AppColors.primary;
    }
  }

  void _cyclePlaybackMode() {
    final current = ref.read(musicPlayerProvider).playbackMode;
    final modes = AppConstants.playbackModes;
    final nextIndex = (modes.indexOf(current) + 1) % modes.length;
    ref.read(musicPlayerProvider.notifier).setPlaybackMode(modes[nextIndex]);
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(musicPlayerProvider);

    _updateRotation(playerState.isPlaying);

    if (playerState.currentSong != null && _currentLyric == null) {
      Future.microtask(() => _loadLyric(playerState.currentSong!.id));
    }

    if (playerState.currentSong == null && _currentLyric != null) {
      Future.microtask(() {
        setState(() {
          _currentLyric = null;
          _currentLyricIndex = -1;
        });
        _lyricCheckTimer?.cancel();
      });
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.backgroundDark,
              AppColors.primary.withOpacity(0.15),
              AppColors.backgroundDark,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: playerState.currentSong != null
                    ? _buildPlayerContent(playerState)
                    : _buildEmptyState(),
              ),
              _buildBottomControls(playerState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final playerState = ref.watch(musicPlayerProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.keyboard_arrow_down,
              color: AppColors.textPrimaryDark,
              size: 32,
            ),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  playerState.currentSong?.name ?? '未在播放',
                  style: const TextStyle(
                    color: AppColors.textPrimaryDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                if (playerState.currentSong != null)
                  Text(
                    _artistNames(playerState.currentSong!),
                    style: const TextStyle(
                      color: AppColors.textSecondaryDark,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.queue_music,
              color: AppColors.textSecondaryDark,
              size: 24,
            ),
            onPressed: () {},
            tooltip: '播放列表',
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerContent(MusicPlayerState playerState) {
    return Column(
      children: [
        const Spacer(flex: 1),
        _buildAlbumArt(playerState),
        const Spacer(flex: 1),
        _buildLyricView(),
        const Spacer(flex: 2),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_note,
            color: AppColors.textSecondaryDark,
            size: 80,
          ),
          SizedBox(height: 16),
          Text(
            '选择一首歌曲开始播放',
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumArt(MusicPlayerState playerState) {
    final song = playerState.currentSong!;

    return AnimatedBuilder(
      animation: _rotateAnimation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _rotateAnimation.value,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 40,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(130),
              child: song.coverUrl != null
                  ? CachedNetworkImage(
                      imageUrl: song.coverUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: AppColors.cardDark,
                        child: const Icon(
                          Icons.album,
                          color: AppColors.textSecondaryDark,
                          size: 80,
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.cardDark,
                        child: const Icon(
                          Icons.album,
                          color: AppColors.textSecondaryDark,
                          size: 80,
                        ),
                      ),
                    )
                  : Container(
                      color: AppColors.cardDark,
                      child: const Icon(
                        Icons.album,
                        color: AppColors.textSecondaryDark,
                        size: 80,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLyricView() {
    if (_currentLyric == null || _currentLyric!.lines.isEmpty) {
      return Column(
        children: [
          const SizedBox(height: 4),
          Text(
            ref.watch(musicPlayerProvider).currentSong?.name ?? '',
            style: const TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            ref.watch(musicPlayerProvider).currentSong != null
                ? _artistNames(ref.watch(musicPlayerProvider).currentSong!)
                : '',
            style: const TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return SizedBox(
      height: 240,
      child: ListView.builder(
        controller: _lyricScrollController,
        itemCount: _currentLyric!.lines.length,
        itemExtent: 48,
        itemBuilder: (context, index) {
          final line = _currentLyric!.lines[index];
          final isCurrent = index == _currentLyricIndex;

          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  line.text,
                  style: TextStyle(
                    color: isCurrent
                        ? AppColors.primary
                        : AppColors.textSecondaryDark,
                    fontSize: isCurrent ? 16 : 14,
                    fontWeight:
                        isCurrent ? FontWeight.bold : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (line.translation != null)
                  Text(
                    line.translation!,
                    style: TextStyle(
                      color: isCurrent
                          ? AppColors.primary.withOpacity(0.7)
                          : AppColors.textSecondaryDark.withOpacity(0.5),
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomControls(MusicPlayerState playerState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _buildProgressBar(playerState),
          const SizedBox(height: 12),
          _buildPlayControls(playerState),
          const SizedBox(height: 12),
          _buildExtraControls(playerState),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildProgressBar(MusicPlayerState playerState) {
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: playerState.position.inMilliseconds
                .toDouble()
                .clamp(0, playerState.duration.inMilliseconds.toDouble()),
            max: playerState.duration.inMilliseconds.toDouble(),
            onChanged: (value) {
              ref
                  .read(musicPlayerProvider.notifier)
                  .seekTo(Duration(milliseconds: value.toInt()));
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(playerState.position),
                style: const TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 12,
                ),
              ),
              Text(
                _formatDuration(playerState.duration),
                style: const TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlayControls(MusicPlayerState playerState) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: Icon(
            _playbackModeIcon(playerState.playbackMode),
            color: _playbackModeColor(playerState.playbackMode),
            size: 24,
          ),
          onPressed: _cyclePlaybackMode,
          tooltip: AppConstants.playbackModeLabel(playerState.playbackMode),
        ),
        IconButton(
          icon: const Icon(
            Icons.skip_previous,
            color: AppColors.textPrimaryDark,
            size: 36,
          ),
          onPressed: playerState.currentSong != null
              ? () => ref.read(musicPlayerProvider.notifier).previous()
              : null,
        ),
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              playerState.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 34,
            ),
            onPressed: () {
              ref.read(musicPlayerProvider.notifier).togglePlayPause();
            },
          ),
        ),
        IconButton(
          icon: const Icon(
            Icons.skip_next,
            color: AppColors.textPrimaryDark,
            size: 36,
          ),
          onPressed: playerState.currentSong != null
              ? () => ref.read(musicPlayerProvider.notifier).next()
              : null,
        ),
        IconButton(
          icon: Icon(
            playerState.playbackMode == PlaybackMode.random
                ? Icons.shuffle_on
                : Icons.shuffle,
            color: playerState.playbackMode == PlaybackMode.random
                ? AppColors.primary
                : AppColors.textSecondaryDark,
            size: 24,
          ),
          onPressed: () {
            final mode = playerState.playbackMode == PlaybackMode.random
                ? PlaybackMode.sequential
                : PlaybackMode.random;
            ref.read(musicPlayerProvider.notifier).setPlaybackMode(mode);
          },
          tooltip: '随机播放',
        ),
      ],
    );
  }

  Widget _buildExtraControls(MusicPlayerState playerState) {
    final song = playerState.currentSong;
    final songRepo = ref.watch(songRepositoryProvider);
    final isLiked =
        song != null ? songRepo.isLiked(song.id) : false;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: Icon(
            isLiked ? Icons.favorite : Icons.favorite_border,
            color: isLiked ? AppColors.primary : AppColors.textSecondaryDark,
            size: 24,
          ),
          onPressed: song != null
              ? () {
                  songRepo.toggleLike(song);
                  setState(() {});
                }
              : null,
          tooltip: '喜欢',
        ),
        IconButton(
          icon: const Icon(
            Icons.download_outlined,
            color: AppColors.textSecondaryDark,
            size: 24,
          ),
          onPressed: () {},
          tooltip: '下载',
        ),
        IconButton(
          icon: const Icon(
            Icons.comment_outlined,
            color: AppColors.textSecondaryDark,
            size: 24,
          ),
          onPressed: () {},
          tooltip: '评论',
        ),
        IconButton(
          icon: const Icon(
            Icons.share_outlined,
            color: AppColors.textSecondaryDark,
            size: 24,
          ),
          onPressed: () {},
          tooltip: '分享',
        ),
      ],
    );
  }
}