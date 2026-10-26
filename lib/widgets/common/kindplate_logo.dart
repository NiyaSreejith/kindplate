import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class KindPlateLogo extends StatelessWidget {
  final double size;
  final bool showWordmark;
  final bool showTagline;
  final Color? wordmarkColor;
  final Color? leafColor;
  final bool isDarkBackground;

  const KindPlateLogo({
    super.key,
    this.size = 64,
    this.showWordmark = true,
    this.showTagline = true,
    this.wordmarkColor,
    this.leafColor,
    this.isDarkBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveWordmarkColor = wordmarkColor ?? (isDarkBackground ? Colors.white : AppColors.forestGreen);
    final effectiveTaglineColor = isDarkBackground ? Colors.white.withValues(alpha: 0.85) : AppColors.mutedText;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Exact vector icon replicating 3 leaves inside a bowl from design sheet
        SizedBox(
          width: size,
          height: size * 0.85,
          child: CustomPaint(
            painter: _KindPlateBowlLeafPainter(
              primaryColor: leafColor ?? (isDarkBackground ? Colors.white : AppColors.forestGreen),
              accentColor: isDarkBackground ? const Color(0xFFA7C4A0) : AppColors.sageGreen,
            ),
          ),
        ),
        if (showWordmark) ...[
          const SizedBox(height: 8),
          Text(
            'KindPlate',
            style: AppTypography.displayLarge.copyWith(
              fontSize: (size * 0.46).clamp(18.0, 36.0),
              fontWeight: FontWeight.w700,
              color: effectiveWordmarkColor,
              letterSpacing: -0.3,
            ),
          ),
        ],
        if (showTagline) ...[
          const SizedBox(height: 4),
          Text(
            'Good food. Greater good.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              fontSize: (size * 0.22).clamp(11.0, 15.0),
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
              color: effectiveTaglineColor,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ],
    );
  }
}

class _KindPlateBowlLeafPainter extends CustomPainter {
  final Color primaryColor;
  final Color accentColor;

  _KindPlateBowlLeafPainter({
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Bottom bowl / plate curve
    final bowlPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;

    final bowlPath = Path()
      ..moveTo(w * 0.12, h * 0.68)
      ..cubicTo(w * 0.25, h * 0.98, w * 0.75, h * 0.98, w * 0.88, h * 0.68)
      ..cubicTo(w * 0.70, h * 0.84, w * 0.30, h * 0.84, w * 0.12, h * 0.68)
      ..close();
    canvas.drawPath(bowlPath, bowlPaint);

    // 2. Center tall leaf
    final centerLeafPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;

    final centerLeaf = Path()
      ..moveTo(w * 0.50, h * 0.72)
      ..cubicTo(w * 0.36, h * 0.45, w * 0.40, h * 0.18, w * 0.50, h * 0.05)
      ..cubicTo(w * 0.60, h * 0.18, w * 0.64, h * 0.45, w * 0.50, h * 0.72)
      ..close();
    canvas.drawPath(centerLeaf, centerLeafPaint);

    // 3. Left sprouting leaf
    final leftLeafPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    final leftLeaf = Path()
      ..moveTo(w * 0.46, h * 0.68)
      ..cubicTo(w * 0.28, h * 0.55, w * 0.15, h * 0.38, w * 0.20, h * 0.22)
      ..cubicTo(w * 0.34, h * 0.28, w * 0.42, h * 0.46, w * 0.46, h * 0.68)
      ..close();
    canvas.drawPath(leftLeaf, leftLeafPaint);

    // 4. Right sprouting leaf
    final rightLeafPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;

    final rightLeaf = Path()
      ..moveTo(w * 0.54, h * 0.68)
      ..cubicTo(w * 0.58, h * 0.46, w * 0.66, h * 0.28, w * 0.80, h * 0.22)
      ..cubicTo(w * 0.85, h * 0.38, w * 0.72, h * 0.55, w * 0.54, h * 0.68)
      ..close();
    canvas.drawPath(rightLeaf, rightLeafPaint);
  }

  @override
  bool shouldRepaint(covariant _KindPlateBowlLeafPainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor || oldDelegate.accentColor != accentColor;
  }
}
