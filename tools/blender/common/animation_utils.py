"""Common Action, keyframe, marker and root-motion helpers."""
import bpy

def create_action(armature, name, frame_end, loop=False):
    action=bpy.data.actions.get(name) or bpy.data.actions.new(name); action.use_fake_user=True
    armature.animation_data_create(); armature.animation_data.action=action
    action["frame_end"]=frame_end; action["loop"]=loop; return action

def key_bone(armature, bone_name, frame, location=None, rotation=None):
    bone=armature.pose.bones.get(bone_name)
    if not bone: return False
    bone.rotation_mode="XYZ"
    if location is not None: bone.location=location; bone.keyframe_insert("location",frame=frame)
    if rotation is not None: bone.rotation_euler=rotation; bone.keyframe_insert("rotation_euler",frame=frame)
    return True

def add_markers(action, markers):
    for name, frame in markers.items(): action.pose_markers.new(name).frame=frame

def list_actions(): return sorted(a.name for a in bpy.data.actions)

def validate_root_motion(action, epsilon=1e-4):
    curves=[c for c in action.fcurves if 'pose.bones["Root"].location' in c.data_path and c.array_index in (0,1)]
    return all(abs(p.co.y) <= epsilon for c in curves for p in c.keyframe_points)
