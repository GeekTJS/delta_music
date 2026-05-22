import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'song_repository.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../models/song.dart';

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository(
    api: ref.watch(aggregatedMusicApiProvider),
    storage: ref.watch(storageServiceProvider),
  );
});

class SearchRepository {
  final AggregatedMusicApi _api;
  final StorageService _storage;

  SearchRepository({
    required AggregatedMusicApi api,
    required StorageService storage,
  })  : _api = api,
        _storage = storage;

  Future<List<Song>> searchSongs(String keyword, {int limit = 30}) async {
    return _api.searchSongs(keyword, limit: limit);
  }

  Future<List<String>> getHotSearch() async {
    return _api.getHotSearch();
  }

  List<String> getSearchHistory() {
    return _storage.getSearchHistory();
  }

  Future<void> addToSearchHistory(String keyword) async {
    await _storage.addSearchHistory(keyword);
  }

  Future<void> clearSearchHistory() async {
    await _storage.clearSearchHistory();
  }
}