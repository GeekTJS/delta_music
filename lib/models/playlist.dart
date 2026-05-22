import 'package:json_annotation/json_annotation.dart';

import 'song.dart';

part 'playlist.g.dart';

@JsonSerializable()
class Playlist {
  final String id;
  final String name;
  final String? coverUrl;
  final String? description;
  final int? playCount;
  final int? songCount;
  final List<String>? tags;
  final DateTime? createDate;
  final DateTime? updateDate;
  final bool isUserCreated;
  final List<Song>? songs;

  const Playlist({
    required this.id,
    required this.name,
    this.coverUrl,
    this.description,
    this.playCount,
    this.songCount,
    this.tags,
    this.createDate,
    this.updateDate,
    this.isUserCreated = false,
    this.songs,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) =>
      _$PlaylistFromJson(json);

  Map<String, dynamic> toJson() => _$PlaylistToJson(this);

  Playlist copyWith({
    String? id,
    String? name,
    String? coverUrl,
    String? description,
    int? playCount,
    int? songCount,
    List<String>? tags,
    DateTime? createDate,
    DateTime? updateDate,
    bool? isUserCreated,
    List<Song>? songs,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      coverUrl: coverUrl ?? this.coverUrl,
      description: description ?? this.description,
      playCount: playCount ?? this.playCount,
      songCount: songCount ?? this.songCount,
      tags: tags ?? this.tags,
      createDate: createDate ?? this.createDate,
      updateDate: updateDate ?? this.updateDate,
      isUserCreated: isUserCreated ?? this.isUserCreated,
      songs: songs ?? this.songs,
    );
  }
}