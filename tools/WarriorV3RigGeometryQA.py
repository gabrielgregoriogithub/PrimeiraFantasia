import bpy,json,hashlib
from pathlib import Path
from mathutils import Vector
from mathutils.kdtree import KDTree
r=Path(__file__).resolve().parents[1];b=r/'assets/characters/warrior_v3'
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(b/'raw/Warrior_V3_RAW.glb'));raw=next(o for o in bpy.context.scene.objects if o.type=='MESH')
height=max(v.co.z for v in raw.data.vertices)-min(v.co.z for v in raw.data.vertices)
kd=KDTree(len(raw.data.vertices))
for v in raw.data.vertices:kd.insert(Vector((v.co.x/height,v.co.y/height,(v.co.z+height/2)/height)),v.index)
kd.balance()
bpy.ops.import_scene.gltf(filepath=str(b/'rigged/work/Warrior_V3_Rig_Candidate.glb'));rig=next(o for o in bpy.context.scene.objects if o.type=='MESH' and o!=raw)
dist=[kd.find(rig.matrix_world@v.co)[2] for v in rig.data.vertices]
groups={g.index:g.name for g in rig.vertex_groups}
zones={}
for name,pred in {'hair_head':lambda p:p.z>.82,'scarf':lambda p:.63<p.z<.78 and p.x<-.04,'mouth':lambda p:.801<p.z<.815 and p.x>.04,'left_boot':lambda p:p.z<.12 and p.y>.07,'right_boot':lambda p:p.z<.12 and p.y<-.07}.items():
 totals={};count=0
 for v in rig.data.vertices:
  if pred(v.co):
   count+=1
   for g in v.groups:totals[groups[g.group]]=totals.get(groups[g.group],0)+g.weight
 zones[name]={'vertices':count,'average_weights':{k:val/count for k,val in totals.items()}}
result={'max_position_delta_after_uniform_normalization':max(dist),'mean_position_delta':sum(dist)/len(dist),'raw_sha256':hashlib.sha256((b/'raw/Warrior_V3_RAW.glb').read_bytes()).hexdigest(),'zones':zones}
(b/'rigged/work/geometry_weight_audit.json').write_text(json.dumps(result,indent=2),encoding='utf-8');print(json.dumps(result,indent=2))
