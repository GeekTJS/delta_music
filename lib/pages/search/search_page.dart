import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/theme/app_theme.dart';
import '../../models/song.dart';
import '../../providers/search_provider.dart';
import '../../providers/player_provider.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    if (value.trim().isEmpty) return;

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      ref.read(searchProvider.notifier).search(value.trim());
    });
  }

  void _onSearchSubmitted(String value) {
    _debounceTimer?.cancel();
    if (value.trim().isEmpty) return;
    ref.read(searchProvider.notifier).search(value.trim());
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
    final searchState = ref.watch(searchProvider);
    final hasInput = _searchController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          autofocus: true,
          style: const TextStyle(
            color: AppColors.textPrimaryDark,
            fontSize: 16,
          ),
          cursorColor: AppColors.primary,
          decoration: InputDecoration(
            hintText: '搜索音乐、歌手、专辑',
            hintStyle: const TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 15,
            ),
            filled: true,
            fillColor: AppColors.cardDark,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 10,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.clear,
                      color: AppColors.textSecondaryDark,
                      size: 20,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  )
                : null,
          ),
          onChanged: (value) {
            setState(() {});
            _onSearchChanged(value);
          },
          onSubmitted: _onSearchSubmitted,
        ),
      ),
      body: searchState.isSearching
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : hasInput || searchState.searchResults.isNotEmpty
              ? _buildSearchResults(searchState)
              : _buildSearchDefault(searchState),
    );
  }

  Widget _buildSearchDefault(SearchState searchState) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _buildHotSearch(searchState),
        _buildSearchHistory(searchState),
      ],
    );
  }

  Widget _buildHotSearch(SearchState searchState) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '热门搜索',
            style: TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: searchState.hotSearchList.isEmpty
                ? [
                    ...[
                      '告白气球',
                      '起风了',
                      '夜曲',
                      '晴天',
                      '孤勇者',
                      '错位时空',
                      '少年',
                      '星辰大海'
                    ].map((tag) => _buildTagChip(tag))
                  ]
                : searchState.hotSearchList.map((tag) => _buildTagChip(tag)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTagChip(String tag) {
    return GestureDetector(
      onTap: () {
        _searchController.text = tag;
        setState(() {});
        ref.read(searchProvider.notifier).search(tag);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          tag,
          style: const TextStyle(
            color: AppColors.textSecondaryDark,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchHistory(SearchState searchState) {
    if (searchState.searchHistory.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '搜索历史',
                style: TextStyle(
                  color: AppColors.textPrimaryDark,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () {
                  ref.read(searchProvider.notifier).clearHistory();
                },
                child: const Icon(
                  Icons.delete_outline,
                  color: AppColors.textSecondaryDark,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: searchState.searchHistory.map((keyword) {
              return GestureDetector(
                onTap: () {
                  _searchController.text = keyword;
                  setState(() {});
                  ref.read(searchProvider.notifier).search(keyword);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.history,
                        color: AppColors.textSecondaryDark,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        keyword,
                        style: const TextStyle(
                          color: AppColors.textSecondaryDark,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(SearchState searchState) {
    if (searchState.searchResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_off,
              color: AppColors.textSecondaryDark,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              '未找到相关歌曲',
              style: TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: searchState.searchResults.length,
      separatorBuilder: (_, __) => const Divider(
        color: AppColors.dividerDark,
        height: 1,
        indent: 64,
      ),
      itemBuilder: (context, index) {
        final song = searchState.searchResults[index];
        return _buildResultItem(song);
      },
    );
  }

  Widget _buildResultItem(Song song) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
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
}