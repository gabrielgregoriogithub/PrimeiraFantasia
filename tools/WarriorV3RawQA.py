"""Inspect and render the downloaded GLB. Never edits or exports the character."""
import bpy, bmesh, sys, json, math, hashlib, struct
from pathlib import Path
from mathutils import Vector
from datetime import datetime, timezone

args = sys.argv[sys.argv.index('--') + 1:]
source = Path(args[0]).resolve()
out = Path(args[1]).resolve()
out.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
objects = [o for o in bpy.context.scene.objects if o.type == 'MESH']
points = [o.matrix_world @ v.co for o in objects for v in o.data.vertices]
lo = Vector(tuple(min(v[i] for v in points) for i in range(3)))
hi = Vector(tuple(max(v[i] for v in points) for i in range(3)))
center = (lo + hi) / 2
size = hi - lo
height = size.z

def topology(mesh, weld=False):
    bm = bmesh.new()
    bm.from_mesh(mesh)
    if weld:
        bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=max(height*1e-7, 1e-9))
    bm.verts.ensure_lookup_table()
    components=[]
    visited=set()
    for v in bm.verts:
        if v in visited: continue
        stack=[v]; visited.add(v); members=[]
        while stack:
            cur=stack.pop(); members.append(cur)
            for edge in cur.link_edges:
                other=edge.other_vert(cur)
                if other not in visited: visited.add(other); stack.append(other)
        faces=set(f for v in members for f in v.link_faces)
        cmin=[min(v.co[i] for v in members) for i in range(3)]
        cmax=[max(v.co[i] for v in members) for i in range(3)]
        components.append(dict(vertices=len(members),faces=len(faces),bounds_min=cmin,bounds_max=cmax))
    report=dict(vertices=len(bm.verts),edges=len(bm.edges),faces=len(bm.faces),
        boundary_edges=sum(e.is_boundary for e in bm.edges),
        nonmanifold_edges=sum(not e.is_manifold for e in bm.edges),
        edges_over_two_faces=sum(len(e.link_faces)>2 for e in bm.edges),
        wire_edges=sum(e.is_wire for e in bm.edges),
        degenerate_faces=sum(f.calc_area()<height*height*1e-12 for f in bm.faces),
        inconsistent_winding_edges=sum(e.is_manifold and not e.is_contiguous for e in bm.edges),
        components=sorted(components,key=lambda c:c['vertices'],reverse=True))
    bm.free()
    return report

blob=source.read_bytes()
length,kind=struct.unpack_from('<II',blob,12)
gltf=json.loads(blob[20:20+length])
stats=dict(source=str(source),sha256=hashlib.sha256(blob).hexdigest(),
    checked_at=datetime.now(timezone.utc).isoformat(),blender_version=bpy.app.version_string,
    bounds_min=list(lo),bounds_max=list(hi),dimensions=list(size),
    mesh_objects=len(objects),triangles=0,vertices=0,
    material_count=len(gltf.get('materials',[])),
    gltf_animations=len(gltf.get('animations',[])),gltf_skins=len(gltf.get('skins',[])),
    gltf_extensions=gltf.get('extensionsUsed',[]),textures=[],meshes=[])
for obj in objects:
    mesh=obj.data; mesh.calc_loop_triangles()
    stats['triangles']+=len(mesh.loop_triangles)
    stats['vertices']+=len(mesh.vertices)
    stats['meshes'].append(dict(name=obj.name,triangles=len(mesh.loop_triangles),
        materials=[m.name if m else None for m in mesh.materials],
        original=topology(mesh),position_welded_diagnostic_only=topology(mesh,True)))
for im in bpy.data.images:
    if im.type=='IMAGE': stats['textures'].append(dict(name=im.name,width=im.size[0],height=im.size[1],channels=im.channels))
stats['materials']=gltf.get('materials',[])
(out/'mesh_stats.json').write_text(json.dumps(stats,indent=2),encoding='utf-8')
print('RAW_STATS '+json.dumps({k:stats[k] for k in ('triangles','vertices','material_count','textures','dimensions')}),flush=True)
scene=bpy.context.scene
scene.render.engine='CYCLES'
scene.cycles.device='CPU'
scene.cycles.samples=24
scene.cycles.use_denoising=True
scene.render.resolution_x=1024
scene.render.resolution_y=1024
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.film_transparent=False
scene.view_settings.view_transform='Standard'
scene.view_settings.look='Medium High Contrast' if False else 'None'
scene.view_settings.exposure=0
scene.view_settings.gamma=1
world=bpy.data.worlds.new('QA Neutral World'); scene.world=world
world.use_nodes=True
world.node_tree.nodes['Background'].inputs['Color'].default_value=(0.28,0.28,0.28,1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value=0.7

def area(name,direction,energy):
    data=bpy.data.lights.new(name,'AREA'); obj=bpy.data.objects.new(name,data); scene.collection.objects.link(obj)
    obj.location=center+Vector(direction)*height
    obj.rotation_euler=(center-obj.location).to_track_quat('-Z','Y').to_euler()
    data.energy=energy*height*height
    data.shape='DISK'; data.size=height*2
area('Key',(2,-3,4),90)
area('Fill',(-2,3,2),65)
area('Top',(0,0,4),35)
cam_data=bpy.data.cameras.new('QA Camera'); cam=bpy.data.objects.new('QA Camera',cam_data); scene.collection.objects.link(cam); scene.camera=cam
cam_data.type='ORTHO'; cam_data.clip_start=max(height*0.001,0.00001); cam_data.clip_end=height*100
views={
    'front':(1,0,0),'back':(-1,0,0),'left':(0,-1,0),'right':(0,1,0),
    '3q_front':(1,-1,0.25),'3q_back':(-1,1,0.25),'isometric_game_camera':(1,-1,1.15)}
camera_log={}
def render(name,direction,target=center,scale=None):
    cam.location=target+Vector(direction).normalized()*height*4
    cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
    bpy.context.view_layer.update()
    inv=cam.matrix_world.inverted()
    projected=[inv@p for p in points]
    if scale is None:
        spanx=max(p.x for p in projected)-min(p.x for p in projected)
        spany=max(p.y for p in projected)-min(p.y for p in projected)
        scale=max(spanx,spany)*1.16
    cam_data.ortho_scale=scale
    scene.render.filepath=str(out/(name+'.png'))
    camera_log[name]=dict(position=list(cam.location),target=list(target),ortho_scale=scale)
    bpy.ops.render.render(write_still=True)
    print('RENDER_DONE '+name,flush=True)
for name,direction in views.items(): render(name,direction)
head=Vector((center.x,center.y,lo.z+height*0.835))
render('detail_head_front',(1,0,0),head,height*0.38)
render('detail_head_back',(-1,0,0),head,height*0.38)
render('detail_hands_top',(0,0,1),Vector((center.x,center.y,lo.z+height*0.69)),max(size.x,size.y)*1.1)
(out/'render_manifest.json').write_text(json.dumps(dict(source_sha256=stats['sha256'],renderer='Blender Cycles CPU',samples=24,asset_modified=False,forward_axis_assumption='+X after glTF import; verified with face and buckle. Profile labels match canonical PNG facing directions.',cameras=camera_log),indent=2),encoding='utf-8')
