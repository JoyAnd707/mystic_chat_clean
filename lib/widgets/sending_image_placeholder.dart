import 'package:flutter/material.dart';
import 'rotating_envelope.dart';

class SendingImagePlaceholder extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final String envelopeAssetPath;

  const SendingImagePlaceholder({
    super.key,
    required this.width,
    required this.height,
    required this.envelopeAssetPath,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: width,
        height: height,
        child: ColoredBox(
          color: const Color(0xFF0E0E0E),
          child: Center(
            child: RotatingEnvelope(
              assetPath: envelopeAssetPath,
              size: 26, // תשני לפי הוייב
              duration: const Duration(milliseconds: 1800),
              opacity: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}
