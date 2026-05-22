import 'dart:math';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class CustomLoadingIndicator extends StatefulWidget {
  final String? text;
  final double size;
  final LoadingStyle style;

  const CustomLoadingIndicator({
    super.key,
    this.text,
    this.size = 48.0,
    this.style = LoadingStyle.spinningDisc,
  });

  @override
  State<CustomLoadingIndicator> createState() => _CustomLoadingIndicatorState();
}

class _CustomLoadingIndicatorState extends State<CustomLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _rotationAnimation = Tween<double>(begin: 0, end: 2 * pi).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: widget.size,
            height: widget.size,
            child: _buildAnimation(),
          ),
          if (widget.text != null) ...[
            const SizedBox(height: 16),
            Text(
              widget.text!,
              style: const TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnimation() {
    return switch (widget.style) {
      LoadingStyle.spinningDisc => _buildSpinningDisc(),
      LoadingStyle.musicNote => _buildMusicNote(),
    };
  }

  Widget _buildSpinningDisc() {
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _rotationAnimation.value,
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _DiscPainter(),
          ),
        );
      },
    );
  }

  Widget _buildMusicNote() {
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        final t = _rotationAnimation.value;
        final scale1 = 0.8 + 0.2 * sin(t);
        final scale2 = 0.8 + 0.2 * sin(t + pi / 2);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Transform.scale(
              scale: scale1,
              child: const Icon(
                Icons.music_note_rounded,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 2),
            Transform.scale(
              scale: scale2,
              child: const Icon(
                Icons.music_note_rounded,
                color: AppColors.textSecondaryDark,
                size: 20,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DiscPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final bgPaint = Paint()
      ..color = AppColors.dividerDark
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    final arcPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 6),
      -pi / 2,
      4 * pi / 3,
      false,
      arcPaint,
    );

    final dotPaint = Paint()
      ..color = AppColors.textPrimaryDark
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 8, dotPaint);

    final innerPaint = Paint()
      ..color = AppColors.cardDark
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 5, innerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

enum LoadingStyle {
  spinningDisc,
  musicNote,
}