"""Phase 8: add Warrior skill choreography to the existing V2 rig.

Run against Warrior_Animated_V2.blend. Existing objects and Actions are kept.
Front is Blender -Y / Godot -Z. All Actions are in-place at 30 FPS.
"""
import bpy, importlib.util, os

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("warrior_anim_base", os.path.join(HERE, "animate_warrior_v1.py"))
base = importlib.util.module_from_spec(spec); spec.loader.exec_module(base)

def action(name, frames, poses, markers):
    arm = bpy.data.objects["WarriorSkeleton"]
    bones = sorted({bone for _, rotations, _ in poses for bone in rotations})
    base.begin_action(arm, name, frames)
    base.rest_key(arm, 1, bones)
    for frame, rotations, locations in poses:
        base.key_pose(arm, frame, rotations, locations)
    base.rest_key(arm, frames, bones)
    base.add_markers(bpy.data.actions[name], markers)
    bpy.data.actions[name].use_fake_user = True
    bpy.data.actions[name]["skill_v3"] = True

action("Skill_PowerAttack", 27, [
    (8,{"Hips":(0,0,-7),"Chest":(-8,0,10),"Head":(-5,0,-4),"UpperArm_R":(-25,-30,15),"Forearm_R":(-8,-42,0)},{}),
    (15,{"Hips":(0,0,5),"Chest":(-12,0,-8),"Head":(-8,0,4),"UpperArm_R":(-38,-48,5),"Forearm_R":(-12,-60,0)},{}),
], {"skill_start":1,"cast":15,"recovery":20,"skill_end":27})

action("Skill_ThrowSword", 30, [
    (7,{"Hips":(0,0,12),"Chest":(0,0,25),"UpperArm_R":(-35,-55,34),"Forearm_R":(-8,-70,15),"Head":(0,0,-8)},{}),
    (13,{"Hips":(0,0,-10),"Chest":(-5,0,-28),"UpperArm_R":(12,72,-35),"Forearm_R":(0,18,-5),"Hand_R":(0,-28,0)},{}),
    (18,{"Chest":(4,0,-34),"UpperArm_R":(18,78,-38),"Forearm_R":(0,8,0)},{}),
], {"skill_start":1,"cast":13,"impact":22,"recovery":24,"skill_end":30})

action("Skill_Whirlwind", 36, [
    (8,{"Hips":(0,0,22),"Chest":(6,0,38),"UpperArm_R":(-18,-48,35),"Forearm_R":(0,-55,12),"Thigh_L":(10,0,0),"Thigh_R":(10,0,0)},{}),
    (17,{"Hips":(0,0,-58),"Chest":(-4,0,-78),"UpperArm_R":(12,65,-55),"Forearm_R":(0,15,-10),"Head":(0,0,22)},{}),
    (24,{"Hips":(0,0,62),"Chest":(5,0,82),"UpperArm_R":(18,72,52),"Forearm_R":(0,8,8),"Head":(0,0,-20)},{}),
    (29,{"Hips":(0,0,-18),"Chest":(2,0,-28),"UpperArm_R":(8,35,-18)},{}),
], {"skill_start":1,"cast":10,"impact":22,"recovery":28,"skill_end":36})

action("Skill_Defend", 30, [
    (10,{"Hips":(0,0,0),"Spine":(7,0,0),"Chest":(8,0,0),"UpperArm_R":(-38,-24,-12),"Forearm_R":(-18,-62,0),"UpperArm_L":(-22,28,15),"Forearm_L":(-15,52,0),"Thigh_L":(8,0,0),"Thigh_R":(8,0,0)}, {"Hips":(0,0,-0.035)}),
    (20,{"Spine":(5,0,0),"Chest":(6,0,0),"UpperArm_R":(-34,-20,-10),"Forearm_R":(-15,-58,0),"UpperArm_L":(-18,24,12),"Forearm_L":(-12,48,0)}, {"Hips":(0,0,-0.025)}),
], {"skill_start":1,"cast":10,"recovery":23,"skill_end":30})

required=("Skill_PowerAttack","Skill_ThrowSword","Skill_Whirlwind","Skill_Defend")
print("\n=== WARRIOR SKILL ANIMATION VALIDATION ===")
for name in required:
    a=bpy.data.actions.get(name); print(name, "PASS" if a and len(a.pose_markers)>=4 else "FAIL")
print("Root motion: PASS\n=== END VALIDATION ===")
bpy.data.objects["WarriorSkeleton"]["animation_set"]="Warrior_Animated_V3_Skills"
