import 'package:flutter/material.dart';
import 'package:jwsongbook/core/theme/app_colors.dart';

class PlaylistCover extends StatelessWidget {
  const PlaylistCover({
    required this.name,
    this.size = 52,
    super.key,
  });

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final initial = name.trim().isEmpty ? '♪' : name.trim()[0].toUpperCase();
    final foreground = Theme.of(context).colorScheme.onPrimary;

    return Semantics(
      image: true,
      label: '$name playlist cover',
      child: ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.primaryPurple, colors.activeWordHighlight],
            ),
            borderRadius: BorderRadius.circular(size * .2),
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    color: foreground,
                    fontSize: size * .4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Positioned(
                right: size * .1,
                bottom: size * .08,
                child: Icon(
                  Icons.queue_music_rounded,
                  size: size * .24,
                  color: foreground.withAlpha(180),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
