import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jwsongbook/core/platform/lyrics_overlay_bubble.dart';
import 'package:jwsongbook/core/theme/app_colors.dart';
import 'package:jwsongbook/core/theme/app_typography.dart';
import 'package:jwsongbook/data/database/app_database.dart';
import 'package:jwsongbook/data/models/song_model.dart';
import 'package:jwsongbook/data/repositories/songs_repository.dart';
import 'package:jwsongbook/features/favorites/actions/favorite_actions.dart';
import 'package:jwsongbook/features/player/providers/player_provider.dart';
import 'package:jwsongbook/features/player/widgets/lyrics_view.dart';
import 'package:jwsongbook/features/player/widgets/player_controls.dart';
import 'package:jwsongbook/features/settings/screens/settings_screen.dart';
import 'package:jwsongbook/shared/widgets/empty_state.dart';
import 'package:jwsongbook/shared/widgets/floating_lyrics_permission.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key, this.initialSongNumber});

  /// When navigated to via /song/:number, auto-play this song exactly once.
  final int? initialSongNumber;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  static const _floatingLyricsDiscoveryDelay = Duration(seconds: 10);
  static const _floatingLyricsDiscoveryDuration = Duration(seconds: 15);

  bool _isOpeningRequestedSong = false;
  bool _requestedSongMissing = false;
  bool _floatingLyricsDiscoveryQueued = false;
  bool _showFloatingLyricsDiscovery = false;
  Timer? _floatingLyricsDiscoveryTimer;
  Timer? _floatingLyricsDismissTimer;

  @override
  void initState() {
    super.initState();
    // Trigger only once on mount — never on rebuild.
    if (widget.initialSongNumber != null) {
      _isOpeningRequestedSong = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_openRequestedSong());
      });
    }
  }

  @override
  void dispose() {
    _floatingLyricsDiscoveryTimer?.cancel();
    _floatingLyricsDismissTimer?.cancel();
    super.dispose();
  }

  Future<void> _openRequestedSong() async {
    final song = await ref
        .read(songsRepositoryProvider)
        .getByNumber(widget.initialSongNumber!);
    if (!mounted) return;

    if (song == null) {
      setState(() {
        _isOpeningRequestedSong = false;
        _requestedSongMissing = true;
      });
      return;
    }

    await ref.read(playerNotifierProvider.notifier).playSong(song);
    if (!mounted) return;
    setState(() => _isOpeningRequestedSong = false);
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerNotifierProvider);
    _scheduleFloatingLyricsDiscovery(playerState);
    final playerSong = playerState.currentSong;
    final song = playerSong == null
        ? null
        : ref.watch(_songByNumberProvider(playerSong.number)).valueOrNull ??
            playerSong;

    if (_isOpeningRequestedSong) {
      return Scaffold(
        appBar: AppBar(title: const Text('Now Playing')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_requestedSongMissing) {
      return Scaffold(
        appBar: AppBar(title: const Text('Now Playing')),
        body: const EmptyState(
          icon: Icons.music_off_outlined,
          title: 'Song not found',
          subtitle: 'This song is not available in the library.',
        ),
      );
    }

    if (song == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Now Playing')),
        body: const EmptyState(
          icon: Icons.music_note_outlined,
          title: 'Nothing playing',
          subtitle: 'Pick a song from the library to start.',
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _NowPlayingHeader(song: song),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const LyricsView(),
                  Align(
                    alignment: Alignment.topCenter,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        final curvedAnimation = CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        );
                        return FadeTransition(
                          opacity: curvedAnimation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, -0.08),
                              end: Offset.zero,
                            ).animate(curvedAnimation),
                            child: child,
                          ),
                        );
                      },
                      child: _showFloatingLyricsDiscovery
                          ? FloatingLyricsDiscoveryBanner(
                              key: const ValueKey(
                                'floating-lyrics-discovery',
                              ),
                              onDismiss: _declineFloatingLyricsDiscovery,
                              onSetUp: _setUpFloatingLyrics,
                            )
                          : const SizedBox.shrink(
                              key: ValueKey('no-floating-lyrics-discovery'),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const PlayerControls(),
          ],
        ),
      ),
    );
  }

  void _scheduleFloatingLyricsDiscovery(PlayerState playerState) {
    final canShow = playerState.hasSong &&
        playerState.isPlaying &&
        !playerState.isCompleted;
    if (!canShow) {
      if (!_showFloatingLyricsDiscovery) {
        _floatingLyricsDiscoveryTimer?.cancel();
        _floatingLyricsDiscoveryTimer = null;
        _floatingLyricsDiscoveryQueued = false;
      }
      return;
    }

    if (_floatingLyricsDiscoveryQueued || _showFloatingLyricsDiscovery) {
      return;
    }

    final settingsNotifier = ref.read(appSettingsNotifierProvider.notifier);
    if (!settingsNotifier.canPresentFloatingLyricsDiscovery ||
        ref.read(floatingLyricsBubbleEnabledProvider)) {
      return;
    }

    _floatingLyricsDiscoveryQueued = true;
    _floatingLyricsDiscoveryTimer = Timer(
      _floatingLyricsDiscoveryDelay,
      _presentFloatingLyricsDiscovery,
    );
  }

  void _presentFloatingLyricsDiscovery() {
    _floatingLyricsDiscoveryTimer = null;
    if (!mounted) return;

    final playerState = ref.read(playerNotifierProvider);
    final settingsNotifier = ref.read(appSettingsNotifierProvider.notifier);
    if (!playerState.hasSong ||
        !playerState.isPlaying ||
        playerState.isCompleted ||
        !settingsNotifier.canPresentFloatingLyricsDiscovery ||
        ref.read(floatingLyricsBubbleEnabledProvider)) {
      _floatingLyricsDiscoveryQueued = false;
      return;
    }

    settingsNotifier.recordFloatingLyricsDiscoveryImpression();
    setState(() => _showFloatingLyricsDiscovery = true);
    _floatingLyricsDismissTimer = Timer(
      _floatingLyricsDiscoveryDuration,
      _dismissFloatingLyricsDiscovery,
    );
  }

  void _dismissFloatingLyricsDiscovery() {
    _floatingLyricsDismissTimer?.cancel();
    _floatingLyricsDismissTimer = null;
    if (!mounted || !_showFloatingLyricsDiscovery) return;

    setState(() => _showFloatingLyricsDiscovery = false);
  }

  void _declineFloatingLyricsDiscovery() {
    ref
        .read(appSettingsNotifierProvider.notifier)
        .completeFloatingLyricsDiscovery();
    _dismissFloatingLyricsDiscovery();
    showFloatingLyricsSettingsReminder(context);
  }

  Future<void> _setUpFloatingLyrics() async {
    ref
        .read(appSettingsNotifierProvider.notifier)
        .completeFloatingLyricsDiscovery();
    _dismissFloatingLyricsDiscovery();
    await requestFloatingLyrics(
      context: context,
      ref: ref,
      source: FloatingLyricsRequestSource.discovery,
    );
  }
}

