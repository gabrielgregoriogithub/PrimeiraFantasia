"""Export Warrior_Animated_V1 and its Actions to a clean Godot-ready GLB."""

import bpy
import os


ARMATURE_NAME = "WarriorSkeleton"
OUTPUT_NAME = "warrior_animated_v1.glb"


def export_warrior_glb(output_path=None):
    arm = bpy.data.objects.get(ARMATURE_NAME)
    if not arm:
        raise RuntimeError("WarriorSkeleton not found")
    output_path = output_path or os.path.join(os.path.dirname(bpy.data.filepath), OUTPUT_NAME)

    bpy.ops.object.mode_set(mode='OBJECT') if bpy.context.object and bpy.context.object.mode != 'OBJECT' else None
    bpy.ops.object.select_all(action='DESELECT')
    selected = {arm}
    # Include every descendant: rigid body parts, Sword container, and sword pieces.
    pending = [arm]
    while pending:
        parent = pending.pop()
        for child in parent.children:
            if child not in selected:
                selected.add(child)
                pending.append(child)
    for obj in selected:
        obj.hide_set(False)
        obj.select_set(True)
    bpy.context.view_layer.objects.active = arm

    kwargs = dict(
        filepath=output_path,
        export_format='GLB',
        use_selection=True,
        export_animations=True,
        export_animation_mode='ACTIONS',
        export_nla_strips=False,
        export_skins=True,
        export_materials='EXPORT',
        export_cameras=False,
        export_lights=False,
        export_yup=True,
    )
    try:
        bpy.ops.export_scene.gltf(**kwargs)
    except TypeError:
        # Compatibility fallback for Blender versions without animation_mode.
        kwargs.pop('export_animation_mode', None)
        kwargs['export_all_actions'] = True
        bpy.ops.export_scene.gltf(**kwargs)
    print("GLB exported:", output_path)
    print("Exported objects:", ", ".join(sorted(o.name for o in selected)))
    return output_path


if __name__ == "__main__":
    export_warrior_glb()
