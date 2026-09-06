import bpy,bmesh,json
from pathlib import Path
r=Path(__file__).resolve().parents[1];b=r/'assets/characters/warrior_v3/equipment'
stats={}
for name in ['WarriorSword','WarriorShield']:
 bpy.ops.wm.open_mainfile(filepath=str(b/'work'/f'{name}.blend'))
 for mat in bpy.data.materials:
  p=mat.node_tree.nodes.get('Principled BSDF') if mat.use_nodes else None
  if p and 'silver' in mat.name.lower():
   c=(.19,.205,.22,1) if name=='WarriorSword' else (.12,.135,.145,1)
   p.inputs['Base Color'].default_value=c;p.inputs['Metallic'].default_value=.05;p.inputs['Roughness'].default_value=.94;mat.diffuse_color=c
 if name=='WarriorSword':
  for o in bpy.context.scene.objects:
   if o.type=='MESH' and (o.name=='Grip' or o.name.startswith('Leather wrap')):
    for v in o.data.vertices:v.co.x*=.79;v.co.y*=.79
  blade=bpy.data.objects['Blade']
  for v in blade.data.vertices:
   if v.co.z>.454:v.co.x=0;v.co.y=0
  bm=bmesh.new();bm.from_mesh(blade.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-8);bmesh.ops.dissolve_degenerate(bm,dist=1e-9,edges=list(bm.edges));bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(blade.data);bm.free()
 else:
  strap=bpy.data.objects.get('Rear forearm strap')
  if strap:bpy.data.objects.remove(strap,do_unlink=True)
  # Clearance behind the shield for curled fingers; handle pivot stays fixed.
  for o in bpy.context.scene.objects:
   if o.type=='MESH' and o.name!='Rear hand grip':o.location.y-=.020
  wood_material=next(m for m in bpy.data.materials if 'wood' in m.name.lower())
  for x in [-.040,.040]:
   bpy.ops.mesh.primitive_cube_add(size=1,location=(x,-.016,0))
   mount=bpy.context.object;mount.name='Rear grip mounting block';mount.dimensions=(.014,.044,.020);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);mount.data.materials.append(wood_material)
   bevel=mount.modifiers.new('Rounded leather mount edges','BEVEL');bevel.width=.002;bevel.segments=2;bpy.ops.object.modifier_apply(modifier=bevel.name)
  img=bpy.data.images.load(str(b/'textures/shield_wood_generated.png'));img.scale(1024,1024);img.filepath_raw=str(b/'textures/shield_wood_1024.png');img.file_format='PNG';img.save();img.pack()
  mat=next(m for m in bpy.data.materials if 'wood' in m.name.lower());tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=img;p=mat.node_tree.nodes.get('Principled BSDF');mat.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])
  for o in bpy.context.scene.objects:
   if o.type!='MESH' or mat not in list(o.data.materials):continue
   uv=o.data.uv_layers.new(name='EquipmentUV')
   for loop in o.data.loops:
    co=o.data.vertices[loop.vertex_index].co
    uv.data[loop.index].uv=(co.x/.235+.5,(co.z+.185)/.36) if o.name=='Shield body' else (.13+co.x*.05,.42+co.z*.05)
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
 # Correct unambiguous winding only on these independently modeled props.
 for o in meshes:
  bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
 bpy.ops.wm.save_as_mainfile(filepath=str(b/'work'/f'{name}_finished.blend'))
 bpy.ops.export_scene.gltf(filepath=str(b/f'{name}.glb'),export_format='GLB',export_animations=False)
 stats[name]={'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes),'materials':len({m.name for o in meshes for m in o.data.materials}),'textures':[[1024,1024]] if name=='WarriorShield' else [],'skinned':False}
(b/'work/equipment_finished_stats.json').write_text(json.dumps(stats,indent=2),encoding='utf-8');print(json.dumps(stats))
