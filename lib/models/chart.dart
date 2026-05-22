import 'package:json_annotation/json_annotation.dart';

import 'song.dart';

part 'chart.g.dart';

@JsonSerializable()
class Chart {
  final String id;
  final String name;
  final String type;
  final String? coverUrl;
  final List<Song>? songs;
  final DateTime? updateDate;

  const Chart({
    required this.id,
    required this.name,
    required this.type,
    this.coverUrl,
    this.songs,
    this.updateDate,
  });

  factory Chart.fromJson(Map<String, dynamic> json) => _$ChartFromJson(json);

  Map<String, dynamic> toJson() => _$ChartToJson(this);
}