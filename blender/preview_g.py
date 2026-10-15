# Planches de scène du lot G (docs/ORDRE_BLENDER_G.md § 3) : les nouveaux .glb posés dans un décor (eau, sable, friche)
# avec la caméra du jeu (lacet 45°, plongée 35°), matériau ISM de preview_style.py.
#   blender -b -P preview_g.py -- <crique|nuages|terreplein|budget> <sortie.png>
import bpy, sys, os, math, json
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, 'parts'))
args = sys.argv[sys.argv.index('--') + 1:]
scene, outpng = args[0], args[1]

bpy.ops.wm.read_factory_settings(use_empty=True)
import lib
import preview_lib as P
from palette import C

ALL = []            # modèles (pour le cadrage)
NEW = []            # (nom, lo, hi) des nouveaux modèles, pour les étiquettes


def put(name, x, y, z=0.0, rot=0.0, tag=None, lab=(0, 0)):
    """lab = décalage (x, y) de l'étiquette quand l'emplacement par défaut est masqué."""
    objs = P.load(name, (x, y, z), rot)
    ALL.extend(objs)
    if tag is not None:
        lo, hi = P.bbox(objs)
        d = Vector((lab[0], lab[1], 0))
        NEW.append((tag, lo + d, hi + d))
    return objs


def ground(x, y, z, w, d, c, th=0.3):
    g = lib.Model('g', 1)
    g.boxb((0, 0, -th), (w, d, th), (0, 0, 0), c)
    ob = g.to_object('ground', (x, y, z))
    P.assign(ob)
    return ob


def water(x, y, z, w, d):
    return ground(x, y, z, w, d, C('water'), 0.05)


def labels(cam, size=1.0):
    """Étiquette face caméra, devant le modèle (hors de son emprise), à la hauteur de sa base."""
    for tag, lo, hi in NEW:
        c = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, max(lo.z, -0.2) + size * 0.9))
        half = max(hi.x - lo.x, hi.y - lo.y) / 2
        P.label(tag, c + P.F * (half * 0.72 + 1.0 + size * 0.6), size, cam)


def frame_all(cam, W=2400, hmax=1800, pad=3.0):
    lo, hi = P.bbox(ALL)
    pts = [(x, y, z) for x in (lo.x - pad, hi.x + pad) for y in (lo.y - pad, hi.y + pad) for z in (min(lo.z, 0) - 0.5, hi.z)]
    P.frame(cam, pts, W, hmax)


# ---------------------------------------------------------------------------------------------------------------- crique
if scene == 'crique':
    water(0, 10, 0.0, 90, 60)
    ground(0, -7, 0.5, 60, 14, C('sand_warm'), 0.5)                      # la terre, 0,5 au-dessus de l'eau
    ground(0, -0.3, 0.52, 60, 0.8, C('sand'), 0.52)                      # plage
    ground(0, -12.5, 0.55, 60, 3.0, C('grass'), 0.05)
    # services à quai (registre B), Marcel
    put('fuel_pump', -17.5, -3.5, 0.5, 0, 'fuel_pump')
    put('wash_bay', -9.5, -5.0, 0.5, 0, 'wash_bay')
    put('fish_hall', 1.0, -8.0, 0.5)
    put('marcel', 12.3, -2.0, 0.5, 0, 'marcel')
    put('boat_trawler', -18.0, 4.0, 0.0, 15)
    # grande jetée (tournée de 90° : s'avance en mer sur Y, les pneus côté -X) et le thonier à couple
    put('pier_long', 12.0, 7.0, 0.0, 90, 'pier_long')
    put('boat_tuna', 9.2, 7.5, 0.0, 90)
    # marina : passerelle (pontoon) puis ponton de plaisance et ses 6 voiliers, le petit yacht en bout
    put('pontoon', -9.0, 3.0, 0.0, 90)
    put('marina_pontoon', -4.0, 6.0, 0.0, 0, 'marina_pontoon')
    for i, bx in enumerate((-6.5, -4.0, -1.5)):
        put('sailboat_a' if i % 2 == 0 else 'sailboat_b', bx, 6.0 - 2.5, 0.0, 90, 'sailboat_a' if i == 0 else None)
        put('sailboat_b' if i % 2 == 0 else 'sailboat_a', bx, 6.0 + 2.5, 0.0, -90, 'sailboat_b' if i == 0 else None)
    put('yacht_small', 4.2, 6.0, 0.0, 0, 'yacht_small')
    put('boat_dinghy', -14.0, 9.5, 0.0, 200)
    put('gull', -11.5, -1.0, 0.5)
    put('gull_b', 15.5, 9.5, 0.9, 40)
    put('docker', 2.5, -3.5, 0.5)
    # le caboteur de Corsaire passe au large
    put('ship_passing', 4.0, 23.0, 0.0, 180, 'ship_passing')
    cam = P.camera()
    labels(cam, 0.8)
    frame_all(cam, 2400, 1700, 2.0)
    P.render(outpng)

