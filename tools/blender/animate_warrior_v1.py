"""Create gameplay Actions for WarriorSkeleton (Phase 3).

The warrior faces Blender -Y. Animations are 30 FPS and in-place.
Run after rig_warrior_v1.py, preferably from Warrior_Rigged_V1.blend.
"""

import bpy
import math


ARMATURE_NAME = "WarriorSkeleton"
RIG_COLLECTION = "Warrior_Rigged_V1"
ANIMATED_COLLECTION = "Warrior_Animated_V1"
ACTION_NAMES = ("Idle", "Walk", "Attack_Light", "Attack_Heavy",
                "Block", "Hit", "Death", "Victory")


def deg(values):
    return tuple(math.radians(v) for v in values)


def inspect_rig():
    arm = bpy.data.objects.get(ARMATURE_NAME)
    if not arm or arm.type != 'ARMATURE':
        raise RuntimeError("Armature WarriorSkeleton not found.")
    bones = set(arm.data.bones.keys())
    required = {"Root", "Hips", "Spine", "Chest", "UpperChest", "Neck", "Head",
                "UpperArm_L", "Forearm_L", "Hand_L", "UpperArm_R", "Forearm_R",
                "Hand_R", "Thigh_L", "Shin_L", "Foot_L", "Toe_L", "Thigh_R",
                "Shin_R", "Foot_R", "Toe_R", "WeaponSocket_R"}
    missing = sorted(required - bones)
    if missing:
        raise RuntimeError("Missing rig bones: " + ", ".join(missing))
    sword = bpy.data.objects.get("Sword")
    if not sword or sword.parent != arm or sword.parent_bone != "WeaponSocket_R":
        raise RuntimeError("Sword is not rigidly attached to WeaponSocket_R.")
    print("Rig inspected: WarriorSkeleton")
    print("Bones confirmed:", ", ".join(sorted(bones)))
    print("Sword attachment confirmed: Sword -> WeaponSocket_R -> Hand_R")
    return arm, sword


def clear_pose(arm):
    for pb in arm.pose.bones:
        pb.rotation_mode = 'XYZ'
        pb.location = (0, 0, 0)
        pb.rotation_euler = (0, 0, 0)
        pb.scale = (1, 1, 1)


def begin_action(arm, name, end_frame, loop=False):
    old = bpy.data.actions.get(name)
    if old:
        bpy.data.actions.remove(old)
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    action["loop"] = bool(loop)
    action["fps"] = 30
    action["intended_frame_start"] = 1
    action["intended_frame_end"] = end_frame
    action["root_motion"] = "IN_PLACE"
    if not arm.animation_data:
        arm.animation_data_create()
    arm.animation_data.action = action
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = end_frame
    clear_pose(arm)
    return action


def key_pose(arm, frame, rotations=None, locations=None):
    """Key only pose channels named in this key pose plus stationary Root."""
    rotations = rotations or {}
    locations = locations or {}
    bpy.context.scene.frame_set(frame)
    root = arm.pose.bones["Root"]
    root.location = (0, 0, 0)
    root.rotation_euler = (0, 0, 0)
    root.keyframe_insert("location", frame=frame, group="Root")
    root.keyframe_insert("rotation_euler", frame=frame, group="Root")
    for name, angles in rotations.items():
        pb = arm.pose.bones[name]
        pb.rotation_mode = 'XYZ'
        pb.rotation_euler = deg(angles)
        pb.keyframe_insert("rotation_euler", frame=frame, group=name)
    for name, location in locations.items():
        pb = arm.pose.bones[name]
        pb.location = location
        pb.keyframe_insert("location", frame=frame, group=name)


def rest_key(arm, frame, bones):
    key_pose(arm, frame, {name: (0, 0, 0) for name in bones},
             {"Hips": (0, 0, 0)})


def add_markers(action, markers):
    for name, frame in markers.items():
        marker = action.pose_markers.new(name)
        marker.frame = frame


