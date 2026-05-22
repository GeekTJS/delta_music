import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/logger_util.dart';
import '../models/song.dart';
import '../repositories/search_repository.dart';

class SearchState {
  final String keyword;
  final List<Song> searchResults;
  final List<String> hotSearchList;
  final List<String> searchHistory;
  final bool isSearching;

  const SearchState({
    this.keyword = '',
    this.searchResults = const [],
    this.hotSearchList = const [],
    this.searchHistory = const [],
    this.isSearching = false,
  });

  SearchState copyWith({
    String? keyword,
    List<Song>? searchResults,
    List<String>? hotSearchList,
    List<String>? searchHistory,
    bool? isSearching,
  }) {
    return SearchState(
      keyword: keyword ?? this.keyword,
      searchResults: searchResults ?? this.searchResults,
      hotSearchList: hotSearchList ?? this.hotSearchList,
      searchHistory: searchHistory ?? this.searchHistory,
      isSearching: isSearching ?? this.isSearching,
    );
  }
}

class SearchNotifier extends StateNotifier<SearchState> {
  final SearchRepository _repo;

  SearchNotifier(this._repo) : super(const SearchState()) {
    _init();
  }

  void _init() {
    loadHotSearch();
    final history = _repo.getSearchHistory();
    state = state.copyWith(searchHistory: history);
  }

  Future<void> search(String keyword) async {
    if (keyword.trim().isEmpty) return;

    state = state.copyWith(keyword: keyword, isSearching: true);
    try {
      final results = await _repo.searchSongs(keyword);
      state = state.copyWith(searchResults: results, isSearching: false);
      await addToHistory(keyword);
    } catch (e) {
      AppLogger.e('[SearchNotifier] Search failed', e);
      state = state.copyWith(isSearching: false);
    }
  }

  Future<void> loadHotSearch() async {
    try {
      final hotList = await _repo.getHotSearch();
      state = state.copyWith(hotSearchList: hotList);
    } catch (e) {
      AppLogger.e('[SearchNotifier] Failed to load hot search', e);
    }
  }

  Future<void> addToHistory(String keyword) async {
    try {
      await _repo.addToSearchHistory(keyword);
      final history = _repo.getSearchHistory();
      state = state.copyWith(searchHistory: history);
    } catch (e) {
      AppLogger.e('[SearchNotifier] Failed to add to history', e);
    }
  }

  Future<void> clearHistory() async {
    try {
      await _repo.clearSearchHistory();
      state = state.copyWith(searchHistory: []);
    } catch (e) {
      AppLogger.e('[SearchNotifier] Failed to clear history', e);
    }
  }
}

final searchProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  final repo = ref.watch(searchRepositoryProvider);
  return SearchNotifier(repo);
});