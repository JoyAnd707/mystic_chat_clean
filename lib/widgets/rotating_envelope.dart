import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RotatingEnvelope extends StatefulWidget {
  final String assetPath;

  /// Overall icon box size (square)
  final double size;

  /// Rotation cycle duration
  final Duration duration;

  /// Base icon opacity
  final double opacity;

  /// 3D perspective amount
  final double perspective;

  /// Glow color (tint)
  final Color glowColor;

  /// Glow opacity (0..1) ✅ strength
  final double glowOpacity;

  /// Glow blur sigma ✅ softness/spread
  final double glowSigma;

  /// Optional: extra tight glow layer (makes lines pop)
  final double tightGlowOpacity;
  final double tightGlowSigma;

  const RotatingEnvelope({
    super.key,
    required this.assetPath,
    this.size = 200,
    this.duration = const Duration(milliseconds: 1600),
    this.opacity = 1.0,
    this.perspective = 0.0026,
    this.glowColor = const Color(0xFF6FFFE9),
    this.glowOpacity = 0.70,
    this.glowSigma = 6.0,
    this.tightGlowOpacity = 0.35,
    this.tightGlowSigma = 2.2,
  });

  @override
  State<RotatingEnvelope> createState() => _RotatingEnvelopeState();
}

class _RotatingEnvelopeState extends State<RotatingEnvelope>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  ui.Image? _img;
  String? _loadedPath;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration)..repeat();
    _loadIfNeeded(widget.assetPath);
  }

  @override
  void didUpdateWidget(covariant RotatingEnvelope oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.duration != widget.duration) {
      _c.duration = widget.duration;
      if (!_c.isAnimating) _c.repeat();
    }
    if (oldWidget.assetPath != widget.assetPath) {
      _loadIfNeeded(widget.assetPath);
    }
  }

  Future<void> _loadIfNeeded(String path) async {
    if (_loadedPath == path && _img != null) return;
    _loadedPath = path;

    try {
      final ByteData bd = await rootBundle.load(path);
      final Uint8List bytes = bd.buffer.asUint8List();

      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo fi = await codec.getNextFrame();

      if (!mounted) return;
      setState(() => _img = fi.image);
    } catch (_) {
      if (!mounted) return;
      setState(() => _img = null);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value; // 0..1
        final angle = t * math.pi * 2.0;

        final m = Matrix4.identity()
          ..setEntry(3, 2, widget.perspective)
          ..rotateY(angle);

        return Opacity(
          opacity: widget.opacity,
          child: Transform(
            alignment: Alignment.center,
            transform: m,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: _img == null
                  ? Icon(Icons.mail_outline, size: widget.size * 0.7)
                  : CustomPaint(
                      painter: _GlowImagePainter(
                        image: _img!,
                        glowColor: widget.glowColor,
                        glowOpacity: widget.glowOpacity,
                        glowSigma: widget.glowSigma,
                        tightGlowOpacity: widget.tightGlowOpacity,
                        tightGlowSigma: widget.tightGlowSigma,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _GlowImagePainter extends CustomPainter {
  final ui.Image image;

  final Color glowColor;
  final double glowOpacity;
  final double glowSigma;

  final double tightGlowOpacity;
  final double tightGlowSigma;

  _GlowImagePainter({
    required this.image,
    required this.glowColor,
    required this.glowOpacity,
    required this.glowSigma,
    required this.tightGlowOpacity,
    required this.tightGlowSigma,
  });

  // ✅ Preserve aspect ratio like BoxFit.contain (no stretching)
  Rect _fittedDstRect(Size canvasSize) {
    final inputSize = Size(image.width.toDouble(), image.height.toDouble());
    final outputSize = canvasSize;

    final fitted = applyBoxFit(BoxFit.contain, inputSize, outputSize);
    final Size dstSize = fitted.destination;

    final double dx = (outputSize.width - dstSize.width) / 2.0;
    final double dy = (outputSize.height - dstSize.height) / 2.0;

    return Rect.fromLTWH(dx, dy, dstSize.width, dstSize.height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );

    final dst = _fittedDstRect(size);

    // ---- 1) Soft glow (blurred, tinted, alpha-shaped) ----
    if (glowOpacity > 0 && glowSigma > 0) {
      canvas.saveLayer(
        dst,
        Paint()
          ..imageFilter = ui.ImageFilter.blur(sigmaX: glowSigma, sigmaY: glowSigma),
      );

      final glowPaint = Paint()
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high
        ..colorFilter = ColorFilter.mode(
          glowColor.withOpacity(glowOpacity),
          BlendMode.srcIn,
        );

      canvas.drawImageRect(image, src, dst, glowPaint);
      canvas.restore();
    }

    // ---- 2) Tight glow (closer to the lines) ----
    if (tightGlowOpacity > 0 && tightGlowSigma > 0) {
      canvas.saveLayer(
        dst,
        Paint()
          ..imageFilter =
              ui.ImageFilter.blur(sigmaX: tightGlowSigma, sigmaY: tightGlowSigma),
      );

      final tightPaint = Paint()
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high
        ..colorFilter = ColorFilter.mode(
          glowColor.withOpacity(tightGlowOpacity),
          BlendMode.srcIn,
        );

      canvas.drawImageRect(image, src, dst, tightPaint);
      canvas.restore();
    }

    // ---- 3) Sharp image on top ----
    final basePaint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;

    canvas.drawImageRect(image, src, dst, basePaint);
  }

  @override
  bool shouldRepaint(covariant _GlowImagePainter old) {
    return old.image != image ||
        old.glowColor != glowColor ||
        old.glowOpacity != glowOpacity ||
        old.glowSigma != glowSigma ||
        old.tightGlowOpacity != tightGlowOpacity ||
        old.tightGlowSigma != tightGlowSigma;
  }
}
