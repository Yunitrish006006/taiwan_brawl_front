import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'street_scrap_module.dart';

/// Renders one pose from the optional Street Scrap protagonist art pack.
///
/// Pose 0 is idle. Poses 1–3 are walking, searching, and sorting/work.
/// Without the art pack, a small pixel painter keeps the shell lightweight.
class StreetScrapProtagonistSprite extends StatelessWidget {
  const StreetScrapProtagonistSprite({
    super.key,
    required this.pose,
    required this.height,
    this.art,
  });

  final int pose;
  final double height;
  final StreetScrapProtagonistArt? art;

  @override
  Widget build(BuildContext context) {
    final displayedPose = pose.clamp(0, 3);
    final isIdle = displayedPose == 0;
    final Uint8List? imageBytes = art == null
        ? null
        : isIdle
        ? art!.idlePng
        : art!.actionsPng;
    return SizedBox(
      width: height * (628 / 835),
      height: height,
      child: imageBytes == null
          ? CustomPaint(
              key: ValueKey('street-scrap-protagonist-pose-$displayedPose'),
              painter: _StreetScrapProtagonistFallbackPainter(displayedPose),
              isComplex: true,
              willChange: false,
            )
          : Image.memory(
              imageBytes,
              key: ValueKey('street-scrap-protagonist-pose-$displayedPose'),
              alignment: isIdle
                  ? Alignment.center
                  : Alignment(-1.0 + (displayedPose - 1).toDouble(), 0),
              fit: isIdle ? BoxFit.contain : BoxFit.cover,
              filterQuality: FilterQuality.none,
              excludeFromSemantics: true,
            ),
    );
  }
}

class _StreetScrapProtagonistFallbackPainter extends CustomPainter {
  const _StreetScrapProtagonistFallbackPainter(this.pose);

  final int pose;

  static const _outline = Color(0xFF26332B);
  static const _coat = Color(0xFF596F68);
  static const _coatLight = Color(0xFF829087);
  static const _skin = Color(0xFFD4A982);
  static const _hair = Color(0xFF493A31);
  static const _hat = Color(0xFF79654A);
  static const _trousers = Color(0xFF414B48);
  static const _sack = Color(0xFFA27E4F);
  static const _sackLight = Color(0xFFC3A16B);

  @override
  void paint(Canvas canvas, Size size) {
    final cellX = size.width / 16;
    final cellY = size.height / 22;
    final paint = Paint()..isAntiAlias = false;

    void block(int x, int y, Color color, {int width = 1, int height = 1}) {
      paint.color = color;
      canvas.drawRect(
        Rect.fromLTWH(cellX * x, cellY * y, cellX * width, cellY * height),
        paint,
      );
    }

    // Worn shoulder sack, drawn behind the figure.
    block(1, 9, _outline, width: 3, height: 5);
    block(2, 9, _sack, width: 2, height: 4);
    block(2, 10, _sackLight, width: 1);
    block(3, 12, _hat, width: 1);

    // Cap, hair, and face.
    block(5, 2, _outline, width: 7);
    block(6, 1, _outline, width: 5);
    block(6, 2, _hat, width: 5, height: 2);
    block(4, 4, _outline, width: 9);
    block(5, 4, _hair, width: 7);
    block(6, 5, _skin, width: 6, height: 3);
    block(5, 5, _hair, width: 1, height: 3);
    block(11, 6, _hair, width: 1, height: 2);
    block(7, 6, _outline);
    block(10, 6, _outline);
    block(8, 7, _hair, width: 2);

    // Jacket and arms vary slightly by pose while staying deliberately simple.
    block(4, 8, _outline, width: 9, height: 8);
    block(5, 9, _coat, width: 7, height: 6);
    block(8, 9, _coatLight);
    block(8, 10, _coatLight);
    block(7, 9, _hat, width: 3);
    block(3, 9, _outline, width: 2, height: 5);
    block(3, 10, _coat, width: 1, height: 3);
    block(12, 9, _outline, width: 2, height: 5);

    if (pose == 1) {
      block(12, 8, _coat, width: 1, height: 3);
      block(2, 10, _skin, width: 1);
      block(4, 14, _skin, width: 1);
    } else if (pose == 2) {
      block(12, 12, _coat, width: 2, height: 2);
      block(13, 13, _skin);
      block(5, 13, _skin, width: 2);
    } else if (pose == 3) {
      block(12, 11, _coat, width: 2, height: 2);
      block(13, 12, _skin);
      block(5, 12, _skin, width: 2);
    } else {
      block(12, 10, _coat, width: 1, height: 3);
      block(13, 13, _skin);
    }

    // Trouser legs and scuffed shoes.
    block(5, 15, _outline, width: 7, height: 5);
    block(6, 16, _trousers, width: 2, height: 4);
    block(9, 16, _trousers, width: 2, height: 4);
    if (pose == 1) {
      block(5, 19, _trousers, width: 2);
      block(10, 18, _trousers, width: 2);
    }
    block(4, 20, _outline, width: 4);
    block(9, 20, _outline, width: 4);
    block(5, 20, _hat, width: 2);
    block(10, 20, _hat, width: 2);
    block(5, 21, _outline, width: 3);
    block(9, 21, _outline, width: 3);
  }

  @override
  bool shouldRepaint(_StreetScrapProtagonistFallbackPainter oldDelegate) =>
      pose != oldDelegate.pose;
}
