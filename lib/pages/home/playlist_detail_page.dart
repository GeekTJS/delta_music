import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/theme/app_theme.dart';
import '../../models/playlist.dart';
import '../../models/song.dart';
import '../../providers/playlist_provider.dart';
import '../../providers/player_provider.dart';
import '../../repositories/playlist_repository.dart';

class PlaylistDetailPage extends ConsumerStatefulWidget {
  final String id;

  const PlaylistDetailPage({super.key, required this.id});

  @override
  ConsumerState<PlaylistDetailPage> createState() =>
      _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends ConsumerState<PlaylistDetailPage> {
  Playlist? _playlist;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaylist();
  }

  Future<void> _loadPlaylist() async {
    final repo = ref.read(playlistRepositoryProvider);
    try {
      final playlist = await repo.getPlaylistDetail(widget.id) ??
          await repo.loadUserPlaylist(widget.id);
      if (mounted) {
        setState(() {
          _playlist = playlist;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatCount(int? count) {
    if (count == null) return '';
    if (count >= 100000000) {
      return '${(count / 100000000).toStringAsFixed(1)}亿';
    } else if (count >= 10000) {
      return '${(count / 10000).toStringAsFixed(1)}万';
    }
    return count.toString();
  }

  String _formatDuration(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  String _artistNames(Song song) {
    return song.artists.map((a) => a.name).join(' / ');
  }

  void _playAll() {
    if (_playlist?.songs != null && _playlist!.songs!.isNotEmpty) {
      ref
          .read(musicPlayerProvider.notifier)
          .playPlaylist(_playlist!.songs!, 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _playlist == null
              ? _buildNotFound()
              : CustomScrollView(
                  slivers: [
                    _buildSliverAppBar(),
                    _buildPlayAllButton(),
                    _buildSongListHeader(),
                    _buildSongList(),
                  ],
                ),
    );
  }

  Widget _buildNotFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.playlist_remove,
            color: AppColors.textSecondaryDark,
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            '歌单未找到',
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.pop(),
            child: const Text(
              '返回',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: AppColors.backgroundDark,
      leading: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(20),
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
          ),
          child: IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            _playlist!.coverUrl != null
                ? Hero(
                    tag: 'playlist_cover_${_playlist!.id}',
                    child: CachedNetworkImage(
                      imageUrl: _playlist!.coverUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.cardDark,
                      ),
                    ),
                  )
                : Container(color: AppColors.cardDark),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    AppColors.backgroundDark,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.5, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 20,
              bottom: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _playlist!.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  if (_playlist!.description != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        _playlist!.description!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  Row(
                    children: [
                      if (_playlist!.playCount != null) ...[
                        const Icon(
                          Icons.play_arrow,
                          color: Colors.white70,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatCount(_playlist!.playCount),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      const Icon(
                        Icons.music_note,
                        color: Colors.white70,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_playlist!.songCount ?? _playlist!.songs?.length ?? 0} 首',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayAllButton() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SizedBox(
          height: 44,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.play_arrow, size: 22),
            label: const Text(
              '播放全部',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: _playAll,
          ),
        ),
      ),
    );
  }

  Widget _buildSongListHeader() {
    return const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.only(left: 16, top: 8, bottom: 4),
        child: Text(
          '歌曲列表',
          style: TextStyle(
            color: AppColors.textSecondaryDark,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildSongList() {
    final songs = _playlist!.songs;

    if (songs == null || songs.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              '歌单中没有歌曲',
              style: TextStyle(color: AppColors.textSecondaryDark),
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final song = songs[index];
          return _buildSongItem(song, index);
        },
        childCount: songs.length,
      ),
    );
  }

  Widget _buildSongItem(Song song, int index) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: SizedBox(
            width: 40,
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          title: Text(
            song.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            _artistNames(song),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 13,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatDuration(song.duration),
                style: const TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.more_vert,
                color: AppColors.textSecondaryDark,
                size: 20,
              ),
            ],
          ),
          onTap: () {
            ref.read(musicPlayerProvider.notifier).playPlaylist(
                  _playlist!.songs!,
                  index,
                );
          },
        ),
        const Divider(
          color: AppColors.dividerDark,
          height: 1,
          indent: 56,
        ),
      ],
    );
  }
}