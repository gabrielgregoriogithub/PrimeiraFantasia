import bpy,json,math,hashlib
from pathlib import Path
from mathutils import Vector,Quaternion
r=Path(__file__).resolve().parents[1];b=r/'assets/characters/warrior_v3';w=b/'rigged/work';source=b/'rigged/Warrior_V3_RIGGED.glb'
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(source))
a=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');m=next(o for o in bpy.context.scene.objects if o.type=='MESH')
original_positions=[tuple(v.co) for v in m.data.vertices];original_bones=[x.name for x in a.data.bones]
spec={};grip={};finger_info=[]
bpy.context.view_layer.objects.active=a;bpy.ops.object.mode_set(mode='EDIT')
for side,s,offset in [('Right',-1,0),('Left',1,-.035)]:
 hand=a.data.edit_bones['mixamorig:'+side+'Hand']
 for digit,x,length,z in [('Pinky',.006,.033,.716),('Ring',.024,.046,.718),('Middle',.041,.052,.720),('Index',.058,.043,.717)]:
  x+=offset;root=.410
  ends=[root,root+length*.40,root+length*.74,root+length]
  parent=hand
  for j in range(3):
   name='mixamorig:'+side+'Hand'+digit+str(j+1);bone=a.data.edit_bones.new(name);bone.head=(x,s*ends[j],z);bone.tail=(x,s*ends[j+1],z);bone.parent=parent;bone.use_connect=j>0;parent=bone
   angle=([45,35,20] if digit=='Pinky' else [45,65,40])[j]
   grip[name]=['X',-s*angle]
  finger_info.append({'side':side,'s':s,'digit':digit,'x':x,'root':root,'ends':ends})
 points=[Vector((.053+offset,s*.385,.710)),Vector((.064+offset,s*.396,.689)),Vector((.074+offset,s*.403,.674)),Vector((.082+offset,s*.406,.671))]
 parent=hand
 for j in range(3):
  name='mixamorig:'+side+'HandThumb'+str(j+1);bone=a.data.edit_bones.new(name);bone.head=points[j];bone.tail=points[j+1];bone.parent=parent;bone.use_connect=j>0;parent=bone
  grip[name]=['Y',[50,80,0][j]]
 spec[side]={'thumb_points':[list(p) for p in points]}
bpy.ops.object.mode_set(mode='OBJECT')
for name in grip:m.vertex_groups.new(name=name)
changed=[]
def smooth(t):
 t=max(0,min(1,t));return t*t*(3-2*t)
def assign(v,weights):
 for g in list(v.groups):m.vertex_groups[g.group].remove([v.index])
 for name,weight in weights.items():
  if weight>1e-7:m.vertex_groups[name].add([v.index],weight,'REPLACE')
 changed.append(v.index)
for v in m.data.vertices:
 p=v.co
 if abs(p.y)<.374:continue
 side='Left' if p.y>0 else 'Right';s=1 if p.y>0 else -1;off=-.035 if s==1 else 0;hand='mixamorig:'+side+'Hand';t=s*p.y
 # Thumb is lateral to the index finger, proximal to the finger row.
 if p.x>.042+off and p.z<.711 and .374<t<.420:
  influence=smooth((.711-p.z)/.018)*smooth((p.x-(.042+off))/.018)*smooth((.420-t)/.010)*smooth((t-.374)/.014)
  blend=smooth((.689-p.z)/.014)
  assign(v,{hand:1-influence,'mixamorig:'+side+'HandThumb1':influence*(1-blend),'mixamorig:'+side+'HandThumb2':influence*blend});continue
 if t<.402 or p.x>.070+off:continue
 finger=min([f for f in finger_info if f['side']==side],key=lambda f:abs(p.x-f['x']))
 ends=finger['ends'];base='mixamorig:'+side+'Hand'+finger['digit'];influence=smooth((t-.402)/.010)
 weights={hand:1-influence,base+'1':influence}
 for j in [1,2]:
  blend=smooth((t-(ends[j]-.003))/.006)
  if blend>0:
   prev=base+str(j);nxt=base+str(j+1);mass=weights.get(prev,0);weights[prev]=mass*(1-blend);weights[nxt]=mass*blend
 assign(v,weights)
assert all(tuple(v.co)==original_positions[v.index] for v in m.data.vertices)
for p in a.pose.bones:p.rotation_mode='QUATERNION';p.rotation_quaternion=Quaternion()
bpy.ops.wm.save_as_mainfile(filepath=str(w/'Warrior_V3_RIGGED_EQUIPPABLE.blend'))
bpy.ops.export_scene.gltf(filepath=str(b/'rigged/Warrior_V3_RIGGED_EQUIPPABLE.glb'),export_format='GLB',export_animations=False)
audit={'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'bone_count_before':len(original_bones),'bone_count_after':len(a.data.bones),'added_bones':list(grip),'changed_weight_vertices':len(changed),'changed_vertex_indices':changed,'positions_changed':0,'triangles':sum(len(p.vertices)-2 for p in m.data.polygons),'finger_spec':finger_info,'thumb_spec':spec,'grip_rotations_model_axes_degrees':grip}
(w/'GRIP_RIG_AUDIT.json').write_text(json.dumps(audit,indent=2),encoding='utf-8')
(w/'GRIP_POSE.json').write_text(json.dumps(grip,indent=2),encoding='utf-8')
mapping=json.loads((b/'rigged/BONE_MAP.json').read_text(encoding='utf-8'));mapping['bone_count']=len(a.data.bones);mapping['bones']=[x.name for x in a.data.bones];mapping['finger_bones']={side:[n for n in grip if side in n] for side in ['Left','Right']};(b/'rigged/BONE_MAP_EQUIPPABLE.json').write_text(json.dumps(mapping,indent=2),encoding='utf-8')
print('GRIP_RIG_CREATED',len(a.data.bones),'changed_weights',len(changed))
