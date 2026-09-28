import 'dart:ui';

import 'figure_rig.dart';

// Poses are authored on a 1.6 × 1.0 stage (floor y = 0.95, ankles at 0.93),
// figure facing right. Standing hip height = 0.47.

const _a = 0.93; // ankle on the floor
const _up = Offset(0, -1);
const _down = Offset(0, 1);
const _back = Offset(-1, 0);
const _fwd = Offset(1, 0);

Offset _o(double x, double y) => Offset(x, y);

/// Standing pose at [x]. Arms hang unless hands are given.
Pose _stand(
  double x, {
  double hipY = 0.47,
  double lean = 0,
  Offset? nh,
  Offset? fh,
  Offset? nf,
  Offset? ff,
  Offset nElbow = const Offset(-1, 0.4),
  Offset? fElbow,
  Offset nKnee = const Offset(1, -0.2),
  Offset? fKnee,
  double headTilt = 0,
}) {
  final hip = _o(x, hipY);
  final sh = hip + Offset(lean, -0.30);
  return Pose(
    hip: hip,
    shoulder: sh,
    nh: nh ?? _o(sh.dx + 0.04, sh.dy + 0.30),
    fh: fh ?? _o(sh.dx - 0.02, sh.dy + 0.30),
    nf: nf ?? _o(x + 0.03, _a),
    ff: ff ?? _o(x - 0.03, _a),
    nElbow: nElbow,
    fElbow: fElbow,
    nKnee: nKnee,
    fKnee: fKnee,
    headTilt: headTilt,
  );
}

/// Supine (on the back), head to the left.
Pose _supine({
  double hipX = 0.74,
  double hipY = 0.88,
  Offset shoulder = const Offset(0.44, 0.88),
  Offset? nh,
  Offset? fh,
  required Offset nf,
  Offset? ff,
  Offset nKnee = _up,
  Offset? fKnee,
  Offset nElbow = _down,
  double headTilt = 0,
}) =>
    Pose(
      hip: _o(hipX, hipY),
      shoulder: shoulder,
      nh: nh ?? _o(shoulder.dx + 0.22, 0.92),
      fh: fh ?? nh ?? _o(shoulder.dx + 0.22, 0.92),
      nf: nf,
      ff: ff ?? nf,
      nKnee: nKnee,
      fKnee: fKnee,
      nElbow: nElbow,
      headTilt: headTilt,
    );

/// Plank-family pose: hands/forearms right, feet left.
Pose _plank({
  required Offset hip,
  required Offset shoulder,
  Offset hands = const Offset(1.12, 0.93),
  Offset? fh,
  Offset feet = const Offset(0.36, 0.92),
  Offset? ff,
  Offset nElbow = const Offset(-1, -0.8),
  Offset nKnee = _down,
  Offset? fKnee,
  double curve = 0,
  double headTilt = 0,
}) =>
    Pose(
      hip: hip,
      shoulder: shoulder,
      nh: hands,
      fh: fh ?? hands,
      nf: feet,
      ff: ff ?? feet,
      nElbow: nElbow,
      nKnee: nKnee,
      fKnee: fKnee,
      curve: curve,
      headTilt: headTilt,
    );

/// Prone (face down), head to the right.
Pose _prone({double lift = 0, double armLift = 0, Offset? hands, double legLift = 0}) => Pose(
      hip: _o(0.70, 0.89),
      shoulder: _o(1.0, 0.88 - lift),
      nh: hands ?? _o(1.32, 0.90 - armLift),
      fh: hands ?? _o(1.32, 0.90 - armLift),
      nf: _o(0.25, 0.91 - legLift),
      ff: _o(0.25, 0.91 - legLift),
      nElbow: _up,
      nKnee: _down,
      headTilt: -lift * 120,
    );

/// Quadruped (hands and knees).
Pose _quad({Offset? nh, Offset? ff, double hipY = 0.62, double curve = 0, double headTilt = 0, double kneeY = _a}) => Pose(
      hip: _o(0.66, hipY),
      shoulder: _o(0.98, 0.62),
      nh: nh ?? _o(1.0, _a),
      fh: _o(1.0, _a),
      nf: _o(0.40, kneeY),
      ff: ff ?? _o(0.40, kneeY),
      nElbow: _back,
      nKnee: _down,
      curve: curve,
      headTilt: headTilt,
    );

