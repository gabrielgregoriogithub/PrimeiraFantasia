import bpy,json,math,sys
from pathlib import Path
from mathutils import Vector,Quaternion
root=Path(__file__).resolve().parents[1];b=root/'assets/characters/warrior_v3';out=b/'previews/rig'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(b/'rigged/work/Warrior_V3_Rig_Candidate.glb'))
a=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');m=next(o for o in bpy.context.scene.objects if o.type=='MESH')
poses={
'REST_TPOSE':{},
'COMBAT_STANCE':{'LeftArm':('X',-45),'RightArm':('X',45),'LeftForeArm':('Z',-45),'RightForeArm':('Z',45),'LeftUpLeg':('Y',-10),'RightUpLeg':('Y',-10),'LeftLeg':('Y',20),'RightLeg':('Y',20),'LeftFoot':('Y',-10),'RightFoot':('Y',-10)},
'RIGHT_ARM_FORWARD':{'RightArm':('Z',70),'RightForeArm':('Z',20)},
'LEFT_ARM_FORWARD':{'LeftArm':('Z',-70),'LeftForeArm':('Z',-20)},
'BOTH_ARMS_DOWN':{'LeftArm':('X',-75),'RightArm':('X',75)},
'KNEE_BEND':{'LeftUpLeg':('Y',-35),'LeftLeg':('Y',70),'LeftFoot':('Y',-35)},
'TORSO_TWIST_LEFT':{'Spine':('Z',10),'Spine1':('Z',10),'Spine2':('Z',10)},
'TORSO_TWIST_RIGHT':{'Spine':('Z',-10),'Spine1':('Z',-10),'Spine2':('Z',-10)},
'HEAD_LEFT':{'Head':('Z',45)},'HEAD_RIGHT':{'Head':('Z',-45)}}
(b/'rigged/work/TEST_POSES.json').write_text(json.dumps(poses,indent=2),encoding='utf-8')
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.render.resolution_x=768;scene.render.resolution_y=768;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.view_settings.view_transform='Standard';scene.view_settings.look='None'
world=bpy.data.worlds.new('QA');scene.world=world;world.use_nodes=True;world.node_tree.nodes['Background'].inputs['Color'].default_value=(.28,.28,.28,1);world.node_tree.nodes['Background'].inputs['Strength'].default_value=.7
center=Vector((0,0,.5))
for name,pos,power in [('Key',(2,-3,4),90),('Fill',(-2,3,2),65),('Top',(0,0,4),35)]:
 d=bpy.data.lights.new(name,'AREA');o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=center+Vector(pos);o.rotation_euler=(center-o.location).to_track_quat('-Z','Y').to_euler();d.energy=power;d.shape='DISK';d.size=2
d=bpy.data.cameras.new('Camera');cam=bpy.data.objects.new('Camera',d);scene.collection.objects.link(cam);scene.camera=cam;d.type='ORTHO';d.ortho_scale=1.17
stats={}
for name,changes in poses.items():
 for p in a.pose.bones:p.rotation_mode='QUATERNION';p.rotation_quaternion=Quaternion();p.location=(0,0,0)
 for bone,(axis,degrees) in changes.items():
  p=a.pose.bones['mixamorig:'+bone];axisv=Vector({'X':(1,0,0),'Y':(0,1,0),'Z':(0,0,1)}[axis]);local=p.bone.matrix_local.to_3x3().inverted()@axisv;p.rotation_quaternion=Quaternion(local,math.radians(degrees))
 bpy.context.view_layer.update();ev=m.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh();pts=[ev.matrix_world@v.co for v in mesh.vertices];ev.to_mesh_clear()
 stats[name]={'min':[min(p[i] for p in pts) for i in range(3)],'max':[max(p[i] for p in pts) for i in range(3)],'finite':all(math.isfinite(c) for p in pts for c in p)}
 folder=out/name;folder.mkdir(parents=True,exist_ok=True)
 for view,vec in {'front':(1,0,0),'back':(-1,0,0),'left':(0,-1,0),'right':(0,1,0),'3q':(1,-1,.25)}.items():
  if (folder/(view+'.png')).exists():continue
  cam.location=center+Vector(vec).normalized()*4;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(folder/(view+'.png'));bpy.ops.render.render(write_still=True)
 print('POSE_DONE '+name,flush=True)
(b/'rigged/work/pose_stats.json').write_text(json.dumps(stats,indent=2),encoding='utf-8')
