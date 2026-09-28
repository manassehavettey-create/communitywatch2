import '../models/enums.dart';

/// A node in a progression path. [alternatives] are same-level substitutes
/// used when the main exercise isn't possible in the current environment or
/// with the user's limitations.
class SkillNode {
  const SkillNode(this.exerciseId, {this.alternatives = const [], this.milestone = false});
  final String exerciseId;
  final List<String> alternatives;

  /// Highlighted on the tree as a named milestone.
  final bool milestone;
}

class SkillPath {
  const SkillPath({
    required this.id,
    required this.name,
    required this.area,
    required this.focus,
    required this.nodes,
    required this.repRange,
    required this.holdRange,
    required this.goalLabel,
  });

  final String id;
  final String name;
  final Area area;
  final Set<MuscleFocus> focus;
  final List<SkillNode> nodes;

  /// Rep window used for rep-based nodes on this path (min, max).
  final (int, int) repRange;

  /// Seconds window used for timed nodes on this path (min, max).
  final (int, int) holdRange;

  /// The "Advanced Goal" shown on the tree.
  final String goalLabel;

  int get length => nodes.length;
  SkillNode node(int index) => nodes[index.clamp(0, nodes.length - 1)];
  int indexOf(String exerciseId) =>
      nodes.indexWhere((n) => n.exerciseId == exerciseId || n.alternatives.contains(exerciseId));
}

abstract final class PathIds {
  static const push = 'push';
  static const legs = 'legs';
  static const core = 'core';
  static const back = 'back';
  static const hips = 'hips';
  static const conditioning = 'conditioning';
  static const all = [push, legs, core, back, hips, conditioning];
}

