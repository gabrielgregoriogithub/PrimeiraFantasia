"""Read-only spatial diagnosis of candidate_01; no edited mesh is saved."""
import bpy,bmesh,json,hashlib
from pathlib import Path
from datetime import datetime,timezone
root=Path(__file__).resolve().parents[1]
asset=root/'assets/characters/warrior_v3'
source=asset/'raw/candidates/Warrior_V3_candidate_01.glb'
out=asset/'raw/salvage_diagnostic'
out.mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
obj=next(o for o in bpy.context.scene.objects if o.type=='MESH')
bm=bmesh.new();bm.from_mesh(obj.data)
bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=0.99951171875e-7)
bm.verts.ensure_lookup_table();bm.edges.ensure_lookup_table();bm.faces.ensure_lookup_table()
bm.verts.index_update();bm.edges.index_update();bm.faces.index_update()
components=[];seen=set()
for v in bm.verts:
    if v in seen:continue
    stack=[v];seen.add(v);verts=[]
    while stack:
        c=stack.pop();verts.append(c)
        for e in c.link_edges:
            n=e.other_vert(c)
            if n not in seen:seen.add(n);stack.append(n)
    faces=set(f for x in verts for f in x.link_faces)
    edges=set(e for x in verts for e in x.link_edges)
    points=[obj.matrix_world@x.co for x in verts]
    components.append(dict(verts=verts,faces=faces,edges=edges,points=points))
components.sort(key=lambda c:len(c['verts']),reverse=True)
rows=[];lookup={}
for i,c in enumerate(components):
    for v in c['verts']:lookup[v]=i
    rows.append(dict(id=i,vertices=len(c['verts']),faces=len(c['faces']),
        min=[min(v[j] for v in c['points']) for j in range(3)],max=[max(v[j] for v in c['points']) for j in range(3)],
        boundary_edges=sum(e.is_boundary for e in c['edges']),branch_edges=sum(len(e.link_faces)>2 for e in c['edges']),
        degenerate_faces=sum(f.calc_area()<0.99951171875**2*1e-12 for f in c['faces'])))
bad=[]
for e in bm.edges:
    if len(e.link_faces)>2:
        bad.append(dict(edge=e.index,component=lookup[e.verts[0]],center=list(obj.matrix_world@((e.verts[0].co+e.verts[1].co)/2)),
          vertices=[list(v.co) for v in e.verts],faces=[f.index for f in e.link_faces],face_areas=[f.calc_area() for f in e.link_faces]))
deg=[dict(face=f.index,component=lookup[f.verts[0]],center=list(obj.matrix_world@f.calc_center_median()),area=f.calc_area(),vertices=[list(v.co) for v in f.verts]) for f in bm.faces if f.calc_area()<0.99951171875**2*1e-12]
boundaries=[];seen_edges=set()
for e in bm.edges:
    if not e.is_boundary or e in seen_edges:continue
    stack=[e];seen_edges.add(e);group=[]
    while stack:
        c=stack.pop();group.append(c)
        for v in c.verts:
            for n in v.link_edges:
                if n.is_boundary and n not in seen_edges:seen_edges.add(n);stack.append(n)
    verts=set(v for x in group for v in x.verts)
    points=[obj.matrix_world@v.co for v in verts]
    boundaries.append(dict(id=len(boundaries),component=lookup[e.verts[0]],edges=len(group),
        min=[min(p[j] for p in points) for j in range(3)],max=[max(p[j] for p in points) for j in range(3)],
        simple_loop=all(sum(x.is_boundary for x in v.link_edges)==2 for v in verts)))
report=dict(source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),time=datetime.now(timezone.utc).isoformat(),
    source_vertices=len(obj.data.vertices),position_vertices=len(bm.verts),triangles=len(bm.faces),
    components=rows,branch_edges=bad,degenerate_faces=deg,boundary_groups=boundaries,
    inconsistent_winding_edges=sum(e.is_manifold and not e.is_contiguous for e in bm.edges),
    coordinate_system='world Blender: +X front, -X back, Z up; character height about 1; origin mid-height',
    diagnostic_only=True,mesh_saved=False)
face_seen=set();sheets=[]
for f in bm.faces:
    if f in face_seen:continue
    stack=[f];face_seen.add(f);sheet=[]
    while stack:
        cur=stack.pop();sheet.append(cur)
        for e in cur.edges:
            if not e.is_manifold:continue
            for n in e.link_faces:
                if n not in face_seen:face_seen.add(n);stack.append(n)
    verts=set(v for face in sheet for v in face.verts)
    sheets.append(dict(component=lookup[f.verts[0]],faces=len(sheet),face_ids=[x.index for x in sheet],
        min=[min(v.co[j] for v in verts) for j in range(3)],max=[max(v.co[j] for v in verts) for j in range(3)]))
report['manifold_face_sheets']=sorted(sheets,key=lambda s:s['faces'],reverse=True)
(out/'diagnosis.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2),flush=True)
bm.free()