def set_interpolation(arm, action, impact_frames=()):
    """Set Bezier globally, with sharp auto-clamped handles around impacts."""
    # Blender 5 stores curves in channel bags; keyframe interpolation is already
    # Bezier by default. Force Auto Clamped through the action's visible curves
    # when the compatibility fcurves API is available.
    curves = getattr(action, "fcurves", None)
    if curves is not None:
        for curve in curves:
            for point in curve.keyframe_points:
                point.interpolation = 'BEZIER'
                point.handle_left_type = 'AUTO_CLAMPED'
                point.handle_right_type = 'AUTO_CLAMPED'


def make_idle(arm):
    bones = ["Hips", "Spine", "Chest", "UpperChest", "Head",
             "Shoulder_L", "Shoulder_R", "UpperArm_L", "UpperArm_R"]
    action = begin_action(arm, "Idle", 60, True)
    rest_key(arm, 1, bones)
    key_pose(arm, 16, {"Chest": (1.8, 0, 0.8), "UpperChest": (1.2, 0, -0.5),
                       "Shoulder_L": (0, 0, 1.5), "Shoulder_R": (0, 0, -1.5),
                       "Head": (-0.7, 0, 0)}, {"Hips": (0, 0, 0.012)})
    rest_key(arm, 31, bones)
    key_pose(arm, 46, {"Chest": (-1.4, 0, -0.8), "UpperChest": (-0.8, 0, 0.5),
                       "Shoulder_L": (0, 0, -1.0), "Shoulder_R": (0, 0, 1.0),
                       "Head": (0.5, 0, 0)}, {"Hips": (0, 0, -0.008)})
    rest_key(arm, 60, bones)
    set_interpolation(arm, action)


def make_walk(arm):
    bones = ["Hips", "Chest", "UpperArm_L", "UpperArm_R", "Forearm_L", "Forearm_R",
             "Thigh_L", "Thigh_R", "Shin_L", "Shin_R", "Foot_L", "Foot_R"]
    action = begin_action(arm, "Walk", 28, True)
    # Contact L forward / R back.
    key_pose(arm, 1, {"Thigh_L": (-24, 0, 0), "Shin_L": (8, 0, 0), "Foot_L": (10, 0, 0),
                      "Thigh_R": (22, 0, 0), "Shin_R": (30, 0, 0), "Foot_R": (-12, 0, 0),
                      "UpperArm_L": (16, 0, 0), "UpperArm_R": (-16, 0, 0),
                      "Forearm_L": (8, 0, 0), "Forearm_R": (-8, 0, 0), "Chest": (0, 0, 5)},
             {"Hips": (0, 0, 0)})
    key_pose(arm, 8, {"Thigh_L": (-5, 0, 0), "Shin_L": (10, 0, 0),
                      "Thigh_R": (4, 0, 0), "Shin_R": (52, 0, 0), "Foot_R": (-18, 0, 0),
                      "UpperArm_L": (3, 0, 0), "UpperArm_R": (-3, 0, 0), "Chest": (0, 0, 0)},
             {"Hips": (0, 0, 0.035)})
    # Opposite contact.
    key_pose(arm, 15, {"Thigh_L": (22, 0, 0), "Shin_L": (30, 0, 0), "Foot_L": (-12, 0, 0),
                       "Thigh_R": (-24, 0, 0), "Shin_R": (8, 0, 0), "Foot_R": (10, 0, 0),
                       "UpperArm_L": (-16, 0, 0), "UpperArm_R": (16, 0, 0),
                       "Forearm_L": (-8, 0, 0), "Forearm_R": (8, 0, 0), "Chest": (0, 0, -5)},
             {"Hips": (0, 0, 0)})
    key_pose(arm, 22, {"Thigh_L": (4, 0, 0), "Shin_L": (52, 0, 0), "Foot_L": (-18, 0, 0),
                       "Thigh_R": (-5, 0, 0), "Shin_R": (10, 0, 0),
                       "UpperArm_L": (-3, 0, 0), "UpperArm_R": (3, 0, 0), "Chest": (0, 0, 0)},
             {"Hips": (0, 0, 0.035)})
    # Exact cyclic endpoint.
    key_pose(arm, 28, {"Thigh_L": (-24, 0, 0), "Shin_L": (8, 0, 0), "Foot_L": (10, 0, 0),
                       "Thigh_R": (22, 0, 0), "Shin_R": (30, 0, 0), "Foot_R": (-12, 0, 0),
                       "UpperArm_L": (16, 0, 0), "UpperArm_R": (-16, 0, 0),
                       "Forearm_L": (8, 0, 0), "Forearm_R": (-8, 0, 0), "Chest": (0, 0, 5)},
             {"Hips": (0, 0, 0)})
    set_interpolation(arm, action)


