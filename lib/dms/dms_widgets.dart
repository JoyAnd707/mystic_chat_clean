part of 'dms_screens.dart';



class _MysticNewBadge extends StatelessWidget {
  const _MysticNewBadge();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(1.1),
      child: Container(
        color: const Color(0xFFFF6769), // #ff6769
        padding: const EdgeInsets.symmetric(horizontal: 0.7, vertical: 0.15),
        child: const Text(
          'NEW',
          textHeightBehavior: TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
          style: TextStyle(
            color: Colors.white,
            fontSize: 6.0,
            fontWeight: FontWeight.w900,
            height: 1.0,
            letterSpacing: 0.12,
          ),
        ),
      ),
    );
  }
}

/// =======================================
/// DM TOP BAR (your PNG)
/// =======================================
class _DmTopBar extends StatelessWidget {
  final Future<void> Function()? onBack;

  const _DmTopBar({this.onBack});

  static const double _resourceBarHeight = 34;
  static const double _barAspect = 2048 / 212;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: _resourceBarHeight,
            width: double.infinity,
            child: Container(color: Colors.transparent),
          ),

          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final barH = w / _barAspect;

              return SizedBox(
                width: w,
                height: barH,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        'assets/ui/TextMessageBarMenu.png',
                        fit: BoxFit.fitWidth,
                        alignment: Alignment.center,
                      ),
                    ),

                    Align(
                      alignment: Alignment.center,
                      child: Text(
                        'Text Message',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w300,
                          height: 1.0,
                        ),
                      ),
                    ),

                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () async {
                          if (onBack != null) {
                            await onBack!.call();
                            return;
                          }

                          // fallback: just pop (NO SFX here)
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                        child: const SizedBox(
                          width: 72,
                          height: double.infinity,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

String mysticPreviewClamp(String text, int maxChars) {
  final t = text.trim();
  if (t.length <= maxChars) return t;
  return '${t.substring(0, maxChars)}...';
}


/// =======================================
/// DM ROW TILE (same look you already tuned)
/// =======================================
class _DmRowTile extends StatelessWidget {
  final DmUser user;
  final VoidCallback onTap;

  final bool unread;
  final String previewText;
  final int lastUpdatedMs;

  final double uiScale;

  const _DmRowTile({
    required this.user,
    required this.onTap,
    required this.unread,
    required this.previewText,
    required this.lastUpdatedMs,
    required this.uiScale,
  });

  @override
  Widget build(BuildContext context) {
    double s(double v) => v * uiScale;

    final double tileHeight = s(76);
final double envelopeRight = s(8);


    final double avatarSize = s(72);

    final double outerFrameThickness = s(3.2);
    final double innerDarkStroke = s(1.1);

    final double gapAfterAvatar = s(10);
    final double innerLeftPadding = s(10);
final double rightInset = s(2);       // ✅ יותר ימינה (פחות רווח פנימי)
final double envelopeBoxW = s(44);    // ✅ טיפה יותר צר
final double envelopeSize = s(36);    // ✅ קטנה ממש קצת
final double envelopeBottomPad = s(1.0); // ✅ יורדת למטה (פחות padding מהתחתית)



    const Color unreadTeal = Color(0xFF46F5D6);

    final Color frameColor =
        unread ? unreadTeal.withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.88);

    final String envelopeAsset = unread
        ? 'assets/ui/DMSmessageUnread.png'
        : 'assets/ui/DMSmessageRead.png';

    final String ts = mysticTimestampFromMs(lastUpdatedMs);

    // ✅ compute TOP of envelope inside the Stack so NEW can align to it
    final double envelopeTop =
        tileHeight - envelopeBottomPad - envelopeSize;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: tileHeight,
        child: Container(
          decoration: BoxDecoration(
border: Border.all(color: frameColor, width: outerFrameThickness),
),
child: Container(
  decoration: BoxDecoration(
    border: Border.all(
      color: Colors.black.withValues(alpha: 0.65),
      width: innerDarkStroke,
    ),
    color: const Color(0x80555555),
  ),

  // 👇 עטיפת הפונט – כאן זה נכון
  child: DefaultTextStyle(
    style: const TextStyle(fontFamily: 'NanumGothic'),
    child: Stack(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            innerLeftPadding,
            0,
            rightInset,
            0,
          ),
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: avatarSize,
                    height: avatarSize,
                    child: Container(
                      color: Colors.black,
                      alignment: Alignment.center,
                      child: Text(
                        user.name.characters.first.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: s(22),
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: gapAfterAvatar),

                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: unread
                                    ? (envelopeBoxW + s(32) + s(12))
                                    : (envelopeBoxW + s(8)),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: s(8)),
                                  Text(
                                    user.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                     fontSize: s(14.0),        // ⬅️ קצת יותר קטן
fontWeight: FontWeight.w800,

                                      height: 1.0,
                                    ),
                                  ),

                                  // ✅ preview a bit higher (less gap)
                                  SizedBox(height: s(12)),



                                  Text(
                                  (previewText.trim().isEmpty)
    ? 'Tap to open chat'
    : mysticPreviewClamp(previewText, 15),

                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.70),
                                      fontSize: s(12),

                                      fontWeight: FontWeight.w900,

                                      height: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

// ✅ envelope
Positioned(
  right: envelopeRight,
  bottom: envelopeBottomPad,
  child: SizedBox(
    width: envelopeBoxW,
    height: envelopeSize,
    child: Align(
      alignment: Alignment.bottomRight,
      child: SizedBox(
        width: envelopeSize,
        height: envelopeSize,
        child: Image.asset(
          envelopeAsset,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => Icon(
            Icons.mail_outline,
            color: Colors.white.withValues(alpha: 0.8),
            size: s(22),
          ),
        ),
      ),
    ),
  ),
),


                      // ✅ NEW: align TOP with envelope TOP
    if (unread)
  Positioned(
    right: envelopeRight + envelopeSize + s(6),
    top: envelopeTop + s(2),
    child: const _MysticNewBadge(),
  ),

                    ],
                  ),
                ),

                if (ts.isNotEmpty)
                  Positioned(
                    top: s(6),
                    right: s(6),
                    child: Text(
  ts,
  style: TextStyle(
    color: Colors.white.withValues(alpha: 0.78),
    fontSize: s(11.0),          // ⬅️ קטן יותר
    fontWeight: FontWeight.w700, // ⬅️ יותר בולד


                        height: 1.0,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    )
     );

  }
}


/// =======================================
/// DM bottom bar (uses your TypeMessageButton/TypeBar/Send button assets)
/// BUT isolated here (no reuse of group BottomBorderBar).
/// =======================================
class _DmBottomBar extends StatelessWidget {
  final double height;
  final bool isTyping;
  final VoidCallback onTapTypeMessage;
  final Future<void> Function() onSend;

  final TextEditingController controller;
  final FocusNode focusNode;
  final double uiScale;

  const _DmBottomBar({
    required this.height,
    required this.isTyping,
    required this.onTapTypeMessage,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.uiScale,
  });

  static const double _typeButtonWidth = 260;

  // ✅ one send button on the RIGHT only
  static const double _sendBoxSize = 40;
  static const double _sendScale = 0.9;
  static const double _sendInset = 14;
  static const double _sendDown = 3;

  // ✅ NEW assets for DMs
  static const String _answerButtonAsset = 'assets/ui/DmsAnswerButton.png';
  static const String _answerBarAsset = 'assets/ui/DmsAnswerBar.png';

  // ✅ Your new envelope send icon
  static const String _sendEnvelopeAsset = 'assets/ui/DmsSendMessageButton.png';

  @override
  Widget build(BuildContext context) {
    if (height <= 0) return const SizedBox.shrink();
    double s(double v) => v * uiScale;

    return Container(
      height: height,
      width: double.infinity,
      color: Colors.black,
      padding: EdgeInsets.only(bottom: s(0)),
      child: isTyping ? _typingBar(s) : _answerButtonBar(s),
    );
  }

  // =====================
  // BEFORE TYPING (ANSWER button)
  // =====================
  Widget _answerButtonBar(double Function(double) s) {
    return Stack(
      alignment: Alignment.center,
      children: [
        GestureDetector(
          onTap: onTapTypeMessage,
          child: SizedBox(
            width: s(_typeButtonWidth),
            child: Image.asset(
              _answerButtonAsset,
              fit: BoxFit.fitWidth,
            ),
          ),
        ),

        // ✅ ONLY ONE on the RIGHT (inactive in answer mode)
        _inactiveSendButtonRightOnly(s: s),
      ],
    );
  }

  Widget _inactiveSendButtonRightOnly({
    required double Function(double) s,
  }) {
    return Positioned(
      right: s(_sendInset),
      child: Transform.translate(
        offset: Offset(0, s(_sendDown)),
        child: IgnorePointer(
          ignoring: true,
          child: SizedBox(
            width: s(_sendBoxSize),
            height: s(_sendBoxSize),
            child: Transform.scale(
              scale: _sendScale,
              child: Image.asset(
                _sendEnvelopeAsset,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =====================
  // TYPING MODE (ANSWER bar)
  // =====================
  Widget _typingBar(double Function(double) s) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: s(_typeButtonWidth),
          child: Stack(
            children: [
              Image.asset(
                _answerBarAsset,
                fit: BoxFit.fitWidth,
              ),
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: s(18),
                    vertical: s(8),
                  ),
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    maxLines: 1,

                    textAlignVertical: TextAlignVertical.center,
                    textInputAction: TextInputAction.done,

                    style: TextStyle(
                      color: Colors.white,
                      fontSize: s(18),
                      height: 1.0,
                      fontWeight: FontWeight.w600,
                    ),

                    cursorColor: Colors.white,

                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Type...',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: s(18),
                        height: 1.0,
                        fontWeight: FontWeight.w600,
                      ),
                      isDense: true,
                      contentPadding: EdgeInsets.only(
                        left: 0,
                        right: 0,
                        top: s(2),
                        bottom: s(0),
                      ),
                    ),

                    onEditingComplete: () {
                      focusNode.unfocus();
                    },

                    onSubmitted: (_) async => await onSend(),

                  ),
                ),
              ),
            ],
          ),
        ),

        // ✅ ONLY ONE on the RIGHT (active in typing mode)
        _activeSendButtonRightOnly(s: s),
      ],
    );
  }

  Widget _activeSendButtonRightOnly({
    required double Function(double) s,
  }) {
    return Positioned(
      right: s(_sendInset),
      child: Transform.translate(
        offset: Offset(0, s(_sendDown)),
        child: GestureDetector(
          onTap: () async => await onSend(),

          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: s(_sendBoxSize),
            height: s(_sendBoxSize),
            child: Transform.scale(
              scale: _sendScale,
              child: Image.asset(
                _sendEnvelopeAsset,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
      ),
    );
  }
}




/// =======================================
/// Star twinkle overlay (DMs list only)
/// =======================================
class MysticStarTwinkleOverlay extends StatelessWidget {
  final Animation<double> animation;
  final int starCount;
  final double sizeMultiplier;

  const MysticStarTwinkleOverlay({
    super.key,
    required this.animation,
    this.starCount = 90,
    this.sizeMultiplier = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return CustomPaint(
          painter: _StarTwinklePainter(
            t: animation.value,
            starCount: starCount,
            sizeMultiplier: sizeMultiplier,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _TwinkleStar {
  final double nx;
  final double ny;
  final double baseR;
  final double speed;
  final double phase;

  _TwinkleStar({
    required this.nx,
    required this.ny,
    required this.baseR,
    required this.speed,
    required this.phase,
  });
}


class _StarTwinklePainter extends CustomPainter {
  final double t;
  final int starCount;
  final double sizeMultiplier;
  late final List<_TwinkleStar> _stars;

  _StarTwinklePainter({
    required this.t,
    required this.starCount,
    required this.sizeMultiplier,
  }) {
    final rng = Random(42);

    _stars = List<_TwinkleStar>.generate(starCount, (i) {
      final tier = rng.nextDouble();
      final double baseR;

      if (tier < 0.78) {
        baseR = 0.9 + rng.nextDouble() * 0.6;
      } else if (tier < 0.96) {
        baseR = 1.6 + rng.nextDouble() * 0.9;
      } else {
        baseR = 2.8 + rng.nextDouble() * 1.2;
      }

      return _TwinkleStar(
        nx: rng.nextDouble(),
        ny: rng.nextDouble(),
        baseR: baseR,
        speed: 0.7 + rng.nextDouble() * 1.6,
        phase: rng.nextDouble() * pi * 2,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final core = Paint()..style = PaintingStyle.fill;

    // soft rim paint (we set blur + color per-star)
    final soft = Paint()..style = PaintingStyle.fill;

    final tt = t * pi * 2;

    for (final s in _stars) {
      final x = s.nx * size.width;
      final y = s.ny * size.height;

      final wave = sin(tt * s.speed + s.phase);
      final alpha = (0.35 + 0.65 * (wave * 0.5 + 0.5)).clamp(0.12, 1.0);

      final r = (s.baseR * sizeMultiplier).clamp(0.9, 14.0);

      final blurSigma = (r * 0.55).clamp(0.9, 3.2);
      soft.maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma);

      soft.color = Colors.white.withOpacity((alpha * 0.22).clamp(0.04, 0.22));
      canvas.drawCircle(Offset(x, y), r * 1.25, soft);

      core.color = Colors.white.withOpacity(alpha);
      canvas.drawCircle(Offset(x, y), r, core);
    }
  }

  @override
  bool shouldRepaint(covariant _StarTwinklePainter old) {
    return old.t != t ||
        old.starCount != starCount ||
        old.sizeMultiplier != sizeMultiplier;
  }
}

class _DmDateDivider extends StatelessWidget {
  final String text;
  final double uiScale;

  const _DmDateDivider({
    required this.text,
    required this.uiScale,
  });

  @override
  Widget build(BuildContext context) {
    double s(double v) => v * uiScale;

    if (text.trim().isEmpty) return const SizedBox.shrink();

    final double starSize = s(24);
    final double lineH = s(1.2);
    final Color lineColor = Colors.white.withValues(alpha: 0.72);

    // ✅ Use real screen width (stable), optionally respecting safe-area
    final mq = MediaQuery.of(context);
    final double safeL = mq.padding.left;
    final double safeR = mq.padding.right;
    final double fullW = mq.size.width - safeL - safeR;

    Widget star() {
      return Image.asset(
        'assets/ui/DmsDateStar.png',
        width: starSize,
        height: starSize,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) =>
            SizedBox(width: starSize, height: starSize),
      );
    }

    Widget line() {
      return Container(height: lineH, color: lineColor);
    }

Widget sideStarsAndLine() {
  return SizedBox(
    height: starSize,
    child: Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // line behind
        Positioned.fill(
          child: Align(
            alignment: Alignment.center,
            child: line(),
          ),
        ),

        // ✅ stars flush to edges (touch screen edge)
        Positioned(left: -s(2), child: star()),
Positioned(right: -s(2), child: star()),

      ],
    ),
  );
}


    return Padding(
      padding: EdgeInsets.symmetric(vertical: s(14)),
      child: Align(
        alignment: Alignment.center,
        child: SizedBox(
          width: fullW, // ✅ always centered, no drifting
          child: Row(
            children: [
              Expanded(child: sideStarsAndLine()),
              SizedBox(width: s(12)),
              Text(
                text,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: s(18),
                  fontWeight: FontWeight.w400,
                  height: 1.0,
                  letterSpacing: 0.2,
                ),
              ),
              SizedBox(width: s(12)),
              Expanded(child: sideStarsAndLine()),
            ],
          ),
        ),
      ),
    );
  }
}



class _DmBottomCornerLine extends StatelessWidget {
  final double uiScale;

  const _DmBottomCornerLine({
    required this.uiScale,
  });

  @override
  Widget build(BuildContext context) {
    double s(double v) => v * uiScale;

    // 🔧 TUNING
    final double starSize = s(22);         // size of the corner diamonds
    final double edgeInset = s(0);         // ✅ touch the screen edge
    final double lineH = s(1.2);
    final Color lineColor = Colors.white.withValues(alpha: 0.60);

    Widget star() {
      return Image.asset(
        'assets/ui/DmsBottomTwoStars.png',
        width: starSize,
        height: starSize,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) =>
            SizedBox(width: starSize, height: starSize),
      );
    }

    return SizedBox(
      height: starSize,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ✅ line runs UNDER the diamonds (connected look)
          Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: Container(
                height: lineH,
                // ✅ let the line reach almost the full width
                // (keep 0 so it "touches" visually; if your PNG has transparent padding, bump to s(1)-s(2))
                margin: EdgeInsets.symmetric(horizontal: s(2)),
                color: lineColor,
              ),
            ),
          ),

          // ✅ corner diamonds - flush to edges
          Positioned(
            left: edgeInset,
            child: star(),
          ),
          Positioned(
            right: edgeInset,
            child: star(),
          ),
        ],
      ),
    );
  }
}




