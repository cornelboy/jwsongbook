import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jwsongbook/core/constants/app_constants.dart';
import 'package:jwsongbook/core/theme/app_colors.dart';
import 'package:jwsongbook/core/theme/app_typography.dart';
import 'package:jwsongbook/data/database/app_database.dart';
import 'package:jwsongbook/data/models/song_model.dart';
import 'package:jwsongbook/data/models/synced_lyrics_model.dart';
import 'package:jwsongbook/data/services/song_download_service.dart';
import 'package:jwsongbook/features/player/providers/lyrics_sync_provider.dart';
import 'package:jwsongbook/features/player/providers/player_provider.dart';
import 'package:jwsongbook/features/settings/screens/settings_screen.dart';
import 'package:jwsongbook/shared/widgets/empty_state.dart';

/// Scrolling karaoke-style lyrics view.
///
/// Displays word-by-word highlighted lyrics synced to the current playback
/// position.  Auto-scrolls to keep the active line at ~30 % from the top
/// when [AppSettings.autoScrollEnabled] is true.
/// After a drag, visible lyrics resume following after a short delay. Lyrics
/// dragged off-screen stay paused until the user requests "Follow lyrics".
class LyricsView extends ConsumerStatefulWidget {
  const LyricsView({super.key});

  @override
  ConsumerState<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends ConsumerState<LyricsView> {
  final _scrollController = ScrollController();
  final _lyricsViewportKey = GlobalKey();
  final Map<int, GlobalKey> _lineKeys = <int, GlobalKey>{};
  final Set<int> _autoCheckedLyrics = <int>{};
  bool _userScrolled = false;
  bool _isAutoScrolling = false;
  bool _isCheckingLyrics = false;
  String? _lyricsCheckMessage;
  bool _lyricsCheckFailed = false;
  int? _lyricsCheckSongNumber;
  int _lastScrolledLineIndex = -1;
  int _lastSeekRevision = -1;
  int _lastPositionMs = 0;
  int _autoScrollGeneration = 0;
  int? _lastSongId;
  bool? _lastCongregationMode;
  double? _lastFontScaleFactor;
  bool _lastIsPlaying = false;
  bool _isUserDragging = false;
  bool _followWhenNeeded = false;
  Timer? _followResumeTimer;
  bool _isResumingFollow = false;
  int _scrollRequestGeneration = 0;
  bool _hasPositionedLyrics = false;
  bool _isInitialPositionPending = false;

  @override
  void dispose() {
    _cancelFollowResume();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkForLyrics(Song song, {required bool manual}) async {
    if (_isCheckingLyrics && _lyricsCheckSongNumber == song.number) return;

    if (!AppConstants.hasSongManifestUrl) {
      if (manual && mounted) {
        setState(() {
          _lyricsCheckFailed = true;
          _lyricsCheckMessage = 'Lyrics checking is not available right now.';
        });
      }
      return;
    }

    setState(() {
      _isCheckingLyrics = true;
      _lyricsCheckMessage = null;
      _lyricsCheckFailed = false;
      _lyricsCheckSongNumber = song.number;
    });

    final checkedSongNumber = song.number;
    try {
      final found =
          await ref.read(songDownloadServiceProvider).downloadMissingLyrics(
                song: song,
                manifestUri: Uri.parse(AppConstants.songManifestUrl),
              );
      if (!mounted || _lyricsCheckSongNumber != checkedSongNumber) return;

      if (found) {
        ref.invalidate(currentSongLyricsProvider);
      } else if (manual) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('No new synced lyrics found.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {
      if (manual && mounted && _lyricsCheckSongNumber == checkedSongNumber) {
        setState(() {
          _lyricsCheckFailed = true;
          _lyricsCheckMessage = 'Check your connection, then try again.';
        });
      }
    } finally {
      if (mounted && _lyricsCheckSongNumber == checkedSongNumber) {
        setState(() {
          _isCheckingLyrics = false;
          _lyricsCheckSongNumber = null;
        });
      }
    }
  }

  Future<bool> _scrollToLine(
    int lineIndex, {
    bool force = false,
    Duration? duration,
    bool resume = false,
  }) async {
    if (_isUserDragging) return false;
    if (!force && _userScrolled) return false;
    if (_isResumingFollow && !resume && !force) return true;
    if (!force && lineIndex == _lastScrolledLineIndex) return true;

    final lineContext = _lineKeys[lineIndex]?.currentContext;
    if (lineContext == null) return false;
    _lastScrolledLineIndex = lineIndex;
    final generation = ++_autoScrollGeneration;
    _isAutoScrolling = true;
    _isResumingFollow = resume;

    if (resume) {
      final target = lineContext.findRenderObject()!;
      final viewport = RenderAbstractViewport.of(target);
      final targetOffset = viewport
          .getOffsetToReveal(target, AppConstants.activeLyricLinePosition)
          .offset
          .clamp(
            _scrollController.position.minScrollExtent,
            _scrollController.position.maxScrollExtent,
          );
      final distance = (targetOffset - _scrollController.offset).abs();
      final fraction = (distance / _scrollController.position.viewportDimension)
          .clamp(0.0, 1.0);
      final minMs = AppConstants.lyricFollowResumeMinDuration.inMilliseconds;
      final maxMs = AppConstants.lyricFollowResumeMaxDuration.inMilliseconds;
      duration =
          Duration(milliseconds: (minMs + (maxMs - minMs) * fraction).round());
    }

    await Scrollable.ensureVisible(
      lineContext,
      alignment: AppConstants.activeLyricLinePosition,
      duration: duration ?? AppConstants.lyricFollowCatchUpDuration,
      curve: Curves.easeInOutCubic,
    );
    if (mounted && generation == _autoScrollGeneration) {
      _isAutoScrolling = false;
      if (_isResumingFollow) {
        setState(() => _isResumingFollow = false);
      }
    }
    return true;
  }

  void _scheduleScrollToLine(
    int lineIndex, {
    bool force = false,
    int attempts = 1,
    Duration? duration,
    bool resume = false,
  }) {
    if (lineIndex < 0) return;
    final requestGeneration = _scrollRequestGeneration;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_scrollController.hasClients ||
          requestGeneration != _scrollRequestGeneration) {
        return;
      }
      _scrollToLine(
        lineIndex,
        force: force,
        duration: duration,
        resume: resume,
      ).then((didScroll) {
        if (!mounted || requestGeneration != _scrollRequestGeneration) return;
        if (!didScroll && attempts > 1) {
          _scheduleScrollToLine(
            lineIndex,
            force: force,
            attempts: attempts - 1,
            duration: duration,
            resume: resume,
          );
        }
      });
    });
  }