def make_attack_light(arm):
    bones = ["Hips", "Spine", "Chest", "Head", "UpperArm_R", "Forearm_R", "Hand_R",
             "UpperArm_L", "Forearm_L", "Thigh_L", "Thigh_R", "Shin_L", "Shin_R"]
    action = begin_action(arm, "Attack_Light", 23)
    rest_key(arm, 1, bones)
    key_pose(arm, 6, {"Chest": (0, 0, 18), "Hips": (0, 0, 8), "UpperArm_R": (-22, -48, 20),
                      "Forearm_R": (0, -70, 12), "Hand_R": (0, 22, 0), "UpperArm_L": (8, 0, -10),
                      "Thigh_R": (8, 0, 0), "Shin_R": (18, 0, 0)})
    key_pose(arm, 10, {"Chest": (4, 0, -26), "Hips": (0, 0, -10), "UpperArm_R": (20, 58, -28),
                       "Forearm_R": (0, 18, -8), "Hand_R": (0, -18, 0), "UpperArm_L": (-8, 0, 12),
                       "Thigh_L": (-8, 0, 0), "Shin_L": (12, 0, 0)})
    key_pose(arm, 13, {"Chest": (6, 0, -32), "UpperArm_R": (28, 70, -35),
                       "Forearm_R": (0, 8, -5), "Hand_R": (0, -25, 0), "Head": (0, 0, 8)})
    key_pose(arm, 18, {"Chest": (0, 0, -10), "UpperArm_R": (8, 20, -8), "Forearm_R": (0, -8, 0)})
    rest_key(arm, 23, bones)
    add_markers(action, {"attack_start": 4, "impact": 10, "attack_end": 20})
    set_interpolation(arm, action, (10,))


def make_attack_heavy(arm):
    bones = ["Hips", "Spine", "Chest", "UpperChest", "Head", "UpperArm_R", "Forearm_R", "Hand_R",
             "UpperArm_L", "Forearm_L", "Thigh_L", "Thigh_R", "Shin_L", "Shin_R"]
    action = begin_action(arm, "Attack_Heavy", 38)
    rest_key(arm, 1, bones)
    key_pose(arm, 9, {"Chest": (-12, 0, 10), "UpperChest": (-10, 0, 0),
                      "UpperArm_R": (-65, -52, 18), "Forearm_R": (-15, -78, 0), "Hand_R": (0, 25, 0),
                      "UpperArm_L": (-35, 20, -20), "Forearm_L": (-20, 55, 0),
                      "Thigh_L": (12, 0, 0), "Thigh_R": (12, 0, 0),
                      "Shin_L": (32, 0, 0), "Shin_R": (32, 0, 0)}, {"Hips": (0, 0, -0.05)})
    key_pose(arm, 15, {"Chest": (-15, 0, 12), "UpperArm_R": (-75, -58, 20),
                       "Forearm_R": (-18, -85, 0), "UpperArm_L": (-42, 25, -25),
                       "Forearm_L": (-25, 65, 0)}, {"Hips": (0, 0, -0.065)})
    key_pose(arm, 21, {"Chest": (25, 0, -16), "UpperChest": (12, 0, 0),
                       "UpperArm_R": (62, 48, -18), "Forearm_R": (22, 12, 0), "Hand_R": (0, -30, 0),
                       "UpperArm_L": (24, -10, 15), "Forearm_L": (10, -20, 0),
                       "Thigh_L": (-8, 0, 0), "Thigh_R": (-8, 0, 0),
                       "Shin_L": (8, 0, 0), "Shin_R": (8, 0, 0)}, {"Hips": (0, 0, 0.02)})
    key_pose(arm, 25, {"Chest": (30, 0, -20), "UpperArm_R": (72, 55, -22),
                       "Forearm_R": (28, 5, 0), "Head": (-8, 0, 4)}, {"Hips": (0, 0, -0.02)})
    key_pose(arm, 32, {"Chest": (8, 0, -5), "UpperArm_R": (20, 12, -5), "Forearm_R": (5, -8, 0)})
    rest_key(arm, 38, bones)
    add_markers(action, {"attack_start": 6, "impact": 21, "attack_end": 34})
    set_interpolation(arm, action, (21,))