/// =======================================
/// DM message row (TEMP bubble placeholder)
/// Later we replace with your exact DMSbubble asset logic.
/// =======================================
class _DmMessageRow extends StatelessWidget {
  final bool isMe;
  final String text;
  final String time;
  final double uiScale;

  // ✅ NEW
  final String meLetter;
  final String otherLetter;

  const _DmMessageRow({
    required this.isMe,
    required this.text,
    required this.time,
    required this.uiScale,
    required this.meLetter,
    required this.otherLetter,
  });

  @override
  Widget build(BuildContext context) {

    double s(double v) => v * uiScale;

    return LayoutBuilder(
      builder: (context, constraints) {
        // ✅ DM bubble body transparency (Mystic vibe)
        // Alpha guide:
        // 0xFF = fully opaque, 0xCC ≈ 80%, 0xB3 ≈ 70%, 0x99 ≈ 60%
        const Color bodyFill = Color(0xB3606060);

        final Color borderColor = isMe ? Colors.white : const Color(0xFF46F5D6);
        const Color textColor = Colors.white;


        final double strokeW = s(2);

        final String cornerAsset = isMe
            ? 'assets/ui/DMSbubbleCornerISME.png'
            : 'assets/ui/DMSbubbleCornerOTHERS.png';

        // 🎛️ KNOBS
        final double cornerWidth = s(28);
        final double chamfer = s(8.5);
        final double cornerInset = s(0.5);

        // ✅ sizes
        final double avatarSize = s(48);
        final double gap = s(18);

        // ✅ time: fixed box width (Mystic vibe + stable layout)
        final double timeBoxW = s(64);
        final double timeGap = s(8);

        // ✅ desired bubble width like your preview
        final double desiredBubbleMax = s(232);

        // ✅ reserve ONLY what is actually on the row
        // Row also sits inside ListView padding (left/right 14) + your row padding (8),
        // so we add a small safety.
        final double reserved =
            avatarSize +
            gap +
            (time.isNotEmpty ? (timeBoxW + timeGap) : 0.0) +
            s(20); // safety

        final double availableForBubble = (constraints.maxWidth - reserved);

        final double bubbleMaxWidth = min(
          desiredBubbleMax,
          availableForBubble.clamp(s(140), desiredBubbleMax),
        );

        final bubble = ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: bubbleMaxWidth,
            minHeight: avatarSize,
          ),
          child: ClipPath(
            clipper: _ChamferBubbleClipper(isMe: isMe, chamfer: chamfer),
            child: CustomPaint(
              painter: _ChamferBubblePainter(
                isMe: isMe,
                chamfer: chamfer,
                fill: bodyFill,
                stroke: borderColor,
                strokeWidth: strokeW,
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      s(14),
                      s(12),
                      s(14),
                      s(10),
                    ),
child: Builder(
  builder: (context) {
    final bool isRtl = RegExp(r'[\u0590-\u05FF]').hasMatch(text);

    return Text(
      text,
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      textAlign: TextAlign.start, // יתיישר נכון לפי הכיוון
      style: TextStyle(
        fontFamily: 'NanumGothic',
        color: textColor,
        fontSize: s(20),
        fontWeight: FontWeight.w400,
        height: 1.3,
        letterSpacing: -0.3,
      ),
    );
  },
),




                  ),
                  Positioned(
                    top: cornerInset,
                    left: isMe ? cornerInset : null,
                    right: isMe ? null : cornerInset,
                    child: IgnorePointer(
                      child: Image.asset(
                        cornerAsset,
                        width: cornerWidth,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

       final leftAvatar = _Avatar(letter: otherLetter, size: avatarSize);
final rightAvatar = _Avatar(letter: meLetter, size: avatarSize);


        final timeWidget = (time.isEmpty)
            ? const SizedBox.shrink()
            : SizedBox(
                width: timeBoxW,
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    time,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: s(14),
                      fontWeight: FontWeight.w300,
                      height: 1.0,
                    ),
                  ),
                ),
              );

final row = Padding(
  padding: EdgeInsets.only(
    right: isMe ? s(8) : 0.0,
    left: isMe ? 0.0 : s(8),
  ),
  child: Row(
    mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,

    // ✅ זה מה שמחזיר את תמונת הפרופיל למעלה
    crossAxisAlignment: CrossAxisAlignment.start,

    children: [
      if (!isMe) ...[
        Align(
          alignment: Alignment.topCenter,
          child: leftAvatar,
        ),
        SizedBox(width: gap),
      ],

      // ✅ הזמן נשאר מיושר למטה מול הבועה בזכות ה-row הפנימי
      Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isMe && time.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.only(bottom: s(2)),
              child: Text(
                time,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: s(14),
                  fontWeight: FontWeight.w500,
                  height: 1.0,
                ),
              ),
            ),
            SizedBox(width: s(8)),
          ],

          Padding(
            padding: EdgeInsets.only(
              left: isMe ? 0.0 : s(2.5),
              right: isMe ? s(2.5) : 0.0,
            ),
            child: bubble,
          ),

          if (!isMe && time.isNotEmpty) ...[
            SizedBox(width: s(8)),
            Padding(
              padding: EdgeInsets.only(bottom: s(2)),
              child: Text(
                time,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: s(14),
                  fontWeight: FontWeight.w500,
                  height: 1.0,
                ),
              ),
            ),
          ],
        ],
      ),

