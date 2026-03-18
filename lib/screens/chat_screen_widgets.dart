part of 'chat_screen.dart';

/// =======================
/// Helpers: date formatting (no intl)
/// =======================
bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _dayLabel(DateTime d) {
  // Simple label: "Today", "Yesterday", or "DD/MM/YYYY"
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(d.year, d.month, d.day);

  final diffDays = today.difference(that).inDays;
  if (diffDays == 0) return 'Today';
  if (diffDays == 1) return 'Yesterday';

  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}

/// =======================
/// UNREAD divider
/// =======================
class _UnreadDivider extends StatelessWidget {
  final double uiScale;
  final String text;

  const _UnreadDivider({
    required this.uiScale,
    this.text = 'UNREAD',
  });

  @override
  Widget build(BuildContext context) {
    double s(double v) => v * uiScale;

    return Padding(
      padding: EdgeInsets.fromLTRB(s(10), s(12), s(10), s(8)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // left line
          Expanded(
            child: Container(
              height: s(1),
              color: Colors.white.withOpacity(0.25),
            ),
          ),

          SizedBox(width: s(10)),

          // ✅ your decor instead of hourglass
          Image.asset(
            'assets/ui/LastReadBarDecor.png', // <-- put your file here
            width: s(30),
            height: s(30),
            fit: BoxFit.contain,
          ),

          SizedBox(width: s(8)),

          Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: s(12),
              fontWeight: FontWeight.w900,
              letterSpacing: s(0.8),
              height: 1.0,
            ),
          ),

          SizedBox(width: s(10)),

          // right line
          Expanded(
            child: Container(
              height: s(1),
              color: Colors.white.withOpacity(0.25),
            ),
          ),
        ],
      ),
    );
  }
}
/// =======================
/// Group Chat date divider
/// =======================
class _GcDateDivider extends StatelessWidget {
  final String label;
  final double uiScale;

  const _GcDateDivider({
    required this.label,
    required this.uiScale,
  });

  @override
  Widget build(BuildContext context) {
    double s(double v) => v * uiScale;

    return Padding(
      padding: EdgeInsets.fromLTRB(s(10), s(10), s(10), s(6)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // left line
          Expanded(
            child: Container(
              height: s(1),
              color: Colors.white.withOpacity(0.25),
            ),
          ),

          SizedBox(width: s(10)),

          // hourglass icon
          Image.asset(
            'assets/ui/GCHourglassDateAndTime.png',
            width: s(26),
            height: s(26),
            fit: BoxFit.contain,
          ),

          SizedBox(width: s(8)),

          // date text
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: s(12),
              fontWeight: FontWeight.w800,
              letterSpacing: s(0.6),
              height: 1.0,
            ),
          ),

          SizedBox(width: s(10)),

          // right line
          Expanded(
            child: Container(
              height: s(1),
              color: Colors.white.withOpacity(0.25),
            ),
          ),
        ],
      ),
    );
  }
}

/// =======================
/// Mentions picker bar (WhatsApp-like)
/// =======================
class _MentionPickerBar extends StatelessWidget {
  final double uiScale;
  final List<ChatUser> results;
  final void Function(ChatUser user) onPick;
  final VoidCallback onClose;

  // used to tint the little heart dot (same mapping as in state)
  final Color Function(String userId) heartColorForUserId;

  const _MentionPickerBar({
    required this.uiScale,
    required this.results,
    required this.onPick,
    required this.onClose,
    required this.heartColorForUserId,
  });

