import bpy,json,math
from pathlib import Path
from mathutils import Vector,Matrix,Quaternion
r=Path(__file__).resolve().parents[1];b=r/'assets/characters/warrior_v3';out=b/'previews/equipment_grip';out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(b/'rigged/Warrior_V3_RIGGED_EQUIPPABLE.glb'))
a=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');grip=json.loads((b/'rigged/work/GRIP_POSE.json').read_text())
for name,(axis,angle) in grip.items():
 p=a.pose.bones[name];p.rotation_mode='QUATERNION';vec=Vector({'X':(1,0,0),'Y':(0,1,0),'Z':(0,0,1)}[axis]);p.rotation_quaternion=Quaternion(p.bone.matrix_local.to_3x3().inverted()@vec,math.radians(angle))
bpy.context.view_layer.update()
configs=[('Right','WarriorSword',Matrix(((0,0,1),(-1,0,0),(0,-1,0))),Vector((.034,-.409,.699))),('Left','WarriorShield',Matrix(((1,0,0),(0,0,-1),(0,1,0))),Vector((0,.409,.699)))]
for side,name,basis,pos in configs:
 existing=set(bpy.context.scene.objects);bpy.ops.import_scene.gltf(filepath=str(b/'equipment'/f'{name}.glb'));new=set(bpy.context.scene.objects)-existing
 root=bpy.data.objects.new(name+'_attachment',None);bpy.context.collection.objects.link(root)
 for o in new:
  if o.parent not in new:o.parent=root
 desired=basis.to_4x4();desired.translation=pos;bone=a.pose.bones['mixamorig:'+side+'Hand'];root.matrix_world=a.matrix_world@bone.matrix@bone.bone.matrix_local.inverted()@desired
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True;scene.render.resolution_x=768;scene.render.resolution_y=768;scene.render.resolution_percentage=100;scene.view_settings.view_transform='Standard';scene.view_settings.look='None'
world=bpy.data.worlds.new('Neutral');scene.world=world;world.use_nodes=True;world.node_tree.nodes['Background'].inputs['Color'].default_value=(.28,.28,.28,1);world.node_tree.nodes['Background'].inputs['Strength'].default_value=.7
for name,pos in [('A',(1,-1,2)),('B',(-1,1,1))]:
 d=bpy.data.lights.new(name,'AREA');o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=pos;d.energy=70;d.size=2
d=bpy.data.cameras.new('Camera');cam=bpy.data.objects.new('Camera',d);scene.collection.objects.link(cam);scene.camera=cam;d.type='ORTHO';d.ortho_scale=.155
for side,s in [('right',-1),('left',1)]:
 target=Vector((.025 if s<0 else -.005,s*.407,.703))
 for view,vec in {'top':(0,0,1),'palm':(0,0,-1),'side':(1,0,0),'3q':(1,s,-.5)}.items():
  cam.location=target+Vector(vec).normalized()*.5;cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(out/f'{side}_{view}.png');bpy.ops.render.render(write_still=True)