const List<SkillPath> kSkillPaths = [
  SkillPath(
    id: PathIds.push,
    name: 'Push-up Path',
    area: Area.upper,
    focus: {MuscleFocus.chest, MuscleFocus.arms, MuscleFocus.shoulders},
    repRange: (6, 15),
    holdRange: (15, 45),
    goalLabel: 'One-arm Push-up',
    nodes: [
      SkillNode('wall_push_up', alternatives: ['incline_push_up']),
      SkillNode('incline_push_up', alternatives: ['knee_push_up']),
      SkillNode('knee_push_up', alternatives: ['incline_push_up']),
      SkillNode('push_up', milestone: true, alternatives: ['incline_push_up']),
      SkillNode('diamond_push_up'),
      SkillNode('decline_push_up', alternatives: ['pike_push_up']),
      SkillNode('archer_push_up', milestone: true),
      SkillNode('incline_one_arm_push_up', alternatives: ['pseudo_planche_push_up']),
      SkillNode('one_arm_push_up', milestone: true),
    ],
  ),
  SkillPath(
    id: PathIds.legs,
    name: 'Leg Path',
    area: Area.legs,
    focus: {MuscleFocus.legs},
    repRange: (8, 20),
    holdRange: (20, 60),
    goalLabel: 'Pistol Squat',
    nodes: [
      SkillNode('sit_to_stand', alternatives: ['quarter_squat']),
      SkillNode('bodyweight_squat', milestone: true, alternatives: ['sit_to_stand']),
      SkillNode('pause_squat'),
      SkillNode('split_squat', milestone: true, alternatives: ['pause_squat']),
      SkillNode('tempo_split_squat', alternatives: ['pause_squat']),
      SkillNode('bulgarian_split_squat', milestone: true, alternatives: ['tempo_split_squat']),
      SkillNode('skater_squat', alternatives: ['bulgarian_split_squat', 'tempo_split_squat']),
      SkillNode('assisted_pistol_squat', alternatives: ['box_pistol_squat', 'skater_squat']),
      SkillNode('box_pistol_squat', alternatives: ['assisted_pistol_squat']),
      SkillNode('pistol_squat', milestone: true),
    ],
  ),
  SkillPath(
    id: PathIds.core,
    name: 'Core Path',
    area: Area.core,
    focus: {MuscleFocus.core},
    repRange: (8, 15),
    holdRange: (20, 90),
    goalLabel: 'Tuck L-sit',
    nodes: [
      SkillNode('dead_bug', alternatives: ['standing_knee_to_elbow']),
      SkillNode('plank', milestone: true, alternatives: ['wall_plank']),
      SkillNode('long_lever_plank', alternatives: ['wall_plank']),
      SkillNode('side_plank', milestone: true, alternatives: ['standing_side_crunch']),
      SkillNode('hollow_body_hold', milestone: true),
      SkillNode('hollow_body_rock'),
      SkillNode('v_up'),
      SkillNode('tuck_l_sit', milestone: true, alternatives: ['v_up']),
    ],
  ),
  SkillPath(
    id: PathIds.back,
    name: 'Back Path',
    area: Area.upper,
    focus: {MuscleFocus.back, MuscleFocus.shoulders},
    repRange: (8, 15),
    holdRange: (15, 45),
    goalLabel: 'Arch Body Rock',
    nodes: [
      SkillNode('prone_y_raise', alternatives: ['wall_angel']),
      SkillNode('prone_ytw', alternatives: ['towel_pull_apart']),
      SkillNode('superman_hold', milestone: true, alternatives: ['bent_over_ytw']),
      SkillNode('reverse_snow_angel', alternatives: ['towel_row_hold']),
      SkillNode('prone_swimmer', alternatives: ['towel_row_hold']),
      SkillNode('towel_floor_pull', milestone: true, alternatives: ['prone_swimmer']),
      SkillNode('arch_body_hold'),
      SkillNode('arch_body_rock', milestone: true),
    ],
  ),
  SkillPath(
    id: PathIds.hips,
    name: 'Hip Path',
    area: Area.legs,
    focus: {MuscleFocus.legs},
    repRange: (8, 20),
    holdRange: (20, 45),
    goalLabel: 'Single-leg Towel Curl',
    nodes: [
      SkillNode('glute_bridge', alternatives: ['standing_glute_kickback']),
      SkillNode('glute_bridge_march', alternatives: ['good_morning']),
      SkillNode('b_stance_glute_bridge', alternatives: ['good_morning']),
      SkillNode('single_leg_glute_bridge', milestone: true, alternatives: ['single_leg_rdl']),
      SkillNode('hip_thrust', alternatives: ['single_leg_glute_bridge']),
      SkillNode('single_leg_rdl', milestone: true),
      SkillNode('single_leg_hip_thrust', alternatives: ['single_leg_rdl']),
      SkillNode('hamstring_walkout', alternatives: ['single_leg_rdl']),
      SkillNode('towel_leg_curl', milestone: true, alternatives: ['hamstring_walkout']),
      SkillNode('single_leg_towel_curl', milestone: true),
    ],
  ),
  SkillPath(
    id: PathIds.conditioning,
    name: 'Conditioning Path',
    area: Area.conditioning,
    focus: {MuscleFocus.fullBody},
    repRange: (6, 15),
    holdRange: (20, 50),
    goalLabel: 'Burpee Tuck Jump',
    nodes: [
      SkillNode('march_in_place'),
      SkillNode('step_jack'),
      SkillNode('shadow_boxing', alternatives: ['step_jack']),
      SkillNode('mountain_climber', milestone: true, alternatives: ['speed_squat']),
      SkillNode('jumping_jack', alternatives: ['low_impact_skater', 'shadow_boxing']),
      SkillNode('step_back_burpee', alternatives: ['speed_squat']),
      SkillNode('burpee_no_push_up', milestone: true, alternatives: ['step_back_burpee', 'speed_squat']),
      SkillNode('burpee', alternatives: ['step_back_burpee', 'speed_squat']),
      SkillNode('burpee_tuck_jump', milestone: true, alternatives: ['burpee', 'step_back_burpee', 'speed_squat']),
    ],
  ),
];

final Map<String, SkillPath> kPathById = {for (final p in kSkillPaths) p.id: p};

SkillPath pathById(String id) => kPathById[id] ?? (throw ArgumentError('Unknown path $id'));
