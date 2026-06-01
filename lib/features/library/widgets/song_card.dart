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
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Song number badge
            SizedBox(
              width: 44,
              child: Text(
                song.paddedNumber,
                style: AppTypography.songNumber.copyWith(
                  color: isCurrentlyPlaying
                      ? AppColors.primaryPurple
                      : AppColors.textMedium,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Title + synced badge
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
                  if (song.hasSyncedLyrics) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.lyrics_outlined,
                          size: 12,
                          color: AppColors.textMedium,
                        ),
                        const SizedBox(width: 4),
                        Text('Synced', style: AppTypography.caption),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Favorite button
            if (onFavoriteTap != null)
              IconButton(
                onPressed: onFavoriteTap,
                icon: Icon(
                  song.isFavorited ? Icons.favorite : Icons.favorite_outline,
                  color: song.isFavorited
                      ? AppColors.primaryPurple
                      : AppColors.textMedium,
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 48,
                  minHeight: 48,
                ),
              ),
            // Now-playing indicator
            if (isCurrentlyPlaying)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.equalizer,
                  color: AppColors.primaryPurple,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
