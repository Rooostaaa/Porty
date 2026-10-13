# Rendu avant / après d'un bâtiment dans l'ambiance du brief (docs/BRIEF_STYLE_PORTS.md) :
# caméra iso (lacet 45°, plongée 35°), cadrage serré, trottoir + asphalte violet + herbe citron,
# ombrage par face (dessus 100 %, flancs ~68–76 %) et ombres portées nettes à −15 %.
#   blender -b -P preview_style.py -- <dossier_avant> <dossier_apres> <sortie.png> nom1[@rotation][,nom2...]
# Un nom suffixé @90 est rendu tourné de 90° (comme dans layout.gd) ; un modèle sans fichier « avant » est marqué NOUVEAU.
import bpy, sys, os, math
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
args = sys.argv[sys.argv.index('--') + 1:]
src_a, src_b, outpng, names = args[0], args[1], args[2], args[3].split(',')

bpy.ops.wm.read_factory_settings(use_empty=True)
import lib
from palette import C

sc = bpy.context.scene
PITCH, YAW = math.radians(35), math.radians(45)
R = Vector((1, 1, 0)).normalized()           # droite de l'écran, au sol
F = Vector((1, -1, 0)).normalized()          # vers la caméra, au sol


def material():
    """Couleur de sommet × facteur d'orientation de face ; 85 % en émission (aplat), 15 % éclairé par le soleil
    (c'est cette part qui fait les ombres portées)."""
    mat = bpy.data.materials.new('ism')
    nt = mat.node_tree
    nt.nodes.clear()
    n = nt.nodes
    att = n.new('ShaderNodeAttribute')
    att.attribute_name = 'Color'
    geo = n.new('ShaderNodeNewGeometry')
    sep = n.new('ShaderNodeSeparateXYZ')
    nt.links.new(geo.outputs['Normal'], sep.inputs[0])

    def math_node(op, a, b):
        m = n.new('ShaderNodeMath')
        m.operation = op
        for i, v in enumerate((a, b)):
            if isinstance(v, float):
                m.inputs[i].default_value = v
            else:
                nt.links.new(v, m.inputs[i])
        return m.outputs[0]
    # facteur = 0,72 + 0,28·nz − 0,04·nx − 0,04·ny  → dessus 1,0 ; face −Y 0,76 ; face +X 0,68
    f = math_node('MULTIPLY_ADD', sep.outputs['Z'], 0.28)
    f.node.inputs[2].default_value = 0.72
    f = math_node('SUBTRACT', f, math_node('MULTIPLY', sep.outputs['X'], 0.04))
    f = math_node('SUBTRACT', f, math_node('MULTIPLY', sep.outputs['Y'], 0.04))
    mix = n.new('ShaderNodeMix')
    mix.data_type = 'RGBA'
    mix.blend_type = 'MULTIPLY'
    mix.inputs['Factor'].default_value = 1.0
    nt.links.new(att.outputs['Color'], mix.inputs[6])
    comb = n.new('ShaderNodeCombineXYZ')
    for i in range(3):
        nt.links.new(f, comb.inputs[i])
    nt.links.new(comb.outputs[0], mix.inputs[7])
    col = mix.outputs[2]
    em = n.new('ShaderNodeEmission')
    em.inputs['Strength'].default_value = 0.85
    nt.links.new(col, em.inputs['Color'])
    dif = n.new('ShaderNodeBsdfDiffuse')
    nt.links.new(col, dif.inputs['Color'])
    add = n.new('ShaderNodeAddShader')
    nt.links.new(em.outputs[0], add.inputs[0])
    nt.links.new(dif.outputs[0], add.inputs[1])
    out = n.new('ShaderNodeOutputMaterial')
    nt.links.new(add.outputs[0], out.inputs['Surface'])
    return mat


MAT = material()


def assign(ob):
    if ob.type != 'MESH':
        return
    me = ob.data
    if me.color_attributes and me.color_attributes[0].name != 'Color':
        me.color_attributes[0].name = 'Color'
    me.materials.clear()
    me.materials.append(MAT)


def bbox(objs):
    lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
    for ob in objs:
        if ob.type != 'MESH':
            continue
        for c in ob.bound_box:
            w = ob.matrix_world @ Vector(c)
            lo = Vector(min(lo[i], w[i]) for i in range(3))
            hi = Vector(max(hi[i], w[i]) for i in range(3))
    return lo, hi


def load(path, at):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    objs = [o for o in bpy.data.objects if o not in before]
    for o in objs:
        if o.parent is None:
            o.location += at
        assign(o)
    bpy.context.view_layer.update()
    return objs


# --- placement : chaque bâtiment avant (à gauche) / après (à droite), alignés sur la droite de l'écran ----------------
pairs = []
cursor = 0.0
for spec in names:
    name, _, rot = spec.partition('@')
    ry = math.radians(float(rot)) if rot else 0.0
    for src, tag in ((src_a, 'AVANT'), (src_b, 'APRÈS')):
        p = os.path.join(src, name + '.glb')
        if not os.path.exists(p):
            continue
        if tag == 'APRÈS' and not os.path.exists(os.path.join(src_a, name + '.glb')):
            tag = 'NOUVEAU'
        objs = load(p, Vector((0, 0, 0)))
        for o in objs:
            if o.parent is None:
                o.rotation_euler = (0, 0, ry)
        bpy.context.view_layer.update()
        lo, hi = bbox(objs)
        size = max(hi.x - lo.x, hi.y - lo.y)
        cursor += size * 0.75 + 2.5
        at = R * cursor - Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, 0))
        for o in objs:
            if o.parent is None:
                o.location += at
        bpy.context.view_layer.update()
        lo2, hi2 = bbox(objs)
        pairs.append((tag, name, objs, lo2, hi2))
        cursor += size * 0.75 + 2.5
        # personnage pour l'échelle, devant l'entrée
        dock = os.path.join(src_b, 'docker.glb')
        if os.path.exists(dock):
            c = (lo2 + hi2) / 2
            load(dock, Vector((c.x, lo2.y - 1.4, 0)) + R * 0.0)

