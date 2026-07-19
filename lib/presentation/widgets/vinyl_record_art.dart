import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/library_models.dart';
import 'album_art.dart';

/// A skeuomorphic vinyl record used by the vinyl now-playing style.
///
/// - **Rest:** cartridge fully clear of the platter (outside the outer rim).
/// - **Play:** small clockwise drop; head on the mid-line of the black groove
///   ring, upper-right only (never across the label).
/// - Pivot sits well above the disc so the base is not glued to the rim.
class VinylRecordArt extends StatefulWidget {
  const VinylRecordArt({
    required this.album,
    required this.isPlaying,
    this.isActive = true,
    this.size,
    super.key,
  });

  final Album album;
  final bool isPlaying;
  final bool isActive;
  final double? size;

  @override
  State<VinylRecordArt> createState() => VinylRecordArtState();
}

class VinylRecordArtState extends State<VinylRecordArt>
    with SingleTickerProviderStateMixin {
  static const _revolutionDuration = Duration(seconds: 14);
  static const _armSwingDuration = Duration(milliseconds: 700);

  /// Record diameter / composition side. Slightly under full width so the
  /// raised pivot still has clear air above the rim.
  static const _discFraction = 0.86;

  static const _labelFraction = _VinylDiscPainter.labelFrameRadius;

  /// Disc sits lower so the pivot (near the top) reads farther from the rim.
  static const _discCenterFraction = Offset(0.5, 0.58);

  /// Tonearm base — high in the composition, away from the platter.
  static const _armPivotFraction = Offset(0.5, 0.02);

  static const _armBoxFraction = 0.84;

  static const _grooveMidRadiusFraction =
      (_VinylDiscPainter.labelFrameRadius +
          _VinylDiscPainter.outerSurfaceRadius) /
      2;

  /// Solved so rest is outside the rim and play lands mid-groove upper-right.
  static final double _armPlayTurns = _solveArmPlayTurns();

  static double _solveArmPlayTurns() {
    const side = 1.0;
    final discRadius = side * _discFraction / 2;
    final targetRadius = discRadius * _grooveMidRadiusFraction;
    final outerRadius =
        discRadius * _VinylDiscPainter.outerSurfaceRadius;
    final discCenter = Offset(
      side * _discCenterFraction.dx,
      side * _discCenterFraction.dy,
    );
    final pivot = Offset(
      side * _armPivotFraction.dx,
      side * _armPivotFraction.dy,
    );
    final cartLocal = _TonearmPainter.cartridgeCenterFromPivot(
      side * _armBoxFraction,
    );

    // Sanity: rest pose must sit outside the platter.
    final restWorld = pivot + cartLocal;
    assert(
      (restWorld - discCenter).distance > outerRadius * 1.02,
      'Vinyl rest pose must clear the outer rim.',
    );

    var bestTurns = 0.04;
    var bestError = double.infinity;
    for (var i = 0; i <= 600; i++) {
      final turns = i / 600 * 0.10;
      final theta = turns * 2 * math.pi;
      final cosT = math.cos(theta);
      final sinT = math.sin(theta);
      final world =
          pivot +
          Offset(
            cartLocal.dx * cosT - cartLocal.dy * sinT,
            cartLocal.dx * sinT + cartLocal.dy * cosT,
          );
      // Right side + upper half of the black ring only.
      if (world.dx < discCenter.dx + discRadius * 0.15) continue;
      if (world.dy > discCenter.dy - discRadius * 0.08) continue;
      final error = ((world - discCenter).distance - targetRadius).abs();
      if (error < bestError) {
        bestError = error;
        bestTurns = turns;
      }
    }
    return bestTurns;
  }

  late final AnimationController _rotation;
  bool _reduceMotion = false;

  @visibleForTesting
  bool get isDiscSpinning => _rotation.isAnimating;

  @visibleForTesting
  double get discTurns => _rotation.value;

  @override
  void initState() {
    super.initState();
    _rotation = AnimationController(
      vsync: this,
      duration: _revolutionDuration,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion != _reduceMotion) {
      _reduceMotion = reduceMotion;
    }
    _syncRotation();
  }

  @override
  void didUpdateWidget(covariant VinylRecordArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying ||
        widget.isActive != oldWidget.isActive) {
      _syncRotation();
    }
  }

  void _syncRotation() {
    final shouldSpin = widget.isPlaying && widget.isActive && !_reduceMotion;
    if (shouldSpin) {
      if (!_rotation.isAnimating) _rotation.repeat();
    } else {
      _rotation.stop();
    }
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final armDuration = _reduceMotion ? Duration.zero : _armSwingDuration;
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = widget.size ?? constraints.biggest.shortestSide;
        final side = available.isFinite && available > 0 ? available : 240.0;
        final discDiameter = side * _discFraction;
        final labelDiameter = discDiameter * _labelFraction;
        final discCenter = Offset(
          side * _discCenterFraction.dx,
          side * _discCenterFraction.dy,
        );
        final armPivot = Offset(
          side * _armPivotFraction.dx,
          side * _armPivotFraction.dy,
        );
        final armBox = side * _armBoxFraction;
        return SizedBox.square(
          key: const ValueKey('vinyl-record-art'),
          dimension: side,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: discCenter.dx - discDiameter / 2,
                top: discCenter.dy - discDiameter / 2,
                child: RotationTransition(
                  turns: _rotation,
                  child: SizedBox.square(
                    dimension: discDiameter,
                    child: Stack(
                      children: [
                        const Positioned.fill(
                          child: CustomPaint(painter: _VinylDiscPainter()),
                        ),
                        Center(
                          child: ClipOval(
                            child: AlbumArt(
                              album: widget.album,
                              size: labelDiameter,
                              borderRadius: 0,
                              showShadow: false,
                              gaplessPlayback: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: armPivot.dx - armBox / 2,
                top: armPivot.dy - armBox / 2,
                child: AnimatedRotation(
                  turns: widget.isPlaying ? _armPlayTurns : 0,
                  duration: armDuration,
                  curve: Curves.easeOutCubic,
                  child: CustomPaint(
                    size: Size.square(armBox),
                    painter: const _TonearmPainter(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VinylDiscPainter extends CustomPainter {
  const _VinylDiscPainter();

  static const labelFrameRadius = 0.66;
  static const outerSurfaceRadius = 0.94;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF26262B));
    canvas.drawCircle(
      center,
      radius - 0.75,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.08),
    );

    canvas.drawCircle(
      center,
      radius * outerSurfaceRadius,
      Paint()..color = const Color(0xFF0E0E10),
    );

    final groovePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.03);
    for (var r = radius * 0.72; r < radius * 0.90; r += radius * 0.045) {
      canvas.drawCircle(center, r, groovePaint);
    }

    canvas.drawCircle(
      center,
      radius * (labelFrameRadius + 0.012),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.022
        ..color = const Color(0xFF050506),
    );

    canvas.drawCircle(
      center,
      radius * outerSurfaceRadius,
      Paint()
        ..shader = SweepGradient(
          colors: [
            Colors.transparent,
            Colors.white.withValues(alpha: 0.05),
            Colors.transparent,
            Colors.transparent,
            Colors.white.withValues(alpha: 0.08),
            Colors.transparent,
          ],
          stops: const [0.0, 0.09, 0.20, 0.58, 0.70, 0.83],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(_VinylDiscPainter oldPainter) => false;
}

/// Bent-tube tonearm (original proportions): long steep run out of the pivot,
/// soft elbow, short near-level run into the headshell — same family as the
/// reference white S-curve arm. Rest pose still clears the platter because
/// the composition pivot sits high above a slightly lower disc.
class _TonearmPainter extends CustomPainter {
  const _TonearmPainter();

  static const _armColor = Color(0xFFF2F2F4);

  /// Rest offsets from pivot in [unit] multiples (+x right, +y down).
  /// These ratios match the first vinyl implementation (elbow + long boom).
  static const elbowFromPivot = Offset(0.205, 0.163);
  static const tipFromPivot = Offset(0.413, 0.18);
  static const cartridgePastTip = 0.055;

  static Offset cartridgeCenterFromPivot(double unit) {
    final tip = Offset(tipFromPivot.dx * unit, tipFromPivot.dy * unit);
    final elbow = Offset(elbowFromPivot.dx * unit, elbowFromPivot.dy * unit);
    final seg2 = tip - elbow;
    final dir = seg2 / seg2.distance;
    return tip + dir * (cartridgePastTip * unit);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final pivot = size.center(Offset.zero);
    final unit = size.shortestSide;
    // Rest: headshell clear of the upper-right rim (composition places the
    // pivot high enough that this boom does not sit on the black ring).
    final tip = pivot + Offset(tipFromPivot.dx * unit, tipFromPivot.dy * unit);
    final elbow =
        pivot + Offset(elbowFromPivot.dx * unit, elbowFromPivot.dy * unit);
    final seg1 = elbow - pivot;
    final seg2 = tip - elbow;
    // Rounded elbow: trim both segments and bridge with a quadratic.
    final trim = unit * 0.035;
    final before = elbow - seg1 / seg1.distance * trim;
    final after = elbow + seg2 / seg2.distance * trim;
    final armPath = Path()
      ..moveTo(pivot.dx, pivot.dy)
      ..lineTo(before.dx, before.dy)
      ..quadraticBezierTo(elbow.dx, elbow.dy, after.dx, after.dy)
      ..lineTo(tip.dx, tip.dy);
    canvas.drawPath(
      armPath,
      Paint()
        ..color = _armColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 0.028
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Cartridge: clean headshell aligned with the last segment (reference
    // white block with a thin face groove).
    final tangentAngle = math.atan2(tip.dy - elbow.dy, tip.dx - elbow.dx);
    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    canvas.rotate(tangentAngle);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(unit * cartridgePastTip, 0),
          width: unit * 0.11,
          height: unit * 0.046,
        ),
        Radius.circular(unit * 0.010),
      ),
      Paint()..color = _armColor,
    );
    // Face vent / stylus block detail on the headshell.
    canvas.drawLine(
      Offset(unit * 0.006, -unit * 0.020),
      Offset(unit * 0.006, unit * 0.020),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..strokeWidth = unit * 0.008
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(unit * 0.028, -unit * 0.014),
      Offset(unit * 0.028, unit * 0.014),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..strokeWidth = unit * 0.006
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();

    // Pivot cap.
    canvas.drawCircle(pivot, unit * 0.040, Paint()..color = _armColor);
    canvas.drawCircle(
      pivot,
      unit * 0.040,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 0.007
        ..color = Colors.black.withValues(alpha: 0.18),
    );
    canvas.drawCircle(
      pivot,
      unit * 0.013,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(_TonearmPainter oldPainter) => false;
}
