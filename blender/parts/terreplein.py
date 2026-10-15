# Lot G — le terre-plein (docs/ORDRE_BLENDER_G.md § 2, docs/CADRAGE_DEBUT.md § 6) : registre C, saturé, lisible en petit.
# Le port à conteneurs se construit à la main sur un remblai : plateforme, quai n°1 court, piste et barrière, grue de bord
# du caboteur, conteneurs en attente de douane.
# Repère Blender : X = longueur, Y = profondeur (+Y = côté mer, -Y = face principale), Z = haut.
# Sols : dessus en z = 0 (comme terrain.py). Modèles articulés : pièces nommées sur leur pivot, axes en repère Godot
# dans assets_meta.json → « nodes » (comme chantier.py).
import math
import bpy
import bmesh
from mathutils import Matrix
from lib import Model, SCALE_PROPS, to_godot, hazard_band
from palette import C
from crique import bar

S = SCALE_PROPS


# =============================================================== sols ================================================

def ground_platform():
    """Plateforme de terre battue / remblai compacté, module 8 × 8 (dessus en z = 0) : couches de remblai visibles sur
    les bords, dessus terre claire, traces de pelleteuse (ornières de chenilles), enrochement bas sur deux bords."""
    m = Model('ground_platform', 290)
    w = 8.0
    m.cham((0, 0, -2.4), (w, w, 1.5), 0.15, C('earth_dark'))
    m.cham((0, 0, -0.9), (w, w, 0.9), 0.15, C('earth'), top=C('sand_warm'))
    for x, y, rz in ((-1.7, 1.0, 0.15), (1.5, -1.5, -0.35)):                            # ornières de chenilles
        for s in (-0.42, 0.42):
            m.box((x - s * math.sin(rz), y + s * math.cos(rz), 0.004), (4.0, 0.36, 0.01), (0, 0, rz), C('gravel_dark'))
    for i, (x, y) in enumerate(((-3.2, 3.2), (-1.8, 3.4), (3.2, -3.1), (3.3, -1.6))):   # dans le module 8 × 8
        m.ico((x, y, 0.05), (0.65, 0.55, 0.45), (0, 0, i * 1.1), C('rock') if i % 2 else C('rock_dark'), 0, 0.3)
    m.to_object()
    return {'module': [w, w]}


def _track_edges(m, segs):
    for (x, y, L, rz) in segs:
        m.box((x, y, 0.025), (L, 0.5, 0.05), (0, 0, rz), C('grass'))


def track_dirt():
    """Piste en terre, module 8 u sur X (plaque posée sur un sol, 0,04 d'épaisseur) : bande de terre sombre de 4 u,
    deux ornières, bords herbeux, flaque."""
    m = Model('track_dirt', 291)
    L, Wd = 8.0, 4.0
    m.boxb((0, 0, 0), (L, Wd, 0.04), (0, 0, 0), C('earth'))
    for y in (-0.9, 0.9):
        m.box((0, y, 0.045), (L, 0.42, 0.012), (0, 0, 0), C('earth_dark'))
    m.box((0, 0, 0.045), (L, 0.3, 0.008), (0, 0, 0), C('sand_warm'))
    m.ico((1.6, -0.9, 0.05), (0.7, 0.4, 0.02), (0, 0, 0.3), C('glass_light'), 0)
    _track_edges(m, ((0, Wd / 2 + 0.2, L, 0), (0, -Wd / 2 - 0.2, L, 0)))
    for x, y in ((-2.5, 2.5), (1.5, -2.5), (3.3, 2.4)):
        m.ico((x, y, 0.05), (0.45, 0.4, 0.22), (0, 0, x), C('grass_dark'), 0)
    m.to_object()
    return {'module': L, 'width': Wd, 'axis': 'x'}


def track_dirt_turn():
    """Virage à 90° de la piste (module 8 × 8) : entre par le bord -X, sort par le bord +Y ; la terre suit un quart de
    couronne (centre au coin (-4, +4)), ornières courbes, bords herbeux en arcs."""
    m = Model('track_dirt_turn', 292)
    a = 8.0
    cx, cy = -a / 2, a / 2
    n = 6

    def arc(r):
        return [(cx + math.cos(t) * r, cy + math.sin(t) * r) for t in
                (-math.pi / 2 + k * (math.pi / 2) / n for k in range(n + 1))]

    def ring(r0, r1, z, c):
        """Couronne plate (dessus seul) entre les rayons r0 et r1, posée à la hauteur z."""
        b = bmesh.new()
        lo = [b.verts.new((x, y, z)) for x, y in arc(r0)]
        hi = [b.verts.new((x, y, z)) for x, y in arc(r1)]
        for k in range(n):
            b.faces.new([lo[k], hi[k], hi[k + 1], lo[k + 1]])
        bmesh.ops.recalc_face_normals(b, faces=b.faces[:])
        m._add(b, Matrix.Identity(4), c)
    m.prism(arc(2.0) + list(reversed(arc(6.0))), 0.0, 0.04, C('earth'))              # la terre, en un seul prisme
    ring(2.9, 3.3, 0.045, C('earth_dark'))
    ring(4.7, 5.1, 0.045, C('earth_dark'))
    ring(3.85, 4.15, 0.045, C('sand_warm'))
    ring(1.5, 2.0, 0.05, C('grass'))
    ring(6.0, 6.5, 0.05, C('grass'))
    for x, y in ((2.2, -2.4), (3.0, -1.0), (-3.0, 3.0)):
        m.ico((x, y, 0.05), (0.45, 0.4, 0.22), (0, 0, x), C('grass_dark'), 0)
    m.to_object()
    return {'module': [a, a], 'enter': '-x', 'exit': '+y'}


