import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../models/playlist.dart';
import '../../models/chart.dart';
import '../../models/song.dart';
import '../../providers/home_provider.dart';
import '../../providers/player_provider.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late final PageController _bannerController;
  late final Timer _bannerTimer;
  int _bannerIndex = 0;

  final List<Map<String, String>> _banners = [
    {
      'title': '夏日热门推荐',
      'subtitle': '聆听最火热的音乐',
      'color': '0xFFE74C3C',
    },
    {
      'title': '新歌首发',
      'subtitle': '抢先收听最新专辑',
      'color': '0xFF3498DB',
    },
    {
      'title': '古典钢琴',
      'subtitle': '感受经典音乐的魅力',
      'color': '0xFF2ECC71',
    },
    {
      'title': '电子音乐',
      'subtitle': '跟随节奏一起摇摆',
      'color': '0xFF9B59B6',
    },
  ];

  @override
  void initState() {
    super.initState();
    _bannerController = PageController();
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_bannerController.hasClients) {
        _bannerIndex = (_bannerIndex + 1) % _banners.length;
        _bannerController.animateToPage(
          _bannerIndex,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
    Future.microtask(() {
      ref.read(homeProvider.notifier).loadHomeData();
    });
  }

  @override
  void dispose() {
    _bannerTimer.cancel();
    _bannerController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('三角洲音乐'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(homeProvider.notifier).loadHomeData(),
        child: homeState.isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _buildBannerCarousel(),
                  const SizedBox(height: 8),
                  _buildSectionTitle('推荐歌单', onTap: null),
                  _buildPlaylistSection(homeState.recommendPlaylists),
                  const SizedBox(height: 8),
                  _buildSectionTitle('排行榜', onTap: null),
                  _buildChartSection(homeState.charts),
                  const SizedBox(height: 8),
                  _buildSectionTitle('新歌速递', onTap: null),
                  _buildNewSongsSection(homeState.newSongs),
                  const SizedBox(height: 24),
                ],
              ),
      ),
    );
  }

  Widget _buildBannerCarousel() {
    return SizedBox(
      height: 160,
      child: PageView.builder(
        controller: _bannerController,
        itemCount: _banners.length,
        onPageChanged: (index) {
          _bannerIndex = index;
        },
        itemBuilder: (context, index) {
          final banner = _banners[index];
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  Color(int.parse(banner['color']!)),
                  Color(int.parse(banner['color']!)).withOpacity(0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    banner['title']!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    banner['subtitle']!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (onTap != null)
            GestureDetector(
              onTap: onTap,
              child: const Row(
                children: [
                  Text(
                    '查看更多',
                    style: TextStyle(
                      color: AppColors.textSecondaryDark,
                      fontSize: 13,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: AppColors.textSecondaryDark,
                    size: 18,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaylistSection(List<Playlist> playlists) {
    if (playlists.isEmpty) {
      return const SizedBox(
        height: 140,
        child: Center(
          child: Text(
            '暂无推荐歌单',
            style: TextStyle(color: AppColors.textSecondaryDark),
          ),
        ),
      );
    }

    return SizedBox(
      height: 180,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: playlists.length > 3 ? 3 : playlists.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return _buildPlaylistCard(playlists[index]);
        },
      ),
    );
  }

  Widget _buildPlaylistCard(Playlist playlist) {
    return GestureDetector(
      onTap: () => context.push('/playlist/${playlist.id}'),
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Hero(
                  tag: 'playlist_cover_${playlist.id}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: playlist.coverUrl != null
                        ? CachedNetworkImage(
                            imageUrl: playlist.coverUrl!,
                            width: 140,
                            height: 140,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: AppColors.cardDark,
                              child: const Icon(
                                Icons.music_note,
                                color: AppColors.textSecondaryDark,
                                size: 40,
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: AppColors.cardDark,
                              child: const Icon(
                                Icons.music_note,
                                color: AppColors.textSecondaryDark,
                                size: 40,
                              ),
                            ),
                          )
                        : Container(
                            width: 140,
                            height: 140,
                            color: AppColors.cardDark,
                            child: const Icon(
                              Icons.music_note,
                              color: AppColors.textSecondaryDark,
                              size: 40,
                            ),
                          ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 12,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          _formatCount(playlist.playCount),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              playlist.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimaryDark,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection(List<Chart> charts) {
    if (charts.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: Text(
            '暂无排行榜数据',
            style: TextStyle(color: AppColors.textSecondaryDark),
          ),
        ),
      );
    }

    final displayCharts = charts.length > 3 ? charts.sublist(0, 3) : charts;

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: displayCharts.length,
      separatorBuilder: (_, __) => const Divider(
        color: AppColors.dividerDark,
        height: 1,
        indent: 56,
      ),
      itemBuilder: (context, index) {
        final chart = displayCharts[index];
        return _buildChartItem(chart, index);
      },
    );
  }

  Widget _buildChartItem(Chart chart, int rank) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: chart.coverUrl != null
                ? CachedNetworkImage(
                    imageUrl: chart.coverUrl!,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: 44,
                      height: 44,
                      color: AppColors.cardDark,
                      child: const Icon(Icons.show_chart,
                          color: AppColors.primary, size: 20),
                    ),
                  )
                : Container(
                    width: 44,
                    height: 44,
                    color: AppColors.cardDark,
                    child: const Icon(Icons.show_chart,
                        color: AppColors.primary, size: 20),
                  ),
          ),
          if (rank < 3)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: rank == 0
                      ? AppColors.primary
                      : rank == 1
                          ? const Color(0xFFFF9800)
                          : const Color(0xFFFFC107),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                  ),
                ),
                child: Center(
                  child: Text(
                    '${rank + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        chart.name,
        style: const TextStyle(
          color: AppColors.textPrimaryDark,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        chart.updateDate != null
            ? '更新于 ${chart.updateDate!.month}月${chart.updateDate!.day}日'
            : '每日更新',
        style: const TextStyle(
          color: AppColors.textSecondaryDark,
          fontSize: 12,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.textSecondaryDark,
        size: 20,
      ),
      onTap: () {},
    );
  }

  Widget _buildNewSongsSection(List<Song> songs) {
    if (songs.isEmpty) {
      return const SizedBox(
        height: 60,
        child: Center(
          child: Text(
            '暂无新歌',
            style: TextStyle(color: AppColors.textSecondaryDark),
          ),
        ),
      );
    }

    final displaySongs = songs.length > 5 ? songs.sublist(0, 5) : songs;

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: displaySongs.length,
      separatorBuilder: (_, __) => const Divider(
        color: AppColors.dividerDark,
        height: 1,
        indent: 56,
      ),
      itemBuilder: (context, index) {
        return _buildSongItem(displaySongs[index], index);
      },
    );
  }

  Widget _buildSongItem(Song song, int index) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
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
                        size: 20,
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
                      size: 20,
                    ),
                  ),
          ),
        ],
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
          IconButton(
            icon: const Icon(
              Icons.more_vert,
              color: AppColors.textSecondaryDark,
              size: 20,
            ),
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      onTap: () {
        ref.read(musicPlayerProvider.notifier).playSong(song);
      },
    );
  }
}