  @override
  Widget build(BuildContext context) {
    final shown = results.take(8).toList();

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: EdgeInsets.fromLTRB(12 * uiScale, 0, 12 * uiScale, 8 * uiScale),
        padding: EdgeInsets.fromLTRB(10 * uiScale, 10 * uiScale, 10 * uiScale, 10 * uiScale),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.78),
          borderRadius: BorderRadius.circular(14 * uiScale),
          border: Border.all(
            color: Colors.white.withOpacity(0.18),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 16 * uiScale,
              spreadRadius: 1 * uiScale,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  'Mention',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12 * uiScale,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onClose,
                  child: Container(
                    width: 28 * uiScale,
                    height: 28 * uiScale,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.12),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.close,
                      color: Colors.white.withOpacity(0.85),
                      size: 18 * uiScale,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8 * uiScale),
            if (shown.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 6 * uiScale),
                child: Text(
                  'No matches',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12 * uiScale,
                  ),
                ),
              )
            else
              Column(
                children: [
                  for (final u in shown)
                    _MentionUserTile(
                      uiScale: uiScale,
                      user: u,
                      onTap: () => onPick(u),
                      dotColor: heartColorForUserId(u.id),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _MentionUserTile extends StatelessWidget {
  final double uiScale;
  final ChatUser user;
  final VoidCallback onTap;
  final Color dotColor;

  const _MentionUserTile({
    required this.uiScale,
    required this.user,
    required this.onTap,
    required this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 6 * uiScale),
        child: Row(
          children: [
            // dot
            Container(
              width: 10 * uiScale,
              height: 10 * uiScale,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: dotColor.withOpacity(0.55),
                    blurRadius: 10 * uiScale,
                    spreadRadius: 0.5 * uiScale,
                  ),
                ],
              ),
            ),
            SizedBox(width: 10 * uiScale),
            Expanded(
              child: Text(
                user.name,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.92),
                  fontSize: 14 * uiScale,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 8 * uiScale),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withOpacity(0.55),
              size: 20 * uiScale,
            ),
          ],
        ),
      ),
    );
  }
}

