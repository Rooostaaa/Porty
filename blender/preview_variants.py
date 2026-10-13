# Étude de style (docs/ETUDE_STYLE.md) : la même scène (capitainerie, conteneurs, chariot, docker, quai, eau) rendue dans
# trois directions : A « commercial ISM », B « port nordique jouet », C « industriel pop ». Les variantes B et C sont
# construites ici même ; A est le pilote de parts/buildings.py. Les couleurs hors palette (X) sont celles de l'essai.
#   blender -b -P preview_variants.py -- <dossier blender du projet> <sortie.png>
import bpy, sys, os, math
from mathutils import Vector

args = sys.argv[sys.argv.index('--') + 1:]
BL, outpng = args[0], args[1]
sys.path.insert(0, BL)
sys.path.insert(0, os.path.join(BL, 'parts'))
bpy.ops.wm.read_factory_settings(use_empty=True)
import lib
from lib import Model, closed_block, door, window_band, awning, planter, roll_door, pilaster, mul
from palette import C
import buildings, cargo, equipment, world

sc = bpy.context.scene
PITCH = math.radians(35)
R = Vector((1, 1, 0)).normalized()
F = Vector((1, -1, 0)).normalized()
TILE = 13.0


# ---------------------------------------------------------------- matériau du rendu (comme preview_style.py)
def material():
    mat = bpy.data.materials.new('ism')
    nt = mat.node_tree
    nt.nodes.clear()
    n = nt.nodes
    att = n.new('ShaderNodeAttribute'); att.attribute_name = 'Color'
    geo = n.new('ShaderNodeNewGeometry')
    sep = n.new('ShaderNodeSeparateXYZ'); nt.links.new(geo.outputs['Normal'], sep.inputs[0])

    def math_node(op, a, b):
        m = n.new('ShaderNodeMath'); m.operation = op
        for i, v in enumerate((a, b)):
            if isinstance(v, float):
                m.inputs[i].default_value = v
            else:
                nt.links.new(v, m.inputs[i])
        return m.outputs[0]
    f = math_node('MULTIPLY_ADD', sep.outputs['Z'], 0.28); f.node.inputs[2].default_value = 0.72
    f = math_node('SUBTRACT', f, math_node('MULTIPLY', sep.outputs['X'], 0.04))
    f = math_node('SUBTRACT', f, math_node('MULTIPLY', sep.outputs['Y'], 0.04))
    mix = n.new('ShaderNodeMix'); mix.data_type = 'RGBA'; mix.blend_type = 'MULTIPLY'; mix.inputs['Factor'].default_value = 1.0
    nt.links.new(att.outputs['Color'], mix.inputs[6])
    comb = n.new('ShaderNodeCombineXYZ')
    for i in range(3):
        nt.links.new(f, comb.inputs[i])
    nt.links.new(comb.outputs[0], mix.inputs[7])
    col = mix.outputs[2]
    em = n.new('ShaderNodeEmission'); em.inputs['Strength'].default_value = 0.85; nt.links.new(col, em.inputs['Color'])
    dif = n.new('ShaderNodeBsdfDiffuse'); nt.links.new(col, dif.inputs['Color'])
    add = n.new('ShaderNodeAddShader'); nt.links.new(em.outputs[0], add.inputs[0]); nt.links.new(dif.outputs[0], add.inputs[1])
    out = n.new('ShaderNodeOutputMaterial'); nt.links.new(add.outputs[0], out.inputs['Surface'])
    return mat


MAT = material()


def assign(ob):
    if ob.type == 'MESH':
        me = ob.data
        if me.color_attributes and me.color_attributes[0].name != 'Color':
            me.color_attributes[0].name = 'Color'
        me.materials.clear(); me.materials.append(MAT)


def built(fn, name, at, ry=0.0):
    """Appelle une fonction de parts/ (qui crée l'objet `name`) et le déplace."""
    before = set(bpy.data.objects)
    fn()
    objs = [o for o in bpy.data.objects if o not in before]
    for o in objs:
        if o.parent is None:
            o.location = Vector(at)
            o.rotation_euler = (0, 0, math.radians(ry))
        assign(o)
    return objs


