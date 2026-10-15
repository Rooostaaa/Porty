# Aides communes aux planches de scène (preview_g.py) : matériau ISM de preview_style.py (couleur de sommet × facteur
# d'orientation de face, 85 % émission + 15 % soleil pour les ombres portées), chargement des .glb, caméra du jeu
# (lacet 45°, plongée 35°) cadrée sur le contenu, soleil et rendu EEVEE.
import bpy, os, math
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
MODELS = os.path.join(HERE, '..', 'godot', 'assets', 'models')
PITCH, YAW = math.radians(35), math.radians(45)
R = Vector((1, 1, 0)).normalized()           # droite de l'écran, au sol
F = Vector((1, -1, 0)).normalized()          # vers la caméra, au sol
_MAT = None


def material():
    global _MAT
    if _MAT is not None:
        return _MAT
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
    _MAT = mat
    return mat


def assign(ob):
    if ob.type != 'MESH':
        return
    me = ob.data
    if me.color_attributes and me.color_attributes[0].name != 'Color':
        me.color_attributes[0].name = 'Color'
    me.materials.clear()
    me.materials.append(material())


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


def load(name, at=(0, 0, 0), rot=0.0, src=None):
    """Importe <name>.glb, pose ses racines en `at` (repère Blender) tournées de `rot` degrés autour de Z.
    Renvoie la liste des objets importés (le matériau ISM est appliqué)."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(src or MODELS, name + '.glb'))
    objs = [o for o in bpy.data.objects if o not in before]
    for o in objs:
        if o.parent is None:
            o.location = Vector(at)
            o.rotation_euler = (0, 0, math.radians(rot))
        assign(o)
    bpy.context.view_layer.update()
    return objs


def find(objs, name):
    for o in objs:
        if o.name == name or o.name.startswith(name + '.'):
            return o
    return None


def label_material():
    from palette import C
    import lib
    lab = bpy.data.materials.get('lab')
    if lab is not None:
        return lab
    lab = bpy.data.materials.new('lab')
    lab.node_tree.nodes.clear()
    e = lab.node_tree.nodes.new('ShaderNodeEmission')
    c = C('plinth')
    e.inputs['Color'].default_value = (lib.srgb_to_lin(c[0]), lib.srgb_to_lin(c[1]), lib.srgb_to_lin(c[2]), 1)
    o = lab.node_tree.nodes.new('ShaderNodeOutputMaterial')
    lab.node_tree.links.new(e.outputs[0], o.inputs['Surface'])
    return lab


def label(text, at, size=1.0, cam=None, mat=None):
    """Étiquette plate face à la caméra (ou à plat au sol si cam est None)."""
    bpy.ops.object.text_add()
    t = bpy.context.object
    t.data.body = text
    t.data.align_x = 'CENTER'
    t.data.size = size
    t.data.materials.append(mat or label_material())
    import lib
    path = next((f for f in lib.FONTS[1:] if os.path.exists(f)), None)
    if path:
        t.data.font = bpy.data.fonts.load(path, check_existing=True)
    t.location = Vector(at)
    if cam is not None:
        t.rotation_euler = cam.rotation_euler
    return t


def camera(pitch=PITCH):
    sc = bpy.context.scene
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = 'ORTHO'
    cam.data.clip_end = 4000
    d = Vector((math.cos(pitch) * F.x, math.cos(pitch) * F.y, math.sin(pitch)))
    cam.location = d * 600
    cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
    bpy.context.view_layer.update()
    return cam


def frame(cam, points, W=2400, hmax=1800, margin=1.04):
    """Cadre la caméra orthographique sur une liste de points (repère monde) ; la hauteur suit le contenu."""
    sc = bpy.context.scene
    inv = cam.matrix_world.inverted()
    xs, ys = [], []
    for p in points:
        q = inv @ Vector(p)
        xs.append(q.x)
        ys.append(q.y)
    w, h = max(xs) - min(xs), max(ys) - min(ys)
    H = int(min(hmax, max(700, W * h / w * 1.05)))
    cam.data.ortho_scale = max(w, h * W / H) * margin
    shift = cam.matrix_world.to_3x3() @ Vector(((max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2, 0))
    cam.location += shift
    sc.render.resolution_x, sc.render.resolution_y = W, H
    bpy.context.view_layer.update()


def corners(objs, z0=0.0):
    lo, hi = bbox(objs)
    return [(x, y, z) for x in (lo.x, hi.x) for y in (lo.y, hi.y) for z in (min(z0, lo.z), hi.z)]


def render(outpng, sky=(0.0, 0.0, 0.0), samples=32):
    sc = bpy.context.scene
    sun = bpy.data.objects.new('sun', bpy.data.lights.new('sun', 'SUN'))
    sc.collection.objects.link(sun)
    sun.data.energy = 0.15 * math.pi / 0.8
    sun.data.angle = math.radians(0.5)
    sun.rotation_euler = Vector((-1.0, -0.35, 1.25)).normalized().to_track_quat('Z', 'Y').to_euler()
    sc.world = bpy.data.worlds.new('w')
    sc.world.color = sky
    for eng in ('BLENDER_EEVEE', 'BLENDER_EEVEE_NEXT'):
        try:
            sc.render.engine = eng
            break
        except TypeError:
            pass
    sc.view_settings.view_transform = 'Standard'
    sc.render.filepath = outpng
    try:
        sc.eevee.taa_render_samples = samples
    except AttributeError:
        pass
    bpy.ops.render.render(write_still=True)
    print('rendu', outpng)
