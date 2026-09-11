import 'package:flutter/material.dart';
import 'package:jwsongbook/core/theme/app_colors.dart';

/// Matched offline status marks with identical circle and glyph geometry.
class OfflineStatusIcon extends StatelessWidget {
  const OfflineStatusIcon.download({
    this.size = 22,
    this.color,
    super.key,
  }) : isDownloaded = false;

  const OfflineStatusIcon.downloaded({
    this.size = 22,
    this.color,
    super.key,
  }) : isDownloaded = true;

  final double size;
  final Color? color;
  final bool isDownloaded;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color ?? colors.textMedium,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          isDownloaded ? Icons.check_rounded : Icons.arrow_downward_rounded,
          size: size * .58,
          color: colors.background,
        ),
      ),
    );
  }
}
