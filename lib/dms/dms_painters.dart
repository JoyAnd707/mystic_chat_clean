part of 'dms_screens.dart';


class _ChamferBubbleClipper extends CustomClipper<Path> {
  final bool isMe;
  final double chamfer;

  _ChamferBubbleClipper({required this.isMe, required this.chamfer});

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final c = chamfer.clamp(0.0, w * 0.45);

    final p = Path();

    if (isMe) {
      // ✅ chamfer at TOP-LEFT (bubble on right, like Mystic)
      p.moveTo(c, 0);
      p.lineTo(w, 0);
      p.lineTo(w, h);
      p.lineTo(0, h);
      p.lineTo(0, c);
      p.close();
    } else {
      // ✅ chamfer at TOP-RIGHT (bubble on left, like Mystic)
      p.moveTo(0, 0);
      p.lineTo(w - c, 0);
      p.lineTo(w, c);
      p.lineTo(w, h);
      p.lineTo(0, h);
      p.close();
    }

    return p;
  }

  @override
  bool shouldReclip(covariant _ChamferBubbleClipper oldClipper) {
    return oldClipper.isMe != isMe || oldClipper.chamfer != chamfer;
  }
}



class _ChamferBubblePainter extends CustomPainter {
  final bool isMe;
  final double chamfer;
  final Color fill;
  final Color stroke;
  final double strokeWidth;

  _ChamferBubblePainter({
    required this.isMe,
    required this.chamfer,
    required this.fill,
    required this.stroke,
    required this.strokeWidth,
  });

