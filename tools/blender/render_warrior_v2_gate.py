"""Render the static Warrior3D_v2 gate from the tactical camera in 4 facings."""
import bpy, math, os, sys
from mathutils import Vector
args=sys.argv[sys.argv.index('--')+1:]; blend,out_dir=args; bpy.ops.wm.open_mainfile(filepath=blend)
os.makedirs(out_dir,exist_ok=True); scene=bpy.context.scene
scene.render.engine='BLENDER_EEVEE_NEXT'; scene.render.resolution_x=384; scene.render.resolution_y=384; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.render.film_transparent=True
world=bpy.data.worlds.new('TacticalWorld'); scene.world=world; world.color=(.08,.10,.14)
bpy.ops.object.light_add(type='AREA',location=(3,-4,6)); bpy.context.object.data.energy=850; bpy.context.object.data.shape='DISK'; bpy.context.object.data.size=4
bpy.ops.object.light_add(type='AREA',location=(-3,2,3)); bpy.context.object.data.energy=450; bpy.context.object.data.color=(.35,.55,1); bpy.context.object.data.size=3
bpy.ops.object.camera_add(location=(3.4,-5.0,3.5)); camera=bpy.context.object; scene.camera=camera; camera.data.type='ORTHO'; camera.data.ortho_scale=2.45
def track(obj,point): obj.rotation_euler=(Vector(point)-obj.location).to_track_quat('-Z','Y').to_euler()
track(camera,(0,0,.9)); arm=bpy.data.objects['WarriorV2_Armature']
for name,degrees in [('north',0),('east',90),('south',180),('west',270)]:
    arm.rotation_euler[2]=math.radians(degrees); scene.render.filepath=os.path.join(out_dir,'warrior_v2_'+name+'.png'); bpy.ops.render.render(write_still=True)
print('WARRIOR_V2_GATE_RENDERS',out_dir)
