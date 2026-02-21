import 'dart:async';
import 'package:flutter/material.dart';

class NewMessagesBadge extends StatefulWidget {
  final int count;
  final Color badgeColor;

  /// ✅ NEW: if true -> show a small @ indicator (mentions exist below)
  final bool hasMention;

  final VoidCallback? onTap;

  const NewMessagesBadge({
    super.key,
    required this.count,
    required this.badgeColor,
    this.hasMention = false,
    this.onTap,
  });

  @override
  State<NewMessagesBadge> createState() => _NewMessagesBadgeState();
}

class _NewMessagesBadgeState extends State<NewMessagesBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeCtrl;
  late final Animation<double> _dx;

  Timer? _pulseTimer;

  @override
  void initState() {
    super.initState();

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    _dx = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -3), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -3, end: 3), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 3, end: -2), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -2, end: 2), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 2, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeOut));

    _startPulse();
  }

  @override
  void didUpdateWidget(covariant NewMessagesBadge oldWidget) {
    super.didUpdateWidget(oldWidget);

    // כשהמספר עולה → תן "טיק" קטן מיידית (חמוד)
    if (widget.count > oldWidget.count) {
      _shakeOnce();
    }

    // ✅ גם אם count לא עלה אבל הופיע mention -> טיק קטן
    if (!oldWidget.hasMention && widget.hasMention) {
      _shakeOnce();
    }

    // אם פתאום count נהיה 0, אין טעם להשאיר טיימר
    if (widget.count == 0) {
      _stopPulse();
    } else if (oldWidget.count == 0 && widget.count > 0) {
      _startPulse();
    }
  }

  void _startPulse() {
    _pulseTimer?.cancel();
    if (widget.count == 0) return;

    // רטט כל 2 שניות
    _pulseTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      _shakeOnce();
    });
  }

  void _stopPulse() {
    _pulseTimer?.cancel();
    _pulseTimer = null;
  }

  Future<void> _shakeOnce() async {
    if (_shakeCtrl.isAnimating) return;
    await _shakeCtrl.forward(from: 0);
  }

  @override
  void dispose() {
    _stopPulse();
    _shakeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.count <= 0) return const SizedBox.shrink();

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _shakeCtrl,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(_dx.value, 0),
            child: child,
          );
        },
        child: _BadgeBody(
          count: widget.count,
          badgeColor: widget.badgeColor,
          hasMention: widget.hasMention,
        ),
      ),
    );
  }
}

class _BadgeBody extends StatelessWidget {
  final int count;
  final Color badgeColor;
  final bool hasMention;

  const _BadgeBody({
    required this.count,
    required this.badgeColor,
    required this.hasMention,
  });

  @override
  Widget build(BuildContext context) {
    // לשמור קומפקטי כמו בתמונה שלך
    const double size = 44;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Center(
            child: Icon(
              Icons.mail_outline_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),

          // ✅ @ indicator (mentions exist below)
if (hasMention)
  Positioned(
    left: -6,
    top: -6,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor, // ✅ same as unread count bubble
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.black.withOpacity(0.35),
          width: 1,
        ),
      ),
      child: const Text(
        '@',
        textHeightBehavior: TextHeightBehavior(
          applyHeightToFirstAscent: false,
          applyHeightToLastDescent: false,
        ),
        style: TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          height: 1.0,
        ),
      ),
    ),
  ),


          // העיגול האדום עם המספר
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor, // #ef797e
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.black.withOpacity(0.35),
                  width: 1,
                ),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
