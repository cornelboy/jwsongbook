import 'package:flutter/material.dart';

import 'package:jwsongbook/core/theme/app_colors.dart';

typedef PlaybackSeekCallback = Future<void> Function(Duration position);
typedef PlaybackSeekLabelBuilder = String Function(Duration position);

class PlaybackSeekSlider extends StatefulWidget {
  const PlaybackSeekSlider({
    required this.position,
    required this.duration,
    required this.onSeek,
    this.showTimeLabels = false,
    this.timeStyle,
    this.timeLabelPadding = const EdgeInsets.symmetric(horizontal: 8),
    this.markerPositions = const [],
    this.markerColor,
    this.thumbRadius,
    this.trackHeight,
    this.dragLabelBuilder,
    super.key,
  });

  final Duration position;
  final Duration duration;
  final PlaybackSeekCallback? onSeek;
  final bool showTimeLabels;
  final TextStyle? timeStyle;
  final EdgeInsetsGeometry timeLabelPadding;
  final List<double> markerPositions;
  final Color? markerColor;
  final double? thumbRadius;
  final double? trackHeight;
  final PlaybackSeekLabelBuilder? dragLabelBuilder;

  @override
  State<PlaybackSeekSlider> createState() => _PlaybackSeekSliderState();
}

class _PlaybackSeekSliderState extends State<PlaybackSeekSlider> {
  double? _dragValue;
  bool _isCommittingSeek = false;

  bool get _isEnabled =>
      widget.onSeek != null && widget.duration > Duration.zero;

  double get _liveValue {
    final durationMs = widget.duration.inMilliseconds;
    if (durationMs <= 0) return 0;
    return (widget.position.inMilliseconds / durationMs).clamp(0.0, 1.0);
  }

  double get _displayValue => (_dragValue ?? _liveValue).clamp(0.0, 1.0);

  Duration get _displayPosition => Duration(
        milliseconds: (_displayValue * widget.duration.inMilliseconds).round(),
      );

  @override
  void didUpdateWidget(covariant PlaybackSeekSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration <= Duration.zero && _dragValue != null) {
      _dragValue = null;
      _isCommittingSeek = false;
    }
  }

  void _handleChangeStart(double value) {
    if (!_isEnabled || _isCommittingSeek) return;
    setState(() => _dragValue = value);
  }

  void _handleChanged(double value) {
    if (!_isEnabled || _isCommittingSeek) return;
    setState(() => _dragValue = value);
  }

  Future<void> _handleChangeEnd(double value) async {
    final onSeek = widget.onSeek;
    if (!_isEnabled || _isCommittingSeek || onSeek == null) return;

    final target = Duration(
      milliseconds:
          (value.clamp(0.0, 1.0) * widget.duration.inMilliseconds).round(),
    );
    setState(() {
      _dragValue = value;
      _isCommittingSeek = true;
    });

    try {
      await onSeek(target);
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'JW Songs playback controls',
          context: ErrorDescription('while committing a slider seek'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _dragValue = null;
          _isCommittingSeek = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget slider = Slider(
      value: _displayValue,
      onChangeStart: _isEnabled ? _handleChangeStart : null,
      onChanged: _isEnabled ? _handleChanged : null,
      onChangeEnd: _isEnabled ? _handleChangeEnd : null,
      label: widget.dragLabelBuilder?.call(_displayPosition),
      semanticFormatterCallback: (value) => _formatDuration(
        Duration(
          milliseconds: (value * widget.duration.inMilliseconds).round(),
        ),
      ),
    );

    if (widget.markerPositions.isNotEmpty ||
        widget.thumbRadius != null ||
        widget.trackHeight != null ||
        widget.dragLabelBuilder != null) {
      final theme = SliderTheme.of(context);
      slider = SliderTheme(
        data: theme.copyWith(
          trackHeight: widget.trackHeight ?? theme.trackHeight,
          trackShape: widget.markerPositions.isEmpty
              ? theme.trackShape
              : _MarkerSliderTrackShape(
                  markerPositions: widget.markerPositions,
                  markerColor:
                      widget.markerColor ?? context.appColors.textInactive,
                ),
          thumbShape: widget.thumbRadius == null
              ? theme.thumbShape
              : RoundSliderThumbShape(
                  enabledThumbRadius: widget.thumbRadius!,
                  disabledThumbRadius: widget.thumbRadius!,
                ),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
          showValueIndicator: widget.dragLabelBuilder == null
              ? theme.showValueIndicator
              : ShowValueIndicator.onDrag,
        ),
        child: slider,
      );
    }

    if (!widget.showTimeLabels) return slider;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        slider,
        Padding(
          padding: widget.timeLabelPadding,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(_displayPosition), style: widget.timeStyle),
              Text(_formatDuration(widget.duration), style: widget.timeStyle),
            ],
          ),
        ),
      ],
    );
  }

  static String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _MarkerSliderTrackShape extends RoundedRectSliderTrackShape {
  const _MarkerSliderTrackShape({
    required this.markerPositions,
    required this.markerColor,
  });

  final List<double> markerPositions;
  final Color markerColor;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    super.paint(
      context,
      offset,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      enableAnimation: enableAnimation,
      textDirection: textDirection,
      thumbCenter: thumbCenter,
      secondaryOffset: secondaryOffset,
      isDiscrete: isDiscrete,
      isEnabled: isEnabled,
      additionalActiveTrackHeight: additionalActiveTrackHeight,
    );

    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final paint = Paint()..color = markerColor;

    for (final position in markerPositions) {
      final value = position.clamp(0.0, 1.0);
      final logicalValue =
          textDirection == TextDirection.rtl ? 1 - value : value;
      final center = Offset(
        trackRect.left + (trackRect.width * logicalValue),
        trackRect.center.dy,
      );
      context.canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: 2, height: 8),
          const Radius.circular(1),
        ),
        paint,
      );
    }
  }
}
