"""Reusable rig helpers for Blender character assets."""
import bpy

HUMANOID_REQUIRED = ("Root","Hips","Spine","Chest","Neck","Head","Shoulder_L","UpperArm_L","Forearm_L","Hand_L","Shoulder_R","UpperArm_R","Forearm_R","Hand_R","Thigh_L","Shin_L","Foot_L","Thigh_R","Shin_R","Foot_R")

def validate_armature(armature, required=HUMANOID_REQUIRED):
    names = {bone.name for bone in armature.data.bones} if armature else set()
    return {"valid": all(n in names for n in required), "missing": [n for n in required if n not in names]}

def validate_symmetry(armature, tolerance=0.001):
    warnings=[]
    for bone in armature.data.bones:
        if bone.name.endswith("_L"):
            other=armature.data.bones.get(bone.name[:-2]+"_R")
            if not other: warnings.append("missing pair: "+bone.name)
            elif abs(bone.head.x + other.head.x) > tolerance: warnings.append("asymmetric: "+bone.name)
    return warnings

def ensure_socket(armature, name, parent_name, head, tail):
    bpy.context.view_layer.objects.active=armature; bpy.ops.object.mode_set(mode="EDIT")
    bone=armature.data.edit_bones.get(name) or armature.data.edit_bones.new(name)
    bone.head, bone.tail = head, tail; bone.parent=armature.data.edit_bones.get(parent_name); bone.use_deform=False
    bpy.ops.object.mode_set(mode="OBJECT"); return bone

def validate_transforms(objects, tolerance=1e-4):
    return [o.name for o in objects if any(abs(s-1.0)>tolerance for s in o.scale)]