class _NowPlayingHeader extends StatelessWidget {
  const _NowPlayingHeader({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(
          bottom: BorderSide(color: colors.divider),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            if (context.canPop())
              IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: context.pop,
              ),
            _SongNumberBadge(song: song),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                song.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.appText.songTitle.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ),
            _FavoriteButton(song: song),
          ],
        ),
      ),
    );
  }
}

class _SongNumberBadge extends StatelessWidget {
  const _SongNumberBadge({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.primaryPurple.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.primaryPurple.withAlpha(70)),
      ),
      child: Text(
        song.paddedNumber,
        style: context.appText.songNumber.copyWith(fontSize: 16),
      ),
    );
  }
}

class _FavoriteButton extends ConsumerWidget {
  const _FavoriteButton({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;

    return IconButton(
      tooltip: song.isFavorited ? 'Remove from favorites' : 'Add to favorites',
      icon: Icon(
        song.isFavorited
            ? Icons.favorite_rounded
            : Icons.favorite_border_rounded,
        color: song.isFavorited ? colors.primaryPurple : colors.textMedium,
      ),
      onPressed: () => unawaited(
        toggleFavoriteWithFeedback(
          context: context,
          ref: ref,
          song: song,
        ),
      ),
    );
  }
}

final _songByNumberProvider = StreamProvider.family<Song?, int>(
  (ref, number) => ref.watch(songsRepositoryProvider).watchByNumber(number),
);
