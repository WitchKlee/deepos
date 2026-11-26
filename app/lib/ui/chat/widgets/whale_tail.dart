// DeepOS geometric activity indicator (replaces upstream whale-tail sprite sheets
// with an original vector orbital pulse, zero external image assets).

import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Primary accent blue for light surfaces.
const deepSeekBlue = Color(0xFF4D6BFE);

/// Lifted accent blue for dark surfaces.
const deepSeekBlueDark = Color(0xFF7A98FB);

/// Default indicator color for [brightness].
Color whaleColorFor(Brightness brightness) => brightness == Brightness.dark ? deepSeekBlueDark : deepSeekBlue;

/// Retained layout ratio constant for callers.
abstract final class WhaleSprites {
  static const aspect = 1.0;

  @visibleForTesting
  static void reset() {}
}

/// Animated geometric orbital pulse indicator.
///
/// Responds smoothly to [level]:
/// - 0: waiting for user confirmation / answer (slow calm pulse)
/// - 1: running tools / waiting for first token (gentle orbit)
/// - 2..4: streaming output at increasing speed
/// When [still] is true (or reduced motion is enabled), draws a crisp static emblem.
class WhaleTail extends StatefulWidget {
  const WhaleTail({super.key, this.level = 1, required this.color, this.height = 20, this.still = false});

  final int level;
  final Color color;
  final double height;
  final bool still;

  @override
  State<WhaleTail> createState() => WhaleTailState();
}

class WhaleTailState extends State<WhaleTail> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final _repaint = ValueNotifier<int>(0);
  bool _reduced = false;

  static const _ease = 0.35;

  double _phase = 0;
  double _rate = 0.5;
  Duration _last = Duration.zero;

  static int formOf(int level) => level <= 2 ? 2 : level.clamp(2, 4);

  static double rateOf(int level) => switch (level) {
    <= 0 => 0.35,
    1 => 0.7,
    2 => 1.1,
    3 => 1.65,
    _ => 2.25,
  };

  @override
  void initState() {
    super.initState();
    _rate = rateOf(widget.level);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _sync();
  }

  @override
  void didUpdateWidget(WhaleTail oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  bool get _moving => !widget.still && !_reduced;

  @visibleForTesting
  int get shownForm => _moving ? formOf(widget.level) : 1;

  @visibleForTesting
  double get rate => _rate;

  @visibleForTesting
  int get frame => (_phase * 12).floor();

  void _sync() {
    if (_moving && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!_moving && _ticker.isActive) {
      _ticker.stop();
      _repaint.value++;
    }
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt <= 0 || dt > 0.25) return;
    final target = rateOf(widget.level);
    _rate += (target - _rate) * (1 - math.exp(-dt / _ease));
    _phase = (_phase + dt * _rate) % (math.pi * 200);
    _repaint.value++;
  }

  @override
  Widget build(BuildContext context) {
    final size = Size(widget.height * WhaleSprites.aspect, widget.height);
    return RepaintBoundary(
      child: CustomPaint(
        size: size,
        painter: _OrbitalPulsePainter(
          repaint: _repaint,
          color: widget.color,
          moving: _moving,
          phaseOf: () => _phase,
          level: widget.level,
        ),
      ),
    );
  }
}

class _OrbitalPulsePainter extends CustomPainter {
  _OrbitalPulsePainter({
    required Listenable repaint,
    required this.color,
    required this.moving,
    required this.phaseOf,
    required this.level,
  }) : super(repaint: repaint);

  final Color color;
  final bool moving;
  final double Function() phaseOf;
  final int level;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(size.width, size.height) * 0.42;
    final center = Offset(cx, cy);
    final phase = moving ? phaseOf() : 0.0;

    // Outer subtle ring
    final ringPaint = Paint()
      ..color = color.withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.4, size.height * 0.085);
    canvas.drawCircle(center, r, ringPaint);

    // Sweeping orbital arc
    final sweep = moving ? math.pi * (0.65 + 0.12 * level.clamp(0, 4)) : math.pi * 1.15;
    final startAngle = moving ? phase * 2.2 - math.pi / 2 : -math.pi * 0.72;
    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(1.8, size.height * 0.11);
    canvas.drawArc(Rect.fromCircle(center: center, radius: r), startAngle, sweep, false, arcPaint);

    // Inner breathing core diamond
    final pulse = moving ? 0.86 + 0.16 * math.sin(phase * 3.0) : 1.0;
    final coreR = r * 0.42 * pulse;
    final diamond = Path()
      ..moveTo(cx, cy - coreR)
      ..lineTo(cx + coreR, cy)
      ..lineTo(cx, cy + coreR)
      ..lineTo(cx - coreR, cy)
      ..close();
    canvas.drawPath(diamond, Paint()..color = color.withValues(alpha: 0.92));

    // Orbiting satellite dot
    final dotAngle = startAngle + sweep;
    final dotPos = Offset(cx + math.cos(dotAngle) * r, cy + math.sin(dotAngle) * r);
    canvas.drawCircle(dotPos, math.max(1.6, size.height * 0.09), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_OrbitalPulsePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.moving != moving || oldDelegate.level != level;
}