/// =======================
/// Reply preview bar (WhatsApp-like)
/// =======================
class ReplyPreviewBar extends StatelessWidget {
  final double uiScale;
  final Color stripeColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const ReplyPreviewBar({super.key, 
    required this.uiScale,
    required this.stripeColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: EdgeInsets.fromLTRB(12 * uiScale, 10 * uiScale, 10 * uiScale, 10 * uiScale),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.78),
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.10), width: 1),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 4 * uiScale,
              height: 40 * uiScale,
              decoration: BoxDecoration(
                color: stripeColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            SizedBox(width: 10 * uiScale),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.92),
                        fontSize: 12 * uiScale,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2 * uiScale),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 12 * uiScale,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 10 * uiScale),
            GestureDetector(
              onTap: onClose,
              child: Container(
                width: 28 * uiScale,
                height: 28 * uiScale,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.12),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.close,
                  color: Colors.white.withOpacity(0.85),
                  size: 18 * uiScale,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// =======================
/// "New messages below" badge (overlay)
/// =======================


class NewMessagesBadge extends StatefulWidget {
  final int count;
  final Color badgeColor;     // צבע העיגולים הקטנים (#F36364)
  final bool hasMention;
  final VoidCallback onTap;

  // ✅ האייקון שבאמצע
  final String iconAsset;

  const NewMessagesBadge({
    super.key,
    required this.count,
    required this.badgeColor,
    required this.hasMention,
    required this.onTap,
    this.iconAsset = 'assets/ui/DMSlittleLetterIcon.png', // שימי כאן את הנתיב שלך
  });

  @override
  State<NewMessagesBadge> createState() => _NewMessagesBadgeState();
}

class _NewMessagesBadgeState extends State<NewMessagesBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();

    // ✅ רטט קטן כל 2 שניות
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double _shakeT(double t) {
    // t in [0..1], רטט רק בתחילת כל מחזור (כ-14% מהזמן), ואז שקט
    const active = 0.14;
    if (t > active) return 0.0;

    // 0..active -> 0..1
    final x = t / active;

    // תנודות קצרות
    final wobble = sin(x * pi * 10); // 5 "הלוך-חזור" קצר
    // מעט דעיכה
    final decay = (1.0 - x);
    return wobble * decay;
  }

  Widget _smallBubble({
    required String text,
    required double uiScale,
  }) {
    final double size = 18 * uiScale;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: widget.badgeColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: widget.badgeColor.withOpacity(0.45),
            blurRadius: 10 * uiScale,
            spreadRadius: 0.4 * uiScale,
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 11 * uiScale,
          fontWeight: FontWeight.w900,
          height: 1.0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // אם את לא מעבירה uiScale פנימה – אפשר לקחת מהטקסט-סקייל/רוחב מסך,
    // אבל כדי לא לגעת בעוד קוד, נשאיר כאן סקייל עדין קבוע:
    final double uiScale = (MediaQuery.of(context).size.width / 390.0).clamp(0.85, 1.2);

    // ✅ המספר בעיגול הימני-עליון
    final String countLabel = (widget.count >= 99) ? '99+' : widget.count.toString();

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          final t = _ctrl.value;
          final s = _shakeT(t);

          // רטט קטן (2–3 פיקסלים) גם X וגם Y
          final dx = s * (2.2 * uiScale);
          final dy = s * (1.2 * uiScale);

          return Transform.translate(
            offset: Offset(dx, dy),
            child: child,
          );
        },
        child: Container(
          width: 56 * uiScale,
          height: 56 * uiScale,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.72),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withOpacity(0.18),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 16 * uiScale,
                spreadRadius: 1 * uiScale,
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ✅ האייקון במרכז (במקום המספר הגדול)
              Center(
                child: Image.asset(
                  widget.iconAsset,
                  width: 30 * uiScale,
                  height: 30 * uiScale,
                  fit: BoxFit.contain,
                ),
              ),

              // ✅ עיגול הודעות בפינה ימין-למעלה (קצת "בתוך" הווידג'ט)
              if (widget.count > 0)
                Positioned(
                  top: -6 * uiScale,
                  right: -6 * uiScale,
                  child: _smallBubble(
                    text: countLabel,
                    uiScale: uiScale,
                  ),
                ),

              // ✅ עיגול @ בפינה שמאל-למעלה (קצת "בתוך" הווידג'ט)
              if (widget.hasMention)
                Positioned(
                  top: -6 * uiScale,
                  left: -6 * uiScale,
                  child: _smallBubble(
                    text: '@',
                    uiScale: uiScale,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ✅ Painter שמצייר: קו אדום דק + “פייד” קטן פנימה (כמו Mystic, בלי glow blocks)
class _MysticRedFramePainter extends CustomPainter {
  static const Color _solidRed = Color(0xFFE53935);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 1) קו אדום סולידי דק שנוגע בקצוות
    const double stroke = 2.0;
    final borderPaint = Paint()
      ..color = _solidRed
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    canvas.drawRect(rect.deflate(stroke / 2), borderPaint);

    // 2) פייד עדין פנימה בלבד (עובי קטן)
    const double fadeThickness = 10.0;

    // TOP
    final topRect = Rect.fromLTWH(0, 0, size.width, fadeThickness);
    final topPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x33E53935),
          Color(0x10E53935),
          Color(0x00E53935),
        ],
        stops: [0.0, 0.55, 1.0],
      ).createShader(topRect);
    canvas.drawRect(topRect, topPaint);

    // BOTTOM
    final bottomRect =
        Rect.fromLTWH(0, size.height - fadeThickness, size.width, fadeThickness);
    final bottomPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          Color(0x33E53935),
          Color(0x10E53935),
          Color(0x00E53935),
        ],
        stops: [0.0, 0.55, 1.0],
      ).createShader(bottomRect);
    canvas.drawRect(bottomRect, bottomPaint);

    // LEFT
    final leftRect = Rect.fromLTWH(0, 0, fadeThickness, size.height);
    final leftPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Color(0x33E53935),
          Color(0x10E53935),
          Color(0x00E53935),
        ],
        stops: [0.0, 0.55, 1.0],
      ).createShader(leftRect);
    canvas.drawRect(leftRect, leftPaint);

    // RIGHT
    final rightRect =
        Rect.fromLTWH(size.width - fadeThickness, 0, fadeThickness, size.height);
    final rightPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
        colors: [
          Color(0x33E53935),
          Color(0x10E53935),
          Color(0x00E53935),
        ],
        stops: [0.0, 0.55, 1.0],
      ).createShader(rightRect);
    canvas.drawRect(rightRect, rightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


/// =======================
/// Small "system bar" used in state file
/// =======================
class SystemMessageBar extends StatelessWidget {
  final String text;
  final double uiScale;

  const SystemMessageBar({super.key, 
    required this.text,
    required this.uiScale,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, // ✅ spreads full width
      padding: EdgeInsets.symmetric(
        horizontal: 14 * uiScale,
        vertical: 10 * uiScale,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35), // ✅ translucent bar look
        borderRadius: BorderRadius.circular(4 * uiScale), // ✅ subtle rectangle (not pill)
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withOpacity(0.88),
          fontSize: 11 * uiScale,
          fontWeight: FontWeight.w400,
          height: 1.0,
        ),
      ),
    );
  }
}
