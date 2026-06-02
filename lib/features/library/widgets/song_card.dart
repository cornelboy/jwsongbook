import 'package:flutter/material.dart';

import 'package:jwsongbook/core/theme/app_colors.dart';
import 'package:jwsongbook/core/theme/app_typography.dart';
import 'package:jwsongbook/data/database/app_database.dart';
import 'package:jwsongbook/data/models/song_model.dart';
import 'package:jwsongbook/features/downloads/providers/download_controller.dart';

class SongCard extends StatelessWidget {
  const SongCard({
    super.key,
    required this.song,
    required this.onTap,
    this.onFavoriteTap,
    this.onDownloadTap,
    this.downloadStatus = const SongDownloadStatus.idle(),
    this.isCurrentlyPlaying = false,
  });

  final Song song;
  final VoidCallback onTap;
  final VoidCallback? onFavoriteTap;
  final VoidCallback? onDownloadTap;
  final SongDownloadStatus downloadStatus;
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
                  ),
                ],
              ),
            ),
            _DownloadAction(
              hasLocalAudio: song.hasLocalAudio || downloadStatus.isDownloaded,
              status: downloadStatus,
              onTap: onDownloadTap,
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
  });

  final bool hasSyncedLyrics;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      const Text('Kingdom Song', style: AppTypography.caption),
    ];

    if (hasSyncedLyrics) {
      children.add(
        const _MetaItem(
          icon: Icons.lyrics_outlined,
          label: 'Synced',
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textMedium),
        const SizedBox(width: 4),
        Text(label, style: AppTypography.caption),
      ],
    );
  }
}

class _DownloadAction extends StatelessWidget {
  const _DownloadAction({
    required this.hasLocalAudio,
    required this.status,
    required this.onTap,
  });

  final bool hasLocalAudio;
  final SongDownloadStatus status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (hasLocalAudio) {
      return const SizedBox(width: 8);
    }

    if (status.isDownloading) {
      return SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: status.progress,
              color: AppColors.primaryPurple,
            ),
          ),
        ),
      );
    }

    return IconButton(
      onPressed: onTap,
      icon: const Icon(
        Icons.download_outlined,
        color: AppColors.textInactive,
      ),
      tooltip: 'Download',
      splashRadius: 22,
    );
  }
}
