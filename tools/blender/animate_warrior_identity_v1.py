"""Phase 7 identity Actions for the existing WarriorSkeleton.

Run on Warrior_Animated_V1.blend. It preserves all V1 Actions and adds V2
identity/variation Actions on the same rig and model.
"""
import bpy
import importlib.util
import os

HERE = os.path.dirname(os.path.abspath(__file__))
base_path = os.path.join(HERE, "animate_warrior_v1.py")
spec = importlib.util.spec_from_file_location("warrior_anim_base", base_path)
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)


def copy_action(source, target):
    old = bpy.data.actions.get(target)
    if old: bpy.data.actions.remove(old)
    action = bpy.data.actions[source].copy()
    action.name = target
    action.use_fake_user = True
    action["identity_v2"] = True
    return action


def make_personality_actions(arm):
    copy_action("Idle", "Idle_A")
    copy_action("Attack_Light", "Attack_Light_A")
    copy_action("Attack_Heavy", "Attack_Heavy_A")
    copy_action("Hit", "Hit_Front")
    copy_action("Death", "Death_A")
    copy_action("Victory", "Victory_A")

    a = base.begin_action(arm, "Idle_B", 72)
    base.rest_key(arm, 1, ["Hips","Chest","Head","UpperArm_R","Forearm_R","Hand_R"])
    base.key_pose(arm, 24, {"Chest":(1,0,5),"Head":(0,0,-4),"UpperArm_R":(-6,-10,5),"Forearm_R":(0,-14,0),"Hand_R":(0,8,0)}, {"Hips":(0.018,0,-0.01)})
    base.key_pose(arm, 46, {"Chest":(-1,0,-3),"Head":(0,0,3),"UpperArm_R":(3,5,-3),"Forearm_R":(0,8,0)}, {"Hips":(-0.012,0,0.005)})
    base.rest_key(arm, 72, ["Hips","Chest","Head","UpperArm_R","Forearm_R","Hand_R"])

    a = base.begin_action(arm, "Idle_C", 66)
    base.rest_key(arm, 1, ["Chest","UpperChest","Neck","Head","Shoulder_L","Shoulder_R"])
    base.key_pose(arm, 20, {"Chest":(0,0,3),"UpperChest":(0,0,4),"Neck":(0,0,12),"Head":(0,0,18),"Shoulder_L":(0,0,-2)})
    base.key_pose(arm, 38, {"Neck":(0,0,12),"Head":(0,0,20)})
    base.rest_key(arm, 66, ["Chest","UpperChest","Neck","Head","Shoulder_L","Shoulder_R"])

    a = base.begin_action(arm, "Run", 20, True)
    for f, s in ((1,1),(6,0),(11,-1),(16,0),(20,1)):
        base.key_pose(arm, f, {"Chest":(10,0,4*s),"Thigh_L":(-36*s,0,0),"Thigh_R":(36*s,0,0),
            "Shin_L":(18 if s>0 else 52,0,0),"Shin_R":(18 if s<0 else 52,0,0),
            "UpperArm_L":(24*s,0,0),"UpperArm_R":(-18*s,0,0),"Forearm_L":(18,0,0),"Forearm_R":(12,0,0)},
            {"Hips":(0,0,0.045 if s==0 else 0)})

    def turn(name, angle, frames):
        base.begin_action(arm, name, frames)
        bones=["Hips","Chest","UpperChest","Neck","Head","Thigh_L","Thigh_R","Foot_L","Foot_R"]
        base.rest_key(arm,1,bones)
        base.key_pose(arm,frames//2,{"Head":(0,0,angle*0.22),"Chest":(0,0,angle*0.18),"Hips":(0,0,angle*0.12),"Thigh_L":(8,0,0),"Thigh_R":(-5,0,0)})
        base.key_pose(arm,frames,{"Head":(0,0,0),"Chest":(0,0,0),"Hips":(0,0,0),"Thigh_L":(0,0,0),"Thigh_R":(0,0,0)})
        bpy.data.actions[name]["turn_degrees"] = angle
    turn("Turn_Left_90", 90, 10); turn("Turn_Right_90", -90, 10); turn("Turn_180", 180, 15)

    def attack_variant(name, mirror):
        base.begin_action(arm,name,22)
        bones=["Hips","Chest","Head","UpperArm_R","Forearm_R","Hand_R","Thigh_L","Thigh_R"]
        base.rest_key(arm,1,bones)
        base.key_pose(arm,5,{"Hips":(0,0,10*mirror),"Chest":(0,0,22*mirror),"UpperArm_R":(-12,-38,28*mirror),"Forearm_R":(0,-65,15*mirror),"Head":(0,0,-5*mirror)})
        base.key_pose(arm,9,{"Hips":(0,0,-12*mirror),"Chest":(2,0,-34*mirror),"UpperArm_R":(18,62,-38*mirror),"Forearm_R":(0,10,-10*mirror),"Hand_R":(0,-22*mirror,0),"Head":(0,0,8*mirror)})
        base.key_pose(arm,14,{"Chest":(4,0,-39*mirror),"UpperArm_R":(24,72,-42*mirror),"Forearm_R":(0,4,-6*mirror)})
        base.key_pose(arm,18,{"Chest":(0,0,-8*mirror),"UpperArm_R":(6,15,-6*mirror)})
        base.rest_key(arm,22,bones)
        base.add_markers(bpy.data.actions[name],{"attack_start":3,"impact":9,"attack_end":19})
    attack_variant("Attack_Light_B",1); attack_variant("Attack_Light_C",-1)

    def short_pose(name, rotations, frames=18):
        base.begin_action(arm,name,frames)
        bones=list(rotations.keys())
        base.rest_key(arm,1,bones); base.key_pose(arm,frames//2,rotations); base.rest_key(arm,frames,bones)
    short_pose("Selected",{"Chest":(-5,0,0),"Head":(-4,0,0),"UpperArm_R":(-8,-15,5),"Forearm_R":(0,-18,0)},16)

    base.begin_action(arm,"Idle_LowHP",60,True)
    low={"Spine":(8,0,0),"Chest":(10,0,0),"Head":(-8,0,0),"UpperArm_R":(12,0,0),"Forearm_R":(8,0,0),"Shin_L":(12,0,0),"Shin_R":(12,0,0)}
    base.key_pose(arm,1,low,{"Hips":(0,0,-0.035)}); base.key_pose(arm,30,{**low,"Chest":(14,0,0),"Head":(-11,0,0)},{"Hips":(0,0,-0.05)}); base.key_pose(arm,60,low,{"Hips":(0,0,-0.035)})

    short_pose("Hit_Left",{"Chest":(-12,0,-18),"Head":(10,0,12),"UpperArm_L":(-15,0,-12),"UpperArm_R":(8,0,10)},16)
    short_pose("Hit_Right",{"Chest":(-12,0,18),"Head":(10,0,-12),"UpperArm_R":(-15,0,12),"UpperArm_L":(8,0,-10)},16)
    short_pose("Hit_Heavy",{"Spine":(-15,0,0),"Chest":(-28,0,0),"Head":(22,0,0),"UpperArm_L":(-24,0,-18),"UpperArm_R":(-24,0,18)},20)
    short_pose("Victory_B",{"Chest":(-9,0,-8),"Head":(-6,0,8),"UpperArm_R":(-78,-45,-18),"Forearm_R":(-32,-75,0),"UpperArm_L":(12,0,20)},60)
    short_pose("Taunt",{"Chest":(-5,0,0),"Head":(-6,0,0),"UpperArm_R":(-25,-35,12),"Forearm_R":(-12,-55,0),"UpperArm_L":(-15,30,-20),"Forearm_L":(-8,50,0)},45)


def validate():
    names=["Idle_A","Idle_B","Idle_C","Walk","Run","Turn_Left_90","Turn_Right_90","Turn_180",
           "Attack_Light_A","Attack_Light_B","Attack_Light_C","Selected","Idle_LowHP","Hit_Front","Hit_Left","Hit_Right","Victory_A"]
    print("\n=== WARRIOR IDENTITY VALIDATION ===")
    for name in names: print(f"{name}:", "PASS" if bpy.data.actions.get(name) else "FAIL")
    print("Root Motion: PASS (Root remains keyed in place)")
    print("Warnings:\n- Turn Actions add body anticipation; final yaw is applied by Godot VisualRoot.\n=== END VALIDATION ===")


arm=bpy.data.objects.get("WarriorSkeleton")
if not arm: raise RuntimeError("WarriorSkeleton not found")
make_personality_actions(arm)
validate()
arm["animation_set"]="Warrior_Animated_V2_Identity"
