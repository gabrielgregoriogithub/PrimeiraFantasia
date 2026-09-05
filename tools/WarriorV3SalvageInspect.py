"""Read-only diagnostic renders and bounded repair estimates, derived from original GLB."""
import bpy,bmesh,json,math
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parents[1];asset=root/'assets/characters/warrior_v3'
out=asset/'raw/salvage_diagnostic'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(asset/'raw/candidates/Warrior_V3_candidate_01.glb'))
obj=next(o for o in bpy.context.scene.objects if o.type=='MESH')
mesh=obj.data
bm=bmesh.new();bm.from_mesh(mesh)
fid=bm.faces.layers.int.new('source_face')
for f in bm.faces:f[fid]=f.index
bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=0.99951171875e-7)
comps=[];seen=set()
for v in bm.verts:
    if v in seen:continue
    todo=[v];seen.add(v);verts=[]
    while todo:
        x=todo.pop();verts.append(x)
        for e in x.link_edges:
            n=e.other_vert(x)
            if n not in seen:seen.add(n);todo.append(n)
    comps.append((verts,set(f for x in verts for f in x.link_faces)))
comps.sort(key=lambda x:len(x[0]),reverse=True)
report={}
for cid in [0,3,10,11,12,26,27,33,34,35]:
    fs=comps[cid][1]
    report[str(cid)]={'face_ids':sorted(f[fid] for f in fs),'area':sum(f.calc_area() for f in fs)}
report['branch_faces']=[]
for e in bm.edges:
    if len(e.link_faces)>2:
        report['branch_faces'].append({'edge_center':list((e.verts[0].co+e.verts[1].co)/2),
          'faces':[{'id':f[fid],'vertices':[list(v.co) for v in f.verts],'normal':list(f.normal),'area':f.calc_area()} for f in e.link_faces]})
# Quantify the central extra rear skirt tab. No edit occurs here.
torso_ids=set(report['0']['face_ids'])
region=[p for p in mesh.polygons if p.index in torso_ids and all(mesh.vertices[v].co.x<-.025 and -.055<mesh.vertices[v].co.y<.035 and mesh.vertices[v].co.z<-.055 for v in p.vertices)]
report['rear_center_hem_region']={'faces':len(region),'ids':[p.index for p in region],
    'fraction_all_faces':len(region)/len(mesh.polygons),'vertices':len(set(v for p in region for v in p.vertices))}
(out/'local_regions.json').write_text(json.dumps(report,indent=2),encoding='utf-8')

scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.render.resolution_x=1024;scene.render.resolution_y=1024;scene.render.resolution_percentage=100
scene.view_settings.view_transform='Standard';scene.view_settings.look='None'
world=bpy.data.worlds.new('Diagnostic World');scene.world=world;world.use_nodes=True
world.node_tree.nodes['Background'].inputs['Color'].default_value=(.28,.28,.28,1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value=.7
for name,pos,power in [('Key',(2,-3,4),90),('Fill',(-2,3,2),65),('Top',(0,0,4),35)]:
    d=bpy.data.lights.new(name,'AREA');o=bpy.data.objects.new(name,d);scene.collection.objects.link(o)
    o.location=pos;o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler();d.energy=power;d.shape='DISK';d.size=2
camdata=bpy.data.cameras.new('Diagnostic Camera');cam=bpy.data.objects.new('Diagnostic Camera',camdata);scene.collection.objects.link(cam)
scene.camera=cam;camdata.type='ORTHO';camdata.clip_start=.00001
def render(name,target,direction,scale):
    cam.location=Vector(target)+Vector(direction).normalized()*4
    cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();camdata.ortho_scale=scale
    scene.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True)
render('back_waist_original',(-.08,-.01,.0),(-1,0,.1),.36)
# Isolate existing component 0 for inspection. No original mesh is modified or saved.
obj.hide_render=True
ids=set(report['0']['face_ids']);polys=[p for p in mesh.polygons if p.index in ids]
sub=bpy.data.meshes.new('Diagnostic torso isolation');sub.from_pydata([v.co for v in mesh.vertices],[],[list(p.vertices) for p in polys]);sub.update()
sub.materials.append(mesh.materials[0]);uv=sub.uv_layers.new(name='UVMap')
normals=[]
for old,new in zip(polys,sub.polygons):
    new.use_smooth=old.use_smooth
    for oldloop,newloop in zip(old.loop_indices,new.loop_indices):
        uv.data[newloop].uv=mesh.uv_layers.active.data[oldloop].uv
        normals.append(mesh.corner_normals[oldloop].vector[:])
sub.normals_split_custom_set(normals)
temp=bpy.data.objects.new('DIAGNOSTIC ONLY torso without other components',sub);scene.collection.objects.link(temp);temp.matrix_world=obj.matrix_world.copy()
render('back_waist_underlying_surface',(-.08,-.01,.0),(-1,0,.1),.36)
red=bpy.data.materials.new('Diagnostic selection red');red.diffuse_color=(1,.025,.01,1);sub.materials.append(red)
for old,new in zip(polys,sub.polygons):
    if old.index in set(report['rear_center_hem_region']['ids']):new.material_index=1
render('back_hem_selection_diagnostic',(-.08,-.01,-.04),(-1,0,.1),.30)
temp.hide_render=True;obj.hide_render=False
render('mouth_topology_region',(.062,-.01,.308),(1,-.6,.3),.07)
bm.free()