# ---------------------------------------------------------------- couleurs de l'étude, désormais toutes dans palette.json
X = {k: C(v) for k, v in {
    # B — nordique
    'falun': 'falun', 'cream': 'wood_cream', 'trim': 'wood_trim', 'roof_b': 'roof_b_blue', 'glass_b': 'glass_light',
    'apron_b': 'apron_warm', 'asphalt_b': 'asphalt', 'grass_b': 'grass', 'kerb_b': 'kerb',
    # C — industriel
    'clad': 'clad_steel', 'clad_dark': 'clad_steel_dark', 'roof_c': 'roof_light', 'cap_c': 'cap_light', 'hazard': 'hazard',
    'apron_c': 'apron_dark', 'asphalt_c': 'asphalt_dark', 'grass_c': 'grass_dark', 'mark_c': 'mark_yellow', 'door_c': 'door_orange',
    'label': 'ui_text', 'water': 'water', 'water_deep': 'water_deep', 'quay': 'concrete', 'quay_dark': 'concrete_dark',
}.items()}


# ---------------------------------------------------------------- variante B : capitainerie « port nordique jouet »
def harbor_office_nordic():
    m = Model('harbor_office_b', 31)
    w, d, h, z0 = 4.6, 3.8, 2.6, 0.2
    m.boxb((0, 0, 0), (w + 0.5, d + 0.5, z0), (0, 0, 0), X['kerb_b'])                       # socle clair
    m.cham((0, 0, z0), (w, d, h), 0.08, X['cream'])                                            # corps blanc crème
    m.boxb((0, 0, z0), (w + 0.06, d + 0.06, 0.35), (0, 0, 0), C('navy'))                      # bandeau bas marine
    for sx in (-1, 1):                                                                         # planches d'angle
        for sy in (-1, 1):
            m.boxb((sx * (w / 2 - 0.08), sy * (d / 2 - 0.08), z0), (0.22, 0.22, h), (0, 0, 0), X['trim'])
    # bardage : lames horizontales légèrement en relief sur les faces vues (-y, +x)
    for i in range(1, 8):
        z = z0 + 0.35 + i * 0.3
        m.boxb((0, -d / 2 - 0.015, z), (w - 0.3, 0.03, 0.04), (0, 0, 0), mul(X['cream'], 0.88))
        m.boxb((w / 2 + 0.015, 0, z), (0.03, d - 0.3, 0.04), (0, 0, 0), mul(X['cream'], 0.88))
    # fenêtres à cadre blanc, verre clair
    for (side, plane, ts) in (('-y', -d / 2, (-1.4, 1.4)), ('+x', w / 2, (-1.0, 1.0))):
        for t in ts:
            window_band(m, side, plane, t, z0 + 1.0, 0.9, 0.95, n=2, glass=X['glass_b'], mullion=X['trim'], sill=False)
            m.boxb(lib._face(side, plane, t, 0.06, z0 + 0.92), lib._size(side, 1.05, 0.12, 0.08), (0, 0, 0), X['trim'])
    # porte rouge sous un petit auvent blanc/bleu
    m.boxb((0, -d / 2 - 0.02, z0), (0.95, 0.06, 1.7), (0, 0, 0), X['falun'])
    m.boxb((0, -d / 2 - 0.05, z0), (1.1, 0.08, 0.08), (0, 0, 0), X['trim'])
    for tt in (-0.5, 0.5):
        m.boxb((tt, -d / 2 - 0.05, z0), (0.08, 0.08, 1.75), (0, 0, 0), X['trim'])
    m.boxb((0, -d / 2 - 0.05, z0 + 1.72), (1.1, 0.08, 0.08), (0, 0, 0), X['trim'])
    awning(m, '-y', -d / 2, 0, z0 + 2.2, 1.5, depth=0.5, drop=0.14, c=X['roof_b'], c2=X['trim'], n=5, valance=0.12)
    # toit à deux pentes bleu, débordant, avec sous-face claire
    top = z0 + h
    ov = 0.35
    m.prism_x([(-d / 2 - ov, top - 0.05), (d / 2 + ov, top - 0.05), (d / 2 + ov, top + 0.02), (0, top + 1.45), (-d / 2 - ov, top + 0.02)],
              -w / 2 - ov, w / 2 + ov, X['roof_b'])
    m.prism_x([(-d / 2 - ov - 0.06, top + 0.02), (-d / 2 - ov - 0.06, top + 0.14), (0, top + 1.57), (d / 2 + ov + 0.06, top + 0.14), (d / 2 + ov + 0.06, top + 0.02), (0, top + 1.45)],
              -w / 2 - ov - 0.04, w / 2 + ov + 0.04, mul(X['roof_b'], 0.82))                      # rives
    # belvédère sur le faîte + mât
    bx, bz = -0.9, top + 1.1
    m.boxb((bx, 0, bz), (1.5, 1.5, 0.5), (0, 0, 0), X['cream'])
    m.boxb((bx, 0, bz + 0.5), (1.3, 1.3, 0.8), (0, 0, 0), X['glass_b'])
    for u, v in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
        m.boxb((bx + u * 0.6, v * 0.6, bz + 0.5), (0.1, 0.1, 0.8), (0, 0, 0), X['trim'])
    m.cyl((bx, 0, bz + 1.3 + 0.45), (1.25, 1.25, 0.9), (0, 0, math.pi / 4), X['roof_b'], 4, 0.0)
    m.cylb((bx, 0, bz + 2.2), 0.05, 1.8, X['trim'], 6)
    m.box((bx + 0.28, 0, bz + 3.7), (0.5, 0.03, 0.32), (0, 0, 0), C('red'))
    # bouée, jardinières, bollard
    lib.emblem_life_ring(m, (1.5, -d / 2 - 0.1, z0 + 1.45), 0.42)
    planter(m, (-1.0, -d / 2 - 0.7, 0), 0.6, pot=X['trim'], shrub=C('pine'))
    planter(m, (1.0, -d / 2 - 0.7, 0), 0.6, pot=X['trim'], shrub=C('pine'))
    lib.bollard(m, w / 2 + 0.7, -0.3)
    m.to_object()


