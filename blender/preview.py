# Planche contact des .glb exportés (rendu Workbench, couleurs de sommet).
#   blender -b -P preview.py -- <feuille> <sortie.png> [dossier_glb]
import bpy, sys, os, math
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
args = sys.argv[sys.argv.index('--') + 1:]
sheet, outpng = args[0], args[1]
src = args[2] if len(args) > 2 else os.path.join(HERE, '..', 'godot', 'assets', 'models')

SHEETS = {
    'terrain': ['ground_gravel', 'ground_asphalt', 'ground_grass', 'ground_sand', 'quay', 'quay_end', 'road', 'rail',
                'rock', 'tree', 'bush', 'lighthouse', 'lamp', 'fence', 'buoy', 'buoy_green'],
    'harbour': ['bollard', 'fender', 'ladder', 'cleat', 'crane_rail', 'breakwater', 'life_ring_post', 'net_pile', 'crate_fish',
                'gull', 'gull_b', 'fishing_boat', 'sidewalk', 'crosswalk', 'yard_marks', 'gate_lanes', 'sign_p', 'ghost_lot'],
    'buildings': ['harbor_office', 'customs_hut', 'hangar', 'control_tower', 'gate_booth', 'barrier', 'reefer_rack', 'office',
                  'workshop', 'customs_office', 'scanner', 'inspection_hall', 'imo_fence', 'rail_terminal', 'substation',
                  'it_center', 'warehouse'],
    'equipment': ['crane_mobile', 'crane_sts', 'straddle', 'reach_stacker', 'rtg', 'truck', 'tractor', 'forklift',
                  'locomotive', 'wagon', 'tug', 'pilot_boat', 'van'],
    'ships': ['ship_mini', 'ship_coaster', 'ship_feeder', 'ship_panamax'],
    'world': ['ground_parking', 'house_a', 'house_b', 'shop', 'silo', 'hill', 'car_a', 'car_b', 'car_c', 'stack'],
    'cargo': ['container40', 'container20', 'reefer40', 'flatrack', 'docker', 'customs_officer', 'inspector', 'manager',
              'cone', 'barrel', 'pallet', 'sign'],
}
names = SHEETS[sheet]

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene


def bbox(objs):
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for ob in objs:
        if ob.type != 'MESH':
            continue
        for c in ob.bound_box:
            w = ob.matrix_world @ Vector(c)
            lo = Vector((min(lo[i], w[i]) for i in range(3)))
            hi = Vector((max(hi[i], w[i]) for i in range(3)))
    return lo, hi


cols = 5 if len(names) > 6 else len(names)
cell = 0.0
groups = []
for name in names:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(src, name + '.glb'))
    objs = [o for o in bpy.data.objects if o not in before]
    roots = [o for o in objs if o.parent is None]
    lo, hi = bbox(objs)
    groups.append((name, roots, lo, hi))
    cell = max(cell, (hi - lo).x, (hi - lo).y)
cell *= 1.15
for i, (name, roots, lo, hi) in enumerate(groups):
    r, c = divmod(i, cols)
    centre = (lo + hi) / 2
    for o in roots:
        o.location.x += c * cell - centre.x
        o.location.y += -r * cell - centre.y
    # étiquette
    bpy.ops.object.text_add(location=(c * cell - cell * 0.45, -r * cell - cell * 0.45, 0.05))
    t = bpy.context.object
    t.data.body = name
    t.data.size = cell * 0.07
    for o in [x for x in bpy.data.objects if x.type == 'MESH']:
        me = o.data
        if me.color_attributes:
            me.color_attributes.active_color = me.color_attributes[0]

sc.render.engine = 'BLENDER_WORKBENCH'
sh = sc.display.shading
sh.light = 'STUDIO'
try:
    sh.color_type = 'VERTEX'
except TypeError:
    sh.color_type = 'ATTRIBUTE'
sh.show_shadows = True
sh.show_cavity = False
sc.display.render_aa = '8'
sc.world = bpy.data.worlds.new('w')
sc.world.color = (0.55, 0.75, 0.95)
rows = math.ceil(len(names) / cols)
cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
sc.collection.objects.link(cam)
sc.camera = cam
cx, cy = (cols - 1) * cell / 2, -(rows - 1) * cell / 2
cam.data.type = 'ORTHO'
cam.data.ortho_scale = max(cols * cell, rows * cell * 1.25) * 1.08
cam.location = (cx + 40, cy - 40, 40)
direction = Vector((cx, cy, 0)) - cam.location
cam.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
cam.data.clip_end = 1000
sc.render.resolution_x = 1600
sc.render.resolution_y = int(1600 * max(0.45, rows / cols * 0.95))
sc.render.filepath = outpng
bpy.ops.render.render(write_still=True)
print('rendu', outpng)
