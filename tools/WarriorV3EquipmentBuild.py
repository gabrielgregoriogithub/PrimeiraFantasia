import bpy,math,json
from pathlib import Path
from mathutils import Vector
r=Path(__file__).resolve().parents[1];b=r/'assets/characters/warrior_v3/equipment';(b/'work').mkdir(parents=True,exist_ok=True)
def material(name,color,metal=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=.78;return m
def mesh(name,vs,fs,mat):
 d=bpy.data.meshes.new(name);d.from_pydata(vs,[],fs);d.update();o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o);d.materials.append(mat);return o
def bevel(o,width=.002,segments=2):
 bpy.context.view_layer.objects.active=o;o.select_set(True);m=o.modifiers.new('Small edge bevel','BEVEL');m.width=width;m.segments=segments;bpy.ops.object.modifier_apply(modifier=m.name);o.select_set(False)
def rings(name,profiles,n,mat):
 vs=[(rad*math.cos(2*math.pi*i/n),rad*math.sin(2*math.pi*i/n),z) for z,rad in profiles for i in range(n)];fs=[]
 for j in range(len(profiles)-1):
  for i in range(n):a=j*n+i;c=j*n+(i+1)%n;fs.append((a,c,c+n,a+n))
 fs += [tuple(reversed(range(n))),tuple((len(profiles)-1)*n+i for i in range(n))]
 return mesh(name,vs,fs,mat)
def save(name):
 objs=[o for o in bpy.context.scene.objects if o.type=='MESH'];tri=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in objs)
 bpy.ops.wm.save_as_mainfile(filepath=str(b/'work'/f'{name}.blend'))
 bpy.ops.export_scene.gltf(filepath=str(b/f'{name}.glb'),export_format='GLB',export_animations=False)
 return {'triangles':tri,'materials':len({m.name for o in objs for m in o.data.materials}),'textures':[],'parts':[o.name for o in objs],'pivot':'Origin at center of grip; no skin'}
bpy.ops.wm.read_factory_settings(use_empty=True);silver=material('Matte silver',(.42,.45,.48),.35);leather=material('Warm dark leather',(.16,.065,.025))
# Diamond cross-section blade, broad shoulders and taper to a restrained point.
profiles=[(.061,.027,.006),(.08,.029,.006),(.34,.025,.0048),(.41,.018,.003),(.455,0,.0001)]
vs=[]
for z,w,t in profiles:vs += [(-w,0,z),(0,-t,z),(w,0,z),(0,t,z)]
fs=[(3,2,1,0)]
for j in range(4):
 for i in range(4):fs.append((j*4+i,j*4+(i+1)%4,(j+1)*4+(i+1)%4,(j+1)*4+i))
mesh('Blade',vs,fs,silver)
outline=[(-.073,.040),(-.073,.055),(-.025,.07),(.025,.07),(.073,.055),(.073,.040),(.025,.051),(-.025,.051)]
vs=[(x,y,z) for y in [-.009,.009] for x,z in outline];n=len(outline);fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
guard=mesh('Guard',vs,fs,silver);bevel(guard,.002,3)
rings('Grip',[(-.041,.012),(-.035,.013),(.038,.012),(.05,.014)],12,leather)
for i in range(8):
 z=-.035+i*.01;rings('Leather wrap %02d'%i,[(z,.0131),(z+.003,.0134),(z+.006,.0126)],12,leather)
rings('Pommel',[(-.077,.006),(-.071,.017),(-.056,.021),(-.043,.013)],10,silver)
stats={'WarriorSword':save('WarriorSword')}
bpy.ops.wm.read_factory_settings(use_empty=True);silver=material('Matte silver',(.36,.39,.41),.3);wood=material('Dark warm wood and leather',(.14,.057,.022))
outline=[(-.115,.11),(-.104,.14),(-.055,.165),(0,.172),(.055,.165),(.104,.14),(.115,.11),(.105,.025),(.084,-.065),(.044,-.145),(0,-.183),(-.044,-.145),(-.084,-.065),(-.105,.025)]
n=len(outline);vs=[(x,y,z) for y in [-.028,-.014] for x,z in outline];fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
body=mesh('Shield body',vs,fs,wood);bevel(body,.003,2)
vs=[]
for scale,y in [(1.03,-.01),(1.03,-.032),(.88,-.038),(.88,-.018)]:vs += [(x*scale,y,z*scale) for x,z in outline]
fs=[]
for j in range(4):
 for i in range(n):fs.append((j*n+i,j*n+(i+1)%n,((j+1)%4)*n+(i+1)%n,((j+1)%4)*n+i))
rim=mesh('Reinforced rim',vs,fs,silver);bevel(rim,.002,2)
boss=rings('Central reinforcement',[(0,.047),(.008,.048),(.025,.034),(.036,.012)],16,silver);boss.rotation_euler.x=math.pi/2;boss.location.y=-.032
grip=rings('Rear hand grip',[(-.038,.008),(.038,.008)],12,wood);grip.rotation_euler.y=math.pi/2;grip.location.y=.003
# Rear forearm strap, rectangular leather arch.
vs=[(x,y,z) for z in [-.074,-.055] for x,y in [(-.047,-.012),(-.047,.018),(.047,.018),(.047,-.012),(.035,-.012),(.035,.008),(-.035,.008),(-.035,-.012)]]
fs=[tuple(reversed(range(8))),tuple(range(8,16))]+[(i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8)]
strap=mesh('Rear forearm strap',vs,fs,wood);bevel(strap,.001,2)
for i in [0,2,4,6,8,10,12]:
 x,z=outline[i];o=rings('Rim rivet %02d'%i,[(0,.004),(.003,.004),(.0045,.002)],8,silver);o.rotation_euler.x=math.pi/2;o.location=(x*.96,-.035,z*.96)
stats['WarriorShield']=save('WarriorShield')
stats['orientation']={'Sword':'GLB +Y blade length; +Z broad-face normal; grip origin (0,0,0)','Shield':'GLB +Y up, +Z outward/front; origin at rear hand grip'}
(b/'work/equipment_stats.json').write_text(json.dumps(stats,indent=2),encoding='utf-8');print(json.dumps(stats,indent=2))