# ---------------------------------------------------------------- variante C : capitainerie « industriel pop »
def harbor_office_industrial():
    m = Model('harbor_office_c', 32)
    w, d, h, z0 = 4.6, 3.8, 2.7, 0.2
    m.boxb((0, 0, 0), (w + 0.4, d + 0.4, z0), (0, 0, 0), X['apron_c'])
    m.boxb((0, 0, z0), (w, d, h), (0, 0, 0), X['clad'])
    # bardage ondulé : nervures verticales sur -y et +x
    for i in range(int(w / 0.28)):
        x = -w / 2 + 0.14 + i * 0.28
        m.boxb((x, -d / 2 - 0.02, z0 + 0.45), (0.08, 0.04, h - 0.75), (0, 0, 0), X['clad_dark'])
    for i in range(int(d / 0.28)):
        y = -d / 2 + 0.14 + i * 0.28
        m.boxb((w / 2 + 0.02, y, z0 + 0.45), (0.04, 0.08, h - 0.75), (0, 0, 0), X['clad_dark'])
    # bande de sécurité jaune/noire en bas, casquette claire en haut
    for i in range(12):
        x = -w / 2 + 0.2 + i * 0.4
        m.boxb((x, -d / 2 - 0.03, z0 + 0.02), (0.4, 0.05, 0.38), (0, 0, 0), X['hazard'] if i % 2 == 0 else C('dark'))
    for i in range(10):
        y = -d / 2 + 0.2 + i * 0.4
        m.boxb((w / 2 + 0.03, y, z0 + 0.02), (0.05, 0.4, 0.38), (0, 0, 0), X['hazard'] if i % 2 == 0 else C('dark'))
    top = z0 + h
    m.boxb((0, 0, top), (w + 0.3, d + 0.3, 0.28), (0, 0, 0), X['cap_c'])
    m.boxb((0, 0, top + 0.28), (w - 0.2, d - 0.2, 0.03), (0, 0, 0), X['roof_c'])
    # bande de fenêtres hautes, porte roulante orange, enseigne-conteneur (bloc de couleur, pas de texte)
    window_band(m, '-y', -d / 2, 1.2, z0 + 1.7, 1.8, 0.6, n=3, glass=C('glass'), mullion=C('dark'), sill=False)
    window_band(m, '+x', w / 2, 0.4, z0 + 1.7, 2.2, 0.6, n=4, glass=C('glass'), mullion=C('dark'), sill=False)
    roll_door(m, '-y', -d / 2, -1.1, z0, 1.6, 1.9, X['door_c'], open=False)
    m.boxb((-w / 2 - 0.2, -d / 2 - 0.5, 0), (0.8, 0.8, 1.6), (0, 0, 0), C('box_blue'))          # bloc-emblème bleu
    m.boxb((-w / 2 - 0.2, -d / 2 - 0.5, 1.6), (0.9, 0.9, 0.12), (0, 0, 0), C('white'))
    m.cylb((-w / 2 - 0.2, -d / 2 - 0.5, 1.72), 0.3, 0.3, C('blue'), 8)                         # feu bleu
    # toiture technique : clim, antenne, tuyau, cheminée
    lib.ac_unit(m, 0.9, 0.6, top + 0.31)
    lib.ac_unit(m, -0.6, -0.4, top + 0.31)
    m.cylb((1.6, -1.2, top + 0.31), 0.07, 2.4, C('steel'), 6)
    m.box((1.6, -1.2, top + 2.5), (0.9, 0.05, 0.05), (0, 0, 0), C('steel'))
    m.cylb((-1.7, 1.2, top + 0.31), 0.22, 0.9, C('dark'), 8)
    m.tube((w / 2 + 0.08, -1.0, z0 + 0.2), (w / 2 + 0.08, -1.0, top + 0.2), 0.07, X['hazard'], 6)
    lib.bollard(m, w / 2 + 0.7, -0.3)
    lib.cone(m, -w / 2 - 0.9, -d / 2 - 0.4, 1.3)
    m.to_object()


