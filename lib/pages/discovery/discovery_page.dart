import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/theme/app_theme.dart';
import '../../models/playlist.dart';
import '../../models/chart.dart';
import '../../models/song.dart';
import '../../providers/home_provider.dart';
import '../../providers/player_provider.dart';

class DiscoveryPage extends ConsumerStatefulWidget {
  const DiscoveryPage({super.key});

  @override
  ConsumerState<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends ConsumerState<DiscoveryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = ['推荐', '歌单', '排行榜', '歌手'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    Future.microtask(() {
      ref.read(homeProvider.notifier).loadHomeData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  String _artistNames(Song song) {
    return song.artists.map((a) => a.name).join(' / ');
  }

  String _formatDuration(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('发现'),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRecommendTab(homeState),
                _buildPlaylistGrid(homeState),
                _buildChartList(homeState),
                _buildArtistTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        onTap: () => context.push('/search'),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              const Icon(
                Icons.search,
                color: AppColors.textSecondaryDark,
                size: 22,
              ),
              const SizedBox(width: 10),
              const Text(
                '搜索音乐、歌手、专辑',
                style: TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Container(
                margin: const EdgeInsets.only(right: 6),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFFE53935)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.mic,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: TabBar(
        controller: _tabController,
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: AppColors.textPrimaryDark,
        unselectedLabelColor: AppColors.textSecondaryDark,
        labelStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.normal,
        ),
        tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
      ),
    );
  }

  Widget _buildRecommendTab(HomeState homeState) {
    if (homeState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.read(homeProvider.notifier).loadHomeData(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 8),
          _buildSectionTitle('推荐歌单'),
          _buildPlaylistHorizontal(homeState.recommendPlaylists),
          const SizedBox(height: 16),
          _buildSectionTitle('排行榜'),
          _buildChartListCompact(homeState.charts),
          const SizedBox(height: 16),
          _buildSectionTitle('新歌速递'),
          _buildSongList(homeState.newSongs),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimaryDark,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPlaylistHorizontal(List<Playlist> playlists) {
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
        itemCount: playlists.length,
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
                ClipRRect(
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
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
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

  Widget _buildPlaylistGrid(HomeState homeState) {
    if (homeState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.read(homeProvider.notifier).refreshRecommendations(),
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.82,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: homeState.recommendPlaylists.length,
        itemBuilder: (context, index) {
          return _buildPlaylistCard(homeState.recommendPlaylists[index]);
        },
      ),
    );
  }

  Widget _buildChartList(HomeState homeState) {
    if (homeState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (homeState.charts.isEmpty) {
      return const Center(
        child: Text(
          '暂无排行榜数据',
          style: TextStyle(color: AppColors.textSecondaryDark),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.read(homeProvider.notifier).refreshCharts(),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shrinkWrap: true,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: homeState.charts.length,
        separatorBuilder: (_, __) => const Divider(
          color: AppColors.dividerDark,
          height: 1,
          indent: 60,
        ),
        itemBuilder: (context, index) {
          return _buildChartItem(homeState.charts[index], index);
        },
      ),
    );
  }

  Widget _buildChartListCompact(List<Chart> charts) {
    if (charts.isEmpty) return const SizedBox.shrink();

    final displayCharts = charts.length > 3 ? charts.sublist(0, 3) : charts;

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: displayCharts.length,
      separatorBuilder: (_, __) => const Divider(
        color: AppColors.dividerDark,
        height: 1,
        indent: 60,
      ),
      itemBuilder: (context, index) {
        return _buildChartItem(displayCharts[index], index);
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
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: 48,
                      height: 48,
                      color: AppColors.cardDark,
                      child: const Icon(Icons.show_chart,
                          color: AppColors.primary, size: 22),
                    ),
                  )
                : Container(
                    width: 48,
                    height: 48,
                    color: AppColors.cardDark,
                    child: const Icon(Icons.show_chart,
                        color: AppColors.primary, size: 22),
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
            ? '每日更新 · ${chart.updateDate!.month}月${chart.updateDate!.day}日'
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

  Widget _buildSongList(List<Song> songs) {
    if (songs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '暂无歌曲',
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
        indent: 60,
      ),
      itemBuilder: (context, index) {
        return _buildSongListItem(displaySongs[index]);
      },
    );
  }

  Widget _buildSongListItem(Song song) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: song.coverUrl != null
            ? CachedNetworkImage(
                imageUrl: song.coverUrl!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: 48,
                  height: 48,
                  color: AppColors.cardDark,
                  child: const Icon(
                    Icons.music_note,
                    color: AppColors.textSecondaryDark,
                    size: 22,
                  ),
                ),
              )
            : Container(
                width: 48,
                height: 48,
                color: AppColors.cardDark,
                child: const Icon(
                  Icons.music_note,
                  color: AppColors.textSecondaryDark,
                  size: 22,
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
        ref.read(musicPlayerProvider.notifier).playSong(song);
      },
    );
  }

  Widget _buildArtistTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            color: AppColors.textSecondaryDark,
            size: 64,
          ),
          SizedBox(height: 16),
          Text(
            '歌手列表',
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '即将上线，敬请期待',
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}