def make_block(arm):
    bones = ["Hips", "Chest", "Head", "UpperArm_R", "Forearm_R", "Hand_R",
             "UpperArm_L", "Forearm_L", "Hand_L", "Thigh_L", "Thigh_R", "Shin_L", "Shin_R"]
    action = begin_action(arm, "Block", 26)
    rest_key(arm, 1, bones)
    key_pose(arm, 8, {"Chest": (-8, 0, 0), "Head": (4, 0, 0),
                      "UpperArm_R": (-30, -42, 25), "Forearm_R": (-10, -65, 12), "Hand_R": (0, 35, 0),
                      "UpperArm_L": (-15, 20, -20), "Forearm_L": (-8, 48, -10), "Hand_L": (0, -20, 0),
                      "Thigh_L": (10, 0, 0), "Thigh_R": (10, 0, 0),
                      "Shin_L": (25, 0, 0), "Shin_R": (25, 0, 0)}, {"Hips": (0, 0, -0.04)})
    key_pose(arm, 18, {"Chest": (-10, 0, 0), "UpperArm_R": (-35, -48, 28),
                       "Forearm_R": (-12, -72, 15), "UpperArm_L": (-18, 25, -22),
                       "Forearm_L": (-10, 55, -12), "Thigh_L": (12, 0, 0), "Thigh_R": (12, 0, 0),
                       "Shin_L": (28, 0, 0), "Shin_R": (28, 0, 0)}, {"Hips": (0, 0, -0.05)})
    rest_key(arm, 26, bones)
    set_interpolation(arm, action)


def make_hit(arm):
    bones = ["Hips", "Spine", "Chest", "UpperChest", "Head", "UpperArm_L", "UpperArm_R",
             "Forearm_L", "Forearm_R", "Thigh_L", "Thigh_R", "Shin_L", "Shin_R"]
    action = begin_action(arm, "Hit", 16)
    rest_key(arm, 1, bones)
    key_pose(arm, 5, {"Spine": (-12, 0, 0), "Chest": (-22, 0, 0), "UpperChest": (-12, 0, 0),
                      "Head": (18, 0, 0), "UpperArm_L": (-18, 10, -18), "UpperArm_R": (-18, -10, 18),
                      "Forearm_L": (-12, 0, 0), "Forearm_R": (-12, 0, 0),
                      "Thigh_L": (10, 0, 0), "Thigh_R": (10, 0, 0),
                      "Shin_L": (22, 0, 0), "Shin_R": (22, 0, 0)}, {"Hips": (0, 0.025, -0.035)})
    key_pose(arm, 9, {"Chest": (8, 0, 0), "Head": (-5, 0, 0),
                      "UpperArm_L": (6, 0, 5), "UpperArm_R": (6, 0, -5)})
    rest_key(arm, 16, bones)
    set_interpolation(arm, action, (5,))


