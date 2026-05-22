import 'package:json_annotation/json_annotation.dart';

part 'artist.g.dart';

@JsonSerializable()
class Artist {
  final String id;
  final String name;
  final String? avatarUrl;
  final String? description;
  final int? albumCount;

  const Artist({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.description,
    this.albumCount,
  });

  factory Artist.fromJson(Map<String, dynamic> json) => _$ArtistFromJson(json);

  Map<String, dynamic> toJson() => _$ArtistToJson(this);
}