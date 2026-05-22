import 'package:json_annotation/json_annotation.dart';

import 'artist.dart';

part 'album.g.dart';

@JsonSerializable()
class Album {
  final String id;
  final String name;
  final String? coverUrl;
  final Artist? artist;
  final DateTime? publishDate;
  final int? songCount;
  final String? description;

  const Album({
    required this.id,
    required this.name,
    this.coverUrl,
    this.artist,
    this.publishDate,
    this.songCount,
    this.description,
  });

  factory Album.fromJson(Map<String, dynamic> json) => _$AlbumFromJson(json);

  Map<String, dynamic> toJson() => _$AlbumToJson(this);
}