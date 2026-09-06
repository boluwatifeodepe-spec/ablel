import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class CircularProgressGauge extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final int percentage;
  final double size;

  const CircularProgressGauge({
    super.key,
    required this.progress,
    required this.percentage,
    this.size = 200,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer Soft Glow
          Container(
            width: size * 0.88,
            height: size * 0.88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryPurple.withOpacity(0.3),
                  blurRadius: 40,
                  spreadRadius: 8,
                ),
              ],
            ),
          ),
          // Custom Ring Painter
          CustomPaint(
            size: Size(size, size),
            painter: _GaugePainter(
              progress: progress,
              trackColor: const Color(0xFF1E2638),
              progressGradient: AppColors.vibrantPurpleGradient,
            ),
          ),
          // Centered Percentage Text
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$percentage%',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.2,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  shadows: [
                    Shadow(
                      color: AppColors.primaryPurple.withOpacity(0.8),
                      blurRadius: 16,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Gradient progressGradient;

  _GaugePainter({
    required this.progress,
    required this.trackColor,
    required this.progressGradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 24) / 2;
    const strokeWidth = 14.0;

    // Track Paint
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress Arc Paint
    if (progress > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      final progressPaint = Paint()
        ..shader = progressGradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final sweepAngle = 2 * pi * progress.clamp(0.0, 1.0);
      canvas.drawArc(
        rect,
        -pi / 2, // Start at top
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