  void _scheduleInitialPosition(
    int lineIndex, {
    int attempts = 6,
  }) {
    if (lineIndex < 0 || _hasPositionedLyrics || _isInitialPositionPending) {
      return;
    }
    _isInitialPositionPending = true;
    final songId = _lastSongId;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || songId != _lastSongId) {
        _isInitialPositionPending = false;
        return;
      }

      final didPosition = await _scrollToLine(
        lineIndex,
        force: true,
        duration: Duration.zero,
      );
      if (!mounted || songId != _lastSongId) return;

      _isInitialPositionPending = false;
      if (didPosition || attempts <= 1) {
        setState(() => _hasPositionedLyrics = true);
      } else {
        _scheduleInitialPosition(lineIndex, attempts: attempts - 1);
      }
    });
  }

  void _cancelAutoScroll({
    bool resetTarget = true,
    bool stopActivity = true,
  }) {
    _autoScrollGeneration++;
    _scrollRequestGeneration++;
    if (stopActivity && _scrollController.hasClients && _isAutoScrolling) {
      _scrollController.jumpTo(_scrollController.offset);
    }
    _isAutoScrolling = false;
    _isResumingFollow = false;
    if (resetTarget) _lastScrolledLineIndex = -1;
  }

  void _resetToTopAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _autoScrollGeneration++;
      _isAutoScrolling = true;
      _scrollController.jumpTo(0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _isAutoScrolling = false;
      });
    });
  }

  GlobalKey _lineKeyFor(int index) =>
      _lineKeys.putIfAbsent(index, GlobalKey.new);

  void _setFollowPaused(bool paused) {
    if (!mounted) return;
    ref.read(lyricsFollowPausedProvider.notifier).state = paused;
  }

  bool _isLineSafelyVisible(int lineIndex) {
    final lineBox =
        _lineKeys[lineIndex]?.currentContext?.findRenderObject() as RenderBox?;
    final viewportBox =
        _lyricsViewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (lineBox == null ||
        viewportBox == null ||
        !lineBox.attached ||
        !viewportBox.attached) {
      return false;
    }

    final lineTop = lineBox.localToGlobal(Offset.zero).dy;
    final lineBottom = lineTop + lineBox.size.height;
    final viewportTop = viewportBox.localToGlobal(Offset.zero).dy;
    final safeTop = viewportTop + AppConstants.lyricsTopFadeHeight;
    final safeBottom = viewportTop +
        viewportBox.size.height -
        AppConstants.lyricsBottomFadeHeight;
    final visibleTop = lineTop > safeTop ? lineTop : safeTop;
    final visibleBottom = lineBottom < safeBottom ? lineBottom : safeBottom;
    final visibleHeight = visibleBottom - visibleTop;

    return visibleHeight >= lineBox.size.height * 0.5;
  }

  void _finishUserScroll() {
    final requestGeneration = _scrollRequestGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _isUserDragging ||
          requestGeneration != _scrollRequestGeneration) {
        return;
      }

      final lyrics = ref.read(currentSongLyricsProvider).valueOrNull;
      if (lyrics == null || lyrics.isEmpty) return;
      final cursor = ref.read(syncCursorProvider);
      final positionMs = ref.read(playerNotifierProvider).positionMs;
      final liveLineIndex = cursor.lineIndex >= 0
          ? cursor.lineIndex
          : _playbackScrollTarget(
              lyrics: lyrics,
              cursor: cursor,
              positionMs: positionMs,
            ).lineIndex;
      final keepFollowing =
          liveLineIndex >= 0 && _isLineSafelyVisible(liveLineIndex);

      setState(() {
        _userScrolled = !keepFollowing;
        _followWhenNeeded = keepFollowing;
        _lastScrolledLineIndex = -1;
      });
      _setFollowPaused(!keepFollowing);
      if (keepFollowing) _armFollowResume();
    });
  }

  void _cancelFollowResume() {
    _followResumeTimer?.cancel();
    _followResumeTimer = null;
  }

  void _armFollowResume() {
    final player = ref.read(playerNotifierProvider);
    if (_followResumeTimer != null ||
        !_followWhenNeeded ||
        _isUserDragging ||
        !player.isPlaying ||
        player.isCompleted ||
        !ref.read(appSettingsNotifierProvider).autoScrollEnabled) {
      return;
    }
    _followResumeTimer = Timer(AppConstants.lyricFollowResumeDelay, () {
      _followResumeTimer = null;
      if (!mounted || !_followWhenNeeded || _isUserDragging) return;
      final player = ref.read(playerNotifierProvider);
      final lyrics = ref.read(currentSongLyricsProvider).valueOrNull;
      if (!player.isPlaying ||
          player.isCompleted ||
          lyrics == null ||
          !ref.read(appSettingsNotifierProvider).autoScrollEnabled) {
        return;
      }
      final cursor = ref.read(syncCursorProvider);
      final liveIndex = _syncTargetLineIndex(
        lyrics: lyrics,
        cursor: cursor,
        positionMs: player.positionMs + AppConstants.lyricVisualLeadMs,
      );
      if (!_isLineSafelyVisible(liveIndex)) return;
      setState(() => _resumeFollowing(liveIndex));
    });
  }

  void _resumeFollowing(int lineIndex) {
    _cancelFollowResume();
    _followWhenNeeded = false;
    _lastScrolledLineIndex = -1;
    // Hold the target until the catch-up finishes, even as playback ticks.
    _isResumingFollow = true;
    _scheduleScrollToLine(lineIndex, resume: true);
  }

  int _syncTargetLineIndex({
    required SyncedLyrics lyrics,
    required SyncCursor cursor,
    required int positionMs,
  }) {
    if (lyrics.isEmpty) return -1;
    if (cursor.lineIndex >= 0) return cursor.lineIndex;

    final nextLineIndex = lyrics.nextLineIndexAfter(positionMs);
    if (nextLineIndex >= 0) return nextLineIndex;

    return lyrics.lines.length - 1;
  }

  _AutoScrollTarget _playbackScrollTarget({
    required SyncedLyrics lyrics,
    required SyncCursor cursor,
    required int positionMs,
  }) {
    final visualPositionMs = positionMs + AppConstants.lyricVisualLeadMs;
    final nextIndex = cursor.lineIndex >= 0
        ? cursor.lineIndex + 1
        : lyrics.nextLineIndexAfter(visualPositionMs);
    final currentIndex = cursor.lineIndex >= 0
        ? cursor.lineIndex
        : nextIndex > 0
            ? nextIndex - 1
            : nextIndex >= 0
                ? nextIndex
                : lyrics.lines.length - 1;

    if (currentIndex < 0) return const _AutoScrollTarget.none();
    if (nextIndex < 0 || nextIndex >= lyrics.lines.length) {
      return _AutoScrollTarget(
        lineIndex: currentIndex,
        duration: AppConstants.lyricFollowCatchUpDuration,
      );
    }

    final visualStartMs =
        lyrics.lines[nextIndex].startMs - AppConstants.lyricVisualLeadMs;
    final transitionStartMs =
        visualStartMs - AppConstants.lyricPreScrollDuration.inMilliseconds;
    if (positionMs < transitionStartMs) {
      return _AutoScrollTarget(
        lineIndex: currentIndex,
        duration: AppConstants.lyricFollowCatchUpDuration,
      );
    }

    final remainingMs = (visualStartMs - positionMs)
        .clamp(
          AppConstants.lyricFollowCatchUpDuration.inMilliseconds,
          AppConstants.lyricPreScrollDuration.inMilliseconds,
        )
        .toInt();
    return _AutoScrollTarget(
      lineIndex: nextIndex,
      duration: Duration(milliseconds: remainingMs),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lyricsAsync = ref.watch(currentSongLyricsProvider);
    final cursor = ref.watch(syncCursorProvider);
    final settings = ref.watch(appSettingsNotifierProvider);
    final playerState = ref.watch(playerNotifierProvider);
    final song = playerState.currentSong;
    final playerNotifier = ref.read(playerNotifierProvider.notifier);
    final positionMs = playerState.positionMs;
    final isActivelyPlaying = playerState.isPlaying && !playerState.isCompleted;

    ref.listen<int>(lyricsFollowRequestProvider, (previous, next) {
      if (previous == next || !mounted) return;
      _cancelFollowResume();
      _cancelAutoScroll();

      final liveCursor = ref.read(syncCursorProvider);
      final liveLyrics = ref.read(currentSongLyricsProvider).valueOrNull;
      final targetLineIndex = liveLyrics == null
          ? liveCursor.lineIndex
          : _syncTargetLineIndex(
              lyrics: liveLyrics,
              cursor: liveCursor,
              positionMs: ref.read(playerNotifierProvider).positionMs,
            );
      setState(() {
        _userScrolled = false;
        _followWhenNeeded = false;
        _isUserDragging = false;
        _lastScrolledLineIndex = -1;
        _isResumingFollow = targetLineIndex >= 0;
      });
      _setFollowPaused(false);
      if (targetLineIndex >= 0) {
        _scheduleScrollToLine(
          targetLineIndex,
          force: true,
          attempts: 6,
          resume: true,
        );
      }
    });

    final songChanged = _lastSongId != song?.id;
    final seekChanged = _lastSeekRevision != playerState.seekRevision;
    final jumpedBack = _lastPositionMs - positionMs > 1500;
    final resetToStart = (seekChanged || jumpedBack) && positionMs < 1200;
    final layoutChanged = _lastCongregationMode != settings.congregationMode ||
        _lastFontScaleFactor != settings.fontScaleFactor;
    final playbackPaused = _lastIsPlaying && !isActivelyPlaying;
    _lastSongId = song?.id;
    _lastSeekRevision = playerState.seekRevision;
    _lastPositionMs = positionMs;
    _lastCongregationMode = settings.congregationMode;
    _lastFontScaleFactor = settings.fontScaleFactor;
    _lastIsPlaying = isActivelyPlaying;
    final shouldForceFollow =
        songChanged || seekChanged || jumpedBack || layoutChanged;
    if (shouldForceFollow) {
      _cancelFollowResume();
      _cancelAutoScroll(stopActivity: false);
      if (songChanged) {
        _hasPositionedLyrics = false;
        _isInitialPositionPending = false;
        _lyricsCheckSongNumber = null;
        _isCheckingLyrics = false;
        _lyricsCheckMessage = null;
        _lyricsCheckFailed = false;
      }
      _userScrolled = false;
      _followWhenNeeded = false;
      _isUserDragging = false;
      _lastScrolledLineIndex = -1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setFollowPaused(false);
      });
      if (songChanged || layoutChanged) {
        _lineKeys.clear();
      }
      if (resetToStart) {
        _resetToTopAfterLayout();
      }
    }

    if (!isActivelyPlaying || !settings.autoScrollEnabled) {
      _cancelFollowResume();
    }
    if (playbackPaused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _cancelAutoScroll();
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
          final currentSong = song;
          final canCheckLyrics =
              currentSong != null && currentSong.hasLocalAudio;

          if (canCheckLyrics &&
              !_isCheckingLyrics &&
              !_autoCheckedLyrics.contains(currentSong.number)) {
            _autoCheckedLyrics.add(currentSong.number);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _checkForLyrics(currentSong, manual: false);
              }
            });
          }

          return _MissingLyricsState(
            isChecking: _isCheckingLyrics,
            checkFailed: _lyricsCheckFailed,
            message: _lyricsCheckMessage,
            onCheck: canCheckLyrics
                ? () => _checkForLyrics(currentSong, manual: true)
                : null,
          );
        }

        final initialTarget = isActivelyPlaying
            ? _playbackScrollTarget(
                lyrics: lyrics,
                cursor: cursor,
                positionMs: positionMs,
              ).lineIndex
            : _syncTargetLineIndex(
                lyrics: lyrics,
                cursor: cursor,
                positionMs: positionMs + AppConstants.lyricVisualLeadMs,
              );
        if (!_hasPositionedLyrics) {
          _scheduleInitialPosition(initialTarget);
        } else if (!_userScrolled && settings.autoScrollEnabled) {
          if (shouldForceFollow) {
            final targetLineIndex = _syncTargetLineIndex(
              lyrics: lyrics,
              cursor: cursor,
              positionMs: positionMs + AppConstants.lyricVisualLeadMs,
            );
            _scheduleScrollToLine(
              targetLineIndex,
              force: true,
              attempts: 4,
              duration: AppConstants.lyricFollowCatchUpDuration,
            );
          } else if (isActivelyPlaying && !_isResumingFollow) {
            if (_followWhenNeeded) _armFollowResume();
            final target = _playbackScrollTarget(
              lyrics: lyrics,
              cursor: cursor,
              positionMs: positionMs,
            );
            final targetIsVisible =
                _followWhenNeeded && _isLineSafelyVisible(target.lineIndex);
            if (!targetIsVisible) {
              if (_followWhenNeeded) {
                _resumeFollowing(target.lineIndex);
              } else {
                _scheduleScrollToLine(
                  target.lineIndex,
                  duration: target.duration,
                );
              }
            }
          }
        }

        final stanzaStartIndices = lyrics.sections
            .skip(1)
            .map((section) => section.firstLineIndex)
            .toSet();

        return Opacity(
          opacity: _hasPositionedLyrics ? 1 : 0,
          child: Stack(
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  final isRealUserDrag = (n is ScrollStartNotification &&
                          n.dragDetails != null) ||
                      (n is ScrollUpdateNotification && n.dragDetails != null);
                  if (isRealUserDrag) {
                    _cancelFollowResume();
                    _cancelAutoScroll(
                      resetTarget: true,
                      stopActivity: false,
                    );
                    if (!_isUserDragging || !_userScrolled) {
                      setState(() {
                        _isUserDragging = true;
                        _userScrolled = true;
                        _followWhenNeeded = false;
                      });
                    }
                  } else if (n is ScrollEndNotification && _isUserDragging) {
                    _isUserDragging = false;
                    _finishUserScroll();
                  }
                  return false;
                },
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      key: _lyricsViewportKey,
                      controller: _scrollController,
                      padding: EdgeInsets.symmetric(
                        horizontal: AppConstants.screenPaddingH,
                        vertical: constraints.maxHeight *
                            AppConstants.activeLyricLinePosition,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: List.generate(lyrics.lines.length, (index) {
                          final line = lyrics.lines[index];
                          final isActive = index == cursor.lineIndex;
                          final isPast = index < cursor.lineIndex;
                          final startsStanza =
                              stanzaStartIndices.contains(index);
                          final stanzaGap = settings.congregationMode
                              ? AppConstants.lyricsProjectionStanzaGap
                              : AppConstants.lyricsStanzaGap;
                          const halfLineGap = AppConstants.lyricsLineGap / 2;

                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              _cancelFollowResume();
                              _cancelAutoScroll();
                              setState(() {
                                _userScrolled = false;
                                _followWhenNeeded = false;
                                _isUserDragging = false;
                                _lastScrolledLineIndex = -1;
                              });
                              _setFollowPaused(false);
                              playerNotifier.seekMs(line.startMs);
                            },
                            child: Padding(
                              padding: EdgeInsets.only(
                                top: startsStanza
                                    ? stanzaGap - halfLineGap
                                    : halfLineGap,
                                bottom: halfLineGap,
                              ),
                              child: Container(
                                key: _lineKeyFor(index),
                                child: _StableLyricLine(
                                  line: line,
                                  cursor: cursor,
                                  isActive: isActive,
                                  isPast: isPast,
                                  congregationMode: settings.congregationMode,
                                  fontScaleFactor: settings.fontScaleFactor,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  },
                ),
              ),
              const _LyricsEdgeFades(),
            ],
          ),
        );
      },
    );
  }
}