  Path _path(Size size) {
    return _ChamferBubbleClipper(isMe: isMe, chamfer: chamfer).getClip(size);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final p = _path(size);

    final fillPaint = Paint()
      ..color = fill
      ..style = PaintingStyle.fill;

    canvas.drawPath(p, fillPaint);

    final strokePaint = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.miter;

    canvas.drawPath(p, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _ChamferBubblePainter oldDelegate) {
    return oldDelegate.isMe != isMe ||
        oldDelegate.chamfer != chamfer ||
        oldDelegate.fill != fill ||
        oldDelegate.stroke != stroke ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}




class _MysticStemFromPngTipPainter extends CustomPainter {
  final bool isRightSide;

  // offset from the bubble-row edge (same value you use for Positioned tail)
  final double tailOffset;

  // tail image square size
  final double tailSize;

  // top offset of tail image
  final double tailTop;

  final Color stroke;
  final double strokeWidth;

  // how far above bottom the stem should stop
  final double bottomInset;

  // where inside the tail image the tip is (0..1)
  final double tipXFactorRight;
  final double tipXFactorLeft;

  // where inside the tail image the BOTTOM TIP is (0..1)
  final double tipYFactor;

  // move start point up/down relative to computed tip
  final double tipYInset;  // positive moves start upward
  final double tipYOutset; // positive moves start downward

  // ✅ NEW: pixel nudging for the stem X (negative = left, positive = right)
  final double stemXNudge;


// ✅ NEW: pixel nudging for the stem Y start (negative = up, positive = down)
final double stemYNudge;

  _MysticStemFromPngTipPainter({
    required this.isRightSide,
    required this.tailOffset,
    required this.tailSize,
    required this.tailTop,
    required this.stroke,
    required this.strokeWidth,
    required this.bottomInset,
    required this.tipXFactorRight,
    required this.tipXFactorLeft,
    required this.tipYFactor,
    this.tipYInset = 0.0,
    this.tipYOutset = 0.0,
    this.stemXNudge = 0.0,
    this.stemYNudge = 0.0,

  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.square
      ..isAntiAlias = true;

    final double tailLeft = isRightSide
        ? (size.width - tailOffset - tailSize)
        : tailOffset;

    final double stemXBase = isRightSide
        ? (tailLeft + tailSize * tipXFactorRight)
        : (tailLeft + tailSize * tipXFactorLeft);

    // ✅ just shove it left/right
    final double stemX = (stemXBase + stemXNudge).clamp(0.0, size.width);

    final double tailTipY = tailTop + tailSize * tipYFactor;

   final double yStart =
    (tailTipY - tipYInset + tipYOutset + stemYNudge)
        .clamp(0.0, size.height);


    final double yBottom =
        (size.height - bottomInset).clamp(0.0, size.height);

    canvas.drawLine(
      Offset(stemX, yStart),
      Offset(stemX, yBottom),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _MysticStemFromPngTipPainter old) {
    return old.isRightSide != isRightSide ||
        old.tailOffset != tailOffset ||
        old.tailSize != tailSize ||
        old.tailTop != tailTop ||
        old.stroke != stroke ||
        old.strokeWidth != strokeWidth ||
        old.bottomInset != bottomInset ||
        old.tipXFactorRight != tipXFactorRight ||
        old.tipXFactorLeft != tipXFactorLeft ||
        old.tipYFactor != tipYFactor ||
        old.tipYInset != tipYInset ||
        old.tipYOutset != tipYOutset ||
        old.stemXNudge != stemXNudge ||
        old.stemYNudge != stemYNudge;
  }

}


class _MysticStemOnlyPainter2 extends CustomPainter {
  final bool isRightSide;
  final double avatarSize;
  final double gap;

  final double tailSize;
  final double tailTop;

  final double strokeWidth;
  final Color stroke;
  final double bottomInset;

  _MysticStemOnlyPainter2({
    required this.isRightSide,
    required this.avatarSize,
    required this.gap,
    required this.tailSize,
    required this.tailTop,
    required this.strokeWidth,
    required this.stroke,
    required this.bottomInset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.square
      ..isAntiAlias = true;

    final double avatarLeft = isRightSide ? (size.width - avatarSize) : 0.0;
    final double avatarRight = avatarLeft + avatarSize;

    final double tailLeft = isRightSide
        ? (avatarLeft - gap - tailSize)
        : (avatarRight + gap);

    final double stemX = isRightSide
        ? (tailLeft + tailSize * 0.78)
        : (tailLeft + tailSize * 0.22);

    final double yStart = (tailTop + tailSize).clamp(0.0, size.height);
    final double yBottom = (size.height - bottomInset).clamp(0.0, size.height);

    canvas.drawLine(
      Offset(stemX, yStart),
      Offset(stemX, yBottom),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _MysticStemOnlyPainter2 old) {
    return old.isRightSide != isRightSide ||
        old.avatarSize != avatarSize ||
        old.gap != gap ||
        old.tailSize != tailSize ||
        old.tailTop != tailTop ||
        old.strokeWidth != strokeWidth ||
        old.stroke != stroke ||
        old.bottomInset != bottomInset;
  }
}


class _MysticStemConnectorPainter extends CustomPainter {
  final bool isRightSide;
  final double avatarSize;
  final double gap;

  final double strokeWidth;
  final Color stroke;

  // stem controls
  final double stemBottomInset;

  // keep these fields so your existing call sites won't break,
  // but we will NOT draw the geometric tail anymore.
  final double tailW;
  final double tailH;
  final double tailTop;

  _MysticStemConnectorPainter({
    required this.isRightSide,
    required this.avatarSize,
    required this.gap,
    required this.strokeWidth,
    required this.stroke,
    required this.stemBottomInset,
    required this.tailW,
    required this.tailH,
    required this.tailTop,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.square
      ..isAntiAlias = true;

    // Avatar location (same assumption as before)
    final double avatarLeft = isRightSide ? (size.width - avatarSize) : 0.0;
    final double avatarRight = avatarLeft + avatarSize;

    // Tail PNG is placed between avatar and bubble.
    // We match the same geometry for where the "tip" X should be.
    final double tailSize = tailW; // use tailW as size
    final double tailLeft = isRightSide ? (avatarLeft - gap - tailSize) : (avatarRight + gap);

    final double stemX = isRightSide
        ? (tailLeft + tailSize * 0.78)
        : (tailLeft + tailSize * 0.22);

    final double yStart = (tailTop + tailH).clamp(0.0, size.height);
    final double yBottom = (size.height - stemBottomInset).clamp(0.0, size.height);

    canvas.drawLine(
      Offset(stemX, yStart),
      Offset(stemX, yBottom),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _MysticStemConnectorPainter old) {
    return old.isRightSide != isRightSide ||
        old.avatarSize != avatarSize ||
        old.gap != gap ||
        old.strokeWidth != strokeWidth ||
        old.stroke != stroke ||
        old.stemBottomInset != stemBottomInset ||
        old.tailW != tailW ||
        old.tailH != tailH ||
        old.tailTop != tailTop;
  }
}

class _BubbleTail extends StatelessWidget {
  final bool isRight;
  final Color fill;
  final Color stroke;
  final double size;
  final double strokeWidth;

  const _BubbleTail({
    required this.isRight,
    required this.fill,
    required this.stroke,
    required this.size,
    required this.strokeWidth,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _DetachedTailPainter(
        fill: fill,
        stroke: stroke,
        isRight: isRight,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

class _BubbleCornerShard extends StatelessWidget {
  final Color fill;
  final Color stroke;
  final double size;
  final double strokeWidth;
  final bool isLeftSide;

  const _BubbleCornerShard({
    required this.fill,
    required this.stroke,
    required this.size,
    required this.strokeWidth,
    required this.isLeftSide,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _CornerShardPainter(
        fill: fill,
        stroke: stroke,
        strokeWidth: strokeWidth,
        isLeftSide: isLeftSide,
      ),
    );
  }
}

class _DetachedTailPainter extends CustomPainter {
  final Color fill;
  final Color stroke;
  final bool isRight;
  final double strokeWidth;

  _DetachedTailPainter({
    required this.fill,
    required this.stroke,
    required this.isRight,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final Path p = Path();

    if (isRight) {
      p.moveTo(0, h * 0.18);
      p.lineTo(w * 0.78, 0);
      p.lineTo(w, h * 0.50);
      p.lineTo(w * 0.78, h);
      p.lineTo(0, h * 0.82);
      p.close();
    } else {
      p.moveTo(w, h * 0.18);
      p.lineTo(w * 0.22, 0);
      p.lineTo(0, h * 0.50);
      p.lineTo(w * 0.22, h);
      p.lineTo(w, h * 0.82);
      p.close();
    }

    final fillPaint = Paint()
      ..color = fill
      ..style = PaintingStyle.fill;
    canvas.drawPath(p, fillPaint);

    final strokePaint = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawPath(p, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _DetachedTailPainter old) {
    return old.fill != fill ||
        old.stroke != stroke ||
        old.isRight != isRight ||
        old.strokeWidth != strokeWidth;
  }
}


class _CornerShardPainter extends CustomPainter {
  final Color fill;
  final Color stroke;
  final double strokeWidth;
  final bool isLeftSide;

  _CornerShardPainter({
    required this.fill,
    required this.stroke,
    required this.strokeWidth,
    required this.isLeftSide,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // משולש קטן שמדמה "פינה חתוכה" בתוך הבועה
    final Path p = Path();

    if (isLeftSide) {
      // top-left
      p.moveTo(0, 0);
      p.lineTo(w, 0);
      p.lineTo(0, h);
      p.close();
    } else {
      // top-right
      p.moveTo(w, 0);
      p.lineTo(0, 0);
      p.lineTo(w, h);
      p.close();
    }

    final fillPaint = Paint()
      ..color = fill
      ..style = PaintingStyle.fill;
    canvas.drawPath(p, fillPaint);

    final strokePaint = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawPath(p, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _CornerShardPainter old) {
    return old.fill != fill ||
        old.stroke != stroke ||
        old.strokeWidth != strokeWidth ||
        old.isLeftSide != isLeftSide;
  }
}

