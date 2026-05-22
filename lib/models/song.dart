import 'package:json_annotation/json_annotation.dart';

import 'artist.dart';
import 'album.dart';

part 'song.g.dart';

@JsonSerializable()
class Song {
  final String id;
  final String name;
  final List<Artist> artists;
  final Album? album;
  final int duration;
  final String? playUrl;
  final String? coverUrl;
  final String? lyricUrl;
  final int quality;
  final String source;
  final bool isLiked;
  final bool isLocal;

  const Song({
    required this.id,
    required this.name,
    this.artists = const [],
    this.album,
    required this.duration,
    this.playUrl,
    this.coverUrl,
    this.lyricUrl,
    this.quality = 320,
    this.source = 'netease',
    this.isLiked = false,
    this.isLocal = false,
  });

  factory Song.fromJson(Map<String, dynamic> json) => _$SongFromJson(json);

  Map<String, dynamic> toJson() => _$SongToJson(this);

  Song copyWith({
    String? id,
    String? name,
    List<Artist>? artists,
    Album? album,
    int? duration,
    String? playUrl,
    String? coverUrl,
    String? lyricUrl,
    int? quality,
    String? source,
    bool? isLiked,
    bool? isLocal,
  }) {
    return Song(
      id: id ?? this.id,
      name: name ?? this.name,
      artists: artists ?? this.artists,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      playUrl: playUrl ?? this.playUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      lyricUrl: lyricUrl ?? this.lyricUrl,
      quality: quality ?? this.quality,
      source: source ?? this.source,
      isLiked: isLiked ?? this.isLiked,
      isLocal: isLocal ?? this.isLocal,
    );
  }
}