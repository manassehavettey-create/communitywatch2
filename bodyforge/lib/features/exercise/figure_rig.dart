import 'dart:math' as math;
import 'dart:ui';

/// A tiny 2D rig for animated exercise demonstrations drawn in code.
///
/// Coordinates are normalised to a 1.6 × 1.0 stage; the floor is at y = 0.95
/// and the figure faces +x (right). A pose fixes the hip, the shoulder (the
/// torso direction), and targets for both hands and ankles; two-bone IK
/// bends elbows and knees toward the given hint directions.
abstract final class Rig {
  static const stageW = 1.6;
  static const floor = 0.95;
  static const torso = 0.30;
  static const neck = 0.045;
  static const headR = 0.058;
  static const upperArm = 0.16;
  static const forearm = 0.15;
  static const thigh = 0.23;
  static const shin = 0.23;
  static const ankleY = 0.93;
}

class Pose {
  const Pose({
    required this.hip,
    required this.shoulder,
    required this.nh,
    required this.fh,
    required this.nf,
    required this.ff,
    this.nElbow = const Offset(-1, 0.4),
    this.fElbow,
    this.nKnee = const Offset(1, -0.2),
    this.fKnee,
    this.headTilt = 0,
    this.curve = 0,
  });

  final Offset hip;

  /// Only the direction hip→shoulder is used (length is fixed).
  final Offset shoulder;

  /// Near / far hand and ankle targets.
  final Offset nh, fh, nf, ff;

  /// Bend hints (which side elbows / knees go).
  final Offset nElbow;
  final Offset? fElbow;
  final Offset nKnee;
  final Offset? fKnee;

  /// Extra head rotation in degrees (+ = chin down / forward).
  final double headTilt;

  /// Spine curvature: + rounds the back up (cat), − arches (cow).
  final double curve;

  static Offset _l(Offset a, Offset b, double t) => Offset(lerpDouble(a.dx, b.dx, t)!, lerpDouble(a.dy, b.dy, t)!);

  static Pose lerp(Pose a, Pose b, double t) => Pose(
        hip: _l(a.hip, b.hip, t),
        shoulder: _l(a.shoulder, b.shoulder, t),
        nh: _l(a.nh, b.nh, t),
        fh: _l(a.fh, b.fh, t),
        nf: _l(a.nf, b.nf, t),
        ff: _l(a.ff, b.ff, t),
        nElbow: _l(a.nElbow, b.nElbow, t),
        fElbow: _l(a.fElbow ?? a.nElbow, b.fElbow ?? b.nElbow, t),
        nKnee: _l(a.nKnee, b.nKnee, t),
        fKnee: _l(a.fKnee ?? a.nKnee, b.fKnee ?? b.nKnee, t),
        headTilt: lerpDouble(a.headTilt, b.headTilt, t)!,
        curve: lerpDouble(a.curve, b.curve, t)!,
      );
}

enum PropKind { box, towel }

/// Furniture / towel drawn behind the figure (walls use [Demo.wallX]).
class DemoProp {
  const DemoProp.box(this.rect) : kind = PropKind.box;
  const DemoProp.towel(this.rect) : kind = PropKind.towel;

  final PropKind kind;
  final Rect rect;
}

class Demo {
  const Demo(this.poses, {this.props = const [], this.stepMs = 900, this.pingPong = true, this.front = false, this.wallX});
  final List<Pose> poses;
  final List<DemoProp> props;
  final int stepMs;

  /// A→B→A (true) or cycle A→B→C→A (false).
  final bool pingPong;

  /// Front view: both sides drawn with equal weight.
  final bool front;
  final double? wallX;

  /// Pose at animation value t ∈ [0, 1).
  Pose at(double t) {
    if (poses.length == 1) return poses.first;
    final seq = pingPong ? [...poses, ...poses.reversed.skip(1).take(poses.length - 2)] : poses;
    final n = seq.length;
    final x = (t % 1) * n;
    final i = x.floor();
    final f = x - i;
    final eased = f < 0.5 ? 4 * f * f * f : 1 - math.pow(-2 * f + 2, 3) / 2;
    return Pose.lerp(seq[i % n], seq[(i + 1) % n], eased.toDouble());
  }

  Duration get period {
    final n = pingPong ? math.max(1, 2 * poses.length - 2) : poses.length;
    return Duration(milliseconds: stepMs * n);
  }
}

/// Solved joint positions for drawing.
class Skeleton {
  Skeleton(this.hip, this.shoulder, this.neckTop, this.head, this.nElbow, this.nHand, this.fElbow, this.fHand, this.nKnee,
      this.nAnkle, this.fKnee, this.fAnkle, this.curve);
  final Offset hip, shoulder, neckTop, head, nElbow, nHand, fElbow, fHand, nKnee, nAnkle, fKnee, fAnkle;
  final double curve;

  static Offset _norm(Offset v) {
    final d = v.distance;
    return d == 0 ? const Offset(0, -1) : v / d;
  }

  /// Two-bone IK from [root] toward [target]; the joint goes to the side of
  /// [hint]. Unreachable targets straighten the limb toward them.
  static (Offset, Offset) _ik(Offset root, Offset target, double a, double b, Offset hint) {
    final v = target - root;
    var d = v.distance;
    final dir = _norm(v);
    if (d >= a + b - 1e-6) {
      final joint = root + dir * a;
      return (joint, root + dir * (a + b));
    }
    d = math.max(d, (a - b).abs() + 1e-4);
    final x = (a * a - b * b + d * d) / (2 * d);
    final h = math.sqrt(math.max(0, a * a - x * x));
    final base = root + dir * x;
    final perp = Offset(-dir.dy, dir.dx);
    final side = (perp.dx * hint.dx + perp.dy * hint.dy) >= 0 ? 1.0 : -1.0;
    return (base + perp * h * side, target);
  }

  factory Skeleton.solve(Pose p) {
    final tdir = _norm(p.shoulder - p.hip);
    final shoulder = p.hip + tdir * Rig.torso;
    final neckTop = shoulder + tdir * Rig.neck;
    final tilt = p.headTilt * math.pi / 180;
    final hdir = Offset(tdir.dx * math.cos(tilt) - tdir.dy * math.sin(tilt), tdir.dx * math.sin(tilt) + tdir.dy * math.cos(tilt));
    final head = neckTop + hdir * Rig.headR;
    final (ne, nh) = _ik(shoulder, p.nh, Rig.upperArm, Rig.forearm, p.nElbow);
    final (fe, fh) = _ik(shoulder, p.fh, Rig.upperArm, Rig.forearm, p.fElbow ?? p.nElbow);
    final (nk, na) = _ik(p.hip, p.nf, Rig.thigh, Rig.shin, p.nKnee);
    final (fk, fa) = _ik(p.hip, p.ff, Rig.thigh, Rig.shin, p.fKnee ?? p.nKnee);
    return Skeleton(p.hip, shoulder, neckTop, head, ne, nh, fe, fh, nk, na, fk, fa, p.curve);
  }
}
