import bpy, json, hashlib, sys
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parents[1]
b=root/'assets/characters/warrior_v3'
source=Path(sys.argv[sys.argv.index('--')+1]) if '--' in sys.argv else b/'raw/Warrior_V3_RAW.glb'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
points=[o.matrix_world@v.co for o in meshes for v in o.data.vertices]
lo=[min(p[i] for p in points) for i in range(3)];hi=[max(p[i] for p in points) for i in range(3)]
data={'source':str(source),'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'bounds_min':lo,'bounds_max':hi,'center':[(lo[i]+hi[i])/2 for i in range(3)],'dimensions':[hi[i]-lo[i] for i in range(3)],'meshes':[],'armatures':[]}
for o in meshes:
 data['meshes'].append({'name':o.name,'vertices':len(o.data.vertices),'triangles':sum(len(f.vertices)-2 for f in o.data.polygons),'vertex_groups':[g.name for g in o.vertex_groups],'unweighted':sum(not v.groups for v in o.data.vertices)})
for a in [o for o in bpy.context.scene.objects if o.type=='ARMATURE']:
 data['armatures'].append({'name':a.name,'matrix':list(map(list,a.matrix_world)),'bones':[{'name':x.name,'parent':x.parent.name if x.parent else None,'head':list(a.matrix_world@x.head_local),'tail':list(a.matrix_world@x.tail_local)} for x in a.data.bones]})
out=b/'rigged/work';out.mkdir(exist_ok=True,parents=True)
(out/(source.stem+'_inspection.json')).write_text(json.dumps(data,indent=2),encoding='utf-8')
print(json.dumps(data,indent=2))
