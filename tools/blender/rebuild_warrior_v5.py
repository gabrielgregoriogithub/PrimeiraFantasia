"""Rebuild the current GLB as a readable stylized tactical hero.

Usage: blender --background --python rebuild_warrior_v5.py -- input.glb output.glb
The current armature and Actions are preserved; only presentation geometry/materials
is rebuilt here so gameplay contracts remain unchanged.
"""
import bpy, math, os, sys
from mathutils import Matrix, Vector, Euler

args = sys.argv[sys.argv.index("--") + 1:]
source, output = args
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=source)
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')

def find(prefix):
    return next((o for o in bpy.data.objects if o.name.startswith(prefix)), None)

def mat(name, color, rough=.78, metallic=.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bs = m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = (*color, 1)
    bs.inputs['Roughness'].default_value = rough
    bs.inputs['Metallic'].default_value = metallic
    return m

BLUE_HAIR = mat('Hero Hair Blue', (0.025, .20, .55), .82)
RED_SCARF = mat('Hero Scarf Red', (.68, .035, .045), .88)
STEEL = mat('Hero Steel', (.38, .52, .68), .52, .24)
NAVY = mat('Hero Cloth Navy', (.035, .09, .20), .9)
LEATHER = mat('Hero Leather', (.24, .095, .035), .88)
GOLD = mat('Hero Warm Gold', (.88, .48, .08), .58, .15)
SKIN = mat('Hero Skin', (.82, .49, .30), .9)
WHITE = mat('Hero Tunic', (.74, .82, .85), .9)

palette = {
    'Hair': BLUE_HAIR, 'Head': SKIN, 'Hand': SKIN, 'ChestArmor': STEEL,
    'ShoulderArmor': STEEL, 'Torso': WHITE, 'Waist': NAVY, 'Hips': NAVY,
    'Thigh': NAVY, 'Shin': STEEL, 'Boot': LEATHER, 'Belt': LEATHER,
    'Buckle': GOLD, 'Sword_Blade': STEEL, 'Sword_Guard': GOLD,
    'Sword_Handle': LEATHER, 'Sword_Pommel': GOLD,
}
for obj in [o for o in bpy.data.objects if o.type == 'MESH']:
    for prefix, material in palette.items():
        if obj.name.startswith(prefix):
            obj.data.materials.clear(); obj.data.materials.append(material); break

# Strong, readable silhouette without changing global character scale.
scales = {
    'Head': (1.14,1.14,1.14), 'Hair': (1.18,1.12,1.18),
    'ChestArmor': (1.12,1.08,1.08), 'Torso': (1.08,1.04,1.05),
    'ShoulderArmor_L': (1.28,1.22,1.22), 'ShoulderArmor_R': (1.28,1.22,1.22),
    'Hand_L': (1.16,1.16,1.16), 'Hand_R': (1.16,1.16,1.16),
    'Boot_L': (1.16,1.20,1.10), 'Boot_R': (1.16,1.20,1.10),
    'Sword_Blade': (1.28,1.38,1.45), 'Sword_Guard': (1.18,1.18,1.18),
}
for name, scale in scales.items():
    obj=find(name)
    if obj: obj.scale = tuple(obj.scale[i]*scale[i] for i in range(3))

def bone_prop(name, bone, shape, size, material, offset=(0,0,0), rotation=(0,0,0)):
    if shape == 'cube':
        bpy.ops.mesh.primitive_cube_add(size=1)
    elif shape == 'sphere':
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=.5)
    elif shape == 'cone':
        bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=.5, radius2=0, depth=1)
    elif shape == 'cylinder':
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=.5, depth=1)
    obj=bpy.context.object; obj.name=name; obj.scale=size
    obj.data.materials.append(material)
    world = arm.matrix_world @ arm.pose.bones[bone].matrix @ Matrix.Translation(Vector(offset))
    world @= Euler(rotation, 'XYZ').to_matrix().to_4x4()
    obj.matrix_world=world; keep=obj.matrix_world.copy()
    obj.parent=arm; obj.parent_type='BONE'; obj.parent_bone=bone; obj.matrix_world=keep
    return obj

# Red scarf: broad collar plus asymmetric trailing tail, readable from isometric view.
bone_prop('Scarf_Collar','Neck','cylinder',(.25,.25,.075),RED_SCARF,(0,.01,.015),(math.pi/2,0,0))
bone_prop('Scarf_Tail','Chest','cube',(.11,.035,.34),RED_SCARF,(.15,.05,.18),(math.radians(-16),0,math.radians(-12)))
# Strong eyebrows and three chunky blue hair spikes.
bone_prop('Brow_L','Head','cube',(.10,.025,.025),BLUE_HAIR,(.09,-.185,.07),(0,0,math.radians(-9)))
bone_prop('Brow_R','Head','cube',(.10,.025,.025),BLUE_HAIR,(-.09,-.185,.07),(0,0,math.radians(9)))
for i,(x,z,a) in enumerate(((-.13,.20,-.22),(0,.25,0),(.13,.20,.22))):
    bone_prop(f'HairSpike_{i}','Head','cone',(.12,.12,.30),BLUE_HAIR,(x,0,z),(a,0,0))
# Large shield, a primary silhouette mass.
shield=bone_prop('HeroShield','Hand_L','cylinder',(.43,.43,.075),NAVY,(0,-.08,0),(math.pi/2,0,0))
bone_prop('HeroShieldBoss','Hand_L','sphere',(.14,.08,.14),GOLD,(0,-.16,0))

# Preserve Actions and export all of them.
bpy.context.scene.render.fps=30
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=output, export_format='GLB', use_selection=True,
    export_animations=True, export_animation_mode='ACTIONS', export_nla_strips=False,
    export_skins=True, export_materials='EXPORT', export_cameras=False, export_lights=False,
    export_yup=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.splitext(output)[0]+'.blend')
print('WARRIOR_V5_EXPORTED', output, 'actions', len(bpy.data.actions))
