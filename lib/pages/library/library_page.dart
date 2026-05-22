import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/theme/app_theme.dart';
import '../../models/song.dart';
import '../../models/playlist.dart';
import '../../providers/playlist_provider.dart';
import '../../providers/player_provider.dart';
import '../../repositories/song_repository.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(playlistProvider.notifier).loadPlaylists();
    });
  }

  String _formatCount(int? count) {
    if (count == null) return '0';
    if (count >= 10000) {
      return '${(count / 10000).toStringAsFixed(1)}万';
    }
    return count.toString();
  }

  String _artistNames(Song song) {
    return song.artists.map((a) => a.name).join(' / ');
  }

  void _showCreatePlaylistDialog() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (dialogContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(dialogContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '创建歌单',
                    style: TextStyle(
                      color: AppColors.textPrimaryDark,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textSecondaryDark,
                    ),
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(
                  color: AppColors.textPrimaryDark,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: '请输入歌单名称',
                  hintStyle: const TextStyle(
                    color: AppColors.textSecondaryDark,
                  ),
                  filled: true,
                  fillColor: AppColors.backgroundDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    final name = controller.text.trim();
                    if (name.isNotEmpty) {
                      ref
                          .read(playlistProvider.notifier)
                          .createPlaylist(name);
                      Navigator.pop(dialogContext);
                    }
                  },
                  child: const Text(
                    '创建',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final playlistState = ref.watch(playlistProvider);
    final songRepo = ref.watch(songRepositoryProvider);
    final likedSongs = songRepo.getLikedSongs();
    final recentPlays = songRepo.getPlayHistory();

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('音乐库'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(playlistProvider.notifier).loadPlaylists(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 4),
            _buildLikedSection(likedSongs),
            const Divider(
              color: AppColors.dividerDark,
              height: 1,
              indent: 16,
              endIndent: 16,
            ),
            _buildRecentSection(recentPlays),
            const Divider(
              color: AppColors.dividerDark,
              height: 1,
              indent: 16,
              endIndent: 16,
            ),
            _buildMyPlaylistsSection(playlistState),
            if (playlistState.isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: _showCreatePlaylistDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildLikedSection(List<Song> likedSongs) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, Color(0xFFE53935)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(
          Icons.favorite,
          color: Colors.white,
          size: 24,
        ),
      ),
      title: const Text(
        '我喜欢',
        style: TextStyle(
          color: AppColors.textPrimaryDark,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        '${likedSongs.length} 首歌曲',
        style: const TextStyle(
          color: AppColors.textSecondaryDark,
          fontSize: 13,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.textSecondaryDark,
        size: 22,
      ),
      onTap: () {},
    );
  }

  Widget _buildRecentSection(List<Song> recentPlays) {
    if (recentPlays.isEmpty) {
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Icon(
            Icons.history,
            color: AppColors.textSecondaryDark,
            size: 24,
          ),
        ),
        title: const Text(
          '最近播放',
          style: TextStyle(
            color: AppColors.textPrimaryDark,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: const Text(
          '暂无播放记录',
          style: TextStyle(
            color: AppColors.textSecondaryDark,
            fontSize: 13,
          ),
        ),
        onTap: () {},
      );
    }

    final displayRecent = recentPlays.length > 3 ? recentPlays.sublist(0, 3) : recentPlays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(
              Icons.history,
              color: AppColors.textSecondaryDark,
              size: 24,
            ),
          ),
          title: const Text(
            '最近播放',
            style: TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            '${recentPlays.length} 首',
            style: const TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 13,
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right,
            color: AppColors.textSecondaryDark,
            size: 22,
          ),
          onTap: () {},
        ),
        ...displayRecent.map((song) => ListTile(
              contentPadding: const EdgeInsets.only(left: 16, right: 16),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: song.coverUrl != null
                    ? CachedNetworkImage(
                        imageUrl: song.coverUrl!,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 44,
                          height: 44,
                          color: AppColors.cardDark,
                          child: const Icon(
                            Icons.music_note,
                            color: AppColors.textSecondaryDark,
                            size: 18,
                          ),
                        ),
                      )
                    : Container(
                        width: 44,
                        height: 44,
                        color: AppColors.cardDark,
                        child: const Icon(
                          Icons.music_note,
                          color: AppColors.textSecondaryDark,
                          size: 18,
                        ),
                      ),
              ),
              title: Text(
                song.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimaryDark,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                _artistNames(song),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 12,
                ),
              ),
              trailing: IconButton(
                icon: const Icon(
                  Icons.play_arrow,
                  color: AppColors.textSecondaryDark,
                  size: 22,
                ),
                onPressed: () {
                  ref.read(musicPlayerProvider.notifier).playSong(song);
                },
              ),
              onTap: () {
                ref.read(musicPlayerProvider.notifier).playSong(song);
              },
            )),
      ],
    );
  }

  Widget _buildMyPlaylistsSection(PlaylistState playlistState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          title: const Text(
            '我的歌单',
            style: TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            '${playlistState.userPlaylists.length} 个歌单',
            style: const TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 13,
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right,
            color: AppColors.textSecondaryDark,
            size: 22,
          ),
          onTap: () {},
        ),
        if (playlistState.userPlaylists.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Text(
              '还没有创建歌单，点击右下角按钮创建',
              style: TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 13,
              ),
            ),
          )
        else
          ...playlistState.userPlaylists.map(
            (playlist) => ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: playlist.coverUrl != null
                    ? CachedNetworkImage(
                        imageUrl: playlist.coverUrl!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 48,
                          height: 48,
                          color: AppColors.cardDark,
                          child: const Icon(
                            Icons.queue_music,
                            color: AppColors.textSecondaryDark,
                            size: 24,
                          ),
                        ),
                      )
                    : Container(
                        width: 48,
                        height: 48,
                        color: AppColors.cardDark,
                        child: const Icon(
                          Icons.queue_music,
                          color: AppColors.textSecondaryDark,
                          size: 24,
                        ),
                      ),
              ),
              title: Text(
                playlist.name,
                style: const TextStyle(
                  color: AppColors.textPrimaryDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                '${playlist.songCount ?? playlist.songs?.length ?? 0} 首',
                style: const TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 13,
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: AppColors.textSecondaryDark,
              ),
              onTap: () => context.push('/playlist/${playlist.id}'),
            ),
          ),
      ],
    );
  }
}