      if (isMe) ...[
        SizedBox(width: gap),
        Align(
          alignment: Alignment.topCenter,
          child: rightAvatar,
        ),
      ],
    ],
  ),
);


        // ✅ keep your tail + stem exactly as you had them
        final double tailSize = s(16.0);
        final double tailTop = s(0.0);
        final double tailToBubbleGap = s(5.0);
        final double stemBottomInset = s(0.0);

        final double tailOffset = (avatarSize + gap - tailToBubbleGap) - s(3.0);

        final String tailAsset = isMe
            ? 'assets/ui/DMSbubbleTailISME.png'
            : 'assets/ui/DMSbubbleTailOTHERS.png';

        return Stack(
          clipBehavior: Clip.none,
          children: [
            CustomPaint(
              foregroundPainter: _MysticStemFromPngTipPainter(
                isRightSide: isMe,
                tailOffset: tailOffset,
                tailSize: tailSize,
                tailTop: tailTop,
                stroke: borderColor,
                strokeWidth: strokeW,
                bottomInset: stemBottomInset,
                tipXFactorRight: 0.78,
                tipXFactorLeft: 0.22,
                tipYFactor: 0.96,
                tipYInset: 0.0,
                tipYOutset: 0.0,
                stemXNudge: isMe ? -s(11) : s(11),
                stemYNudge: -s(10),
              ),
              child: row,
            ),
            Positioned(
              top: tailTop,
              right: isMe ? tailOffset : null,
              left: isMe ? null : tailOffset,
              child: IgnorePointer(
                child: Image.asset(
                  tailAsset,
                  width: tailSize,
                  height: tailSize,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}


class _Avatar extends StatelessWidget {
  final String letter;
  final double size;

  const _Avatar({
    required this.letter,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: Colors.white24, width: 1),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      ),
    );
  }
}

