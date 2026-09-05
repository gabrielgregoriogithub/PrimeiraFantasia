import bpy,json,math,hashlib
from pathlib import Path
from mathutils import Vector,Quaternion
from mathutils.kdtree import KDTree
root=Path(__file__).resolve().parents[1];b=root/'assets/characters/warrior_v3';w=b/'rigged/work'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(w/'tripo/Warrior_V3_Tripo_Rig.glb'))
a=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
m=next(o for o in bpy.context.scene.objects if o.type=='MESH' and len(o.data.vertices)>1000)
for o in list(bpy.context.scene.objects):
 if o.type=='MESH' and o!=m: bpy.data.objects.remove(o,do_unlink=True)
pts=[m.matrix_world@v.co for v in m.data.vertices]
lo=Vector([min(p[i] for p in pts) for i in range(3)]);hi=Vector([max(p[i] for p in pts) for i in range(3)])
print('BODY BOUNDS',list(lo),list(hi),'MATRIX',list(map(list,m.matrix_world)))
# Keep the supplied skeleton; normalize the whole asset using a parent, never hips.
norm=bpy.data.objects.new('Warrior_V3_Global',None);bpy.context.collection.objects.link(norm)
for o in list(bpy.context.scene.objects):
 if o!=norm and o.parent is None: o.parent=norm
norm.location.z=-lo.z
# Work at original ~1-unit body height. Godot preview uses a uniform display scale.
mapping={'root':'Root','hips':'mixamorig:Hips','spine':'mixamorig:Spine','chest':'mixamorig:Spine2','neck':'mixamorig:Neck','head':'mixamorig:Head'}
for side,word in [('l','Left'),('r','Right')]:
 for k,v in [('upper_arm','Arm'),('forearm','ForeArm'),('hand','Hand'),('thigh','UpLeg'),('shin','Leg'),('foot','Foot')]: mapping[k+'_'+side]='mixamorig:'+word+v
(b/'rigged/BONE_MAP.json').write_text(json.dumps({'method':'Tripo Mixamo specification','bone_count':len(a.data.bones),'mapping':mapping,'normalization':'Whole-asset parent; Blender +X forward, +Z up; Godot +X forward, +Y up','bones':[x.name for x in a.data.bones]},indent=2),encoding='utf-8')
bpy.ops.wm.save_as_mainfile(filepath=str(w/'Warrior_V3_RIGGED.blend'))
bpy.ops.export_scene.gltf(filepath=str(w/'Warrior_V3_Rig_Candidate.glb'),export_format='GLB',export_animations=False)
print('PREPARED',len(a.data.bones))
