"""Build Warrior3D_v2: a cohesive, skinned, static-pose production base.

The body is generated as one continuous manifold with Blender's Skin/Subdivision
workflow, then deformed by a humanoid Armature through vertex groups. Clothing,
hair and scarf are separate authored meshes but use the same skeleton/weights.
"""
import bpy, math, os, sys
from mathutils import Vector

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "warrior_v2_base.glb"
bpy.ops.wm.read_factory_settings(use_empty=True)

def material(name, color, rough=.78, metallic=0.0):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Roughness'].default_value=rough; p.inputs['Metallic'].default_value=metallic
    return m

SKIN=material('Skin_Warm',(.78,.39,.22),.88); HAIR=material('Hair_Blue',(.025,.16,.52),.82)
SCARF=material('Scarf_Red',(.68,.025,.035),.9); LEATHER=material('Leather_Brown',(.22,.075,.025),.86)
DARK=material('Pants_Dark',(.025,.035,.065),.92); METAL=material('Metal_Light',(.48,.60,.72),.55,.22)
CLOTH=material('Headband_Light',(.82,.84,.78),.9); EYE=material('Brows_Dark',(.015,.035,.09),.9)

# Armature: Blender Z-up; Godot import supplies Skeleton3D with the same names.
bpy.ops.object.armature_add(enter_editmode=True, location=(0,0,0))
arm=bpy.context.object; arm.name='WarriorV2_Armature'; eb=arm.data.edit_bones
eb.remove(eb[0])
def bone(name, head, tail, parent=None):
    b=eb.new(name); b.head=head; b.tail=tail
    if parent: b.parent=eb[parent]; b.use_connect=(Vector(head)-Vector(eb[parent].tail)).length < .001
    return b
bone('Root',(0,0,0),(0,0,.12)); bone('Hips',(0,0,.72),(0,0,.91),'Root')
bone('Spine',(0,0,.91),(0,0,1.16),'Hips'); bone('Chest',(0,0,1.16),(0,0,1.40),'Spine')
bone('Neck',(0,0,1.40),(0,0,1.52),'Chest'); bone('Head',(0,0,1.52),(0,0,1.78),'Neck')
for side,s in [('L',1),('R',-1)]:
    bone('UpperArm_'+side,(s*.17,0,1.36),(s*.48,0,1.27),'Chest')
    bone('Forearm_'+side,(s*.48,0,1.27),(s*.69,-.015,1.08),'UpperArm_'+side)
    bone('Hand_'+side,(s*.69,-.015,1.08),(s*.79,-.04,1.02),'Forearm_'+side)
    bone('Thigh_'+side,(s*.14,0,.76),(s*.16,0,.43),'Hips')
    bone('Shin_'+side,(s*.16,0,.43),(s*.15,0,.12),'Thigh_'+side)
    bone('Foot_'+side,(s*.15,0,.12),(s*.15,-.25,.08),'Shin_'+side)
bone('WeaponSocket_R',(-.79,-.04,1.02),(-.88,-.08,.94),'Hand_R')
bpy.ops.object.mode_set(mode='OBJECT')

# One connected body mesh. Branches are continuous at shoulders and pelvis.
points=[
 (0,0,.74),(0,0,.95),(0,0,1.18),(0,0,1.38),(0,0,1.49),(0,0,1.66),
 (.17,0,1.34),(.48,0,1.27),(.69,-.015,1.08),(.78,-.04,1.02),
 (-.17,0,1.34),(-.48,0,1.27),(-.69,-.015,1.08),(-.78,-.04,1.02),
 (.14,0,.73),(.16,0,.43),(.15,0,.13),(.15,-.22,.08),
 (-.14,0,.73),(-.16,0,.43),(-.15,0,.13),(-.15,-.22,.08)]
edges=[(0,1),(1,2),(2,3),(3,4),(4,5),(3,6),(6,7),(7,8),(8,9),(3,10),(10,11),(11,12),(12,13),
       (0,14),(14,15),(15,16),(16,17),(0,18),(18,19),(19,20),(20,21)]
mesh=bpy.data.meshes.new('BodyMesh'); mesh.from_pydata(points,edges,[]); body=bpy.data.objects.new('BodyMesh',mesh)
bpy.context.collection.objects.link(body); body.data.materials.append(SKIN)
skin=body.modifiers.new('Cohesive anatomy','SKIN'); radii=[(.23,.18,.18),(.24,.17,.20),(.29,.18,.22),(.34,.19,.20),(.11,.10,.10),(.18,.17,.20),
(.18,.17,.18),(.14,.13,.15),(.115,.105,.13),(.13,.115,.13),(.18,.17,.18),(.14,.13,.15),(.115,.105,.13),(.13,.115,.13),
(.18,.18,.21),(.16,.15,.18),(.125,.12,.16),(.14,.23,.10),(.18,.18,.21),(.16,.15,.18),(.125,.12,.16),(.14,.23,.10)]
bpy.context.view_layer.objects.active=body; body.select_set(True)
# Configure the Skin cage before applying it; the result is a single continuous
# manifold rather than independently rotating limb primitives.
bpy.context.view_layer.objects.active=body
bpy.context.view_layer.update()
sv=body.data.skin_vertices[0].data
for i,r in enumerate(radii): sv[i].radius=(r[0],r[2])
bpy.ops.object.modifier_apply(modifier=skin.name)
sub=body.modifiers.new('Smooth stylized anatomy','SUBSURF'); sub.levels=2; sub.render_levels=2
bpy.ops.object.modifier_apply(modifier=sub.name); bpy.ops.object.shade_smooth()

