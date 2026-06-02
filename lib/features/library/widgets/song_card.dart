import 'package:flutter/material.dart';

import 'package:jwsongbook/core/theme/app_colors.dart';
import 'package:jwsongbook/core/theme/app_typography.dart';
import 'package:jwsongbook/data/database/app_database.dart';
import 'package:jwsongbook/data/models/song_model.dart';

class SongCard extends StatelessWidget {
  const SongCard({
    super.key,
    required this.song,
    required this.onTap,
    this.onFavoriteTap,
    this.isCurrentlyPlaying = false,
  });

  final Song song;
  final VoidCallback onTap;
  final VoidCallback? onFavoriteTap;
  final bool isCurrentlyPlaying;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            _SongNumberBadge(
              paddedNumber: song.paddedNumber,
              isActive: isCurrentlyPlaying,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    style: AppTypography.songTitle.copyWith(
                      color: isCurrentlyPlaying
                          ? AppColors.primaryPurple
                          : AppColors.textHigh,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  _SongMetaRow(
                    hasSyncedLyrics: song.hasSyncedLyrics,
                    isCurrentlyPlaying: isCurrentlyPlaying,
                  ),
                ],
              ),
            ),
            if (onFavoriteTap != null)
              IconButton(
                onPressed: onFavoriteTap,
                icon: Icon(
                  song.isFavorited ? Icons.favorite : Icons.favorite_outline,
                  color: song.isFavorited
                      ? AppColors.primaryPurple
                      : AppColors.textMedium,
                  size: 22,
                ),
                tooltip: song.isFavorited
                    ? 'Remove from favorites'
                    : 'Add to favorites',
                splashRadius: 22,
              ),
          ],
        ),
      ),
    );
  }
}

class _SongNumberBadge extends StatelessWidget {
  const _SongNumberBadge({
    required this.paddedNumber,
    required this.isActive,
  });

  final String paddedNumber;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color:
            isActive ? AppColors.primaryPurple.withAlpha(36) : AppColors.card,
        border: Border.all(
          color: isActive
              ? AppColors.primaryPurple.withAlpha(110)
              : AppColors.divider,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        paddedNumber,
        style: AppTypography.songNumber.copyWith(
          color: isActive ? AppColors.primaryPurple : AppColors.textMedium,
        ),
      ),
    );
  }
}

class _SongMetaRow extends StatelessWidget {
  const _SongMetaRow({
    required this.hasSyncedLyrics,
    required this.isCurrentlyPlaying,
  });

  final bool hasSyncedLyrics;
  final bool isCurrentlyPlaying;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      const Text('Kingdom Song', style: AppTypography.caption),
    ];

    if (hasSyncedLyrics) {
      children.addAll([
        const SizedBox(width: 8),
        const Icon(
          Icons.lyrics_outlined,
          size: 13,
          color: AppColors.textMedium,
        ),
        const SizedBox(width: 4),
        const Text('Synced', style: AppTypography.caption),
      ]);
    }

    if (isCurrentlyPlaying) {
      children.addAll([
        const SizedBox(width: 8),
        const Icon(
          Icons.equalizer,
          size: 13,
          color: AppColors.primaryPurple,
        ),
        const SizedBox(width: 4),
        Text(
          'Playing',
          style: AppTypography.caption.copyWith(
            color: AppColors.primaryPurple,
            fontWeight: FontWeight.w600,
          ),
        ),
      ]);
    }

    return Row(children: children);
  }
}