# =============================================================== quai n°1 ============================================

def quay_small():
    """Quai n°1 court : 16 × 6 (axe X, mer en +Y, dessus en z = 0), béton neuf clair à bordure sombre et chasse-roue,
    ligne de sécurité jaune, 4 bittes ×1,35 à chapeau jaune (emblème), défenses pneus, échelle, bollards d'angle ;
    pas de rails de grue (la grue de bord du caboteur décharge)."""
    m = Model('quay_small', 293)
    w, d = 16.0, 6.0
    m.boxb((0, 0, -3.4), (w, d, 3.4), (0, 0, 0), C('concrete_dark'))
    m.boxb((0, 0, -0.3), (w, d, 0.3), (0, 0, 0), C('concrete'))
    for i in range(7):                                                                       # joints de dalle
        m.box((-6.0 + i * 2.0, -0.3, 0.004), (0.06, d - 1.2, 0.01), (0, 0, 0), C('concrete_dark'))
    m.boxb((0, d / 2 - 0.3, -0.3), (w, 0.6, 0.3), (0, 0, 0), C('asphalt_dark'))
    m.box((0, d / 2 - 0.85, 0.01), (w, 0.26, 0.03), (0, 0, 0), C('mark_yellow'))
    m.boxb((0, d / 2 - 0.06, 0.0), (w, 0.12, 0.22), (0, 0, 0), C('plinth'))
    for x in (-6.0, -2.0, 2.0, 6.0):
        m.cylb((x, d / 2 - 0.6, 0), 0.34 * S, 0.06, C('plinth'), 8)
        m.cylb((x, d / 2 - 0.6, 0.06), 0.2 * S, 0.45 * S, C('dark'), 8)
        m.cylb((x, d / 2 - 0.6, 0.06 + 0.45 * S), 0.3 * S, 0.14 * S, C('yellow'), 8)
    for x in (-5.0, -1.0, 3.0, 7.0):
        m.cyl((x, d / 2 + 0.3, -0.9), (0.55 * S, 0.55 * S, 0.4 * S), (math.pi / 2, 0, 0), C('dark'), 10)
        m.cyl((x, d / 2 + 0.3, -0.9), (0.3 * S, 0.3 * S, 0.42 * S), (math.pi / 2, 0, 0), C('plinth'), 8)
        m.tube((x, d / 2 + 0.2, -0.3), (x, d / 2, 0.1), 0.04, C('steel'), 4)
    for s in (-1, 1):
        m.boxb((4.5 + s * 0.25, d / 2 + 0.12, -1.6), (0.08, 0.08, 1.9), (0, 0, 0), C('steel'))
    for k in range(5):
        m.box((4.5, d / 2 + 0.12, -1.4 + k * 0.35), (0.5, 0.06, 0.06), (0, 0, 0), C('mark_yellow') if k == 4 else C('steel'))
    hazard_band(m, '-y', -d / 2, 0, w, -0.3, 0.3, 0.0)                                      # bande jaune-noir côté terre
    m.to_object()
    return {'module': [w, d], 'sea_side': '+y'}


# =============================================================== barrière ============================================

