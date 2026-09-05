"""Verify serialized cleanup, source integrity, protected attributes and render changes."""
import bpy,json,hashlib,struct,math
from pathlib import Path
from collections import Counter
import numpy as np
root=Path(__file__).resolve().parents[1];asset=root/'assets/characters/warrior_v3';work=asset/'raw/work'
src=asset/'raw/candidates/Warrior_V3_candidate_01.glb';dst=work/'Warrior_V3_candidate_01_cleaned.glb'
ops=json.loads((work/'cleanup_operations.json').read_text())
def container(path):
    b=path.read_bytes();n=struct.unpack_from('<I',b,12)[0];j=json.loads(b[20:20+n]);offset=20+n+8
    ims=[]
    for im in j.get('images',[]):
        v=j['bufferViews'][im['bufferView']];start=offset+v.get('byteOffset',0)
        ims.append(hashlib.sha256(b[start:start+v['byteLength']]).hexdigest())
    return {'sha256':hashlib.sha256(b).hexdigest(),'images_sha256':ims,'materials':j.get('materials',[]),'skins':len(j.get('skins',[])),'animations':len(j.get('animations',[]))}
result={'original':container(src),'cleaned':container(dst)}
result['original_unchanged']=result['original']['sha256']==ops['source_sha256']
result['texture_bytes_identical']=result['original']['images_sha256']==result['cleaned']['images_sha256']
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(src));original=next(o for o in bpy.context.scene.objects if o.type=='MESH').data
bpy.ops.import_scene.gltf(filepath=str(dst));cleaned=[o.data for o in bpy.context.scene.objects if o.type=='MESH' and o.data!=original][0]
def key(mesh,p):
    return tuple(sorted(tuple(round(c,7) for c in mesh.vertices[v].co) for v in p.vertices))
lookup={key(cleaned,p):p for p in cleaned.polygons}
removed=set(ops['removed_faces']);mapped=set(map(int,ops['remapped_faces']));moved=set(map(int,ops['moved_vertices']))
protected=[p for p in original.polygons if p.index not in removed and p.index not in mapped and not any(v in moved for v in p.vertices)]
missing=[];uvmax=0.;normalmax=0.
for p in protected:
    other=lookup.get(key(original,p))
    if other is None:missing.append(p.index);continue
    for li in p.loop_indices:
        co=original.vertices[original.loops[li].vertex_index].co
        match=min(other.loop_indices,key=lambda l:(cleaned.vertices[cleaned.loops[l].vertex_index].co-co).length)
        uvmax=max(uvmax,(original.uv_layers.active.data[li].uv-cleaned.uv_layers.active.data[match].uv).length)
        normalmax=max(normalmax,(original.corner_normals[li].vector-cleaned.corner_normals[match].vector).length)
result['serialized_protected']={'faces':len(protected),'missing_or_position_changed':missing,'max_uv_delta':uvmax,'max_normal_vector_delta':normalmax}
# Detect inversion of edited hem triangles by reading final working mesh before export sorting.
bpy.ops.wm.open_mainfile(filepath=str(work/'Warrior_V3_candidate_01_cleanup.blend'))
obj=next(o for o in bpy.context.scene.objects if o.type=='MESH');new=obj.data
origdata=bpy.data.meshes.get('tripo_mesh_f0980b28')
# Original unused datablock may not survive save. Re-import authoritative source for this diagnostic.
bpy.ops.import_scene.gltf(filepath=str(src));old=next(o.data for o in bpy.context.scene.objects if o.type=='MESH' and o.data!=new)
kept=[p for p in old.polygons if p.index not in removed]
inversions=[]
for before,after in zip(kept,new.polygons):
    if any(v in moved for v in before.vertices):
        dot=before.normal.dot(after.normal)
        if dot<0:inversions.append({'source_face':before.index,'normal_dot':dot})
result['edited_hem_inverted_faces']=inversions
views=['front','back','left','right','3q_front','3q_back','isometric_game_camera','detail_head_front','detail_head_back','detail_hands_top']
result['renders']={}
for view in views:
    arrays=[]
    for name in ['candidate_01','candidate_01_cleaned']:
        im=bpy.data.images.load(str(asset/'previews/raw'/name/(view+'.png')),check_existing=False)
        arr=np.empty(im.size[0]*im.size[1]*4,dtype=np.float32);im.pixels.foreach_get(arr)
        arrays.append(arr.reshape(im.size[1],im.size[0],4)[:,:,:3]);bpy.data.images.remove(im)
    delta=np.abs(arrays[0]-arrays[1]);result['renders'][view]={'mean_absolute_rgb':float(delta.mean()),'p99_absolute_rgb':float(np.percentile(delta,99))}
result['critical_checks_pass']=result['original_unchanged'] and result['texture_bytes_identical'] and not missing and uvmax==0 and not inversions
(work/'cleanup_verification.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result,indent=2),flush=True)
