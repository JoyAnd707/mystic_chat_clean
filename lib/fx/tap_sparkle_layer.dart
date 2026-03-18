import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class TapSparkleLayer extends StatefulWidget {
  final Widget child;

  /// Debug-only multiplier to make the tap FX physically larger/smaller on screen.
  /// Set to something huge (e.g. 6–12) to confirm you're running the right file.
  final double debugScale;

  const TapSparkleLayer({
    super.key,
    required this.child,
    this.debugScale = 0.1,
  });

  @override
  State<TapSparkleLayer> createState() => _TapSparkleLayerState();
}

class _SparkleBurst {
  final Offset position;
  final int id;

  _SparkleBurst({
    required this.position,
    required this.id,
  });
}

class _TapSparkleLayerState extends State<TapSparkleLayer> {
  final List<_SparkleBurst> _bursts = <_SparkleBurst>[];
  int _nextId = 0;

  void _spawn(Offset pos) {
    setState(() {
      _bursts.add(_SparkleBurst(position: pos, id: _nextId++));
    });
  }

  void _remove(int id) {
    if (!mounted) return;
    setState(() {
      _bursts.removeWhere((b) => b.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('TapSparkleLayer BUILD ✅  scale=${widget.debugScale}');
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final local = box.globalToLocal(event.position);
        debugPrint('TapSparkleLayer TAP ✅  local=$local  scale=${widget.debugScale}');
        _spawn(local);
      },
      child: Stack(
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: Stack(
                children: _bursts
                    .map(
                      (b) => _OneTapSparkle(
                        key: ValueKey<int>(b.id),
                        position: b.position,
                        scale: widget.debugScale,
                        onDone: () => _remove(b.id),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OneTapSparkle extends StatefulWidget {
  final Offset position;
  final VoidCallback onDone;
  final double scale;

  const _OneTapSparkle({
    super.key,
    required this.position,
    required this.onDone,
    required this.scale,
  });

  @override
  State<_OneTapSparkle> createState() => _OneTapSparkleState();
}
class _OuterStarSeed {
  final double angle;        // כיוון
  final double jitterX;      // סטייה של "מרכז הפיצוץ" (נורמליזציה -1..1)
  final double jitterY;      // סטייה של "מרכז הפיצוץ" (נורמליזציה -1..1)
  final double radiusMul;    // כמה רחוק הכוכב מגיע יחסית לאחרים
  final double sizeMul;      // וריאציה קטנה בגודל
  final double spin;         // סיבוב קטן לכל כוכב

  _OuterStarSeed({
    required this.angle,
    required this.jitterX,
    required this.jitterY,
    required this.radiusMul,
    required this.sizeMul,
    required this.spin,
  });
}


class _OneTapSparkleState extends State<_OneTapSparkle> {
  static const int _frameCount = 11;
  static const Duration _frameDuration = Duration(milliseconds: 35);

  static const int _starCount = 8;

  Timer? _timer;
  int _frameIndex = 0; // 0..10

  late final List<_OuterStarSeed> _outerSeeds;

  @override
  void initState() {
    super.initState();

    final rnd = math.Random(DateTime.now().microsecondsSinceEpoch);
    _outerSeeds = List.generate(_starCount, (_) {
      return _OuterStarSeed(
        angle: rnd.nextDouble() * 2 * math.pi,
        jitterX: (rnd.nextDouble() * 2 - 1), // -1..1
        jitterY: (rnd.nextDouble() * 2 - 1), // -1..1
        radiusMul: 0.9 + rnd.nextDouble() * 0.7, // 0.9..1.6

        sizeMul: 0.85 + rnd.nextDouble() * 0.35, // 0.85..1.20
        spin: (rnd.nextDouble() * 2 - 1) * 0.6, // -0.6..0.6 rad
      );
    });

    _timer = Timer.periodic(_frameDuration, (t) {
      if (!mounted) return;
      setState(() {
        _frameIndex++;
        if (_frameIndex >= _frameCount - 1) {
          _timer?.cancel();
          _timer = null;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onDone();
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  Widget build(BuildContext context) {
    // ✅ Pixel-based sizes so `scale` is a TRUE multiplier.
    const double baseCircleSize = 64.0;
    const double baseInnerStarSize = 28.0;
    const double baseOuterStarSize = 25.0;

    const double baseRippleStart = 12.0;
    const double baseRippleEnd = 60.0;

    final circleSize = baseCircleSize * widget.scale;
    final innerStarSize = baseInnerStarSize * widget.scale;
    final outerStarSize = baseOuterStarSize * widget.scale;

    final rippleStart = baseRippleStart * widget.scale;
    final rippleEnd = baseRippleEnd * widget.scale;

    // Frame windows (0..10)
    final innerLifeT = (_frameIndex / 6.0).clamp(0.0, 1.0); // frames 0..6
    final outerLifeT = (_frameIndex / 7.0).clamp(0.0, 1.0); // frames 0..7

    // Circle fade (start earlier)
    const int circleFadeStart = 6;
    final int circleFadeEnd = _frameCount - 1; // 10

    double circleOpacity = 1.0;
    if (_frameIndex > circleFadeStart) {
      final fadeT =
          ((_frameIndex - circleFadeStart) / (circleFadeEnd - circleFadeStart))
              .clamp(0.0, 1.0);
      circleOpacity = 1.0 - fadeT;
    }

    // Circle color: starts orange, fades to yellow
    const int orangeToYellowEndFrame = 4;
    final double orangeMix =
        (1.0 - (_frameIndex / orangeToYellowEndFrame)).clamp(0.0, 1.0);

    // Circle grows slightly over the whole lifetime (including fade-out)
final double circleLifeT =
    (_frameIndex / (_frameCount - 1)).clamp(0.0, 1.0); // 0..1

// Faster growth: reaches near-final size earlier
final double growthT = Curves.easeOutCubic.transform(circleLifeT);

final double circleScale = _lerp(1.0, 1.55, growthT);



    // Inner star shrinks + fades out by frame 6
    final innerScale = _lerp(1.0, 0.05, innerLifeT);
    final innerOpacity = 1.0 - innerLifeT;

    // Outer stars move outward + fade out across frames 0..7
    final rippleRadius = _lerp(rippleStart, rippleEnd, outerLifeT);
    final outerOpacity = 1.0 - outerLifeT;

    return Positioned(
      left: widget.position.dx - circleSize / 2,
      top: widget.position.dy - circleSize / 2,
      child: SizedBox(
        width: circleSize,
        height: circleSize,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Circle: orange -> yellow + grows slightly + fades out
            Opacity(
              opacity: circleOpacity,
              child: Transform.scale(
                scale: circleScale,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Base (yellow/original)
                    Image.asset(
                      'assets/fx/tap_circle.png',
                      width: circleSize,
                      height: circleSize,
                      fit: BoxFit.contain,
                    ),

                    // Orange overlay that fades out to reveal yellow
                    Opacity(
                      opacity: orangeMix,
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.mode(
                          Color(0xFFFF8A00),
                          BlendMode.modulate,
                        ),
                        child: Image.asset(
                          'assets/fx/tap_circle.png',
                          width: circleSize,
                          height: circleSize,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Inner star
            if (_frameIndex <= 6)
              Center(
                child: Opacity(
                  opacity: innerOpacity,
                  child: Transform.scale(
                    scale: innerScale,
                    child: Image.asset(
                      'assets/fx/tap_star_inner.png',
                      width: innerStarSize,
                      height: innerStarSize,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

            // Outer stars: random scatter per tap
            if (_frameIndex <= 7)
              ...List.generate(_outerSeeds.length, (i) {
                final s = _outerSeeds[i];

                final centerJitterRadius = circleSize * 0.18;
                final cx = circleSize / 2 + s.jitterX * centerJitterRadius;
                final cy = circleSize / 2 + s.jitterY * centerJitterRadius;

                final r = rippleRadius * s.radiusMul;

                final dx = math.cos(s.angle) * r;
                final dy = math.sin(s.angle) * r;

                final starSize = outerStarSize * s.sizeMul;

                return Positioned(
                  left: cx + dx - starSize / 2,
                  top: cy + dy - starSize / 2,
                  child: Opacity(
                    opacity: outerOpacity,
                    child: Transform.rotate(
                      angle: s.angle + (outerLifeT * s.spin),
                      child: Image.asset(
                        'assets/fx/tap_star_outer.png',
                        width: starSize,
                        height: starSize,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}


