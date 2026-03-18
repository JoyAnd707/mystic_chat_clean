import 'package:flutter/material.dart';

class ReplyPreviewBar extends StatelessWidget {
  final double uiScale;
  final Color stripeColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const ReplyPreviewBar({
    super.key,
    required this.uiScale,
    required this.stripeColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    double s(double v) => v * uiScale;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.fromLTRB(s(10), s(8), s(10), s(8)),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.10), width: 1),
            ),
          ),
          child: Row(
            children: [
              // left color stripe
              Container(
                width: s(4),
                height: s(44),
                decoration: BoxDecoration(
                  color: stripeColor,
                  borderRadius: BorderRadius.circular(s(10)),
                ),
              ),
              SizedBox(width: s(10)),

              // @ icon
              Container(
                width: s(28),
                height: s(28),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(s(8)),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.10),
                    width: 1,
                  ),
                ),
                child: Text(
                  '@',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.92),
                    fontWeight: FontWeight.w900,
                    fontSize: s(16),
                    height: 1.0,
                  ),
                ),
              ),

              SizedBox(width: s(10)),

              // text
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.92),
                        fontSize: s(13),
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                        letterSpacing: s(0.2),
                      ),
                    ),
                    SizedBox(height: s(4)),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.72),
                        fontSize: s(12),
                        fontWeight: FontWeight.w600,
                        height: 1.05,
                      ),
                    ),
                  ],
                ),
              ),

              // close
              InkWell(
                onTap: onClose,
                borderRadius: BorderRadius.circular(s(999)),
                child: Padding(
                  padding: EdgeInsets.all(s(6)),
                  child: Icon(
                    Icons.close,
                    color: Colors.white.withOpacity(0.85),
                    size: s(18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