# ---------------------------------------------------------------------------------------------------------------- nuages
elif scene == 'nuages':
    water(10, 10, 0.0, 140, 90)
    ground(-14, -9, 0.5, 40, 20, C('sand_warm'), 0.5)                   # l'anse (terre)
    ground(38, -14, 0.5, 70, 30, C('grass_dark'), 0.5)                  # la friche, sous les nuages
    ground(10, -4, 0.5, 14, 10, C('grass'), 0.5)                         # le cap
    put('hill', 10, -4, 0.5)
    put('odette_hut', -20, -6, 0.5)
    put('pontoon_ruin', -12, 2, 0.0)
    put('boat_dinghy', -8, 5, 0.0, 30)
    put('fish_hall', -8, -12, 0.5)
    put('tree_pine', 6, -7, 0.5)
    put('tree_pine_b', 14, -2, 0.5)
    # le banc de nuages : bancs épais sur la friche (dessous à 1 u au-dessus de la terre), nuages isolés aux bords
    for x, y, r in ((24, -8, 0), (46, -12, 180), (34, 4, 90), (56, 2, 20), (30, -22, -15)):
        put('cloud_bank', x, y, 1.5, r, 'cloud_bank' if (x, y) == (30, -22) else None)
    for x, y, r in ((14, 4, 0), (18, -16, 40), (62, -22, 0), (44, 12, 70), (12, -14, 120), (66, 10, 0)):
        put('cloud_puff', x, y, 2.0 + 0.3 * (x % 3), r, 'cloud_puff' if (x, y) == (14, 4) else None)
    cam = P.camera()
    labels(cam, 1.2)
    frame_all(cam, 2400, 1500, 4.0)
    P.render(outpng)

# ------------------------------------------------------------------------------------------------------------ terre-plein
elif scene == 'terreplein':
    water(0, 40, -1.2, 120, 70)
    ground(0, -8, -0.3, 80, 60, C('grass_dark'), 0.9)                   # la friche, 0,9 au-dessus de l'eau
    ground(0, 4, -0.3, 60, 3, C('sand_warm'), 0.9)
    for x in (-8, 0, 8):
        for y in (-4, 4):
            put('ground_platform', x, y, 0.0, 0, 'ground_platform' if (x, y) == (-8, -4) else None)
    put('quay_small', 0, 11, 0.0, 0, 'quay_small', lab=(6.5, 0))
    ship = put('ship_coaster', 0, 17.2, -1.2, 0)
    crane = put('coaster_crane', 7.4, 17.2, -1.2 + 1.65, 0, 'coaster_crane')
    boom = P.find(crane, 'boom')
    if boom is not None:
        boom.rotation_mode = 'XYZ'                                        # l'import glTF laisse l'objet en quaternion
        boom.rotation_euler = (0, -math.radians(30), -math.pi / 2)       # flèche tournée vers le quai (-Y)
    hook = P.find(crane, 'hook')
    if hook is not None:
        bpy.context.view_layer.update()
        tip = hook.matrix_world.translation
        put('container_wait', tip.x, tip.y, tip.z - 5.0, 90)             # conteneur suspendu au crochet
    # conteneurs posés sur la plateforme par la grue, puis tamponnés
    for i, (x, y, r) in enumerate(((5.5, 6.0, 0), (3.2, 6.2, 0), (0.6, 5.2, 10))):
        put('container_wait', x, y, 0.0, r, 'container_wait' if i == 0 else None)
    for i, (x, y, r) in enumerate(((-3.0, 1.0, 90), (-3.0, -1.6, 90))):
        put('container_ok', x, y, 0.0, r, 'container_ok' if i == 1 else None, lab=(-2.5, 0))
    put('customs_hut', 5.0, -3.0, 0.0)
    put('customs_officer', 8.2, -4.6, 0.0)
    put('docker', -1.0, 3.0, 0.0)
    put('excavator', -7.5, 3.0, 0.0, 200)
    # piste en terre et barrière, le camion attend
    for i, y in enumerate((-12, -20)):
        put('track_dirt', 6, y, -0.3, 90, 'track_dirt' if i == 1 else None, lab=(1.5, -2.0))
    put('track_dirt_turn', 6, -28, -0.3, 0, 'track_dirt_turn')
    put('track_dirt', -2, -28, -0.3, 0)
    put('barrier_post', 6, -9.2, -0.3, 0, 'barrier_post')
    put('truck', 6, -16.5, -0.3, 90)
    put('tree_oak', -6, -14, -0.3)
    put('tree_pine', 14, -18, -0.3)
    put('bush', 11, -12, -0.3)
    cam = P.camera()
    labels(cam, 0.9)
    frame_all(cam, 2400, 1800, 2.5)
    P.render(outpng)

