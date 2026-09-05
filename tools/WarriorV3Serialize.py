"""Serialize Tripo quad FBX to GLB without character geometry edits."""
import bpy, sys, json, hashlib
from pathlib import Path
from datetime import datetime, timezone
source=Path(sys.argv[sys.argv.index('--')+1]).resolve()
target=source.with_suffix('.glb')
if target.exists(): raise RuntimeError('Refusing to overwrite existing GLB')
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(source),use_anim=False)
report={'source':source.name,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
        'blender':bpy.app.version_string,'timestamp':datetime.now(timezone.utc).isoformat(),
        'operation':'FBX import and GLB serialization only; no mesh edits, orientation override, scale normalization or rigging',
        'meshes':[],'images':[]}
for o in bpy.context.scene.objects:
    if o.type=='MESH':
        report['meshes'].append({'name':o.name,'vertices':len(o.data.vertices),'faces':len(o.data.polygons),'quads':sum(len(p.vertices)==4 for p in o.data.polygons),'triangles':sum(len(p.vertices)-2 for p in o.data.polygons)})
for i in bpy.data.images:
    report['images'].append({'name':i.name,'size':list(i.size),'filepath':i.filepath,'packed':bool(i.packed_file),'has_data':i.has_data})
print(json.dumps(report,indent=2),flush=True)
if not report['images'] or any(x['size'][0]==0 for x in report['images']):
    (source.parent/(source.stem+'_serialization_diagnostic.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
    raise RuntimeError('Missing image data: resolve textures before serialization')
bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB',export_animations=False,export_skins=False,export_morph=False)
report['glb_sha256']=hashlib.sha256(target.read_bytes()).hexdigest()
report['glb_bytes']=target.stat().st_size
(source.parent/(source.stem+'_serialization.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
print('SERIALIZED '+str(target),flush=True)