def add_uv(name, primitive, loc, scale, mat, rot=(0,0,0)):
    if primitive=='sphere': bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, location=loc, rotation=rot)
    elif primitive=='cube': bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    elif primitive=='cone': bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=1, radius2=.65, depth=2, location=loc, rotation=rot)
    elif primitive=='cyl': bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=1, depth=2, location=loc, rotation=rot)
    o=bpy.context.object; o.name=name; o.scale=scale; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.data.materials.append(mat); bpy.ops.object.shade_smooth(); return o

# Large readable clothing masses, authored over the body and skinned to the same armature.
tunic=add_uv('ClothingMesh','cone',(0,.005,1.08),(.34,.22,.34),LEATHER)
belt=add_uv('BeltMesh','cyl',(0,0,.88),(.25,.19,.045),DARK)
hair=add_uv('HairMesh','sphere',(0,.015,1.70),(.22,.19,.20),HAIR)
for x,z,ang in [(-.14,1.79,-.22),(0,1.84,0),(.14,1.79,.22)]: add_uv('HairSpike','cone',(x,.01,z),(.105,.105,.22),HAIR,(ang,0,0))
headband=add_uv('HeadbandMesh','cyl',(0,-.012,1.68),(.205,.185,.025),CLOTH)
scarf=add_uv('ScarfMesh','cyl',(0,0,1.45),(.20,.17,.055),SCARF)
tail=add_uv('ScarfTailMesh','cube',(.13,.09,1.30),(.09,.035,.24),SCARF,(0,.15,-.18))
for side,s in [('L',1),('R',-1)]:
    add_uv('BootsMesh_'+side,'cube',(s*.15,-.055,.13),(.17,.25,.13),METAL)
    add_uv('BracerMesh_'+side,'cyl',(s*.59,-.01,1.17),(.14,.14,.13),METAL,(0,math.pi/2,0))
# Brows face toward -Y.
for s in (-1,1): add_uv('BrowMesh','cube',(s*.075,-.185,1.70),(.07,.018,.018),EYE,(0,0,s*.12))

# Sword is an accessory attached to the socket, not a fake limb.
blade=add_uv('Sword','cube',(-.82,-.04,.70),(.055,.025,.42),METAL,(0,0,-.10))
guard=add_uv('SwordGuard','cube',(-.80,-.04,1.01),(.18,.045,.04),LEATHER)

# Join repeated authored components by semantic class (hair remains one HairMesh, etc.).
def join_prefix(prefix, result):
    obs=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.name.startswith(prefix)]
    if len(obs)<2: return obs[0] if obs else None
    bpy.ops.object.select_all(action='DESELECT')
    for o in obs:o.select_set(True)
    bpy.context.view_layer.objects.active=obs[0]; bpy.ops.object.join(); obs[0].name=result; return obs[0]
join_prefix('Hair','HairMesh'); join_prefix('Scarf','ScarfMesh'); join_prefix('Boots','BootsMesh'); join_prefix('Brow','BrowMesh')

# True skeletal deformation: all character meshes receive Armature modifier and automatic weights.
deform=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.name not in ('Sword','SwordGuard')]
bpy.ops.object.select_all(action='DESELECT'); arm.select_set(True)
for o in deform:o.select_set(True)
bpy.context.view_layer.objects.active=arm
bpy.ops.object.parent_set(type='ARMATURE_AUTO')
for o in (blade,guard):
    world=o.matrix_world.copy(); o.parent=arm; o.parent_type='BONE'; o.parent_bone='WeaponSocket_R'; o.matrix_world=world

# Static combat-ready pose. Complex Actions deliberately deferred until the base passes gameplay review.
bpy.context.scene.render.fps=30
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=OUT,export_format='GLB',use_selection=True,export_animations=False,
    export_skins=True,export_materials='EXPORT',export_yup=True,export_cameras=False,export_lights=False)
bpy.ops.wm.save_as_mainfile(filepath=os.path.splitext(OUT)[0]+'.blend')
print('WARRIOR_V2_BASE_EXPORTED',OUT,'deform_meshes',len(deform),'bones',len(arm.data.bones))
