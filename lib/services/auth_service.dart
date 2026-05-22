import 'dart:async';
import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../core/utils/logger_util.dart';

class User {
  final String id;
  final String username;
  final String? avatar;
  final String? nickname;

  const User({
    required this.id,
    required this.username,
    this.avatar,
    this.nickname,
  });

  String get displayName => nickname ?? username;

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'avatar': avatar,
        'nickname': nickname,
      };

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        username: json['username'] as String,
        avatar: json['avatar'] as String?,
        nickname: json['nickname'] as String?,
      );

  User copyWith({
    String? id,
    String? username,
    String? avatar,
    String? nickname,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      avatar: avatar ?? this.avatar,
      nickname: nickname ?? this.nickname,
    );
  }
}

class AuthService {
  static AuthService? _instance;

  static const String _authBoxName = 'delta_auth';
  static const String _keyToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyUser = 'user_data';
  static const String _keyTokenExpiry = 'token_expiry';

  late Box _authBox;

  final _isLoggedInController = StreamController<bool>.broadcast();
  final _currentUserController = StreamController<User?>.broadcast();

  bool _isLoggedIn = false;
  User? _currentUser;
  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;

  Timer? _tokenRefreshTimer;

  AuthService._();

  factory AuthService() {
    _instance ??= AuthService._();
    return _instance!;
  }

  Stream<bool> get isLoggedInStream => _isLoggedInController.stream;
  Stream<User?> get currentUserStream => _currentUserController.stream;

  bool get isLoggedIn => _isLoggedIn;
  User? get currentUser => _currentUser;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  Future<void> init() async {
    _authBox = await Hive.openBox(_authBoxName);
    await _restoreSession();
    AppLogger.i('[Auth] Initialized (logged in: $_isLoggedIn)');
  }

  Future<void> _restoreSession() async {
    try {
      final token = _authBox.get(_keyToken) as String?;
      final refresh = _authBox.get(_keyRefreshToken) as String?;
      final userJson = _authBox.get(_keyUser) as String?;
      final expiryStr = _authBox.get(_keyTokenExpiry) as String?;

      if (token == null || token.isEmpty) {
        _emitState(false, null);
        return;
      }

      final expiry = expiryStr != null ? DateTime.tryParse(expiryStr) : null;

      if (expiry != null && expiry.isBefore(DateTime.now())) {
        AppLogger.d('[Auth] Token expired, attempting refresh');
        final refreshed = await _attemptTokenRefresh(refresh ?? '');
        if (!refreshed) {
          await _clearSession();
          return;
        }
      }

      User? user;
      if (userJson != null && userJson.isNotEmpty) {
        try {
          user = User.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
        } catch (e) {
          AppLogger.w('[Auth] Failed to parse user data', e);
        }
      }

      _accessToken = token;
      _refreshToken = refresh;
      _tokenExpiry = expiry;
      _emitState(true, user);

      _scheduleTokenRefresh();
    } catch (e) {
      AppLogger.e('[Auth] Failed to restore session', e);
      _emitState(false, null);
    }
  }

  Future<void> _clearSession() async {
    _accessToken = null;
    _refreshToken = null;
    _tokenExpiry = null;
    _tokenRefreshTimer?.cancel();
    await _authBox.clear();
    _emitState(false, null);
  }

  Future<bool> login(String username, String password) async {
    try {
      AppLogger.d('[Auth] Logging in: $username');

      await _simulateNetworkDelay();

      if (username.isEmpty || password.isEmpty) {
        throw AuthException('用户名和密码不能为空');
      }

      if (username.length < 3) {
        throw AuthException('用户名至少需要3个字符');
      }

      if (password.length < 6) {
        throw AuthException('密码至少需要6个字符');
      }

      if (username == 'demo' && password == 'demo123') {
        _accessToken = 'mock_access_token_${DateTime.now().millisecondsSinceEpoch}';
        _refreshToken = 'mock_refresh_token_${DateTime.now().millisecondsSinceEpoch}';
      } else {
        _accessToken = 'mock_access_token_${DateTime.now().millisecondsSinceEpoch}';
        _refreshToken = 'mock_refresh_token_${DateTime.now().millisecondsSinceEpoch}';
      }

      _tokenExpiry = DateTime.now().add(const Duration(hours: 24));

      final user = User(
        id: 'user_${username.hashCode.abs()}',
        username: username,
        avatar: 'https://picsum.photos/200/200?random=${username.hashCode % 1000}',
        nickname: username,
      );

      await _authBox.put(_keyToken, _accessToken);
      await _authBox.put(_keyRefreshToken, _refreshToken);
      await _authBox.put(_keyUser, jsonEncode(user.toJson()));
      await _authBox.put(_keyTokenExpiry, _tokenExpiry!.toIso8601String());

      _emitState(true, user);
      _scheduleTokenRefresh();

      AppLogger.i('[Auth] Login success: ${user.displayName}');
      return true;
    } on AuthException {
      rethrow;
    } catch (e) {
      AppLogger.e('[Auth] Login failed', e);
      throw AuthException('登录失败，请检查网络连接');
    }
  }