def barrier_post():
    """Barrière à bascule (celle qu'on touche) : deux poteaux rouge / blanc sur plots béton, caisson moteur avec feu
    orange, bras `arm` (pivot au poteau -X, s'étend vers +X sur 4,6 u, rouge-blanc à jupe, contrepoids) qui repose sur la
    fourche du poteau +X. Face principale -Y ; la piste passe sous le bras (axe Y)."""
    base = Model('base', 294)
    for x in (-2.4, 2.4):
        base.boxb((x, 0, 0), (0.9, 0.9, 0.18), (0, 0, 0), C('concrete'))
    base.boxb((-2.4, 0, 0.18), (0.6, 0.5, 1.0), (0, 0, 0), C('sign_red'))                  # caisson moteur
    base.boxb((-2.4, 0, 0.18), (0.64, 0.54, 0.3), (0, 0, 0), C('white'))
    base.boxb((-2.4, 0, 1.18), (0.66, 0.56, 0.08), (0, 0, 0), C('cap_light'))
    base.cylb((-2.4, 0, 1.26), 0.14, 0.22, C('orange'), 8)
    base.cylb((2.4, 0, 0.18), 0.1, 1.0, C('white'), 6)                                       # poteau d'appui
    base.boxb((2.4, 0, 1.18), (0.3, 0.4, 0.14), (0, 0, 0), C('dark'))                        # fourche
    for s in (-1, 1):
        base.boxb((2.4, s * 0.17, 1.3), (0.3, 0.06, 0.16), (0, 0, 0), C('dark'))
    base.boxb((-2.4, -0.45, 0.18), (0.12, 0.4, 1.0), (0, 0, 0), C('white'))                  # stop : panneau rouge
    base.box((-2.4, -0.68, 1.0), (0.6, 0.04, 0.5), (0, 0, 0), C('sign_red'))
    base.box((-2.4, -0.71, 1.0), (0.36, 0.02, 0.08), (0, 0, 0), C('white'))
    base.to_object('base')

    pivot = (-2.4, 0, 1.1)
    arm = Model('arm', 295)
    arm.box((0, 0, 0), (0.5, 0.5, 0.3), (0, 0, 0), C('dark'))                                 # moyeu
    arm.cyl((0, 0, 0), (0.24, 0.24, 0.6), (math.pi / 2, 0, 0), C('dark'), 8)
    n = 6
    for i in range(n):
        x = 0.4 + (i + 0.5) * 4.6 / n
        arm.box((x, 0, 0.0), (4.6 / n, 0.18, 0.18), (0, 0, 0), C('sign_red') if i % 2 == 0 else C('white'))
    for i in range(3):                                                                        # jupe
        x = 1.8 + i * 1.0
        arm.box((x, 0, -0.3), (0.06, 0.06, 0.45), (0, 0, 0), C('white'))
    arm.box((2.3, 0, -0.52), (3.2, 0.04, 0.06), (0, 0, 0), C('white'))
    arm.box((-0.55, 0, 0.0), (0.6, 0.26, 0.26), (0, 0, 0), C('dark'))                         # contrepoids
    arm.boxb((2.3, 0.1, 0.09), (0.3, 0.02, 0.12), (0, 0, 0), C('sign_red'))
    arm.to_object('arm', pivot)
    return {'nodes': {'arm': {'pivot': to_godot(pivot), 'rotate': 'rotation.z (> 0 : lève, 80° ouvert)',
                              'range_deg': [0, 80]}}, 'arm_length': 5.0, 'gate_x': [-2.1, 2.1]}


# =============================================================== grue de bord ========================================

