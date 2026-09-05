"""Bounded, auditable local cleanup from candidate_01 GLB only."""
import bpy,json,hashlib,math
from pathlib import Path
from mathutils import Vector
from datetime import datetime,timezone
root=Path(__file__).resolve().parents[1];asset=root/'assets/characters/warrior_v3'
source=asset/'raw/candidates/Warrior_V3_candidate_01.glb'
work=asset/'raw/work';work.mkdir(exist_ok=True)
target=work/'Warrior_V3_candidate_01_cleaned.glb'
blend=work/'Warrior_V3_candidate_01_cleanup.blend'
if target.exists() or blend.exists():raise RuntimeError('Working outputs exist; inspect before replacing')
regions=json.loads((asset/'raw/salvage_diagnostic/local_regions.json').read_text())
diag=json.loads((asset/'raw/salvage_diagnostic/diagnosis.json').read_text())
sha=hashlib.sha256(source.read_bytes()).hexdigest()
assert sha==diag['source_sha256']
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
obj=next(o for o in bpy.context.scene.objects if o.type=='MESH');original=obj.data
bpy.context.scene['salvage_source_sha256']=sha
bpy.context.scene['salvage_diagnosis']='SALVAGE_SAFE: limited local operations; final QA pending'
# Save the required isolated working copy before any edit.
bpy.ops.wm.save_as_mainfile(filepath=str(blend))
remove=set()
remove_components=[10,26,27,33,34,35]
for cid in remove_components:remove.update(regions[str(cid)]['face_ids'])
flap=next(s for s in diag['manifold_face_sheets'] if s['component']==0 and s['faces']==14)
remove.update(flap['face_ids'])
degen=[x['face'] for x in diag['degenerate_faces']]
assert len(degen)==1 and original.polygons[degen[0]].area==0
remove.update(degen)
assert len(remove)==361
torso=set(regions['0']['face_ids'])
positions=[v.co.copy() for v in original.vertices]
normals=[n.vector.copy() for n in original.corner_normals]
uvs=[u.uv.copy() for u in original.uv_layers.active.data]
move={}
# Only shorten the extra point between the two rear skirt panels; never move their borders.
for vid in set(v for p in original.polygons if p.index in torso for v in p.vertices):
    co=positions[vid]
    if co.x<-.025 and abs(co.y+.009)<.020 and co.z<-.095:
        move[vid]=Vector((co.x,co.y,-.095))
changed_geometry={p.index for p in original.polygons if any(v in move for v in p.vertices)}
assert all(original.polygons[i].center.x<-.025 and original.polygons[i].center.z<-.07 for i in changed_geometry)

def donor(point):
    p=min(original.polygons,key=lambda f:(f.center-Vector(point)).length_squared)
    uv=sum((uvs[l] for l in p.loop_indices),Vector((0,0)))/len(p.loop_indices)
    image=next(im for im in bpy.data.images if im.type=='IMAGE')
    x=min(image.size[0]-1,max(0,int(uv.x*image.size[0])));y=min(image.size[1]-1,max(0,int(uv.y*image.size[1])))
    offset=(y*image.size[0]+x)*4
    return uv,dict(face=p.index,position=list(p.center),uv=list(uv),rgba=list(image.pixels[offset:offset+4]))
belt_uv,belt_donor=donor((-.075,.041,.039))
pants_uv,pants_donor=donor((-.047,.065,-.19))
back_uv,back_donor=donor((-.086,.008,.151))
button_centers=[Vector(tuple((diag['components'][c]['min'][j]+diag['components'][c]['max'][j])/2 for j in range(3))) for c in (33,34,35)]
remap={}
for p in original.polygons:
    if p.index not in torso or p.index in remove:continue
    c=p.center
    if c.x<-.03 and .014<c.z<.066:
        remap[p.index]=('belt',belt_uv)
    elif c.x<-.025 and abs(c.y+.009)<.022 and -.13<c.z<-.071:
        remap[p.index]=('tab',pants_uv)
    elif any((c-b).length<.011 for b in button_centers):
        remap[p.index]=('button_ghost',back_uv)