# ---------------------------------------------------------------------------------------------------------------- budget
elif scene == 'budget':
    sys.path.insert(0, HERE)
    import build_assets_budget as B
    with open(os.path.join(P.MODELS, 'assets_meta.json'), encoding='utf-8') as f:
        meta = json.load(f)
    rows = [('fuel_pump', 'borne rouge + goutte'), ('wash_bay', 'portique bleu + jets'), ('pier_long', 'lampadaire + pneus'),
            ('marina_pontoon', 'bornes bleu-blanc'), ('sailboat_a', 'mât + voile ferlée  [mast]'),
            ('sailboat_b', 'mât + voile ferlée  [mast]'), ('yacht_small', 'flybridge blanc'), ('marcel', 'ciré jaune'),
            ('ship_passing', 'pavillon Corsaire'), ('cloud_bank', 'vcol uniforme, dessous plat'),
            ('cloud_puff', 'vcol uniforme, dessous plat'), ('ground_platform', '—'), ('quay_small', 'bittes jaunes'),
            ('track_dirt', '—'), ('track_dirt_turn', '—'), ('barrier_post', 'bras rouge-blanc  [arm]'),
            ('coaster_crane', '[boom] [hook]'), ('container_wait', 'étiquette orange'), ('container_ok', 'étiquette verte')]
    mat = P.label_material()
    y = 0.0
    t = P.label('Lot G — triangles par modèle (budgets de docs/ORDRE_BLENDER_G.md § 2)', (0, 2.0, 0), 1.0, None, mat)
    t.data.align_x = 'LEFT'
    for col, x in (('modèle', 0), ('tris', 10.5), ('budget', 14.5), ('emblème / nœuds nommés', 19)):
        t = P.label(col, (x, 0.0, 0), 0.8, None, mat)
        t.data.align_x = 'LEFT'
    total = 0
    for name, note in rows:
        y -= 1.3
        tris = meta.get(name, {}).get('tris', 0)
        total += tris
        bud = B.budget(name)
        for txt, x in ((name, 0), (str(tris), 10.5), (str(bud), 14.5), (note, 19)):
            t = P.label(txt, (x, y, 0), 0.8, None, mat)
            t.data.align_x = 'LEFT'
    y -= 1.6
    t = P.label('total %d triangles, %d modèles, aucun dépassement' % (total, len(rows)), (0, y, 0), 0.8, None, mat)
    t.data.align_x = 'LEFT'
    # fond clair
    g = lib.Model('bg', 1)
    g.boxb((16, (y - 1) / 2 + 1.5, -0.1), (36, -y + 5.5, 0.05), (0, 0, 0), C('wood_cream'))
    P.assign(g.to_object('bg'))
    sc = bpy.context.scene
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = 'ORTHO'
    cam.location = (16, (y - 1) / 2 + 1.5, 50)
    cam.rotation_euler = (0, 0, 0)
    h = -y + 5.5
    sc.render.resolution_x, sc.render.resolution_y = 2000, int(2000 * h / 36)
    cam.data.ortho_scale = 36
    P.render(outpng, (0.95, 0.94, 0.9), 8)
