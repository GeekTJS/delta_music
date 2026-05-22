import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/lyric.dart';

class LyricView extends StatefulWidget {
  final Lyric lyric;
  final Duration currentPosition;
  final double lineHeight;
  final double normalFontSize;
  final double highlightFontSize;
  final EdgeInsets padding;

  const LyricView({
    super.key,
    required this.lyric,
    required this.currentPosition,
    this.lineHeight = 42.0,
    this.normalFontSize = 15.0,
    this.highlightFontSize = 17.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
  });

  @override
  State<LyricView> createState() => _LyricViewState();
}

class _LyricViewState extends State<LyricView> {
  final ScrollController _scrollController = ScrollController();
  int _currentIndex = -1;

  @override
  void didUpdateWidget(covariant LyricView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final positionMs = widget.currentPosition.inMilliseconds;
    int newIndex = -1;

    for (int i = widget.lyric.lines.length - 1; i >= 0; i--) {
      if (widget.lyric.lines[i].timeMs <= positionMs) {
        newIndex = i;
        break;
      }
    }

    if (newIndex != _currentIndex) {
      _currentIndex = newIndex;
      _scrollToLine(newIndex);
    }
  }

  void _scrollToLine(int index) {
    if (!_scrollController.hasClients) return;
    if (index < 0 || index >= widget.lyric.lines.length) return;

    final targetOffset = (index * widget.lineHeight) -
        (_scrollController.position.viewportDimension / 2) +
        (widget.lineHeight / 2);

    final clampedOffset = targetOffset.clamp(
      _scrollController.position.minScrollExtent,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lyric.lines.isEmpty) {
      return Center(
        child: Text(
          '暂无歌词',
          style: TextStyle(
            color: AppColors.textSecondaryDark.withValues(alpha: 0.6),
            fontSize: 15,
          ),
        ),
      );
    }

    final positionMs = widget.currentPosition.inMilliseconds;

    final topPadding =
        _scrollController.hasClients && _scrollController.position.hasContentDimensions
            ? _scrollController.position.viewportDimension / 2 - widget.lineHeight / 2
            : 120.0;

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.only(top: topPadding, bottom: 120),
      itemCount: widget.lyric.lines.length,
      itemBuilder: (context, index) {
        final line = widget.lyric.lines[index];
        final isCurrent = index == _currentIndex;
        final isPast = line.timeMs < positionMs && index < _currentIndex;

        return SizedBox(
          height: widget.lineHeight,
          child: Padding(
            padding: widget.padding,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: TextStyle(
                    color: isCurrent
                        ? AppColors.primary
                        : AppColors.textSecondaryDark.withValues(
                            alpha: isPast ? 0.5 : 0.4,
                          ),
                    fontSize:
                        isCurrent ? widget.highlightFontSize : widget.normalFontSize,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                  ),
                  child: Text(
                    line.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (line.translation != null && widget.lyric.hasTranslation) ...[
                  const SizedBox(height: 2),
                  Text(
                    line.translation!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrent
                          ? AppColors.primary.withValues(alpha: 0.7)
                          : AppColors.textSecondaryDark.withValues(alpha: 0.3),
                      fontSize: widget.normalFontSize - 2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}