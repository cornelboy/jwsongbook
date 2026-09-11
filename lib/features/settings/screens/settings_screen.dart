import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jwsongbook/core/constants/app_constants.dart';
import 'package:jwsongbook/core/platform/lyrics_overlay_bubble.dart';
import 'package:jwsongbook/core/router/app_router.dart';
import 'package:jwsongbook/core/theme/app_colors.dart';
import 'package:jwsongbook/core/theme/app_typography.dart';
import 'package:jwsongbook/data/models/app_settings.dart';
import 'package:jwsongbook/data/repositories/app_settings_repository.dart';
import 'package:jwsongbook/data/repositories/songs_repository.dart';
import 'package:jwsongbook/features/downloads/providers/download_controller.dart';
import 'package:jwsongbook/features/downloads/screens/manage_downloads_screen.dart';
import 'package:jwsongbook/shared/widgets/floating_lyrics_permission.dart';
import 'package:jwsongbook/shared/widgets/offline_download_icon.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_screen.g.dart';

@Riverpod(keepAlive: true)
class AppSettingsNotifier extends _$AppSettingsNotifier {
  bool _floatingLyricsDiscoveryPresentedThisSession = false;

  @override
  AppSettings build() => ref.watch(appSettingsRepositoryProvider).current;

  void setFontScale(double scale) =>
      state = state.copyWith(fontScaleFactor: scale);

  void toggleAutoScroll() {
    state = state.copyWith(autoScrollEnabled: !state.autoScrollEnabled);
    persistInBackground();
  }

  void setThemePreference(AppThemePreference preference) {
    state = state.copyWith(themePreference: preference);
    persistInBackground();
  }

  bool get canPresentFloatingLyricsDiscovery =>
      !_floatingLyricsDiscoveryPresentedThisSession &&
      state.canShowFloatingLyricsDiscovery;

  void recordFloatingLyricsDiscoveryImpression() {
    if (!canPresentFloatingLyricsDiscovery) return;
    _floatingLyricsDiscoveryPresentedThisSession = true;
    state = state.copyWith(
      floatingLyricsDiscoveryImpressions:
          state.floatingLyricsDiscoveryImpressions + 1,
    );
    persistInBackground();
  }

  void completeFloatingLyricsDiscovery() {
    if (state.floatingLyricsDiscoveryCompleted) return;
    _floatingLyricsDiscoveryPresentedThisSession = true;
    state = state.copyWith(floatingLyricsDiscoveryCompleted: true);
    persistInBackground();
  }

  Future<void> persist() => ref.read(appSettingsRepositoryProvider).save(state);

  void persistInBackground() => unawaited(_persistSafely());