affected=remove|changed_geometry|set(remap)
assert len(affected)/len(original.polygons)<.05, 'Abort: edit scope exceeds 5%'
kept=[p for p in original.polygons if p.index not in remove]
used=sorted(set(v for p in kept for v in p.vertices));lookup={old:new for new,old in enumerate(used)}
new=bpy.data.meshes.new('Warrior_V3_local_cleanup')
new.from_pydata([move.get(i,positions[i]) for i in used],[],[[lookup[v] for v in p.vertices] for p in kept]);new.update()
new.materials.append(original.materials[0]);newuv=new.uv_layers.new(name=original.uv_layers.active.name)
custom=[];normal_source_ids=[]
for old,p in zip(kept,new.polygons):
    p.use_smooth=old.use_smooth
    for oldloop,newloop in zip(old.loop_indices,p.loop_indices):
        if old.index in remap:
            base=remap[old.index][1]
            # Sample a tiny continuous existing color patch; source texture bytes stay untouched.
            co=positions[original.loops[oldloop].vertex_index]
            newuv.data[newloop].uv=base+Vector((co.y*.001,co.z*.001))
        else:newuv.data[newloop].uv=uvs[oldloop]
        custom.append(normals[oldloop] if old.index not in changed_geometry else p.normal)
        normal_source_ids.append(oldloop)
new.normals_split_custom_set(custom)
newuv=new.uv_layers.active
obj.data=new
bpy.context.view_layer.update()
protected=[(old,p) for old,p in zip(kept,new.polygons) if old.index not in changed_geometry and old.index not in remap]
max_pos=0.;max_uv=0.;max_normal=0.
for old,p in protected:
    for ol,nl in zip(old.loop_indices,p.loop_indices):
        max_pos=max(max_pos,(original.vertices[original.loops[ol].vertex_index].co-new.vertices[new.loops[nl].vertex_index].co).length)
        max_uv=max(max_uv,(uvs[ol]-newuv.data[nl].uv).length)
        max_normal=max(max_normal,(normals[ol]-new.corner_normals[nl].vector).length)
print('PROTECTED_DELTAS '+json.dumps(dict(position=max_pos,uv=max_uv,normal=max_normal)),flush=True)
assert max_pos==0 and max_uv==0 and max_normal<.001
bpy.context.scene['salvage_affected_faces']=len(affected)
bpy.context.scene['salvage_changed_percent']=len(affected)/len(original.polygons)*100
bpy.ops.wm.save_as_mainfile(filepath=str(blend))
bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB',export_animations=False,export_skins=False,export_morph=False)
report=dict(status='CLEANUP_EXPORTED_QA_PENDING',source=source.name,source_sha256=sha,
    completed_at=datetime.now(timezone.utc).isoformat(),glb_sha256=hashlib.sha256(target.read_bytes()).hexdigest(),
    vertices_before=len(original.vertices),vertices_after=len(new.vertices),triangles_before=len(original.polygons),triangles_after=len(new.polygons),
    removed_faces=sorted(remove),removed_components=remove_components,removed_flap_faces=flap['face_ids'],removed_degenerate=degen,
    moved_vertices={str(k):{'before':list(positions[k]),'after':list(v)} for k,v in move.items()},
    remapped_faces={str(k):v[0] for k,v in remap.items()},affected_source_faces=len(affected),affected_percent=len(affected)/len(original.polygons)*100,
    donors={'belt':belt_donor,'pants':pants_donor,'back':back_donor},
    protected_faces=len(protected),protected_max_position_delta=max_pos,protected_max_uv_delta=max_uv,protected_max_normal_delta=max_normal,
    texture_modified=False,material_count=len(new.materials),
    operations=['Remove isolated invented rear buckle, tongue, keeper and 3 buttons','Remove 14-face overlapping rear belt flap','Remove one zero-area eyebrow face','Local rear belt/button/tab UV mapping to original clean color texels','Shorten only narrow extra central rear hem point'],
    retained_nonmanifold='Mouth surface contact and boot hardware contact are protected, not floating junk; no global manifold operation',
    original_unchanged=hashlib.sha256(source.read_bytes()).hexdigest()==sha)
(work/'cleanup_operations.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps({k:report[k] for k in ['vertices_before','vertices_after','triangles_before','triangles_after','affected_source_faces','affected_percent','protected_max_position_delta','protected_max_uv_delta','protected_max_normal_delta','donors']},indent=2),flush=True)
