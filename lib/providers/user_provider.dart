import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/logger_util.dart';
import '../services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

class PlaybackStats {
  final int totalPlays;
  final Duration totalDuration;
  final List<String> topArtists;
  final List<String> topGenres;

  const PlaybackStats({
    this.totalPlays = 0,
    this.totalDuration = Duration.zero,
    this.topArtists = const [],
    this.topGenres = const [],
  });

  PlaybackStats copyWith({
    int? totalPlays,
    Duration? totalDuration,
    List<String>? topArtists,
    List<String>? topGenres,
  }) {
    return PlaybackStats(
      totalPlays: totalPlays ?? this.totalPlays,
      totalDuration: totalDuration ?? this.totalDuration,
      topArtists: topArtists ?? this.topArtists,
      topGenres: topGenres ?? this.topGenres,
    );
  }
}

class UserState {
  final User? user;
  final bool isLoggedIn;
  final bool isLoading;
  final PlaybackStats? playbackStats;

  const UserState({
    this.user,
    this.isLoggedIn = false,
    this.isLoading = false,
    this.playbackStats,
  });

  UserState copyWith({
    User? user,
    bool? isLoggedIn,
    bool? isLoading,
    PlaybackStats? playbackStats,
    bool clearUser = false,
  }) {
    return UserState(
      user: clearUser ? null : (user ?? this.user),
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isLoading: isLoading ?? this.isLoading,
      playbackStats: playbackStats ?? this.playbackStats,
    );
  }
}

class UserNotifier extends StateNotifier<UserState> {
  final AuthService _auth;
  final Ref _ref;

  UserNotifier(this._auth, this._ref) : super(const UserState()) {
    _syncAuthState();
  }

  void _syncAuthState() {
    state = state.copyWith(
      user: _auth.currentUser,
      isLoggedIn: _auth.isLoggedIn,
    );
  }

  Future<void> login(String username, String password) async {
    state = state.copyWith(isLoading: true);
    try {
      final success = await _auth.login(username, password);
      if (success) {
        state = state.copyWith(
          user: _auth.currentUser,
          isLoggedIn: true,
          isLoading: false,
        );
        await getStats();
      } else {
        state = state.copyWith(isLoading: false);
      }
    } on AuthException catch (e) {
      AppLogger.e('[UserNotifier] Login failed', e);
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    try {
      await _auth.logout();
      state = state.copyWith(
        clearUser: true,
        isLoggedIn: false,
        isLoading: false,
        playbackStats: null,
      );
    } catch (e) {
      AppLogger.e('[UserNotifier] Logout failed', e);
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> getStats() async {
    try {
      final random = Random();
      final stats = PlaybackStats(
        totalPlays: random.nextInt(5000) + 100,
        totalDuration: Duration(hours: random.nextInt(500) + 10),
        topArtists: _mockTopArtists,
        topGenres: _mockTopGenres,
      );
      state = state.copyWith(playbackStats: stats);
    } catch (e) {
      AppLogger.e('[UserNotifier] Failed to get stats', e);
    }
  }

  static const List<String> _mockTopArtists = [
    '周杰伦',
    '林俊杰',
    '陈奕迅',
    '邓紫棋',
    '毛不易',
  ];

  static const List<String> _mockTopGenres = [
    '华语流行',
    'R&B',
    '民谣',
    '摇滚',
    '电子',
  ];
}

final userProvider =
    StateNotifierProvider<UserNotifier, UserState>((ref) {
  final auth = ref.watch(authServiceProvider);
  return UserNotifier(auth, ref);
});