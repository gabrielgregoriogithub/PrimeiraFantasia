import bpy,json
from pathlib import Path
from mathutils import Vector
r=Path(__file__).resolve().parents[1];b=r/'assets/characters/warrior_v3';out=b/'equipment/work/hand_diagnostic';out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(b/'rigged/Warrior_V3_RIGGED.glb'))
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=16;scene.cycles.use_denoising=True;scene.render.resolution_x=768;scene.render.resolution_y=768;scene.render.resolution_percentage=100;scene.view_settings.view_transform='Standard';scene.view_settings.look='None'
world=bpy.data.worlds.new('Neutral');scene.world=world;world.use_nodes=True;world.node_tree.nodes['Background'].inputs['Color'].default_value=(.28,.28,.28,1);world.node_tree.nodes['Background'].inputs['Strength'].default_value=.7
for name,pos in [('A',(0,-1,2)),('B',(1,1,1))]:
 d=bpy.data.lights.new(name,'AREA');o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=pos;d.energy=70;d.size=2
d=bpy.data.cameras.new('Camera');cam=bpy.data.objects.new('Camera',d);scene.collection.objects.link(cam);scene.camera=cam;d.type='ORTHO';d.ortho_scale=.16
m=next(o for o in scene.objects if o.type=='MESH');data={}
for side,sgn in [('right',-1),('left',1)]:
 target=Vector((.025,sgn*.42,.70));cam.location=target+Vector((0,0,.5));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(out/(side+'_top.png'));bpy.ops.render.render(write_still=True)
 verts=[v for v in m.data.vertices if sgn*v.co.y>.395];data[side]=[list(v.co) for v in verts]
(out/'hand_vertices.json').write_text(json.dumps(data),encoding='utf-8')