/// Seated on the floor.
Pose _seated({
  Offset shoulder = const Offset(0.72, 0.56),
  Offset? nh,
  Offset? fh,
  Offset nf = const Offset(1.12, 0.92),
  Offset? ff,
  Offset nKnee = _up,
  Offset? fKnee,
  double hipY = 0.88,
  Offset nElbow = _down,
}) =>
    Pose(
      hip: _o(0.70, hipY),
      shoulder: shoulder,
      nh: nh ?? _o(shoulder.dx + 0.2, 0.8),
      fh: fh ?? nh ?? _o(shoulder.dx + 0.2, 0.8),
      nf: nf,
      ff: ff ?? nf,
      nKnee: nKnee,
      fKnee: fKnee,
      nElbow: nElbow,
    );

// Props.
const _bedBehind = DemoProp.box(Rect.fromLTWH(0.30, 0.70, 0.30, 0.25));
const _chairBehind = DemoProp.box(Rect.fromLTWH(0.40, 0.66, 0.26, 0.29));
const _bedFront = DemoProp.box(Rect.fromLTWH(1.05, 0.62, 0.42, 0.33));
const _stepBox = DemoProp.box(Rect.fromLTWH(0.86, 0.78, 0.36, 0.17));
const _feetBox = DemoProp.box(Rect.fromLTWH(0.10, 0.70, 0.34, 0.25));
const _sofaBehind = DemoProp.box(Rect.fromLTWH(0.18, 0.66, 0.32, 0.29));
const _dipChair = DemoProp.box(Rect.fromLTWH(0.44, 0.62, 0.36, 0.33));
const _towelFloor = DemoProp.towel(Rect.fromLTWH(0.85, 0.935, 0.42, 0.02));