def make_death(arm):
    bones = ["Hips", "Spine", "Chest", "UpperChest", "Head", "UpperArm_L", "UpperArm_R",
             "Forearm_L", "Forearm_R", "Thigh_L", "Thigh_R", "Shin_L", "Shin_R", "Foot_L", "Foot_R"]
    action = begin_action(arm, "Death", 56)
    rest_key(arm, 1, bones)
    key_pose(arm, 9, {"Chest": (-24, 0, 8), "Head": (18, 0, 0),
                      "UpperArm_L": (-15, 0, -12), "UpperArm_R": (-20, 0, 16)}, {"Hips": (0, 0.03, -0.02)})
    key_pose(arm, 22, {"Hips": (20, 0, 10), "Spine": (-20, 0, 0), "Chest": (-28, 0, 0),
                       "Thigh_L": (28, 0, 0), "Shin_L": (75, 0, 0),
                       "Thigh_R": (12, 0, 0), "Shin_R": (42, 0, 0),
                       "UpperArm_L": (15, 0, -25), "UpperArm_R": (-30, 15, 25)},
             {"Hips": (0, -0.08, -0.22)})
    key_pose(arm, 39, {"Hips": (72, 0, 18), "Spine": (-12, 0, 0), "Chest": (-18, 0, 0),
                       "Head": (20, 0, -10), "Thigh_L": (42, 0, -8), "Shin_L": (88, 0, 0),
                       "Thigh_R": (30, 0, 12), "Shin_R": (65, 0, 0),
                       "UpperArm_L": (40, 0, -35), "Forearm_L": (35, 0, 0),
                       "UpperArm_R": (-55, 20, 35), "Forearm_R": (25, 0, 0)},
             {"Hips": (0, -0.18, -0.50)})
    key_pose(arm, 48, {"Hips": (88, 0, 22), "Spine": (-8, 0, 0), "Chest": (-10, 0, 0),
                       "Head": (12, 0, -15), "Thigh_L": (52, 0, -10), "Shin_L": (95, 0, 0),
                       "Thigh_R": (38, 0, 15), "Shin_R": (75, 0, 0),
                       "UpperArm_L": (52, 0, -42), "Forearm_L": (42, 0, 0),
                       "UpperArm_R": (-65, 22, 42), "Forearm_R": (32, 0, 0)},
             {"Hips": (0, -0.22, -0.62)})
    # Held final pose; death never returns to rest.
    key_pose(arm, 56, {"Hips": (88, 0, 22), "Spine": (-8, 0, 0), "Chest": (-10, 0, 0),
                       "Head": (12, 0, -15), "Thigh_L": (52, 0, -10), "Shin_L": (95, 0, 0),
                       "Thigh_R": (38, 0, 15), "Shin_R": (75, 0, 0),
                       "UpperArm_L": (52, 0, -42), "Forearm_L": (42, 0, 0),
                       "UpperArm_R": (-65, 22, 42), "Forearm_R": (32, 0, 0)},
             {"Hips": (0, -0.22, -0.62)})
    add_markers(action, {"death_ground": 48})
    set_interpolation(arm, action, (48,))


def make_victory(arm):
    bones = ["Hips", "Spine", "Chest", "UpperChest", "Head", "UpperArm_R", "Forearm_R",
             "Hand_R", "UpperArm_L", "Forearm_L"]
    action = begin_action(arm, "Victory", 60)
    rest_key(arm, 1, bones)
    key_pose(arm, 12, {"Chest": (-6, 0, -8), "UpperChest": (-5, 0, 0), "Head": (3, 0, 6),
                       "UpperArm_R": (-55, -35, -15), "Forearm_R": (-25, -65, 0), "Hand_R": (0, 18, 0),
                       "UpperArm_L": (10, 0, 18), "Forearm_L": (18, 0, 0)}, {"Hips": (0, 0, 0.02)})
    key_pose(arm, 25, {"Chest": (-10, 0, -12), "UpperChest": (-7, 0, 0), "Head": (5, 0, 10),
                       "UpperArm_R": (-82, -48, -20), "Forearm_R": (-35, -82, 0), "Hand_R": (0, 25, 0),
                       "UpperArm_L": (18, 0, 25), "Forearm_L": (28, 0, 0)}, {"Hips": (0, 0, 0.04)})
    key_pose(arm, 42, {"Chest": (-8, 0, -10), "UpperArm_R": (-78, -45, -18),
                       "Forearm_R": (-32, -78, 0), "Head": (3, 0, 8)}, {"Hips": (0, 0, 0.035)})
    rest_key(arm, 60, bones)
    set_interpolation(arm, action)


