import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jwsongbook/core/constants/app_constants.dart';
import 'package:jwsongbook/core/theme/app_colors.dart';
import 'package:jwsongbook/core/theme/app_typography.dart';
import 'package:jwsongbook/features/downloads/providers/download_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_screen.g.dart';

// ── Settings state ────────────────────────────────────────────────────────────

class AppSettings {
  const AppSettings({
    this.congregationMode = false,
    this.fontScaleFactor = 1.0,
    this.autoScrollEnabled = true,
  });

  final bool congregationMode;
  final double fontScaleFactor;
  final bool autoScrollEnabled;

  AppSettings copyWith({
    bool? congregationMode,
    double? fontScaleFactor,
    bool? autoScrollEnabled,
  }) =>
      AppSettings(
        congregationMode: congregationMode ?? this.congregationMode,
        fontScaleFactor: fontScaleFactor ?? this.fontScaleFactor,
        autoScrollEnabled: autoScrollEnabled ?? this.autoScrollEnabled,
      );
}

@Riverpod(keepAlive: true)
class AppSettingsNotifier extends _$AppSettingsNotifier {
  @override
  AppSettings build() => const AppSettings();

  void toggleCongregationMode() =>
      state = state.copyWith(congregationMode: !state.congregationMode);

  void setFontScale(double scale) =>
      state = state.copyWith(fontScaleFactor: scale);

  void toggleAutoScroll() =>
      state = state.copyWith(autoScrollEnabled: !state.autoScrollEnabled);
}

// ── Screen ───────────────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsNotifierProvider);
    final notifier = ref.read(appSettingsNotifierProvider.notifier);
    final downloadState = ref.watch(downloadControllerProvider);
    final isDownloading = downloadState.songs.values.any(
      (status) => status.isDownloading,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ── Display ──────────────────────────────────────────────────────
          const _SectionHeader('Display'),
          SwitchListTile(
            title: const Text('Congregation Mode'),
            subtitle: const Text(
              'Larger text, centre-aligned — optimised for projection.',
            ),
            value: settings.congregationMode,
            onChanged: (_) => notifier.toggleCongregationMode(),
            activeThumbColor: AppColors.primaryPurple,
          ),
          ListTile(
            title: const Text('Font Size'),
            subtitle: Slider(
              value: settings.fontScaleFactor,
              min: 0.8,
              max: 1.6,
              divisions: 8,
              label: '${(settings.fontScaleFactor * 100).round()}%',
              onChanged: notifier.setFontScale,
            ),
          ),
          SwitchListTile(
            title: const Text('Auto-Scroll Lyrics'),
            subtitle: const Text(
              'Automatically scroll to keep the active line visible.',
            ),
            value: settings.autoScrollEnabled,
            onChanged: (_) => notifier.toggleAutoScroll(),
            activeThumbColor: AppColors.primaryPurple,
          ),

          const Divider(height: 32),

          // ── About ─────────────────────────────────────────────────────────
          const _SectionHeader('Downloads'),
          ListTile(
            leading: isDownloading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_outlined),
            title: const Text('Download all songs'),
            subtitle: const Text(
              AppConstants.songManifestUrl == null
                  ? 'Waiting for server setup'
                  : 'Save every song for offline use',
            ),
            onTap: isDownloading ? null : () => _downloadAllSongs(context, ref),
          ),

          const Divider(height: 32),

          const _SectionHeader('About'),
          const ListTile(
            title: Text('Total Songs'),
            trailing: Text(
              '${AppConstants.totalSongs}',
              style: AppTypography.bodyMedium,
            ),
          ),
          const ListTile(
            title: Text('Version'),
            trailing: Text('0.1.0', style: AppTypography.bodyMedium),
          ),
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
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.caption.copyWith(
          color: AppColors.primaryPurple,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
