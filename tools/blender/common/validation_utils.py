"""Manifest-oriented character validation."""
def validate_character(armature, objects, actions, manifest, rig_utils):
    rig=rig_utils.validate_armature(armature, manifest.get("required_bones", rig_utils.HUMANOID_REQUIRED))
    missing_actions=[a for a in manifest.get("required_actions",[]) if a not in actions]
    sockets=[s for s in manifest.get("sockets",[]) if armature.data.bones.get(s) is None]
    return {"skeleton":rig["valid"],"missing_bones":rig["missing"],"meshes":bool(objects),"missing_actions":missing_actions,"missing_sockets":sockets,"valid":rig["valid"] and not missing_actions}

def print_report(character_id, result):
    print("\n=== CHARACTER EXPORT VALIDATION ===", character_id)
    for key,value in result.items(): print(key, "PASS" if value is True else ("FAIL" if value is False else value))