  Future<void> logout() async {
    try {
      _tokenRefreshTimer?.cancel();
      await _clearSession();
      AppLogger.i('[Auth] Logged out');
    } catch (e) {
      AppLogger.e('[Auth] Logout failed', e);
    }
  }

  Future<bool> updateProfile({String? nickname, String? avatar}) async {
    if (_currentUser == null) return false;

    try {
      await _simulateNetworkDelay();

      final updated = _currentUser!.copyWith(
        nickname: nickname ?? _currentUser!.nickname,
        avatar: avatar ?? _currentUser!.avatar,
      );

      _currentUser = updated;
      _currentUserController.add(updated);

      await _authBox.put(_keyUser, jsonEncode(updated.toJson()));

      AppLogger.d('[Auth] Profile updated: ${updated.displayName}');
      return true;
    } catch (e) {
      AppLogger.e('[Auth] Profile update failed', e);
      return false;
    }
  }

  Future<bool> _attemptTokenRefresh(String refreshToken) async {
    if (refreshToken.isEmpty) return false;

    try {
      AppLogger.d('[Auth] Refreshing token');

      await _simulateNetworkDelay(ms: 500);

      _accessToken = 'mock_refreshed_token_${DateTime.now().millisecondsSinceEpoch}';
      _refreshToken = 'mock_new_refresh_token_${DateTime.now().millisecondsSinceEpoch}';
      _tokenExpiry = DateTime.now().add(const Duration(hours: 24));

      await _authBox.put(_keyToken, _accessToken);
      await _authBox.put(_keyRefreshToken, _refreshToken);
      await _authBox.put(_keyTokenExpiry, _tokenExpiry!.toIso8601String());

      AppLogger.i('[Auth] Token refreshed');
      return true;
    } catch (e) {
      AppLogger.e('[Auth] Token refresh failed', e);
      return false;
    }
  }

  Future<bool> refreshTokenIfNeeded() async {
    if (_accessToken == null) return false;

    if (_tokenExpiry != null &&
        _tokenExpiry!.isBefore(DateTime.now().add(const Duration(minutes: 5)))) {
      return await _attemptTokenRefresh(_refreshToken ?? '');
    }

    return true;
  }

  void _scheduleTokenRefresh() {
    _tokenRefreshTimer?.cancel();
    if (_tokenExpiry == null) return;

    final timeUntilExpiry = _tokenExpiry!.difference(DateTime.now());
    final refreshTime = timeUntilExpiry - const Duration(minutes: 10);

    if (refreshTime.isNegative) return;

    _tokenRefreshTimer = Timer(refreshTime, () async {
      AppLogger.d('[Auth] Scheduled token refresh');
      if (_refreshToken != null) {
        await _attemptTokenRefresh(_refreshToken!);
        _scheduleTokenRefresh();
      }
    });
  }

  void _emitState(bool isLoggedIn, User? user) {
    _isLoggedIn = isLoggedIn;
    _currentUser = user;
    _isLoggedInController.add(isLoggedIn);
    _currentUserController.add(user);
  }

  Future<void> _simulateNetworkDelay({int ms = 0}) async {
    final delay = ms > 0 ? ms : 400;
    await Future.delayed(Duration(milliseconds: delay));
  }

  Future<void> dispose() async {
    _tokenRefreshTimer?.cancel();
    _isLoggedInController.close();
    _currentUserController.close();
    await _authBox.close();
    AppLogger.d('[Auth] Disposed');
  }
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}