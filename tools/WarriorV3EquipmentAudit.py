import bpy,bmesh,json,hashlib
from pathlib import Path
from mathutils.kdtree import KDTree
r=Path(__file__).resolve().parents[1]/'assets/characters/warrior_v3'
def inspect(path):
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.ops.import_scene.gltf(filepath=str(path))
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
 verts=[tuple(o.matrix_world@v.co) for o in meshes for v in o.data.vertices]
 bones={}
 for a in [o for o in bpy.context.scene.objects if o.type=='ARMATURE']:
  bones={b.name:{'parent':b.parent.name if b.parent else None,'matrix':[v for row in b.matrix_local for v in row]} for b in a.data.bones}
 topology={}
 for o in meshes:
  bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7)
  topology[o.name]={'boundary_edges':sum(e.is_boundary for e in bm.edges),'multi_face_edges':sum(len(e.link_faces)>2 for e in bm.edges),'degenerate_faces':sum(f.calc_area()<1e-12 for f in bm.faces)};bm.free()
 return verts,bones,topology
v0,b0,t0=inspect(r/'rigged/Warrior_V3_RIGGED.glb')
v1,b1,t1=inspect(r/'rigged/Warrior_V3_RIGGED_EQUIPPABLE.glb')
kd=KDTree(len(v0))
for i,v in enumerate(v0):kd.insert(v,i)
kd.balance()
out={'original_rig_sha256':hashlib.sha256((r/'rigged/Warrior_V3_RIGGED.glb').read_bytes()).hexdigest(),'raw_sha256':hashlib.sha256((r/'raw/Warrior_V3_RAW.glb').read_bytes()).hexdigest(),'vertices_before':len(v0),'vertices_after':len(v1),'rest_position_max_distance':max(kd.find(v)[2] for v in v1),'original_bones_preserved':all(b1.get(k)==v for k,v in b0.items()),'bones_before':len(b0),'bones_after':len(b1),'equipment':{}}
out['original_bone_matrix_max_delta']=max(abs(x-y) for k in b0 for x,y in zip(b0[k]['matrix'],b1[k]['matrix']))
out['original_bone_parents_preserved']=all(b0[k]['parent']==b1[k]['parent'] for k in b0)
out['original_bones_preserved_within_1e_5']=out['original_bone_parents_preserved'] and out['original_bone_matrix_max_delta']<1e-5
for name in ['WarriorSword','WarriorShield']:
 v,b,t=inspect(r/'equipment'/f'{name}.glb');out['equipment'][name]={'vertices':len(v),'bones':len(b),'topology_by_object':t}
(r/'equipment/work/SERIALIZED_AUDIT.json').write_text(json.dumps(out,indent=2))
print(json.dumps(out))
