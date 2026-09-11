import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jwsongbook/core/platform/lyrics_overlay_bubble.dart';
import 'package:jwsongbook/core/theme/app_colors.dart';
import 'package:jwsongbook/core/theme/app_typography.dart';

enum FloatingLyricsRequestSource { discovery, settings }

Future<void> requestFloatingLyrics({
  required BuildContext context,
  required WidgetRef ref,
  required FloatingLyricsRequestSource source,
}) async {
  final bubble = ref.read(lyricsOverlayBubbleProvider);
  ref.read(floatingLyricsPermissionPendingProvider.notifier).state = false;

  final hasPermission = await bubble.canDrawOverlays();
  if (!context.mounted) return;
  if (hasPermission) {
    ref.read(floatingLyricsBubbleEnabledProvider.notifier).state = true;
    if (source == FloatingLyricsRequestSource.discovery) {
      showFloatingLyricsEnabledNotice(context);
    }
    return;
  }

  final shouldOpenSettings = await showDialog<bool>(
        context: context,
        builder: (_) => const _OverlayPermissionDialog(),
      ) ??
      false;
  if (!context.mounted) return;

  if (!shouldOpenSettings) {
    ref.read(floatingLyricsBubbleEnabledProvider.notifier).state = false;
    ref.read(floatingLyricsPermissionPendingProvider.notifier).state = false;
    if (source == FloatingLyricsRequestSource.discovery) {
      showFloatingLyricsSettingsReminder(context);
    }
    return;
  }

  ref.read(floatingLyricsBubbleEnabledProvider.notifier).state = false;
  ref.read(floatingLyricsPermissionPendingProvider.notifier).state = true;
  await bubble.openOverlaySettings();
}

void showFloatingLyricsSettingsReminder(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        'You can enable Floating Lyrics anytime in Settings.',
      ),
      duration: Duration(seconds: 4),
    ),
  );
}

void showFloatingLyricsEnabledNotice(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Floating Lyrics is on.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 2),
          Text(
            'It will appear when you leave Now Playing or use another app.',
          ),
        ],
      ),
      duration: Duration(seconds: 4),
    ),
  );
}

class FloatingLyricsDiscoveryBanner extends StatelessWidget {
  const FloatingLyricsDiscoveryBanner({
    required this.onDismiss,
    required this.onSetUp,
    super.key,
  });

  final VoidCallback onDismiss;
  final VoidCallback onSetUp;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Semantics(
      container: true,
      label: 'Floating lyrics setup',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Material(
          color: colors.card,
          elevation: 6,
          shadowColor: Colors.black.withAlpha(90),
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
              child: Row(
                children: [
                  const FloatingLyricsMark(size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Floating lyrics',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.appText.bodyMedium.copyWith(
                            color: colors.textHigh,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Show lyrics over other apps',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.appText.caption.copyWith(
                            color: colors.textMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: onSetUp,
                    style: TextButton.styleFrom(
                      foregroundColor: colors.primaryPurple,
                      backgroundColor: colors.primaryPurple.withAlpha(22),
                      minimumSize: const Size(68, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                    ),
                    child: const Text('Set up'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Not now',
                    onPressed: onDismiss,
                    icon: Icon(
                      Icons.close_rounded,
                      color: colors.textMedium,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FloatingLyricsMark extends StatelessWidget {
  const FloatingLyricsMark({required this.size, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF2B1F37),
          border: Border.all(
            color: colors.primaryPurple,
            width: 1,
          ),
        ),
        child: Text(
          'lyrics',
          maxLines: 1,
          style: TextStyle(
            color: const Color(0xE6F2EDF5),
            fontSize: size * 0.2,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _OverlayPermissionDialog extends StatelessWidget {
  const _OverlayPermissionDialog();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    return Dialog(
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FloatingLyricsMark(size: 48),
              const SizedBox(height: 16),
              Text(
                'Allow floating lyrics?',
                style: context.appText.bodyLarge.copyWith(
                  color: colors.textHigh,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'To show lyrics while you use other apps, allow JW Songs to '
                'display over other apps in Android settings.',
                style: context.appText.bodyMedium.copyWith(
                  color: colors.textMedium,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.primaryPurple,
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        side: BorderSide(color: colors.outline),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                      ),
                      child: const Text('Not now'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.primaryPurple,
                        foregroundColor: onPrimary,
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                      ),
                      child: const Text('Open settings'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