// ── Missing lyrics state ─────────────────────────────────────────────────────

class _MissingLyricsState extends StatelessWidget {
  const _MissingLyricsState({
    required this.isChecking,
    required this.checkFailed,
    required this.message,
    required this.onCheck,
  });

  final bool isChecking;
  final bool checkFailed;
  final String? message;
  final VoidCallback? onCheck;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final title =
        checkFailed ? "Couldn't check for lyrics" : 'Synced lyrics unavailable';
    final description = message ??
        "Synced lyrics haven't been added for this song yet.\n"
            'You can still listen to the audio.';

    return Center(
      child: Transform.translate(
        offset: const Offset(0, -12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lyrics_outlined,
                  size: 48,
                  color: colors.textInactive,
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: context.appText.bodyLarge.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: context.appText.bodyMedium,
                ),
                if (onCheck != null) ...[
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: isChecking ? null : onCheck,
                    icon: isChecking
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, size: 20),
                    label: Text(
                      isChecking
                          ? 'Checking...'
                          : checkFailed
                              ? 'Retry'
                              : 'Check again',
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Active line: word-by-word progressive fill ────────────────────────────────

class _AutoScrollTarget {
  const _AutoScrollTarget({
    required this.lineIndex,
    required this.duration,
  });

  const _AutoScrollTarget.none()
      : lineIndex = -1,
        duration = Duration.zero;

  final int lineIndex;
  final Duration duration;
}

class _LyricsEdgeFades extends StatelessWidget {
  const _LyricsEdgeFades();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final transparentBackground = colors.background.withAlpha(0);

    return IgnorePointer(
      child: Column(
        children: [
          Container(
            height: AppConstants.lyricsTopFadeHeight,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [colors.background, transparentBackground],
              ),
            ),
          ),
          const Spacer(),
          Container(
            height: AppConstants.lyricsBottomFadeHeight,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [transparentBackground, colors.background],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StableLyricLine extends StatelessWidget {
  const _StableLyricLine({
    required this.line,
    required this.cursor,
    required this.isActive,
    required this.isPast,
    required this.congregationMode,
    required this.fontScaleFactor,
  });

  final SyncedLine line;
  final SyncCursor cursor;
  final bool isActive;
  final bool isPast;
  final bool congregationMode;
  final double fontScaleFactor;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textStyles = context.appText;
    final activeBase = congregationMode
        ? textStyles.lyricsProjectionActive
        : textStyles.lyricsActive;
    final inactiveBase = isPast
        ? (congregationMode
            ? textStyles.lyricsProjectionUpcoming
            : textStyles.lyricsPast)
        : (congregationMode
            ? textStyles.lyricsProjectionUpcoming
            : textStyles.lyricsUpcoming);
    final activeStyle = activeBase.copyWith(
      fontSize: activeBase.fontSize! * fontScaleFactor,
    );
    final inactiveStyle = inactiveBase.copyWith(
      fontSize: inactiveBase.fontSize! * fontScaleFactor,
    );

    if (line.words.isEmpty) {
      return Text(
        line.text,
        style: isActive ? activeStyle : inactiveStyle,
        textAlign: congregationMode ? TextAlign.center : TextAlign.start,
      );
    }

    return Semantics(
      label: line.text,
      excludeSemantics: true,
      child: Wrap(
        alignment:
            congregationMode ? WrapAlignment.center : WrapAlignment.start,
        spacing: 6,
        runSpacing: 2,
        children: List.generate(line.words.length, (index) {
          final word = line.words[index];
          final isHighlighted = isActive && index < cursor.wordIndex;
          final isCurrentWord = isActive && index == cursor.wordIndex;

          return _StableLyricWord(
            text: word.text,
            activeStyle: activeStyle,
            displayStyle: isActive
                ? activeStyle.copyWith(
                    color: isHighlighted
                        ? colors.activeWordHighlight
                        : colors.textHigh,
                  )
                : inactiveStyle,
            progress: isCurrentWord ? cursor.wordFillProgress : null,
          );
        }),
      ),
    );
  }
}

class _StableLyricWord extends StatefulWidget {
  const _StableLyricWord({
    required this.text,
    required this.activeStyle,
    required this.displayStyle,
    required this.progress,
  });

  final String text;
  final TextStyle activeStyle;
  final TextStyle displayStyle;
  final double? progress;

  @override
  State<_StableLyricWord> createState() => _StableLyricWordState();
}

class _StableLyricWordState extends State<_StableLyricWord> {
  Size _slotSize = Size.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _measureSlot();
  }

  @override
  void didUpdateWidget(covariant _StableLyricWord oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text ||
        widget.activeStyle != oldWidget.activeStyle ||
        widget.displayStyle != oldWidget.displayStyle) {
      _measureSlot();
    }
  }

  void _measureSlot() {
    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final activePainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.activeStyle),
      textDirection: textDirection,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    final displayPainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.displayStyle),
      textDirection: textDirection,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    final slotWidth = (activePainter.width > displayPainter.width
            ? activePainter.width
            : displayPainter.width) +
        1;
    final slotHeight = activePainter.height > displayPainter.height
        ? activePainter.height
        : displayPainter.height;
    _slotSize = Size(slotWidth, slotHeight);
  }

  @override
  Widget build(BuildContext context) {
    final visibleWord = widget.progress == null
        ? Text(widget.text, style: widget.displayStyle)
        : _ProgressFillWord(
            text: widget.text,
            progress: widget.progress!,
            style: widget.activeStyle,
          );

    return SizedBox(
      width: _slotSize.width,
      height: _slotSize.height,
      child: Align(
        alignment: Alignment.centerLeft,
        child: visibleWord,
      ),
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
    final colors = context.appColors;

    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        stops: [progress, progress],
        colors: [colors.activeWordHighlight, colors.textHigh],
      ).createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Text(text, style: style),
    );
  }
}

// ── Inactive line ─────────────────────────────────────────────────────────────