final Map<String, Demo> kDemos = {
  // ─────────────── lower body ───────────────
  'squat': Demo([
    _stand(0.78, nh: _o(1.08, 0.19), fh: _o(1.08, 0.2), nElbow: _down),
    _stand(0.60, hipY: 0.70, lean: 0.18, nh: _o(1.06, 0.42), fh: _o(1.06, 0.43), nf: _o(0.80, _a), ff: _o(0.76, _a), nElbow: _down),
  ]),
  'sit_to_stand': Demo([
    _stand(0.74, nh: _o(1.04, 0.2), fh: _o(1.04, 0.21), nElbow: _down),
    _stand(0.58, hipY: 0.66, lean: 0.17, nh: _o(1.02, 0.40), fh: _o(1.02, 0.41), nf: _o(0.80, _a), ff: _o(0.76, _a), nElbow: _down),
  ], props: const [_chairBehind]),
  'deep_squat': Demo([
    _stand(0.60, hipY: 0.80, lean: 0.12, nh: _o(0.90, 0.60), fh: _o(0.90, 0.61), nf: _o(0.84, _a), ff: _o(0.82, _a), nElbow: _down),
    _stand(0.60, hipY: 0.78, lean: 0.10, nh: _o(0.90, 0.58), fh: _o(0.90, 0.59), nf: _o(0.84, _a), ff: _o(0.82, _a), nElbow: _down),
  ], stepMs: 1600),
  'wall_sit': Demo([
    _stand(0.50, hipY: 0.70, nh: _o(0.66, 0.66), fh: _o(0.64, 0.67), nf: _o(0.74, _a), ff: _o(0.72, _a), nElbow: _down),
    _stand(0.50, hipY: 0.69, nh: _o(0.66, 0.65), fh: _o(0.64, 0.66), nf: _o(0.74, _a), ff: _o(0.72, _a), nElbow: _down),
  ], wallX: 0.40, stepMs: 1500),
  'calf_raise': Demo([
    _stand(0.80),
    _stand(0.80, hipY: 0.42, nf: _o(0.83, 0.88), ff: _o(0.77, 0.88)),
  ], stepMs: 800),
  'split_squat': Demo([
    _stand(0.80, nh: _o(0.86, 0.47), fh: _o(0.84, 0.47), nf: _o(1.00, _a), ff: _o(0.56, 0.90), fKnee: _down),
    _stand(0.78, hipY: 0.66, nh: _o(0.84, 0.66), fh: _o(0.82, 0.66), nf: _o(1.00, _a), ff: _o(0.56, 0.90), fKnee: _down),
  ]),
  'lunge': Demo([
    _stand(0.80),
    _stand(0.74, hipY: 0.66, nh: _o(0.80, 0.66), fh: _o(0.78, 0.66), nf: _o(0.96, _a), ff: _o(0.46, 0.90), fKnee: _down),
  ]),
  'bulgarian': Demo([
    _stand(0.84, lean: 0.06, nh: _o(0.90, 0.47), fh: _o(0.88, 0.47), nf: _o(1.04, _a), ff: _o(0.48, 0.69), fKnee: _down),
    _stand(0.80, hipY: 0.68, lean: 0.10, nh: _o(0.88, 0.66), fh: _o(0.86, 0.66), nf: _o(1.04, _a), ff: _o(0.48, 0.69), fKnee: _down),
  ], props: const [_bedBehind]),
  'lateral_lunge': Demo([
    _stand(0.80, nf: _o(1.02, _a), ff: _o(0.58, _a), nh: _o(0.84, 0.30), fh: _o(0.76, 0.30), nElbow: _down, nKnee: _fwd, fKnee: _back),
    _stand(0.64, hipY: 0.66, lean: -0.02, nf: _o(1.02, _a), ff: _o(0.52, _a), nh: _o(0.72, 0.46), fh: _o(0.64, 0.46), nElbow: _down, nKnee: _fwd, fKnee: _back),
  ], front: true),
  'pistol': Demo([
    _stand(0.80, nh: _o(1.10, 0.19), fh: _o(1.10, 0.2), ff: _o(1.08, 0.74), nElbow: _down),
    _stand(0.66, hipY: 0.78, lean: 0.20, nh: _o(1.14, 0.45), fh: _o(1.14, 0.46), nf: _o(0.80, _a), ff: _o(1.12, 0.80), nElbow: _down),
  ], stepMs: 1100),
  'step_up': Demo([
    _stand(0.74, hipY: 0.52, lean: 0.05, nf: _o(0.96, 0.76), ff: _o(0.70, _a)),
    _stand(0.98, hipY: 0.30, nf: _o(0.98, 0.76), ff: _o(1.00, 0.68), fKnee: _fwd),
  ], props: const [_stepBox]),
  'good_morning': Demo([
    _stand(0.80, nh: _o(0.78, 0.10), fh: _o(0.78, 0.10), nElbow: _o(1, -1)),
    _stand(0.76, lean: 0.29, nh: _o(1.10, 0.36), fh: _o(1.10, 0.36), nElbow: _o(0, -1)).withShoulder(_o(1.05, 0.43)),
  ]),
  'single_leg_rdl': Demo([
    _stand(0.80),
    Pose(
        hip: _o(0.80, 0.47),
        shoulder: _o(1.10, 0.45),
        nh: _o(1.10, 0.76),
        fh: _o(1.08, 0.76),
        nf: _o(0.82, _a),
        ff: _o(0.35, 0.40),
        nElbow: _back,
        fKnee: _down),
  ], stepMs: 1100),
  'kickback': Demo([
    _stand(0.80, lean: 0.14, nh: _o(1.20, 0.30), fh: _o(1.20, 0.31), nElbow: _down),
    _stand(0.80, lean: 0.16, nh: _o(1.20, 0.30), fh: _o(1.20, 0.31), ff: _o(0.40, 0.70), fKnee: _down, nElbow: _down),
  ], wallX: 1.22),
  'glute_bridge': Demo([
    _supine(nf: _o(0.96, _a)),
    _supine(hipY: 0.70, shoulder: _o(0.44, 0.87), nf: _o(0.96, _a)),
  ]),
  'hip_thrust': Demo([
    Pose(hip: _o(0.62, 0.88), shoulder: _o(0.40, 0.70), nh: _o(0.56, 0.74), fh: _o(0.56, 0.74), nf: _o(0.96, _a), ff: _o(0.96, _a), nKnee: _up),
    Pose(hip: _o(0.72, 0.68), shoulder: _o(0.43, 0.70), nh: _o(0.60, 0.66), fh: _o(0.60, 0.66), nf: _o(0.96, _a), ff: _o(0.96, _a), nKnee: _up),
  ], props: const [_sofaBehind]),
  'leg_curl': Demo([
    _supine(hipY: 0.80, nf: _o(1.18, _a)),
    _supine(hipY: 0.70, nf: _o(0.96, _a)),
  ], props: const [_towelFloor]),

  // ─────────────── push ───────────────
  'wall_push_up': Demo([
    Pose(hip: _o(0.86, 0.49), shoulder: _o(1.00, 0.22), nh: _o(1.24, 0.24), fh: _o(1.24, 0.25), nf: _o(0.70, _a), ff: _o(0.68, _a), nElbow: _down),
    Pose(hip: _o(0.93, 0.50), shoulder: _o(1.10, 0.25), nh: _o(1.24, 0.24), fh: _o(1.24, 0.25), nf: _o(0.70, _a), ff: _o(0.68, _a), nElbow: _o(-0.3, 1)),
  ], wallX: 1.26),
  'incline_push_up': Demo([
    _plank(hip: _o(0.72, 0.62), shoulder: _o(1.08, 0.30), hands: _o(1.12, 0.60), feet: _o(0.40, 0.92)),
    _plank(hip: _o(0.74, 0.70), shoulder: _o(1.10, 0.46), hands: _o(1.12, 0.60), feet: _o(0.40, 0.92)),
  ], props: const [_bedFront]),
  'knee_push_up': Demo([
    _plank(hip: _o(0.78, 0.72), shoulder: _o(1.10, 0.62), feet: _o(0.40, 0.80), nKnee: _down),
    _plank(hip: _o(0.78, 0.84), shoulder: _o(1.08, 0.82), feet: _o(0.40, 0.80), nKnee: _down),
  ]),
  'push_up': Demo([
    _plank(hip: _o(0.74, 0.72), shoulder: _o(1.12, 0.62)),
    _plank(hip: _o(0.73, 0.85), shoulder: _o(1.10, 0.82)),
  ]),
  'decline_push_up': Demo([
    _plank(hip: _o(0.78, 0.63), shoulder: _o(1.15, 0.62), hands: _o(1.16, 0.93), feet: _o(0.38, 0.68)),
    _plank(hip: _o(0.77, 0.72), shoulder: _o(1.13, 0.84), hands: _o(1.16, 0.93), feet: _o(0.38, 0.68)),
  ], props: const [_feetBox]),
  'pike_push_up': Demo([
    _plank(hip: _o(0.76, 0.46), shoulder: _o(0.99, 0.66), hands: _o(1.06, 0.93), feet: _o(0.56, 0.92), nElbow: _back),
    _plank(hip: _o(0.78, 0.56), shoulder: _o(1.01, 0.80), hands: _o(1.06, 0.93), feet: _o(0.56, 0.92), nElbow: _o(-1, -1)),
  ]),
  'dip': Demo([
    Pose(hip: _o(0.86, 0.64), shoulder: _o(0.83, 0.34), nh: _o(0.78, 0.62), fh: _o(0.78, 0.62), nf: _o(1.28, _a), ff: _o(1.28, _a), nElbow: _back, nKnee: _up),
    Pose(hip: _o(0.88, 0.78), shoulder: _o(0.85, 0.48), nh: _o(0.78, 0.62), fh: _o(0.78, 0.62), nf: _o(1.28, _a), ff: _o(1.28, _a), nElbow: _o(-1, -0.2), nKnee: _up),
  ], props: const [_dipChair]),
  'plank_tap': Demo([
    _plank(hip: _o(0.74, 0.72), shoulder: _o(1.12, 0.62), nElbow: _back),
    _plank(hip: _o(0.74, 0.72), shoulder: _o(1.12, 0.62), hands: _o(1.06, 0.60), fh: _o(1.12, 0.93), nElbow: _down),
  ], stepMs: 600),

  // ─────────────── pull / back ───────────────
  'towel_row': Demo([
    _seated(nh: _o(1.02, 0.74), nElbow: _down, nKnee: _up),
    _seated(shoulder: _o(0.68, 0.56), nh: _o(0.80, 0.70), nElbow: _o(-1, 0.2)),
  ], props: const [], stepMs: 1000),
  'prone_raise': Demo([
    _prone(),
    _prone(lift: 0.04, armLift: 0.12),
  ]),
  'superman': Demo([
    _prone(),
    _prone(lift: 0.07, armLift: 0.20, legLift: 0.10),
  ], stepMs: 1200),
  'floor_pull': Demo([
    _prone(hands: _o(1.36, 0.93)),
    _prone(hands: _o(1.10, 0.93)),
  ], props: const [DemoProp.towel(Rect.fromLTWH(0.40, 0.935, 0.70, 0.02))]),
  'wall_angel': Demo([
    _stand(0.80, nh: _o(0.98, 0.14), fh: _o(0.62, 0.14), nElbow: _fwd, fElbow: _back),
    _stand(0.80, nh: _o(0.92, -0.05), fh: _o(0.68, -0.05), nElbow: _fwd, fElbow: _back),
  ], front: true, stepMs: 1100),

  // ─────────────── core ───────────────
  'dead_bug': Demo([
    _supine(hipY: 0.88, nh: _o(0.44, 0.56), fh: _o(0.44, 0.56), nf: _o(0.96, 0.64), nKnee: _up),
    _supine(hipY: 0.88, nh: _o(0.12, 0.84), fh: _o(0.44, 0.56), nf: _o(0.96, 0.64), ff: _o(1.18, 0.82), nKnee: _up),
  ]),
  'plank': Demo([
    _plank(hip: _o(0.72, 0.79), shoulder: _o(1.02, 0.72), hands: _o(1.16, 0.93), nElbow: _o(-0.4, 1)),
    _plank(hip: _o(0.72, 0.78), shoulder: _o(1.02, 0.71), hands: _o(1.16, 0.93), nElbow: _o(-0.4, 1)),
  ], stepMs: 1600),
  'side_plank': Demo([
    Pose(hip: _o(0.72, 0.72), shoulder: _o(1.00, 0.56), nh: _o(1.10, 0.93), fh: _o(1.00, 0.24), nf: _o(0.34, _a), ff: _o(0.34, 0.91), nElbow: _o(-0.3, 1), fElbow: _up),
    Pose(hip: _o(0.72, 0.80), shoulder: _o(1.00, 0.58), nh: _o(1.10, 0.93), fh: _o(1.00, 0.26), nf: _o(0.34, _a), ff: _o(0.34, 0.91), nElbow: _o(-0.3, 1), fElbow: _up),
  ], front: true, stepMs: 1300),
  'hollow_hold': Demo([
    _supine(shoulder: _o(0.44, 0.83), nh: _o(0.12, 0.74), nf: _o(1.20, 0.80), nKnee: _up, nElbow: _up),
    _supine(shoulder: _o(0.44, 0.82), nh: _o(0.12, 0.73), nf: _o(1.20, 0.79), nKnee: _up, nElbow: _up),
  ], stepMs: 1600),
  'hollow_rock': Demo([
    _supine(shoulder: _o(0.44, 0.78), nh: _o(0.12, 0.66), nf: _o(1.18, 0.88), nKnee: _up, nElbow: _up),
    _supine(shoulder: _o(0.44, 0.88), nh: _o(0.12, 0.84), nf: _o(1.20, 0.72), nKnee: _up, nElbow: _up),
  ], stepMs: 700),
  'v_up': Demo([
    _supine(shoulder: _o(0.44, 0.86), nh: _o(0.12, 0.84), nf: _o(1.20, 0.88), nKnee: _up, nElbow: _up),
    _supine(hipY: 0.90, shoulder: _o(0.58, 0.64), nh: _o(0.94, 0.44), nf: _o(1.04, 0.50), nKnee: _up, nElbow: _down, headTilt: 15),
  ]),
  'l_sit': Demo([
    _seated(hipY: 0.90, nh: _o(0.72, _a), nf: _o(0.98, 0.86), nElbow: _back),
    _seated(hipY: 0.82, shoulder: _o(0.72, 0.52), nh: _o(0.72, _a), nf: _o(0.98, 0.78), nElbow: _back),
  ], stepMs: 1200),
  'crunch': Demo([
    _supine(nh: _o(0.36, 0.84), nf: _o(0.98, _a), nElbow: _up),
    _supine(shoulder: _o(0.50, 0.74), nh: _o(0.44, 0.66), nf: _o(0.98, _a), nElbow: _up, headTilt: 10),
  ], stepMs: 700),
  'leg_raise': Demo([
    _supine(nf: _o(1.20, 0.91), nKnee: _up),
    _supine(nf: _o(0.80, 0.44), nKnee: _fwd),
  ], stepMs: 1100),
  'bird_dog': Demo([
    _quad(),
    _quad(nh: _o(1.30, 0.58), ff: _o(0.22, 0.60)),
  ], stepMs: 1100),
  'cat_cow': Demo([
    _quad(curve: -0.06, headTilt: -25),
    _quad(curve: 0.08, headTilt: 35),
  ], stepMs: 1500),
  'childs_pose': Demo([
    Pose(hip: _o(0.52, 0.80), shoulder: _o(0.82, 0.84), nh: _o(1.16, _a), fh: _o(1.16, _a), nf: _o(0.38, _a), ff: _o(0.38, _a), nElbow: _up, nKnee: _o(1, 1), headTilt: 20),
    Pose(hip: _o(0.52, 0.79), shoulder: _o(0.82, 0.82), nh: _o(1.17, _a), fh: _o(1.17, _a), nf: _o(0.38, _a), ff: _o(0.38, _a), nElbow: _up, nKnee: _o(1, 1), headTilt: 20),
  ], stepMs: 1800),
  'bear_crawl': Demo([
    _quad(hipY: 0.60, kneeY: 0.90),
    _quad(hipY: 0.60, kneeY: 0.90, nh: _o(1.12, _a), ff: _o(0.50, 0.90)),
  ], stepMs: 600),

  // ─────────────── conditioning ───────────────
  'march': Demo([
    _stand(0.80, nh: _o(0.70, 0.40), fh: _o(0.98, 0.34), nElbow: _back),
    _stand(0.80, nf: _o(0.92, 0.66), nh: _o(0.98, 0.32), fh: _o(0.70, 0.42), nKnee: _o(1, 0.3), nElbow: _down),
    _stand(0.80, nh: _o(0.70, 0.40), fh: _o(0.98, 0.34), nElbow: _back),
    _stand(0.80, ff: _o(0.92, 0.66), fh: _o(0.98, 0.32), nh: _o(0.70, 0.42), fKnee: _o(1, 0.3), nElbow: _down),
  ], pingPong: false, stepMs: 380),
  'jack': Demo([
    _stand(0.80, nf: _o(0.84, _a), ff: _o(0.76, _a), nh: _o(0.86, 0.46), fh: _o(0.74, 0.46), nElbow: _fwd, fElbow: _back),
    _stand(0.80, hipY: 0.49, nf: _o(1.02, _a), ff: _o(0.58, _a), nh: _o(0.98, -0.08), fh: _o(0.62, -0.08), nElbow: _fwd, fElbow: _back),
  ], front: true, stepMs: 450),
  'shadow_box': Demo([
    _stand(0.78, nf: _o(0.92, _a), ff: _o(0.64, _a), nh: _o(0.96, 0.20), fh: _o(0.92, 0.22), nElbow: _down),
    _stand(0.80, lean: 0.03, nf: _o(0.92, _a), ff: _o(0.64, _a), nh: _o(1.28, 0.19), fh: _o(0.92, 0.22), nElbow: _down),
    _stand(0.78, nf: _o(0.92, _a), ff: _o(0.64, _a), nh: _o(0.96, 0.20), fh: _o(0.92, 0.22), nElbow: _down),
    _stand(0.80, lean: 0.03, nf: _o(0.92, _a), ff: _o(0.64, _a), nh: _o(0.96, 0.20), fh: _o(1.26, 0.20), nElbow: _down),
  ], pingPong: false, stepMs: 320),
  'skater': Demo([
    _stand(0.64, hipY: 0.58, lean: 0.06, nf: _o(0.66, _a), ff: _o(0.90, 0.86), nh: _o(0.86, 0.40), fh: _o(0.50, 0.30), nKnee: _back, fKnee: _down),
    _stand(0.96, hipY: 0.58, lean: -0.06, nf: _o(0.70, 0.86), ff: _o(0.94, _a), nh: _o(1.10, 0.30), fh: _o(0.74, 0.40), nKnee: _down, fKnee: _fwd),
  ], front: true, stepMs: 600),
  'mountain_climber': Demo([
    _plank(hip: _o(0.72, 0.68), shoulder: _o(1.10, 0.62), hands: _o(1.12, 0.93), feet: _o(0.36, 0.92), ff: _o(0.90, 0.84), fKnee: _fwd),
    _plank(hip: _o(0.72, 0.68), shoulder: _o(1.10, 0.62), hands: _o(1.12, 0.93), feet: _o(0.90, 0.84), ff: _o(0.36, 0.92), nKnee: _fwd, fKnee: _down),
  ], stepMs: 330),
  'burpee': Demo([
    _stand(0.80, nh: _o(0.86, -0.08), fh: _o(0.84, -0.08), hipY: 0.44, nElbow: _fwd),
    _stand(0.70, hipY: 0.72, lean: 0.24, nh: _o(1.08, _a), fh: _o(1.06, _a), nf: _o(0.84, _a), ff: _o(0.80, _a), nElbow: _back),
    _plank(hip: _o(0.74, 0.72), shoulder: _o(1.08, 0.62), hands: _o(1.08, 0.93)),
    _stand(0.70, hipY: 0.72, lean: 0.24, nh: _o(1.08, _a), fh: _o(1.06, _a), nf: _o(0.84, _a), ff: _o(0.80, _a), nElbow: _back),
  ], pingPong: false, stepMs: 520),
  'squat_jump': Demo([
    _stand(0.66, hipY: 0.70, lean: 0.16, nh: _o(0.72, 0.62), fh: _o(0.70, 0.62), nf: _o(0.84, _a), ff: _o(0.80, _a)),
    _stand(0.80, hipY: 0.34, nf: _o(0.83, 0.80), ff: _o(0.77, 0.80), nh: _o(0.88, -0.08), fh: _o(0.86, -0.08), nElbow: _fwd),
  ], stepMs: 480),

  // ─────────────── mobility ───────────────
  'arm_circles': Demo([
    _stand(0.80, nh: _o(1.10, 0.16), fh: _o(0.50, 0.16), nElbow: _down, fElbow: _down),
    _stand(0.80, nh: _o(1.10, 0.10), fh: _o(0.50, 0.10), nElbow: _down, fElbow: _down),
    _stand(0.80, nh: _o(1.06, 0.14), fh: _o(0.54, 0.14), nElbow: _down, fElbow: _down),
    _stand(0.80, nh: _o(1.10, 0.20), fh: _o(0.50, 0.20), nElbow: _down, fElbow: _down),
  ], front: true, pingPong: false, stepMs: 260),
  'leg_swing': Demo([
    _stand(0.80, nf: _o(1.12, 0.70), nKnee: _up),
    _stand(0.80, nf: _o(0.52, 0.76), nKnee: _down),
  ], stepMs: 650),
  'hip_circles': Demo([
    _stand(0.80, nf: _o(0.92, _a), ff: _o(0.68, _a), nh: _o(0.90, 0.46), fh: _o(0.70, 0.46), nElbow: _fwd, fElbow: _back),
    _stand(0.86, lean: -0.03, nf: _o(0.92, _a), ff: _o(0.68, _a), nh: _o(0.96, 0.46), fh: _o(0.76, 0.46), nElbow: _fwd, fElbow: _back),
    _stand(0.80, hipY: 0.49, nf: _o(0.92, _a), ff: _o(0.68, _a), nh: _o(0.90, 0.48), fh: _o(0.70, 0.48), nElbow: _fwd, fElbow: _back),
    _stand(0.74, lean: 0.03, nf: _o(0.92, _a), ff: _o(0.68, _a), nh: _o(0.84, 0.46), fh: _o(0.64, 0.46), nElbow: _fwd, fElbow: _back),
  ], front: true, pingPong: false, stepMs: 550),
  'stretch_lunge': Demo([
    _stand(0.74, hipY: 0.70, nf: _o(1.00, _a), ff: _o(0.30, 0.90), nh: _o(1.00, 0.84), fh: _o(0.96, 0.84), fKnee: _down, nElbow: _back),
    _stand(0.76, hipY: 0.72, lean: 0.06, nf: _o(1.00, _a), ff: _o(0.30, 0.90), nh: _o(0.86, 0.10), fh: _o(0.98, 0.86), fKnee: _down, nElbow: _back),
  ], stepMs: 1400),
  'quad_stretch': Demo([
    _stand(0.80, ff: _o(0.62, 0.52), fh: _o(0.62, 0.52), fKnee: _down, nh: _o(1.02, 0.20), nElbow: _down),
    _stand(0.80, ff: _o(0.60, 0.50), fh: _o(0.60, 0.50), fKnee: _down, nh: _o(1.02, 0.18), nElbow: _down),
  ], stepMs: 1500),
  'open_book': Demo([
    _supine(nh: _o(0.44, 0.56), fh: _o(0.44, 0.56), nf: _o(0.94, 0.82), nKnee: _up, nElbow: _up),
    _supine(nh: _o(0.14, 0.88), fh: _o(0.44, 0.56), nf: _o(0.94, 0.82), nKnee: _up, nElbow: _up),
  ], stepMs: 1400),
  'hip_90_90': Demo([
    _seated(nf: _o(0.98, 0.91), ff: _o(0.46, 0.91), nKnee: _o(0.4, -1), fKnee: _o(-0.4, -1), nh: _o(0.60, 0.88), fh: _o(0.62, 0.88)),
    _seated(nf: _o(0.46, 0.91), ff: _o(0.98, 0.91), nKnee: _o(-0.4, -1), fKnee: _o(0.4, -1), nh: _o(0.60, 0.88), fh: _o(0.62, 0.88)),
  ], stepMs: 1300),
  'breathing': Demo([
    _seated(nf: _o(0.96, 0.91), ff: _o(0.52, 0.91), nKnee: _o(1, -1), fKnee: _o(-1, -1), nh: _o(0.90, 0.78), fh: _o(0.56, 0.78)),
    _seated(shoulder: _o(0.72, 0.53), nf: _o(0.96, 0.91), ff: _o(0.52, 0.91), nKnee: _o(1, -1), fKnee: _o(-1, -1), nh: _o(0.90, 0.76), fh: _o(0.56, 0.76)),
  ], stepMs: 2000),
};

extension on Pose {
  Pose withShoulder(Offset s) => Pose(
        hip: hip,
        shoulder: s,
        nh: nh,
        fh: fh,
        nf: nf,
        ff: ff,
        nElbow: nElbow,
        fElbow: fElbow,
        nKnee: nKnee,
        fKnee: fKnee,
        headTilt: headTilt,
        curve: curve,
      );
}

/// Demo for an exercise's `demo` key (falls back to a gentle stand).
Demo demoFor(String key) => kDemos[key] ?? Demo([_stand(0.8), _stand(0.8, hipY: 0.46)], stepMs: 1500);