# ---------------------------------------------------------------- scène : trois dalles côte à côte
VARIANTS = [
    ('A  COMMERCIAL ISM', buildings.harbor_office, 'harbor_office',
     dict(grass=C('grass_lime'), apron=C('sidewalk'), asphalt=C('asphalt_violet'), mark=C('marking_thick'), kerb=C('concrete_dark'))),
    ('B  PORT NORDIQUE', harbor_office_nordic, 'harbor_office_b',
     dict(grass=X['grass_b'], apron=X['apron_b'], asphalt=X['asphalt_b'], mark=C('marking'), kerb=X['kerb_b'])),
    ('C  INDUSTRIEL POP', harbor_office_industrial, 'harbor_office_c',
     dict(grass=X['grass_c'], apron=X['apron_c'], asphalt=X['asphalt_c'], mark=X['mark_c'], kerb=C('dark'))),
]

all_objs, labels = [], []
for i, (label, fn, name, g) in enumerate(VARIANTS):
    c = R * (i - 1) * TILE                       # centre de la dalle
    cx, cy = c.x, c.y
    gm = Model('ground_%d' % i, 3)
    # herbe, terre-plein (apron) devant le bâtiment, route devant, trottoir
    gm.boxb((cx, cy, -0.2), (TILE - 0.3, TILE - 0.3, 0.2), (0, 0, 0), g['grass'])
    gm.boxb((cx + 0.3, cy - 2.6, -0.02), (10.5, 6.4, 0.06), (0, 0, 0), g["apron"])
    gm.boxb((cx, cy - 5.0, -0.0), (TILE - 0.3, 2.6, 0.09), (0, 0, 0), g["asphalt"])
    gm.boxb((cx, cy - 6.4, -0.0), (TILE - 0.3, 0.4, 0.14), (0, 0, 0), g["kerb"])
    for k in range(-2, 3):
        gm.boxb((cx + k * 2.2, cy - 5.0, 0.09), (1.2, 0.26, 0.012), (0, 0, 0), g["mark"])
    # quai sur le fond (+y) et eau derrière
    gm.boxb((cx, cy + 5.2, -0.2), (TILE - 0.3, 2.3, 0.5), (0, 0, 0), X["quay"])
    gm.boxb((cx, cy + 6.25, -0.2), (TILE - 0.3, 0.25, 0.55), (0, 0, 0), X["quay_dark"])
    for k in range(-2, 3):
        lib.bollard(gm, cx + k * 2.4, cy + 5.9, 1.3)
    assign(gm.to_object())
    objs = built(fn, name, (cx - 0.3, cy + 0.9, 0))
    gm2 = Model("boxes_%d" % i, 7)
    gm2.boxb((cx - 3.6, cy - 2.4, 0), (4.0, 1.4, 1.3), (0, 0, 0), C("box_red"))
    gm2.boxb((cx - 3.6, cy - 0.9, 0), (4.0, 1.4, 1.3), (0, 0, 0), C("box_green"))
    gm2.boxb((cx - 3.6, cy - 2.4, 1.3), (4.0, 1.4, 1.3), (0, 0, 0), C("box_blue"))
    assign(gm2.to_object())
    objs += built(equipment.forklift, "forklift", (cx + 3.6, cy - 2.4, 0), 200)
    objs += built(cargo.docker, "docker", (cx + 0.5, cy - 1.9, 0))
    all_objs += objs
    labels.append((label, Vector((cx + 1.0, cy - 9.3, 0))))

