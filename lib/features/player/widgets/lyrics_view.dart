import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jwsongbook/core/constants/app_constants.dart';
import 'package:jwsongbook/core/theme/app_colors.dart';
import 'package:jwsongbook/core/theme/app_typography.dart';
import 'package:jwsongbook/data/models/synced_lyrics_model.dart';
import 'package:jwsongbook/features/player/providers/lyrics_sync_provider.dart';
import 'package:jwsongbook/features/player/providers/player_provider.dart';
import 'package:jwsongbook/features/settings/screens/settings_screen.dart';
import 'package:jwsongbook/shared/widgets/empty_state.dart';

/// Scrolling karaoke-style lyrics view.
///
/// Displays word-by-word highlighted lyrics synced to the current playback
/// position.  Auto-scrolls to keep the active line at ~30 % from the top
/// when [AppSettings.autoScrollEnabled] is true.
/// The user can manually scroll; a "Follow lyrics" button re-enables auto-
/// scroll (Story S1-06).
class LyricsView extends ConsumerStatefulWidget {
  const LyricsView({super.key});

  @override
  ConsumerState<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends ConsumerState<LyricsView> {
  final _scrollController = ScrollController();
  bool _userScrolled = false;
  int _lastScrolledLineIndex = -1;

  static const double _lineHeight = 56.0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToLine(int lineIndex) {
    if (_userScrolled) return;
    if (lineIndex == _lastScrolledLineIndex) return;
    _lastScrolledLineIndex = lineIndex;

    final offset = (lineIndex * _lineHeight) -
        (_scrollController.position.viewportDimension *
            AppConstants.activeLyricLinePosition);

    _scrollController.animateTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: AppConstants.autoScrollDuration,
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lyricsAsync = ref.watch(currentSongLyricsProvider);
    final cursor = ref.watch(syncCursorProvider);
    final settings = ref.watch(appSettingsNotifierProvider);
    final playerNotifier = ref.read(playerNotifierProvider.notifier);

    // Auto-scroll only when the setting is on and the user hasn't manually
    // scrolled away.
    if (cursor.lineIndex >= 0 && !_userScrolled && settings.autoScrollEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollToLine(cursor.lineIndex);
        }
      });
    }

    return lyricsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load lyrics',
        subtitle: e.toString(),
      ),
      data: (lyrics) {
        if (lyrics.isEmpty) {
          return const EmptyState(
            icon: Icons.lyrics_outlined,
            title: 'No lyrics available',
            subtitle: 'Synced lyrics for this song are coming soon.',
          );
        }

        return Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n is UserScrollNotification) {
                  setState(() => _userScrolled = true);
                }
                return false;
              },
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(
                      horizontal: AppConstants.screenPaddingH,
                      vertical: constraints.maxHeight *
                          AppConstants.activeLyricLinePosition,
                    ),
                    itemCount: lyrics.lines.length,
                    itemBuilder: (context, index) {
                      final line = lyrics.lines[index];
                      final isActive = index == cursor.lineIndex;
                      final isPast = index < cursor.lineIndex;

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          setState(() {
                            _userScrolled = false;
                            _lastScrolledLineIndex = -1;
                          });
                          playerNotifier.seekMs(line.startMs);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppConstants.spaceSM,
                          ),
                          child: isActive
                              ? _ActiveLyricLine(
                                  line: line,
                                  cursor: cursor,
                                  congregationMode: settings.congregationMode,
                                  fontScaleFactor: settings.fontScaleFactor,
                                )
                              : _InactiveLyricLine(
                                  line: line,
                                  isPast: isPast,
                                  congregationMode: settings.congregationMode,
                                  fontScaleFactor: settings.fontScaleFactor,
                                ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const _LyricsEdgeFades(),
            // "Follow lyrics" button — only when auto-scroll is on and the
            // user has scrolled away from the active line.
            if (cursor.showInstrumentalGap)
              Center(
                child: _InstrumentalEllipsis(
                  congregationMode: settings.congregationMode,
                  fontScaleFactor: settings.fontScaleFactor,
                ),
              ),
            if (_userScrolled && settings.autoScrollEnabled)
              Positioned(
                top: 12,
                right: 16,
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _userScrolled = false;
                      _lastScrolledLineIndex = -1;
                    });
                    _scrollToLine(cursor.lineIndex);
                  },
                  icon: const Icon(Icons.sync, size: 16),
                  label: const Text('Sync'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.surfaceElevated.withAlpha(230),
                    foregroundColor: AppColors.primaryPurple,
                    side: BorderSide(
                      color: AppColors.primaryPurple.withAlpha(160),
                    ),
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: AppTypography.caption.copyWith(
                      color: AppColors.primaryPurple,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── Active line: word-by-word progressive fill ────────────────────────────────

class _LyricsEdgeFades extends StatelessWidget {
  const _LyricsEdgeFades();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Column(
        children: [
          Container(
            height: 72,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.background, Colors.transparent],
              ),
            ),
          ),
          const Spacer(),
          Container(
            height: 88,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, AppColors.background],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InstrumentalEllipsis extends StatefulWidget {
  const _InstrumentalEllipsis({
    required this.congregationMode,
    required this.fontScaleFactor,
  });

  final bool congregationMode;
  final double fontScaleFactor;

  @override
  State<_InstrumentalEllipsis> createState() => _InstrumentalEllipsisState();
}

class _InstrumentalEllipsisState extends State<_InstrumentalEllipsis> {
  Timer? _timer;
  int _dots = 1;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      if (!mounted) return;
      setState(() => _dots = _dots == 3 ? 1 : _dots + 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.congregationMode
        ? AppTypography.lyricsProjectionUpcoming
        : AppTypography.lyricsUpcoming;

    return Text(
      '.' * _dots,
      style: base.copyWith(
        fontSize: (base.fontSize! * widget.fontScaleFactor) + 12,
        color: Colors.white,
        letterSpacing: 4,
      ),
    );
  }
}

class _ActiveLyricLine extends StatelessWidget {
  const _ActiveLyricLine({
    required this.line,
    required this.cursor,
    required this.congregationMode,
    required this.fontScaleFactor,
  });

  final SyncedLine line;
  final SyncCursor cursor;
  final bool congregationMode;
  final double fontScaleFactor;

  @override
  Widget build(BuildContext context) {
    final base = congregationMode
        ? AppTypography.lyricsProjectionActive
        : AppTypography.lyricsActive;
    final baseStyle = base.copyWith(
      fontSize: base.fontSize! * fontScaleFactor,
    );

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: List.generate(line.words.length, (i) {
        final word = line.words[i];
        final isHighlighted = i < cursor.wordIndex;
        final isActive = i == cursor.wordIndex;

        if (isActive) {
          return _ProgressFillWord(
            text: word.text,
            progress: cursor.wordFillProgress,
            style: baseStyle,
          );
        }

        return Text(
          '${word.text} ',
          style: baseStyle.copyWith(
            color: isHighlighted
                ? AppColors.activeWordHighlight
                : AppColors.textHigh,
          ),
        );
      }),
    );
  }
}

/// Renders a single word with a left-to-right colour fill based on [progress].
class _ProgressFillWord extends StatelessWidget {
  const _ProgressFillWord({
    required this.text,
    required this.progress,
    required this.style,
  });

  final String text;
  final double progress;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        stops: [progress, progress],
        colors: const [AppColors.activeWordHighlight, AppColors.textHigh],
      ).createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Text('$text ', style: style),
    );
  }
}

// ── Inactive line ─────────────────────────────────────────────────────────────

class _InactiveLyricLine extends StatelessWidget {
  const _InactiveLyricLine({
    required this.line,
    required this.isPast,
    required this.congregationMode,
    required this.fontScaleFactor,
  });

  final SyncedLine line;
  final bool isPast;
  final bool congregationMode;
  final double fontScaleFactor;

  @override
  Widget build(BuildContext context) {
    final base = isPast
        ? (congregationMode
            ? AppTypography.lyricsProjectionUpcoming
            : AppTypography.lyricsPast)
        : (congregationMode
            ? AppTypography.lyricsProjectionUpcoming
            : AppTypography.lyricsUpcoming);

    final style = base.copyWith(
      fontSize: base.fontSize! * fontScaleFactor,
    );

    return Text(
      line.text,
      style: style,
      textAlign: congregationMode ? TextAlign.center : TextAlign.start,
    );
  }
}