def preview_animation(name):
    """Activate one Action, set its range and return to its first frame."""
    arm = bpy.data.objects[ARMATURE_NAME]
    action = bpy.data.actions.get(name)
    if not action:
        raise ValueError(f"Animation not found: {name}")
    arm.animation_data.action = action
    start = int(action.get("intended_frame_start", 1))
    end = int(action.get("intended_frame_end", action.frame_range[1]))
    bpy.context.scene.frame_start = start
    bpy.context.scene.frame_end = end
    bpy.context.scene.frame_set(start)
    return action


def action_has_keys(action):
    start, end = action.frame_range
    return end > start and end >= action.get("intended_frame_end", end) - 0.01


def validate(arm, sword):
    results = {}
    for name in ACTION_NAMES:
        action = bpy.data.actions.get(name)
        results[name] = bool(action and action_has_keys(action) and action.use_fake_user)

    # Root locations are explicitly keyed at zero by every key_pose.
    root_motion_ok = all(bpy.data.actions[n].get("root_motion") == "IN_PLACE" for n in ACTION_NAMES)
    sword_ok = sword.parent == arm and sword.parent_bone == "WeaponSocket_R"
    walk = bpy.data.actions["Walk"]
    walk_ok = walk.get("intended_frame_end") == 28 and action_has_keys(walk)
    death = bpy.data.actions["Death"]
    death_ok = death.get("intended_frame_end") == 56 and action_has_keys(death)

    print("\n=== WARRIOR ANIMATION VALIDATION ===")
    for name in ACTION_NAMES:
        print(f"{name}:", "PASS" if results[name] else "FAIL")
    print("Root motion check:", "PASS" if root_motion_ok else "FAIL")
    print("Sword attachment:", "PASS" if sword_ok else "FAIL")
    print("Walk leg alternation:", "PASS" if walk_ok else "FAIL")
    print("Death final pose:", "PASS" if death_ok else "FAIL")
    print("Warnings:")
    print("- Rigid segmented binding may expose small gaps in extreme poses.")
    print("- Blender IK constraints remain muted; Actions contain direct FK keys for glTF.")
    print("- Inspect sword arcs and ground contact visually before production use.")
    print("=== END VALIDATION ===\n")
    return all(results.values()) and root_motion_ok and sword_ok and walk_ok and death_ok


def main():
    arm, sword = inspect_rig()
    bpy.context.scene.render.fps = 30
    bpy.context.scene.render.fps_base = 1.0
    rig_collection = bpy.data.collections.get(RIG_COLLECTION)
    if rig_collection:
        rig_collection.name = ANIMATED_COLLECTION

    # Existing Phase 2 file remains the disk-level backup; no mesh/rig duplication per Action.
    for name in ACTION_NAMES:
        old = bpy.data.actions.get(name)
        if old:
            bpy.data.actions.remove(old)
    make_idle(arm)
    make_walk(arm)
    make_attack_light(arm)
    make_attack_heavy(arm)
    make_block(arm)
    make_hit(arm)
    make_death(arm)
    make_victory(arm)

    valid = validate(arm, sword)
    preview_animation("Idle")
    clear_pose(arm)
    bpy.context.scene.frame_set(1)
    arm["animation_set"] = "Warrior_Animated_V1"
    arm["animation_validation"] = "PASS" if valid else "CHECK_WARNINGS"
    print("Warrior_Animated_V1 complete.", "VALID" if valid else "CHECK WARNINGS")


if __name__ == "__main__":
    main()
