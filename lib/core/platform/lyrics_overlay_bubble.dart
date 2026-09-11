import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jwsongbook/core/router/app_router.dart';
import 'package:jwsongbook/data/models/song_model.dart';
import 'package:jwsongbook/data/models/synced_lyrics_model.dart';
import 'package:jwsongbook/features/player/providers/lyrics_sync_provider.dart';
import 'package:jwsongbook/features/player/providers/player_provider.dart';

final floatingLyricsBubbleEnabledProvider = StateProvider<bool>((ref) => false);

final floatingLyricsPermissionPendingProvider =
    StateProvider<bool>((ref) => false);

final floatingLyricsBubbleExpandedProvider =
    StateProvider<bool>((ref) => false);

final lyricsOverlayBubbleProvider = Provider<LyricsOverlayBubble>(
  (ref) => const LyricsOverlayBubble(),
);

bool shouldSuppressFloatingLyricsForLocation(String location) {
  final path = Uri.tryParse(location)?.path;
  return path == AppRoutes.nowPlaying ||
      (path?.startsWith('${AppRoutes.nowPlaying}/') ?? false);
}

class LyricsOverlayBubble {
  const LyricsOverlayBubble();

  static const _channel = MethodChannel('com.example.jwsongbook/overlay');

  void setCommandHandler(
    Future<dynamic> Function(MethodCall call)? handler,
  ) {
    _channel.setMethodCallHandler(handler);
  }

  Future<bool> canDrawOverlays() async {
    if (!Platform.isAndroid) return false;
    return await _channel.invokeMethod<bool>('canDrawOverlays') ?? false;
  }

  Future<bool> consumePendingOpenPlayer() async {
    if (!Platform.isAndroid) return false;
    return await _channel.invokeMethod<bool>('consumePendingOpenPlayer') ??
        false;
  }

  Future<void> openOverlaySettings() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('openOverlaySettings');
  }

  Future<bool> updateBubble(ExternalLyricsOverlayState state) async {
    if (!Platform.isAndroid) return false;
    return await _channel.invokeMethod<bool>(
          'updateBubble',
          state.toChannelArguments(),
        ) ??
        false;
  }

  Future<void> hideBubble() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('hideBubble');
  }

  Future<void> collapseBubble() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('collapseBubble');
  }

  Future<void> setOverlaySuppressed(bool suppressed) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('setOverlaySuppressed', suppressed);
  }
}

class ExternalLyricsOverlayState {
  const ExternalLyricsOverlayState({
    required this.number,
    required this.title,
    required this.line,
    required this.nextLine,
    required this.lyricLines,
    required this.positionMs,
    required this.durationMs,
    required this.playing,
    required this.canControl,
    required this.darkTheme,
  });

  final String number;
  final String title;
  final String line;
  final String nextLine;
  final List<String> lyricLines;
  final int positionMs;
  final int durationMs;
  final bool playing;
  final bool canControl;
  final bool darkTheme;

  Map<String, Object?> toChannelArguments() => {
        'number': number,
        'title': title,
        'line': line,
        'nextLine': nextLine,
        'lyricLines': lyricLines,
        'positionMs': positionMs,
        'durationMs': durationMs,
        'playing': playing,
        'canControl': canControl,
        'darkTheme': darkTheme,
      };
}

class ExternalLyricsBubbleSync extends ConsumerStatefulWidget {
  const ExternalLyricsBubbleSync({
    super.key,
    required this.suppressWhileForeground,
  });

  final bool suppressWhileForeground;

  @override
  ConsumerState<ExternalLyricsBubbleSync> createState() =>
      _ExternalLyricsBubbleSyncState();
}

