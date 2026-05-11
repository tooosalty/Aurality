import 'dart:math' as math;
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Waveform visualizer paired with audioplayers.
/// Resolves a private Firebase Storage path to a download URL before playback.
class WaveformWidget extends StatefulWidget {
  /// Firebase Storage path, e.g. "recordings/shouting_20240101_abc.wav"
  final String storagePath;
  final Color accentColor;
  final bool compact; // true = card size, false = detail full size

  const WaveformWidget({
    super.key,
    required this.storagePath,
    this.accentColor = AppColors.accentRed,
    this.compact = false,
  });

  @override
  State<WaveformWidget> createState() => _WaveformWidgetState();
}

class _WaveformWidgetState extends State<WaveformWidget> {
  final AudioPlayer _player = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = const Duration(seconds: 5);
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;

  bool _resolving = false; // true while fetching download URL
  String? _resolvedUrl;
  String? _resolveError;

  late final List<double> _bars;

  @override
  void initState() {
    super.initState();
    _bars = _generateBars(widget.compact ? 40 : 60);

    _posSub = _player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _durSub = _player.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });
    _stateSub = _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playerState = s);
    });
  }

  List<double> _generateBars(int count) {
    final rand = math.Random(42);
    return List.generate(count, (i) {
      final envelope = math.sin(i / count * math.pi);
      return 0.15 + envelope * (0.5 + rand.nextDouble() * 0.5);
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  /// Resolves the private storagePath → signed download URL, then plays.
  Future<void> _togglePlayback() async {
    if (_playerState == PlayerState.playing) {
      await _player.pause();
      return;
    }
    if (_playerState == PlayerState.completed) {
      await _player.seek(Duration.zero);
    }

    // If we already have a URL, play immediately
    if (_resolvedUrl != null) {
      await _player.play(UrlSource(_resolvedUrl!));
      return;
    }

    // Resolve the storage path to a download URL
    if (widget.storagePath.isEmpty) return;
    setState(() {
      _resolving = true;
      _resolveError = null;
    });
    try {
      final ref = FirebaseStorage.instance.ref(widget.storagePath);
      final url = await ref.getDownloadURL();
      if (!mounted) return;
      setState(() {
        _resolvedUrl = url;
        _resolving = false;
      });
      await _player.play(UrlSource(url));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resolveError = 'Audio unavailable';
        _resolving = false;
      });
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  double get _progress {
    if (_duration.inMilliseconds == 0) return 0;
    return (_position.inMilliseconds / _duration.inMilliseconds).clamp(
      0.0,
      1.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _playerState == PlayerState.playing;
    final barH = widget.compact ? 36.0 : 64.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Waveform bars + playhead
        SizedBox(
          height: barH,
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              return GestureDetector(
                onTapDown: (details) async {
                  if (_resolvedUrl == null) return;
                  final pct = details.localPosition.dx / constraints.maxWidth;
                  await _player.seek(
                    Duration(
                      milliseconds: (_duration.inMilliseconds * pct).round(),
                    ),
                  );
                },
                child: CustomPaint(
                  size: Size(constraints.maxWidth, barH),
                  painter: _WaveformPainter(
                    bars: _bars,
                    progress: _progress,
                    accentColor: widget.accentColor,
                    unplayedColor: AppColors.textMuted,
                    playedColor: AppColors.textSecondary,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // Controls row
        Row(
          children: [
            // Play / Pause / Loading button
            GestureDetector(
              onTap: _resolving ? null : _togglePlayback,
              child: Container(
                width: widget.compact ? 36 : 48,
                height: widget.compact ? 36 : 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.accentColor.withValues(alpha: 0.15),
                  border: Border.all(
                    color: widget.accentColor.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.accentColor.withValues(alpha: 0.25),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: _resolving
                    ? Padding(
                        padding: const EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                            widget.accentColor,
                          ),
                        ),
                      )
                    : Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: widget.accentColor,
                        size: widget.compact ? 20 : 28,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // Time OR error
            if (_resolveError != null)
              Text(
                _resolveError!,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: AppColors.accentRed,
                ),
              )
            else
              Text(
                '${_fmt(_position)} / ${_fmt(_duration)}',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: widget.compact ? 11 : 13,
                  color: AppColors.textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> bars;
  final double progress;
  final Color accentColor;
  final Color unplayedColor;
  final Color playedColor;

  _WaveformPainter({
    required this.bars,
    required this.progress,
    required this.accentColor,
    required this.unplayedColor,
    required this.playedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = bars.length;
    final totalGap = size.width * 0.25;
    final barW = (size.width - totalGap) / n;
    final gap = totalGap / n;
    final playheadX = size.width * progress;

    for (int i = 0; i < n; i++) {
      final x = i * (barW + gap);
      final bH = bars[i] * size.height;
      final top = (size.height - bH) / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, top, barW, bH),
        const Radius.circular(3),
      );
      final isPlayed = (x + barW / 2) < playheadX;
      canvas.drawRRect(
        rect,
        Paint()
          ..color = isPlayed ? playedColor : unplayedColor
          ..style = PaintingStyle.fill,
      );
    }

    if (progress > 0 && progress < 1) {
      canvas.drawLine(
        Offset(playheadX, 0),
        Offset(playheadX, size.height),
        Paint()
          ..color = accentColor.withValues(alpha: 0.3)
          ..strokeWidth = 6
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawLine(
        Offset(playheadX, 0),
        Offset(playheadX, size.height),
        Paint()
          ..color = accentColor
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress || old.bars != bars;
}