# --- sol : herbe citron, trottoir sous chaque bâtiment, route en asphalte violet devant ------------------------------
g = lib.Model('ground', 3)
allo, alhi = bbox([o for t in pairs for o in t[2]])
mid = (allo + alhi) / 2
span = (alhi - allo).length + 40
g.box((mid.x, mid.y, -0.15), (span, span, 0.1), (0, 0, 0), C('grass'))
for tag, name, objs, lo, hi in pairs:
    g.boxb(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2 - 0.6, -0.1), (hi.x - lo.x + 2.4, hi.y - lo.y + 3.6, 0.1), (0, 0, 0), C('apron_warm'))
# route : parallèle à la droite de l'écran, devant (côté caméra) de tous les bâtiments
# la route longe le coin du trottoir le plus proche de la caméra (trottoir = emprise + 1,2 sur X, + 0,6 / 2,4 sur Y)
walk_f = max((hi.x + 1.2 - (lo.y - 2.4)) / math.sqrt(2) for _, _, _, lo, hi in pairs)
road_c = R * R.dot(mid) + F * (walk_f + 3.9 + 0.8)
road_c = Vector((road_c.x, road_c.y, -0.11))
ang = math.atan2(R.y, R.x)
g.boxb(road_c, (span, 7.0, 0.04), (0, 0, ang), C('asphalt_violet'))
for i in range(-int(span / 4), int(span / 4)):
    q = road_c + R * (i * 4.0)
    g.boxb((q.x, q.y, -0.07), (2.0, 0.3, 0.012), (0, 0, ang), C('marking_thick'))
for k in (-1, 1):
    q = road_c + F * (k * 3.7)
    g.boxb((q.x, q.y, -0.1), (span, 0.4, 0.14), (0, 0, ang), C('kerb'))
assign(g.to_object())

# --- étiquettes --------------------------------------------------------------------------------------------------------
lab = bpy.data.materials.new('lab')
lab.node_tree.nodes.clear()
e = lab.node_tree.nodes.new('ShaderNodeEmission')
c = C('plinth')
e.inputs['Color'].default_value = (lib.srgb_to_lin(c[0]), lib.srgb_to_lin(c[1]), lib.srgb_to_lin(c[2]), 1)
o = lab.node_tree.nodes.new('ShaderNodeOutputMaterial')
lab.node_tree.links.new(e.outputs[0], o.inputs['Surface'])

# --- caméra ------------------------------------------------------------------------------------------------------------
cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
sc.collection.objects.link(cam)
sc.camera = cam
cam.data.type = 'ORTHO'
cam.data.clip_end = 2000
d = Vector((math.cos(PITCH) * F.x, math.cos(PITCH) * F.y, math.sin(PITCH)))
cam.location = mid + d * 300
cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
bpy.context.view_layer.update()
inv = cam.matrix_world.inverted()
labels = []

for tag, name, objs, lo, hi in pairs:
    bpy.ops.object.text_add()
    t = bpy.context.object
    t.data.body = tag
    t.data.align_x = 'CENTER'
    t.data.size = 1.3
    t.data.materials.append(lab)
    cx, cy = (lo.x + hi.x) / 2, (lo.y + hi.y) / 2
    t.location = road_c + R * R.dot(Vector((cx, cy, 0)) - road_c) + F * 5.6
    labels.append(t.location.copy())
    t.rotation_euler = cam.rotation_euler

bpy.context.view_layer.update()
xs, ys = [], []
for tag, name, objs, lo, hi in pairs:
    for x in (lo.x, hi.x):
        for y in (lo.y, hi.y):
            for z in (0, hi.z):
                q = inv @ Vector((x, y, z))
                xs.append(q.x)
                ys.append(q.y)
for q in labels:
    for dx in (-2.5, 2.5):
        v = inv @ (q + R * dx)
        xs.append(v.x)
        ys.append(v.y - 1.0)
w, h = max(xs) - min(xs), max(ys) - min(ys)
W = 2400                                                    # la hauteur suit le contenu : les modèles restent grands
H = int(min(1600, max(700, W * h / w * 1.1)))
cam.data.ortho_scale = max(w, h * W / H) * 1.04
shift = cam.matrix_world.to_3x3() @ Vector(((max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2, 0))
cam.location += shift

# --- soleil et rendu ---------------------------------------------------------------------------------------------------
sun = bpy.data.objects.new('sun', bpy.data.lights.new('sun', 'SUN'))
sc.collection.objects.link(sun)
sun.data.energy = 0.15 * math.pi / 0.8
sun.data.angle = math.radians(0.5)
sun.rotation_euler = Vector((-1.0, -0.35, 1.25)).normalized().to_track_quat('Z', 'Y').to_euler()
sc.world = bpy.data.worlds.new('w')
sc.world.color = (0, 0, 0)
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