  Future<void> _persistSafely() async {
    try {
      await persist();
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'JW Songs settings',
          context: ErrorDescription('while saving app settings'),
        ),
      );
    }
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final settings = ref.watch(appSettingsNotifierProvider);
    final notifier = ref.read(appSettingsNotifierProvider.notifier);
    final downloadState = ref.watch(downloadControllerProvider);
    final downloadSummaryAsync = ref.watch(downloadedSongsSummaryProvider);
    final songCountAsync = ref.watch(songCountProvider);
    final showFloatingLyricsBubble =
        ref.watch(floatingLyricsBubbleEnabledProvider);
    final isDownloading = downloadState.isBatchDownloading ||
        downloadState.songs.values.any((status) => status.isDownloading);
    final isPaused = !isDownloading &&
        (downloadState.batchPaused || downloadState.hasPausedDownloads);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Display'),
          _AppearanceSetting(
            value: settings.themePreference,
            onChanged: notifier.setThemePreference,
          ),
          const _InsetDivider(),
          _FontScaleSetting(
            value: settings.fontScaleFactor,
            onChanged: notifier.setFontScale,
            onChangeEnd: notifier.persistInBackground,
          ),
          const _InsetDivider(),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: const Text('Auto-Scroll Lyrics'),
            subtitle: const Text(
              'Automatically scroll to keep the active line visible.',
            ),
            value: settings.autoScrollEnabled,
            onChanged: (_) => notifier.toggleAutoScroll(),
            activeThumbColor: colors.primaryPurple,
          ),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: const Text('Floating Lyrics Bubble'),
            subtitle: const Text(
              'Show a draggable lyrics bubble outside the app.',
            ),
            value: showFloatingLyricsBubble,
            onChanged: (value) => _setFloatingLyricsBubble(
              context: context,
              ref: ref,
              enabled: value,
            ),
            activeThumbColor: colors.primaryPurple,
          ),
          const _SectionDivider(),
          const _SectionHeader('Offline songs'),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: isDownloading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : isPaused
                    ? const Icon(Icons.play_arrow)
                    : const OfflineStatusIcon.download(size: 24),
            title: Text(
              isDownloading
                  ? 'Pause download all'
                  : isPaused
                      ? 'Resume download all'
                      : 'Download all songs',
            ),
            subtitle: _DownloadSubtitle(
              downloadState: downloadState,
              downloadsReady: AppConstants.hasSongManifestUrl,
            ),
            onTap: !AppConstants.hasSongManifestUrl
                ? null
                : isDownloading
                    ? () => ref
                        .read(downloadControllerProvider.notifier)
                        .pauseAllDownloads()
                    : () => _downloadAllSongs(context, ref),
          ),
          const _InsetDivider(),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: const Icon(Icons.folder_delete_outlined),
            title: const Text('Manage downloaded songs'),
            subtitle: Text(
              downloadSummaryAsync.maybeWhen(
                data: (summary) {
                  if (summary.count == 0) return 'No downloaded songs';
                  final label = summary.count == 1 ? 'song' : 'songs';
                  return '${summary.count} $label downloaded - ${formatDownloadBytes(summary.totalBytes)}';
                },
                orElse: () => 'Checking downloads...',
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.manageDownloads),
          ),
          const _SectionDivider(),
          const _SectionHeader('About'),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: const Text('Total Songs'),
            trailing: Text(
              songCountAsync.maybeWhen(
                data: (count) => '$count',
                orElse: () => '...',
              ),
              style: context.appText.bodyMedium,
            ),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: const Text('Version'),
            trailing: Text('0.1.0', style: context.appText.bodyMedium),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _downloadAllSongs(BuildContext context, WidgetRef ref) async {
    await ref.read(downloadControllerProvider.notifier).downloadAllSongs();
    if (!context.mounted) return;

    final message = ref.read(downloadControllerProvider).globalMessage;
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      ref.read(downloadControllerProvider.notifier).clearGlobalMessage();
    }
  }

  Future<void> _setFloatingLyricsBubble({
    required BuildContext context,
    required WidgetRef ref,
    required bool enabled,
  }) async {
    final bubble = ref.read(lyricsOverlayBubbleProvider);

    if (!enabled) {
      ref.read(floatingLyricsBubbleEnabledProvider.notifier).state = false;
      await bubble.hideBubble();
      return;
    }

    await requestFloatingLyrics(
      context: context,
      ref: ref,
      source: FloatingLyricsRequestSource.settings,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        label.toUpperCase(),
        style: context.appText.caption.copyWith(
          color: context.appColors.primaryPurple,
          letterSpacing: 0,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AppearanceSetting extends StatelessWidget {
  const _AppearanceSetting({required this.value, required this.onChanged});

  final AppThemePreference value;
  final ValueChanged<AppThemePreference> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Appearance',
            style: context.appText.bodyLarge.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Choose how JW Songs looks on this device.',
            style: context.appText.bodyMedium,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<AppThemePreference>(
              showSelectedIcon: false,
              style: ButtonStyle(
                minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  return states.contains(WidgetState.selected)
                      ? colors.primaryPurple
                      : colors.textMedium;
                }),
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  return states.contains(WidgetState.selected)
                      ? colors.primaryPurple.withAlpha(30)
                      : Colors.transparent;
                }),
                side: WidgetStatePropertyAll(
                  BorderSide(color: colors.divider),
                ),
                shape: const WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                ),
              ),
              segments: const [
                ButtonSegment(
                  value: AppThemePreference.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('Dark'),
                ),
                ButtonSegment(
                  value: AppThemePreference.light,
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('Light'),
                ),
                ButtonSegment(
                  value: AppThemePreference.system,
                  icon: Icon(Icons.brightness_auto_outlined),
                  label: Text('System'),
                ),
              ],
              selected: {value},
              onSelectionChanged: (selection) => onChanged(selection.single),
            ),
          ),
        ],
      ),
    );
  }
}

class _FontScaleSetting extends StatelessWidget {
  const _FontScaleSetting({
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final VoidCallback onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final percentage = '${(value * 100).round()}%';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Lyrics Font Size',
                  style: context.appText.bodyLarge.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                percentage,
                style: context.appText.bodyMedium.copyWith(
                  color: colors.primaryPurple,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: 0.8,
            max: 1.6,
            divisions: 8,
            label: percentage,
            onChanged: onChanged,
            onChangeEnd: (_) => onChangeEnd(),
          ),
        ],
      ),
    );
  }
}

class _InsetDivider extends StatelessWidget {
  const _InsetDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 16, endIndent: 16);
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 24, indent: 16, endIndent: 16);
  }
}

class _DownloadSubtitle extends StatelessWidget {
  const _DownloadSubtitle({
    required this.downloadState,
    required this.downloadsReady,
  });

  final DownloadState downloadState;
  final bool downloadsReady;

  @override
  Widget build(BuildContext context) {
    if (!downloadsReady) {
      return const Text('Waiting for server setup');
    }

    final progressLabel = downloadState.batchProgressLabel;
    if (progressLabel == null) {
      return const Text('Save every song for offline use');
    }

    final remainingLabel = downloadState.batchRemainingLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(progressLabel),
        if (remainingLabel != null)
          Text(
            remainingLabel,
            style: context.appText.caption,
          ),
      ],
    );
  }
}
