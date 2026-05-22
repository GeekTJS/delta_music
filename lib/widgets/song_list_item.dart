import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/song.dart';

class SongListItem extends StatelessWidget {
  final Song song;
  final VoidCallback? onTap;
  final VoidCallback? onLikeTap;
  final VoidCallback? onMoreTap;
  final int? index;
  final bool showIndex;

  const SongListItem({
    super.key,
    required this.song,
    this.onTap,
    this.onLikeTap,
    this.onMoreTap,
  })  : index = null,
        showIndex = false;

  const SongListItem.withIndex({
    super.key,
    required this.song,
    required this.index,
    this.onTap,
    this.onLikeTap,
    this.onMoreTap,
  })  : showIndex = true;

  String _formatDuration(int milliseconds) {
    final totalSeconds = milliseconds ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            if (showIndex && index != null) ...[
              SizedBox(
                width: 32,
                child: Text(
                  '${index! + 1}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: index! < 3
                        ? AppColors.primary
                        : AppColors.textSecondaryDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 48,
                height: 48,
                child: song.coverUrl != null
                    ? CachedNetworkImage(
                        imageUrl: song.coverUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => _buildPlaceholder(),
                        errorWidget: (context, url, error) =>
                            _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimaryDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    song.artists.map((a) => a.name).join(' / '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondaryDark,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (onLikeTap != null) ...[
              GestureDetector(
                onTap: onLikeTap,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    song.isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_outline_rounded,
                    size: 20,
                    color: song.isLiked
                        ? AppColors.primary
                        : AppColors.textSecondaryDark,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 8),
            Text(
              _formatDuration(song.duration),
              style: const TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 12,
              ),
            ),
            if (onMoreTap != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onMoreTap,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.more_vert_rounded,
                    size: 20,
                    color: AppColors.textSecondaryDark,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.dividerDark,
      child: const Icon(
        Icons.music_note_rounded,
        color: AppColors.textSecondaryDark,
        size: 22,
      ),
    );
  }
}