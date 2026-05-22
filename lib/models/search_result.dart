import 'song.dart';
import 'artist.dart';
import 'album.dart';
import 'playlist.dart';

class SearchResult {
  final String keyword;
  final List<Song> songs;
  final List<Artist> artists;
  final List<Album> albums;
  final List<Playlist> playlists;
  final int totalCount;

  const SearchResult({
    required this.keyword,
    this.songs = const [],
    this.artists = const [],
    this.albums = const [],
    this.playlists = const [],
    this.totalCount = 0,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      keyword: json['keyword'] as String? ?? '',
      songs: (json['songs'] as List<dynamic>?)
              ?.map((e) => Song.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      artists: (json['artists'] as List<dynamic>?)
              ?.map((e) => Artist.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      albums: (json['albums'] as List<dynamic>?)
              ?.map((e) => Album.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      playlists: (json['playlists'] as List<dynamic>?)
              ?.map((e) => Playlist.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalCount: json['totalCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'keyword': keyword,
      'songs': songs.map((e) => e.toJson()).toList(),
      'artists': artists.map((e) => e.toJson()).toList(),
      'albums': albums.map((e) => e.toJson()).toList(),
      'playlists': playlists.map((e) => e.toJson()).toList(),
      'totalCount': totalCount,
    };
  }
}