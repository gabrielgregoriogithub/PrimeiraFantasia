"""Clean glTF/GLB exporter shared by every character."""
import bpy

def descendants(root):
    result={root}; pending=[root]
    while pending:
        for child in pending.pop().children:
            if child not in result: result.add(child); pending.append(child)
    return result

def export_character_glb(armature, output_path, export_animations=True):
    bpy.ops.object.select_all(action="DESELECT"); selected=descendants(armature)
    for obj in selected: obj.hide_set(False); obj.select_set(True)
    bpy.context.view_layer.objects.active=armature
    bpy.ops.export_scene.gltf(filepath=output_path,export_format="GLB",use_selection=True,
        export_animations=export_animations,export_animation_mode="ACTIONS",export_nla_strips=False,
        export_skins=True,export_materials="EXPORT",export_cameras=False,export_lights=False,export_yup=True)
    return {"path":output_path,"objects":sorted(o.name for o in selected)}
