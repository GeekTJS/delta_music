enum PlaybackMode {
  sequential,
  random,
  singleLoop,
}

class AppConstants {
  AppConstants._();

  static const String apiBaseUrl = 'https://api.delta-music.example.com';

  static const String appName = '三角洲音乐';

  static const String appVersion = '1.0.0';

  static const String defaultCoverPlaceholder = 'assets/images/placeholder_cover.png';

  static const double pagePadding = 16.0;

  static const double cardRadius = 8.0;

  static const double listItemHeight = 56.0;

  static const double bottomNavHeight = 56.0;

  static const double miniPlayerHeight = 64.0;

  static const Set<int> qualityOptions = {128, 192, 320, 999};

  static const List<PlaybackMode> playbackModes = [
    PlaybackMode.sequential,
    PlaybackMode.random,
    PlaybackMode.singleLoop,
  ];

  static String playbackModeLabel(PlaybackMode mode) {
    switch (mode) {
      case PlaybackMode.sequential:
        return '顺序播放';
      case PlaybackMode.random:
        return '随机播放';
      case PlaybackMode.singleLoop:
        return '单曲循环';
    }
  }

  static String qualityLabel(int quality) {
    switch (quality) {
      case 128:
        return '标准品质 (128kbps)';
      case 192:
        return '较高品质 (192kbps)';
      case 320:
        return '高品质 (320kbps)';
      case 999:
        return '无损品质';
      default:
        return '$quality kbps';
    }
  }
}