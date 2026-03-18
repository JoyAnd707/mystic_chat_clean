import 'dart:math';
import 'package:flutter/material.dart';

class HeartReactionFlyLayer extends StatefulWidget {
  final Widget child;

  const HeartReactionFlyLayer({super.key, required this.child});

  static _HeartReactionFlyLayerState of(BuildContext context) {
    final state = context.findAncestorStateOfType<_HeartReactionFlyLayerState>();
    assert(state != null, 'HeartReactionFlyLayer not found in tree');
    return state!;
  }

  @override
  State<HeartReactionFlyLayer> createState() => _HeartReactionFlyLayerState();
}

class _HeartReactionFlyLayerState extends State<HeartReactionFlyLayer>
    with TickerProviderStateMixin {
  final List<_FlyingHeart> _hearts = [];

  void spawnHeart({required Color color}) {
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),

    );

    final heart = _FlyingHeart(
      controller: controller,
      color: color,
    );

    setState(() => _hearts.add(heart));

    controller.forward().whenComplete(() {
      if (mounted) setState(() => _hearts.remove(heart));
      controller.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        widget.child,
        IgnorePointer(
          child: Stack(
            children: _hearts.map((h) {
              return AnimatedBuilder(
                animation: h.controller,
                builder: (_, __) {
                  final t = h.controller.value;

                  // ✅ בדיוק באמצע המסך
                  final cx = size.width / 2;
                  final cy = size.height / 2;

                  // ✅ חצי סיבוב קטן מאוד (רדיוס קטן)
                  final minDim = min(size.width, size.height);
                 final radius = minDim * 0.20;


            // ✅ מתחיל למעלה (במקום במרכז)
final angle = (-pi / 2) + (pi * t);

// ✅ חצי סיבוב קטן סביב המרכז
final x = cx + cos(angle) * radius;
final y = cy + sin(angle) * radius;


                  // ✅ נהיה פחות faded לאורך הזמן (עולה בהדרגה)
                  final fadeInEnd = 0.85; // עד מתי הוא ממשיך להתחזק
                  final opacity = (t / fadeInEnd).clamp(0.0, 1.0);

                  // ✅ "נעלם בבום" בפריים האחרון
                  final finalOpacity = (t >= 0.98) ? 0.0 : opacity;

                  const double iconSize = 140.0;

                  return Positioned(
                    left: x - iconSize / 2, // ✅ מרכז התמונה על הנקודה
                    top: y - iconSize / 2,
                    child: Opacity(
                      opacity: finalOpacity,
                      child: ColorFiltered(
                        colorFilter: ColorFilter.mode(h.color, BlendMode.srcIn),
                        child: Image.asset(
                          'assets/reactions/HeartReaction.png',
                          width: iconSize,
                          height: iconSize,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _FlyingHeart {
  final AnimationController controller;
  final Color color;

  _FlyingHeart({required this.controller, required this.color});
}
