"""Visual-only repair for Warrior V3.

Preserves the existing rig/actions and only adds the missing combat rest-pose
channels to Idle_A.  The V3 blend is never overwritten by this script.
"""
import bpy
import math
import os

ARMATURE = "WarriorSkeleton"

def key(pb, frame, euler):
    pb.rotation_mode = "XYZ"
    pb.rotation_euler = tuple(math.radians(v) for v in euler)
    pb.keyframe_insert(data_path="rotation_euler", frame=frame, group=pb.name)

def main():
    arm = bpy.data.objects.get(ARMATURE)
    action = bpy.data.actions.get("Idle_A")
    if not arm or not action:
        raise RuntimeError("WarriorSkeleton/Idle_A not found")
    if not arm.animation_data:
        arm.animation_data_create()
    arm.animation_data.action = action

    # A restrained combat stance: elbows and knees stay close to the body.
    # Positive Y bends the left (+X) chain down; the right (-X) chain mirrors it.
    poses = {
        1:  {"UpperArm_L": (0, 18, 0), "UpperArm_R": (0, -18, 0), "Forearm_L": (0, 10, 0), "Forearm_R": (0, -10, 0), "Shin_L": (0, 3, 0), "Shin_R": (0, -3, 0)},
        16: {"UpperArm_L": (0, 20, 0), "UpperArm_R": (0, -20, 0), "Forearm_L": (0, 12, 0), "Forearm_R": (0, -12, 0), "Shin_L": (0, 4, 0), "Shin_R": (0, -4, 0)},
        31: {"UpperArm_L": (0, 18, 0), "UpperArm_R": (0, -18, 0), "Forearm_L": (0, 10, 0), "Forearm_R": (0, -10, 0), "Shin_L": (0, 3, 0), "Shin_R": (0, -3, 0)},
        46: {"UpperArm_L": (0, 16, 0), "UpperArm_R": (0, -16, 0), "Forearm_L": (0, 8, 0), "Forearm_R": (0, -8, 0), "Shin_L": (0, 2, 0), "Shin_R": (0, -2, 0)},
        60: {"UpperArm_L": (0, 18, 0), "UpperArm_R": (0, -18, 0), "Forearm_L": (0, 10, 0), "Forearm_R": (0, -10, 0), "Shin_L": (0, 3, 0), "Shin_R": (0, -3, 0)},
    }
    for frame, channels in poses.items():
        bpy.context.scene.frame_set(frame)
        for name, angles in channels.items():
            key(arm.pose.bones[name], frame, angles)
    action.use_fake_user = True
    action["visual_fix"] = "combat stance channels added; V3 preserved"
    action["root_motion"] = "IN_PLACE"
    bpy.context.scene.frame_set(1)
    out = os.path.join(os.path.dirname(bpy.data.filepath), "Warrior_Animated_V4_VisualFix.blend")
    bpy.ops.wm.save_as_mainfile(filepath=out)
    print("Saved visual-fix blend:", out)

if __name__ == "__main__":
    main()