# eau commune derrière les trois dalles
wm = Model('water', 4)
wm.boxb((0, 0, -0.6), (300, 300, 0.3), (0, 0, 0), X["water"])
assign(wm.to_object())

# ---------------------------------------------------------------- étiquettes
lab = bpy.data.materials.new('lab')
lab.node_tree.nodes.clear()
e = lab.node_tree.nodes.new('ShaderNodeEmission')
cl = X['label']
e.inputs['Color'].default_value = (lib.srgb_to_lin(cl[0]), lib.srgb_to_lin(cl[1]), lib.srgb_to_lin(cl[2]), 1)
o = lab.node_tree.nodes.new('ShaderNodeOutputMaterial')
lab.node_tree.links.new(e.outputs[0], o.inputs['Surface'])

cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
sc.collection.objects.link(cam)
sc.camera = cam
cam.data.type = 'ORTHO'
cam.data.clip_end = 2000
dvec = Vector((math.cos(PITCH) * F.x, math.cos(PITCH) * F.y, math.sin(PITCH)))
cam.location = Vector((0, 0, 0)) + dvec * 300
cam.rotation_euler = (-dvec).to_track_quat('-Z', 'Y').to_euler()
bpy.context.view_layer.update()
for text, p in labels:
    bpy.ops.object.text_add()
    t = bpy.context.object
    t.data.body = text
    t.data.align_x = 'CENTER'
    t.data.size = 1.6
    try:
        t.data.font = bpy.data.fonts.load(lib.FONTS[1])
    except Exception:
        pass
    t.data.materials.append(lab)
    t.location = p
    t.rotation_euler = cam.rotation_euler

inv = cam.matrix_world.inverted()
xs, ys = [], []
for i in range(3):
    c = R * (i - 1) * TILE
    for dx in (-TILE / 2, TILE / 2):
        for dy in (-TILE / 2 - 3.4, TILE / 2 + 0.5):
            for z in (0, 5.0):
                q = inv @ Vector((c.x + dx, c.y + dy, z))
                xs.append(q.x); ys.append(q.y)
W, H = 2400, 1000
w, h = max(xs) - min(xs), max(ys) - min(ys)
cam.data.ortho_scale = max(w, h * W / H) * 1.03
shift = cam.matrix_world.to_3x3() @ Vector(((max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2, 0))
cam.location += shift

sun = bpy.data.objects.new('sun', bpy.data.lights.new('sun', 'SUN'))
sc.collection.objects.link(sun)
sun.data.energy = 0.15 * math.pi / 0.8
sun.data.angle = math.radians(0.5)
sun.rotation_euler = Vector((-1.0, -0.35, 1.25)).normalized().to_track_quat('Z', 'Y').to_euler()
sc.world = bpy.data.worlds.new('w')
sc.world.color = tuple(lib.srgb_to_lin(v) for v in X["water"])
for eng in ('BLENDER_EEVEE', 'BLENDER_EEVEE_NEXT'):
    try:
        sc.render.engine = eng
        break
    except TypeError:
        pass
sc.view_settings.view_transform = 'Standard'
sc.render.resolution_x, sc.render.resolution_y = W, H
sc.render.filepath = outpng
try:
    sc.eevee.taa_render_samples = 32
except AttributeError:
    pass
bpy.ops.render.render(write_still=True)
print('rendu', outpng)