class _ExternalLyricsBubbleSyncState
    extends ConsumerState<ExternalLyricsBubbleSync>
    with WidgetsBindingObserver {
  String? _lastSyncKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.read(lyricsOverlayBubbleProvider).setCommandHandler(
          _handleOverlayCommand,
        );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumePendingOpenPlayer();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    const LyricsOverlayBubble().setCommandHandler(null);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ExternalLyricsBubbleSync oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.suppressWhileForeground == widget.suppressWhileForeground ||
        !ref.read(floatingLyricsBubbleEnabledProvider)) {
      return;
    }
    unawaited(_syncOverlaySuppression());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final enabled = ref.read(floatingLyricsBubbleEnabledProvider);
    if (enabled && state == AppLifecycleState.resumed) {
      unawaited(_syncOverlaySuppression());
    } else if (enabled &&
        (state == AppLifecycleState.hidden ||
            state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached)) {
      unawaited(
        ref.read(lyricsOverlayBubbleProvider).setOverlaySuppressed(false),
      );
    }

    if (state == AppLifecycleState.resumed) {
      _completePendingPermissionRequest();
    }
  }

  Future<void> _completePendingPermissionRequest() async {
    if (!ref.read(floatingLyricsPermissionPendingProvider)) return;

    final bubble = ref.read(lyricsOverlayBubbleProvider);
    final hasPermission = await bubble.canDrawOverlays();
    if (!mounted) return;

    ref.read(floatingLyricsPermissionPendingProvider.notifier).state = false;
    ref.read(floatingLyricsBubbleEnabledProvider.notifier).state =
        hasPermission;

    if (!hasPermission) {
      await bubble.hideBubble();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Floating Lyrics wasn\'t enabled.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } else if (widget.suppressWhileForeground) {
      _showFloatingLyricsEnabledNotice();
    }
  }

  Future<void> _syncOverlaySuppression() {
    final isForeground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    return ref.read(lyricsOverlayBubbleProvider).setOverlaySuppressed(
          isForeground && widget.suppressWhileForeground,
        );
  }

  void _showFloatingLyricsEnabledNotice() {
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

  Future<void> _handleOverlayCommand(MethodCall call) async {
    switch (call.method) {
      case 'togglePlayPause':
        if (!ref.read(playerNotifierProvider).hasSong) return;
        await ref.read(playerNotifierProvider.notifier).togglePlayPause();
        return;
      case 'closeBubble':
        ref.read(floatingLyricsBubbleEnabledProvider.notifier).state = false;
        ref.read(floatingLyricsPermissionPendingProvider.notifier).state =
            false;
        ref.read(floatingLyricsBubbleExpandedProvider.notifier).state = false;
        await ref.read(lyricsOverlayBubbleProvider).hideBubble();
        return;
      case 'openPlayer':
        ref.read(floatingLyricsBubbleExpandedProvider.notifier).state = false;
        if (mounted) context.go(AppRoutes.nowPlaying);
        return;
      case 'expandedChanged':
        ref.read(floatingLyricsBubbleExpandedProvider.notifier).state =
            call.arguments == true;
        return;
      default:
        throw MissingPluginException('Unknown overlay command: ${call.method}');
    }
  }

  Future<void> _consumePendingOpenPlayer() async {
    final shouldOpen =
        await ref.read(lyricsOverlayBubbleProvider).consumePendingOpenPlayer();
    if (!mounted || !shouldOpen) return;
    context.go(AppRoutes.nowPlaying);
  }

  @override
  Widget build(BuildContext context) {
    final darkTheme = Theme.of(context).brightness == Brightness.dark;
    final enabled = ref.watch(floatingLyricsBubbleEnabledProvider);
    final playerState = ref.watch(playerNotifierProvider);
    final song = playerState.currentSong;
    final lyricsAsync = ref.watch(currentSongLyricsProvider);
    final cursor = ref.watch(syncCursorProvider);
    final overlayState = song == null
        ? ExternalLyricsOverlayState(
            number: '---',
            title: 'JW Songs',
            line: 'Play a song to show floating lyrics.',
            nextLine: '',
            lyricLines: [],
            positionMs: 0,
            durationMs: 0,
            playing: false,
            canControl: false,
            darkTheme: darkTheme,
          )
        : ExternalLyricsOverlayState(
            number: song.paddedNumber,
            title: song.title,
            line: _currentLineText(
              lyricsAsync: lyricsAsync,
              cursor: cursor,
              positionMs: playerState.positionMs,
            ),
            nextLine: '',
            lyricLines: _lyricRows(lyricsAsync.valueOrNull),
            positionMs: playerState.positionMs,
            durationMs: playerState.duration.inMilliseconds,
            playing: playerState.isPlaying && !playerState.isCompleted,
            canControl: true,
            darkTheme: darkTheme,
          );
    final shouldShow = enabled;
    final syncKey = [
      shouldShow,
      overlayState.number,
      overlayState.title,
      overlayState.lyricLines.length,
      overlayState.lyricLines.isEmpty ? '' : overlayState.lyricLines.first,
      overlayState.lyricLines.isEmpty ? '' : overlayState.lyricLines.last,
      overlayState.lyricLines.isEmpty ? overlayState.line : '',
      overlayState.lyricLines.isEmpty ? overlayState.nextLine : '',
      playerState.seekRevision,
      playerState.duration.inMilliseconds,
      overlayState.playing,
      overlayState.canControl,
      overlayState.darkTheme,
    ].join('|');

    if (_lastSyncKey != syncKey) {
      _lastSyncKey = syncKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncBubble(shouldShow: shouldShow, state: overlayState);
      });
    }

    return const SizedBox.shrink();
  }

  Future<void> _syncBubble({
    required bool shouldShow,
    required ExternalLyricsOverlayState? state,
  }) async {
    final bubble = ref.read(lyricsOverlayBubbleProvider);
    if (!shouldShow || state == null) {
      await bubble.hideBubble();
      return;
    }

    final hasPermission = await bubble.canDrawOverlays();
    if (!hasPermission) {
      ref.read(floatingLyricsBubbleEnabledProvider.notifier).state = false;
      await bubble.hideBubble();
      return;
    }

    await bubble.updateBubble(state);
    await _syncOverlaySuppression();
  }

  String _currentLineText({
    required AsyncValue<SyncedLyrics> lyricsAsync,
    required SyncCursor cursor,
    required int positionMs,
  }) {
    final lyrics = lyricsAsync.valueOrNull;
    if (lyricsAsync.isLoading) return 'Waiting for lyrics';
    if (lyrics == null) return 'Waiting for lyrics';
    if (lyrics.isEmpty) {
      return 'Synced lyrics for this song are coming soon.';
    }
    if (cursor.lineIndex >= 0 && cursor.lineIndex < lyrics.lines.length) {
      return lyrics.lines[cursor.lineIndex].text;
    }
    return _lineAfter(lyrics, positionMs)?.text ?? 'Waiting for lyrics';
  }

  SyncedLine? _lineAfter(SyncedLyrics lyrics, int positionMs) {
    for (final line in lyrics.lines) {
      if (line.startMs > positionMs) return line;
    }
    return null;
  }

  List<String> _lyricRows(SyncedLyrics? lyrics) {
    if (lyrics == null || lyrics.isEmpty) return const [];
    return [
      for (final line in lyrics.lines)
        '${line.startMs}\t${line.endMs}\t${line.text.replaceAll('\t', ' ')}',
    ];
  }
}
