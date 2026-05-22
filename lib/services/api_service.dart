import 'dart:math';

import 'package:dio/dio.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/logger_util.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../models/chart.dart';
import '../models/lyric.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import 'api_failover_strategy.dart';

enum SearchType {
  song,
  artist,
  album,
  playlist,
  all,
}

class AggregatedMusicApi {
  static AggregatedMusicApi? _instance;

  final Dio _dio;
  final ApiFailoverStrategy _failover;
  final Random _random;
  bool _useMockData = true;

  AggregatedMusicApi._()
      : _dio = _createDio(),
        _failover = ApiFailoverStrategy(),
        _random = Random();

  factory AggregatedMusicApi() {
    _instance ??= AggregatedMusicApi._();
    return _instance!;
  }

  ApiFailoverStrategy get failover => _failover;

  bool get useMockData => _useMockData;

  set useMockData(bool value) {
    _useMockData = value;
    AppLogger.i('[API] Mock data mode: $_useMockData');
  }

  static Dio _createDio() {
    final dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      headers: {
        'User-Agent': 'DeltaMusic/1.0',
        'Accept': 'application/json',
      },
    ));

    dio.interceptors.add(LogInterceptor(
      request: true,
      requestHeader: true,
      requestBody: true,
      responseHeader: false,
      responseBody: true,
      error: true,
      logPrint: (o) => AppLogger.d(o.toString()),
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) {
        AppLogger.e('[API] Request failed: ${error.requestOptions.uri}', error);
        handler.next(error);
      },
    ));

    return dio;
  }

  Future<List<Song>> searchSongs(
    String keyword, {
    SearchType type = SearchType.song,
    int limit = 20,
  }) async {
    if (_useMockData) {
      return _mockSearchSongs(keyword, type: type, limit: limit);
    }

    try {
      final source = _failover.activeSource;
      final response = await _dio.get('/search', queryParameters: {
        'keyword': keyword,
        'type': type.name,
        'limit': limit,
        'source': source,
      });

      _failover.recordSuccess(source);

      final List<dynamic> data = response.data['songs'] ?? [];
      return data.map((e) => Song.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      _failover.recordFailure(_failover.activeSource);
      AppLogger.w('[API] Search failed, falling back to mock data', e);
      return _mockSearchSongs(keyword, type: type, limit: limit);
    }
  }

  Future<Song?> getSongDetail(String songId) async {
    if (_useMockData) {
      return _mockGetSongDetail(songId);
    }

    try {
      final recordedSource = _failover.getRecordedSource(songId);
      final source = recordedSource ?? _failover.activeSource;

      final response = await _dio.get('/song/$songId', queryParameters: {
        'source': source,
      });

      _failover.recordSuccessForSong(songId, source);

      final data = response.data;
      if (data == null || data is! Map) return null;
      return Song.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      _failover.recordFailure(_failover.activeSource);
      AppLogger.w('[API] Get song detail failed, falling back to mock', e);
      return _mockGetSongDetail(songId);
    }
  }

  Future<String?> getPlayUrl(String songId, {int quality = 320}) async {
    if (_useMockData) {
      return _mockGetPlayUrl(songId, quality: quality);
    }

    try {
      final recordedSource = _failover.getRecordedSource(songId);
      final source = recordedSource ?? _failover.activeSource;

      final response = await _dio.get('/song/$songId/url', queryParameters: {
        'quality': quality,
        'source': source,
      });

      _failover.recordSuccessForSong(songId, source);

      return response.data['url'] as String?;
    } catch (e) {
      _failover.recordFailure(_failover.activeSource);
      AppLogger.w('[API] Get play url failed', e);
      return null;
    }
  }

  Future<Lyric?> getLyric(String songId) async {
    if (_useMockData) {
      return _mockGetLyric(songId);
    }

    try {
      final recordedSource = _failover.getRecordedSource(songId);
      final source = recordedSource ?? _failover.activeSource;

      final response = await _dio.get('/song/$songId/lyric', queryParameters: {
        'source': source,
      });

      _failover.recordSuccess(source);

      final lrc = response.data['lrc'] as String? ?? '';
      final translatedLrc = response.data['tlyric'] as String?;

      if (lrc.isEmpty) return null;

      return Lyric.parse(songId, lrc, translatedLrc: translatedLrc);
    } catch (e) {
      _failover.recordFailure(_failover.activeSource);
      AppLogger.w('[API] Get lyric failed, falling back to mock', e);
      return _mockGetLyric(songId);
    }
  }

  Future<String?> getCoverUrl(String songId, {int size = 300}) async {
    if (_useMockData) {
      return 'https://picsum.photos/$size/$size?random=${songId.hashCode % 1000}';
    }

    try {
      final recordedSource = _failover.getRecordedSource(songId);
      final source = recordedSource ?? _failover.activeSource;

      final response = await _dio.get('/song/$songId/cover', queryParameters: {
        'size': size,
        'source': source,
      });

      _failover.recordSuccess(source);

      return response.data['url'] as String?;
    } catch (e) {
      _failover.recordFailure(_failover.activeSource);
      AppLogger.w('[API] Get cover url failed', e);
      return 'https://picsum.photos/$size/$size?random=${songId.hashCode % 1000}';
    }
  }

  Future<List<Playlist>> getRecommendPlaylists() async {
    if (_useMockData) {
      return _mockGetRecommendPlaylists();
    }

    try {
      final source = _failover.activeSource;
      final response = await _dio.get('/playlists/recommend', queryParameters: {
        'source': source,
      });

      _failover.recordSuccess(source);

      final List<dynamic> data = response.data['playlists'] ?? [];
      return data
          .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _failover.recordFailure(_failover.activeSource);
      AppLogger.w('[API] Get recommend playlists failed, falling back to mock', e);
      return _mockGetRecommendPlaylists();
    }
  }

  Future<Playlist?> getPlaylistDetail(String playlistId) async {
    if (_useMockData) {
      return _mockGetPlaylistDetail(playlistId);
    }

    try {
      final source = _failover.activeSource;
      final response = await _dio.get('/playlist/$playlistId', queryParameters: {
        'source': source,
      });

      _failover.recordSuccess(source);

      final data = response.data;
      if (data == null || data is! Map) return null;
      return Playlist.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      _failover.recordFailure(_failover.activeSource);
      AppLogger.w('[API] Get playlist detail failed, falling back to mock', e);
      return _mockGetPlaylistDetail(playlistId);
    }
  }

  Future<List<Chart>> getCharts() async {
    if (_useMockData) {
      return _mockGetCharts();
    }

    try {
      final source = _failover.activeSource;
      final response = await _dio.get('/charts', queryParameters: {
        'source': source,
      });

      _failover.recordSuccess(source);

      final List<dynamic> data = response.data['charts'] ?? [];
      return data.map((e) => Chart.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      _failover.recordFailure(_failover.activeSource);
      AppLogger.w('[API] Get charts failed, falling back to mock', e);
      return _mockGetCharts();
    }
  }

  Future<List<String>> getHotSearch() async {
    if (_useMockData) {
      return _mockGetHotSearch();
    }

    try {
      final source = _failover.activeSource;
      final response = await _dio.get('/search/hot', queryParameters: {
        'source': source,
      });

      _failover.recordSuccess(source);

      final List<dynamic> data = response.data['keywords'] ?? [];
      return data.map((e) => e.toString()).toList();
    } catch (e) {
      _failover.recordFailure(_failover.activeSource);
      AppLogger.w('[API] Get hot search failed, falling back to mock', e);
      return _mockGetHotSearch();
    }
  }

  Future<List<Song>> getNewSongs() async {
    if (_useMockData) {
      return _mockGetNewSongs();
    }

    try {
      final source = _failover.activeSource;
      final response = await _dio.get('/songs/new', queryParameters: {
        'source': source,
      });

      _failover.recordSuccess(source);

      final List<dynamic> data = response.data['songs'] ?? [];
      return data.map((e) => Song.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      _failover.recordFailure(_failover.activeSource);
      AppLogger.w('[API] Get new songs failed, falling back to mock', e);
      return _mockGetNewSongs();
    }
  }

  String _randomId() =>
      'mock_${_random.nextInt(99999999).toString().padLeft(8, '0')}';

  Future<List<Song>> _mockSearchSongs(
    String keyword, {
    SearchType type = SearchType.song,
    int limit = 20,
  }) async {
    await _simulateNetworkDelay();
    final songs = <Song>[];
    final count = min(limit, 20);
    for (int i = 0; i < count; i++) {
      songs.add(_createMockSong(
        id: 's_${keyword.hashCode}_$i',
        name: '$keyword ${_mockSongSuffixes[i % _mockSongSuffixes.length]}',
      ));
    }
    return songs;
  }

  Future<Song?> _mockGetSongDetail(String songId) async {
    await _simulateNetworkDelay();
    if (songId.isEmpty) return null;
    return _createMockSong(id: songId);
  }

  Future<String?> _mockGetPlayUrl(String songId, {int quality = 320}) async {
    await _simulateNetworkDelay(ms: 300);
    final testUrls = [
      'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
      'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3',
      'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3',
      'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-11.mp3',
    ];
    return testUrls[songId.hashCode.abs() % testUrls.length];
  }

  Future<Lyric?> _mockGetLyric(String songId) async {
    await _simulateNetworkDelay(ms: 200);
    final lrc = '''
[ti:${_mockSongNames[songId.hashCode.abs() % _mockSongNames.length]}]
[ar:未知歌手]
[00:00.00]~
[00:18.00]窗外的麻雀 在电线杆上多嘴
[00:22.00]你说这一句 很有夏天的感觉
[00:27.00]手中的铅笔 在纸上来来回回
[00:31.00]我用几行字形容你是我的谁
[00:36.00]秋刀鱼的滋味 猫跟你都想了解
[00:41.00]初恋的香味就这样被我们寻回
[00:45.00]那温暖的阳光 像刚摘的鲜艳草莓
[00:49.00]你说你舍不得吃掉这一种感觉
[00:54.00]雨下整夜 我的爱溢出就像雨水
[00:57.00]院子落叶 跟我的思念厚厚一叠
[01:02.00]几句是非 也无法将我的热情冷却
[01:07.00]你出现在我诗的每一页
[01:12.00]雨下整夜 我的爱溢出就像雨水
[01:16.00]窗台蝴蝶 像诗里纷飞的美丽章节
[01:21.00]我接着写 把永远爱你写进诗的结尾
[01:25.00]你是我唯一想要的了解
''';
    final translatedLrc = '''
[00:18.00]Sparrows outside the window chirp on the wire
[00:22.00]You say this line feels very summery
[00:27.00]The pencil in my hand goes back and forth on paper
[00:31.00]I describe who you are to me in a few lines
[00:36.00]The taste of saury, the cat and you both want to know
[00:41.00]The fragrance of first love is thus rediscovered by us
''';
    return Lyric.parse(songId, lrc, translatedLrc: translatedLrc);
  }

  Future<List<Playlist>> _mockGetRecommendPlaylists() async {
    await _simulateNetworkDelay();
    final playlists = <Playlist>[];
    for (int i = 0; i < 12; i++) {
      playlists.add(Playlist(
        id: 'pl_rec_$i',
        name: _mockPlaylistNames[i % _mockPlaylistNames.length],
        coverUrl: 'https://picsum.photos/300/300?random=${100 + i}',
        description: '精选推荐歌单，为你打造专属音乐体验',
        playCount: _random.nextInt(9999999) + 100000,
        songCount: _random.nextInt(100) + 10,
        tags: _mockTags,
        isUserCreated: false,
      ));
    }
    return playlists;
  }

  Future<Playlist?> _mockGetPlaylistDetail(String playlistId) async {
    await _simulateNetworkDelay();
    final songs = <Song>[];
    final songCount = _random.nextInt(20) + 10;
    for (int i = 0; i < songCount; i++) {
      songs.add(_createMockSong(id: '${playlistId}_s_$i'));
    }
    return Playlist(
      id: playlistId,
      name: _mockPlaylistNames[playlistId.hashCode.abs() % _mockPlaylistNames.length],
      coverUrl: 'https://picsum.photos/300/300?random=${playlistId.hashCode % 1000}',
      description: '精选歌单，包含${songCount}首好听的歌曲',
      playCount: _random.nextInt(9999999) + 100000,
      songCount: songCount,
      tags: _mockTags,
      isUserCreated: false,
      songs: songs,
    );
  }

  Future<List<Chart>> _mockGetCharts() async {
    await _simulateNetworkDelay();
    final charts = <Chart>[];
    for (int i = 0; i < 5; i++) {
      final songs = <Song>[];
      for (int j = 0; j < 10; j++) {
        songs.add(_createMockSong(id: 'chart${i}_s_$j'));
      }
      charts.add(Chart(
        id: 'chart_$i',
        name: _mockChartNames[i],
        type: _mockChartTypes[i % _mockChartTypes.length],
        coverUrl: 'https://picsum.photos/300/300?random=${300 + i}',
        songs: songs,
        updateDate: DateTime.now().subtract(Duration(hours: _random.nextInt(24))),
      ));
    }
    return charts;
  }

  Future<List<String>> _mockGetHotSearch() async {
    await _simulateNetworkDelay(ms: 200);
    return [
      '七里香',
      '晴天',
      '稻香',
      '夜曲',
      '青花瓷',
      '告白气球',
      '简单爱',
      '说好的幸福呢',
      '一路向北',
      '等你下课',
      '最伟大的作品',
      'Mojito',
    ];
  }

  Future<List<Song>> _mockGetNewSongs() async {
    await _simulateNetworkDelay();
    final songs = <Song>[];
    for (int i = 0; i < 15; i++) {
      songs.add(_createMockSong(
        id: 'new_s_$i',
        name: _mockNewSongNames[i % _mockNewSongNames.length],
      ));
    }
    return songs;
  }

  Song _createMockSong({
    required String id,
    String? name,
  }) {
    final index = id.hashCode.abs();
    final songName = name ?? _mockSongNames[index % _mockSongNames.length];
    final artistName =
        _mockArtistNames[index % _mockArtistNames.length];
    final artist = Artist(
      id: 'a_${artistName.hashCode}',
      name: artistName,
      avatarUrl: 'https://picsum.photos/200/200?random=${artistName.hashCode % 1000}',
    );

    return Song(
      id: id,
      name: songName,
      artists: [artist],
      album: Album(
        id: 'al_${index % 50}',
        name: _mockAlbumNames[index % _mockAlbumNames.length],
        coverUrl: 'https://picsum.photos/300/300?random=${index % 500}',
        artist: artist,
      ),
      duration: _random.nextInt(300) + 120 + _random.nextInt(60),
      playUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-${index % 16 + 1}.mp3',
      coverUrl: 'https://picsum.photos/300/300?random=${index % 500}',
      quality: 320,
      source: 'mock',
    );
  }

  Future<void> _simulateNetworkDelay({int ms = 0}) async {
    final delay = ms > 0 ? ms : _random.nextInt(300) + 200;
    await Future.delayed(Duration(milliseconds: delay));
  }

  static const List<String> _mockSongNames = [
    '七里香',
    '晴天',
    '稻香',
    '夜曲',
    '青花瓷',
    '告白气球',
    '简单爱',
    '说好的幸福呢',
    '一路向北',
    '等你下课',
    '最伟大的作品',
    'Mojito',
    '听妈妈的话',
    '龙拳',
    '以父之名',
    '止战之殇',
    '东风破',
    '发如雪',
    '菊花台',
    '千里之外',
  ];

  static const List<String> _mockSongSuffixes = [
    '(Live版)',
    '(伴奏)',
    '(Remix)',
    '(Acoustic)',
    '(Cover)',
  ];

  static const List<String> _mockArtistNames = [
    '周杰伦',
    '林俊杰',
    '陈奕迅',
    '薛之谦',
    '李荣浩',
    '邓紫棋',
    '毛不易',
    '赵雷',
    '许嵩',
    '周深',
  ];

  static const List<String> _mockAlbumNames = [
    '七里香',
    '叶惠美',
    '魔杰座',
    '十一月的肖邦',
    '依然范特西',
    '最伟大的作品',
    'Jay',
    '范特西',
    '八度空间',
    '跨时代',
    '惊叹号',
    '十二新作',
  ];

  static const List<String> _mockPlaylistNames = [
    '华语经典TOP100',
    'R&B灵魂之夜',
    '深夜自习必备',
    '晨跑燃脂歌单',
    '怀旧金曲合集',
    '民谣在路上',
    '摇滚不死',
    '电子音乐精选',
    '独立音乐推荐',
    '年度最受欢迎',
    '治愈暖心歌单',
    '开车必备BGM',
    '爵士咖啡馆',
    '古典音乐赏析',
    '说唱新势力',
  ];

  static const List<String> _mockChartNames = [
    '热歌榜',
    '新歌榜',
    '飙升榜',
    '原创榜',
    'MV榜',
  ];

  static const List<String> _mockChartTypes = [
    'hot',
    'new',
    'rising',
    'original',
    'mv',
  ];

  static const List<String> _mockNewSongNames = [
    '如果这就是爱情',
    '遇见',
    '那些你很冒险的梦',
    '年少有为',
    '我曾',
    '起风了',
    '错位时空',
    '孤勇者',
    '星辰大海',
    '踏山河',
    '半生雪',
    '赤伶',
    '芒种',
    '少年',
    '后来遇见他',
  ];

  static const List<String> _mockTags = ['华语', '流行', '经典', '推荐'];
}