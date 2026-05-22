import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../providers/player_provider.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(musicPlayerProvider);
    final song = playerState.currentSong;
    final isPlaying = playerState.isPlaying;
    final position = playerState.position;
    final duration = playerState.duration;

    final double progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: song != null ? 64.0 : 0.0,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: song != null ? 1.0 : 0.0,
        child: song != null
            ? GestureDetector(
                onTap: () => context.push('/player'),
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.cardDark,
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 2,
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: AppColors.dividerDark,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: SizedBox(
                                  width: 42,
                                  height: 42,
                                  child: song.coverUrl != null
                                      ? Image.network(
                                          song.coverUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (
                                            context,
                                            error,
                                            stackTrace,
                                          ) {
                                            return _buildPlaceholderCover();
                                          },
                                        )
                                      : _buildPlaceholderCover(),
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
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      song.artists
                                          .map((a) => a.name)
                                          .join(' / '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.textSecondaryDark,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: AppColors.textPrimaryDark,
                                  size: 28,
                                ),
                                onPressed: () {
                                  ref
                                      .read(musicPlayerProvider.notifier)
                                      .togglePlayPause();
                                },
                                splashRadius: 20,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 40,
                                  minHeight: 40,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.skip_next_rounded,
                                  color: AppColors.textPrimaryDark,
                                  size: 28,
                                ),
                                onPressed: () {
                                  ref
                                      .read(musicPlayerProvider.notifier)
                                      .next();
                                },
                                splashRadius: 20,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 40,
                                  minHeight: 40,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildPlaceholderCover() {
    return Container(
      color: AppColors.dividerDark,
      child: const Icon(
        Icons.music_note_rounded,
        color: AppColors.textSecondaryDark,
        size: 24,
      ),
    );
  }
}