def coaster_crane():
    """Grue de bord à poser sur `ship_coaster` (origine = base du socle, au niveau du pont, z = deck) : socle jaune à bande
    jaune-noir, pivot, mât jaune en caisson à cabine, flèche `boom` (pivot en haut du mât, s'étend sur +X, relevée de 30°
    à l'export) et crochet `hook` (enfant de boom, en bout, câble vertical). Rotation de l'ensemble : rotation.y de boom
    autour du mât."""
    base = Model('base', 296)
    base.boxb((0, 0, 0), (2.0, 2.0, 0.3), (0, 0, 0), C('yellow'))
    hazard_band(base, '-y', -1.0, 0, 2.0, 0.02, 0.26, 0.02)
    hazard_band(base, '+x', 1.0, 0, 2.0, 0.02, 0.26, 0.02)
    base.cylb((0, 0, 0.3), 0.75, 0.25, C('dark'), 10)
    base.cylb((0, 0, 0.55), 0.55, 2.6, C('yellow'), 8)                                        # mât
    base.boxb((0.25, -0.75, 0.9), (0.9, 0.7, 0.95), (0, 0, 0), C('white'))                    # cabine
    base.box((0.71, -0.75, 1.45), (0.03, 0.55, 0.45), (0, 0, 0), C('glass_light'))
    base.box((0.25, -1.11, 1.45), (0.7, 0.03, 0.45), (0, 0, 0), C('glass_light'))
    base.boxb((0.25, -0.75, 1.85), (0.98, 0.8, 0.07), (0, 0, 0), C('cap_light'))
    base.boxb((0, 0, 3.15), (0.9, 0.7, 0.5), (0, 0, 0), C('yellow'))                           # tête du mât
    base.ico((0, 0, 3.75), (0.1, 0.1, 0.1), (0, 0, 0), C('sign_red'), 0)
    base.to_object('base')

    pv = (0.0, 0.0, 3.4)
    L = 8.0
    boom = Model('boom', 297)
    bar(boom, (0.3, 0, 0), (L, 0, 0), 0.34, 0.3, C('yellow'))
    boom.box((L - 0.6, 0, 0.0), (1.2, 0.36, 0.32), (0, 0, 0), C('hazard'))
    boom.cyl((0.0, 0, 0), (0.3, 0.3, 0.9), (math.pi / 2, 0, 0), C('dark'), 8)                  # axe
    boom.cyl((L, 0, 0.0), (0.22, 0.22, 0.2), (math.pi / 2, 0, 0), C('dark'), 8)                # poulie de tête
    boom.tube((0.5, 0, 0.3), (L - 0.6, 0, 0.3), 0.025, C('dark'), 4)                           # câble de relevage
    boom.cyl((1.6, 0, -0.7), (0.3, 0.3, 1.8), (0, -0.9, 0), C('steel'), 6)                     # vérin
    boom.cyl((1.2, 0, -0.85), (0.2, 0.2, 1.4), (0, -0.9, 0), C('dark'), 6)
    boom.to_object('boom', pv)

    hook = Model('hook', 298)
    hook.tube((0, 0, 0), (0, 0, -3.0), 0.02, C('dark'), 4)
    hook.boxb((0, 0, -3.4), (0.4, 0.3, 0.4), (0, 0, 0), C('hazard'))
    hook.box((0, 0, -3.5), (0.12, 0.12, 0.25), (0, 0, 0), C('dark'))
    hook.box((0.09, 0, -3.62), (0.3, 0.1, 0.1), (0, 0, 0), C('dark'))
    hob = hook.to_object('hook', (L, 0, 0))
    ob = bpy.data.objects
    ob['boom'].parent = ob['base']
    hob.parent = ob['boom']
    tilt = math.radians(30)
    ob['boom'].rotation_euler = (0, -tilt, 0)
    hob.rotation_euler = (0, tilt, 0)                                                         # le câble reste vertical
    bpy.context.view_layer.update()
    return {'deck_pos_on_coaster': to_godot((7.4, 0, 1.65)),
            'nodes': {'boom': {'parent': 'base', 'pivot': to_godot(pv), 'rotate': 'rotation.z (> 0 lève ; 30° au repos) '
                               'et rotation.y (orientation autour du mât)', 'rest_deg': 30, 'range_deg': [10, 70],
                               'length': L},
                      'hook': {'parent': 'boom', 'pos': to_godot((L, 0, 0)), 'rotate': 'rotation.z = -rotation.z du boom '
                               '(câble vertical) ; descendre : position.y locale (câble 3 u)'}}}


# =============================================================== conteneurs de douane ================================

def _container_customs(name, seed, label):
    """Conteneur 20' « en attente de douane » : gabarit de container20 (2 × 1,3 × 1,3), corps blanc à bandes grises
    (montants et nervures), étiquette colorée sur le dessus, la face -Y et la face +X (lisible à 35° d'en haut)."""
    m = Model(name, seed)
    L, W, H = 2.0, 1.3, 1.3
    m.boxb((0, 0, 0.04), (L - 0.12, W - 0.06, H - 0.08), (0, 0, 0), C('white'))
    for sx in (-1, 1):
        for sy in (-1, 1):
            m.boxb((sx * (L / 2 - 0.06), sy * (W / 2 - 0.05), 0), (0.12, 0.1, H), (0, 0, 0), C('steel'))
    m.boxb((0, 0, H - 0.07), (L, W, 0.07), (0, 0, 0), C('gull_grey'))
    for sy in (-1, 1):
        for x in (-0.5, 0.5):
            m.box((x, sy * (W / 2 - 0.02), H / 2), (0.1, 0.03, H - 0.3), (0, 0, 0), C('steel'))
    m.box((0, 0, H + 0.005), (0.8, 0.5, 0.02), (0, 0, 0), label)
    m.box((0, -W / 2 - 0.01, H / 2), (0.7, 0.03, 0.42), (0, 0, 0), label)
    m.box((L / 2 + 0.01, 0, H / 2), (0.03, 0.5, 0.42), (0, 0, 0), label)
    m.to_object()
    return {'size': [L, W, H]}


def container_wait():
    return _container_customs('container_wait', 299, C('orange'))


def container_ok():
    return _container_customs('container_ok', 300, C('green'))


ASSETS = {
    'ground_platform': ground_platform, 'track_dirt': track_dirt, 'track_dirt_turn': track_dirt_turn,
    'quay_small': quay_small, 'barrier_post': barrier_post, 'coaster_crane': coaster_crane,
    'container_wait': container_wait, 'container_ok': container_ok,
}
