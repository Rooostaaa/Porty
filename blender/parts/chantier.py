# Lot F — chantiers (docs/ORDRE_BLENDER_F.md § 2, docs/PLAN_LOT_F.md F-D2) : registre C, saturé, lisible en petit.
# Repère Blender : X = longueur, Y = profondeur (-Y = face principale), Z = haut ; origine au sol.
# Modèles articulés (aucun rig) : chaque pièce mobile est un objet nommé placé sur son pivot ; Godot la retrouve par son
# nom (find_child) et la fait tourner. Axes donnés en repère Godot (Y haut) dans assets_meta.json → « nodes ».
import math
import bpy
from mathutils import Vector
from lib import Model, hazard_band, emblem_beacon, to_godot
from palette import C
from crique import bar


def site_hoarding():
    """Palissade de chantier, module 4 u (axe X, se raccorde bout à bout) : panneaux blancs, bandes jaune-noir en haut et
    en bas sur les deux faces, poteaux acier sur plots béton, feu orange sur le poteau central."""
    m = Model('site_hoarding', 220)
    L, H = 4.0, 1.9
    for x in (-L / 2, 0.0, L / 2):
        m.boxb((x, 0, 0), (0.5, 0.42, 0.2), (0, 0, 0), C('concrete'))
        m.boxb((x, 0, 0.2), (0.11, 0.11, H), (0, 0, 0), C('steel'))
    m.boxb((0, 0, 0.18), (L, 0.06, H - 0.1), (0, 0, 0), C('white'))
    for side, plane in (('-y', -0.03), ('+y', 0.03)):
        hazard_band(m, side, plane, 0, L, 0.22, 0.3)
        hazard_band(m, side, plane, 0, L, H - 0.36, 0.3)
    emblem_beacon(m, 0, 0, 0.2 + H, C('orange'), 0.8)
    m.to_object()
    return {'module': L}


def scaffold():
    """Échafaudage, module 4 × 4 × 4 (origine au sol, au centre) que le jeu étire autour d'un bâtiment en chantier :
    montants acier, lisses, planchers bois à plinthes orange sur le pourtour (le centre reste vide), croix de
    contreventement jaunes, bâche bleue sur le haut des faces -Y et +X."""
    m = Model('scaffold', 221)
    a, H = 2.0, 4.0
    for x in (-a, 0.0, a):
        for y in (-a, 0.0, a):
            if x == 0.0 and y == 0.0:
                continue
            m.boxb((x, y, 0), (0.1, 0.1, H), (0, 0, 0), C('steel'))
    for z in (2.0, 4.0):
        for s in (-1, 1):
            m.box((0, s * a, z - 0.05), (2 * a, 0.08, 0.08), (0, 0, 0), C('steel'))         # lisses
            m.box((s * a, 0, z - 0.05), (0.08, 2 * a, 0.08), (0, 0, 0), C('steel'))
            m.box((0, s * (a - 0.3), z - 0.12), (2 * a, 0.6, 0.06), (0, 0, 0), C('wood'))   # planchers
            m.box((s * (a - 0.3), 0, z - 0.12), (0.6, 2 * a - 1.2, 0.06), (0, 0, 0), C('wood'))
            m.box((0, s * (a + 0.06), z - 0.02), (2 * a, 0.04, 0.2), (0, 0, 0), C('orange'))  # plinthes
            m.box((s * (a + 0.06), 0, z - 0.02), (0.04, 2 * a, 0.2), (0, 0, 0), C('orange'))
    for x0, x1 in ((-a, 0.0), (0.0, a)):
        bar(m, (x0, -a - 0.06, 0.1), (x1, -a - 0.06, 1.9), 0.06, 0.06, C('yellow'))
    for s in (-1, 1):
        m.box((a + 0.08, s * a / 2, 1.0), (0.06, 0.06, 2.6), (s * 0.95, 0, 0), C('yellow'))
    m.boxb((0, -a - 0.12, 2.15), (2 * a + 0.1, 0.04, 1.85), (0, 0, 0), C('blue'))           # bâche
    m.boxb((a + 0.12, 0, 2.15), (0.04, 2 * a + 0.1, 1.85), (0, 0, 0), C('blue'))
    for s in (-1, 1):
        m.box((s * a / 2, -a - 0.15, 3.1), (0.08, 0.03, 1.85), (0, 0, 0), C('white'))       # sangles
        m.box((a + 0.15, s * a / 2, 3.1), (0.03, 0.08, 1.85), (0, 0, 0), C('white'))
    m.to_object()
    return {'module': [4.0, 4.0, 4.0]}


def site_crane():
    """Petite grue à tour : lest béton, mât en treillis jaune de 10 u ; au sommet la partie tournante `jib` (pivot vertical) :
    pivot, cabine blanche, tête en A, flèche en treillis (+X, 9 u), contre-flèche et contrepoids béton, tirants ; et sous la
    flèche le chariot et son crochet `hook` (enfant de `jib`, se déplace le long de X local)."""
    H, a = 10.0, 0.42
    base = Model('base', 222)
    for sx in (-1, 1):
        for sy in (-1, 1):
            base.cham((sx * 0.72, sy * 0.72, 0), (1.25, 1.25, 0.7), 0.1, C('concrete'))
    base.boxb((0, 0, 0.7), (1.4, 1.4, 0.25), (0, 0, 0), C('hazard'))
    cs = [(a, a), (-a, a), (-a, -a), (a, -a)]
    z0 = 0.95
    for x, y in cs:
        base.beam((x, y, z0), (x, y, H), 0.07, C('yellow'))
    n = 9
    dz = (H - z0) / n
    for k in range(n):
        for i in range(4):
            p, q = cs[i], cs[(i + 1) % 4]
            if k % 2:
                p, q = q, p
            base.beam((p[0], p[1], z0 + k * dz), (q[0], q[1], z0 + (k + 1) * dz), 0.04, C('yellow'))
    base.to_object('base')

    jib = Model('jib', 223)
    jib.boxb((0, 0, 0), (1.3, 1.3, 0.35), (0, 0, 0), C('dark'))
    jib.boxb((0.2, -0.95, -0.2), (0.95, 0.75, 0.95), (0, 0, 0), C('white'))                 # cabine
    jib.box((0.68, -0.95, 0.35), (0.04, 0.6, 0.45), (0, 0, 0), C('glass_light'))
    jib.box((0.2, -1.33, 0.35), (0.7, 0.04, 0.45), (0, 0, 0), C('glass_light'))
    jib.boxb((0.2, -0.95, 0.75), (1.0, 0.8, 0.08), (0, 0, 0), C('cap_light'))
    peak = (0, 0, 2.7)
    for x, y in ((0.45, 0.4), (0.45, -0.4), (-0.45, 0.4), (-0.45, -0.4)):
        jib.beam((x, y, 0.35), peak, 0.05, C('yellow'))
    jib.ico((0, 0, 2.8), (0.12, 0.12, 0.12), (0, 0, 0), C('sign_red'), 0)
    L, zb, zt = 9.0, 0.35, 1.05
    for y in (-0.35, 0.35):
        jib.beam((0.6, y, zb), (L, y, zb), 0.05, C('yellow'))
    jib.beam((0.6, 0, zt), (L - 0.4, 0, zt), 0.05, C('yellow'))
    for s in (-0.35, 0.35):
        for k in range(8):
            x0 = 0.6 + k * (L - 1.0) / 8
            x1 = 0.6 + (k + 1) * (L - 1.0) / 8
            p, q = ((x0, s, zb), (x1, 0, zt)) if k % 2 == 0 else ((x0, 0, zt), (x1, s, zb))
            jib.beam(p, q, 0.03, C('yellow'))
    jib.box((L, 0, zb + 0.15), (0.3, 0.8, 0.4), (0, 0, 0), C('hazard'))
    jib.ico((L + 0.1, 0, zb + 0.45), (0.1, 0.1, 0.1), (0, 0, 0), C('sign_red'), 0)
    for y in (-0.35, 0.35):
        jib.beam((-0.6, y, zb), (-3.6, y, zb), 0.06, C('yellow'))
    jib.box((-2.1, 0, zb + 0.06), (3.0, 0.6, 0.05), (0, 0, 0), C('steel'))
    for k in range(3):
        jib.box((-3.0 + k * 0.35, 0, zb - 0.45), (0.32, 0.9, 1.15), (0, 0, 0), C('concrete'))
    jib.beam(peak, (5.5, 0, zt), 0.025, C('steel'))
    jib.beam(peak, (-3.5, 0, zb + 0.1), 0.025, C('steel'))
    jib.to_object('jib', (0, 0, H))

    hook = Model('hook', 224)
    hook.box((0, 0, zb - 0.1), (0.55, 0.85, 0.2), (0, 0, 0), C('dark'))
    for y in (-0.12, 0.12):
        hook.beam((0, y, zb - 0.2), (0, y, -3.6), 0.015, C('dark'))
    hook.boxb((0, 0, -4.1), (0.42, 0.34, 0.5), (0, 0, 0), C('hazard'))
    hook.boxb((0, 0, -4.4), (0.12, 0.12, 0.3), (0, 0, 0), C('dark'))
    hook.box((0.08, 0, -4.42), (0.3, 0.1, 0.1), (0, 0, 0), C('dark'))
    hob = hook.to_object('hook', (6.0, 0, 0))
    hob.parent = bpy.data.objects['jib']
    bpy.context.view_layer.update()
    return {'height': H, 'jib_length': L,
            'nodes': {'jib': {'pivot': to_godot((0, 0, H)), 'rotate': 'rotation.y (flèche vers +X local, contre-flèche -X)'},
                      'hook': {'parent': 'jib', 'pos': to_godot((6.0, 0, 0)), 'x_range': [1.5, 8.5],
                               'rotate': 'aucune : déplacer position.x (chariot) le long de la flèche ; crochet 4,4 u sous la flèche'}}}


def excavator():
    """Pelleteuse jaune (parc et engins) : chenilles sombres, tourelle `turret` (cabine à toit clair, capot, contrepoids
    à bande noire, gyrophare orange), flèche coudée `boom` (enfant de turret), bras `arm` et godet (enfant de boom).
    Avant en +X."""
    base = Model('base', 225)
    for s in (-1, 1):
        base.boxb((0, s * 0.62, 0.05), (1.7, 0.5, 0.5), (0, 0, 0), C('dark'))
        for x in (-0.85, 0.85):
            base.cyl((x, s * 0.62, 0.3), (0.27, 0.27, 0.5), (math.pi / 2, 0, 0), C('dark'), 8)
        base.box((0, s * 0.62, 0.55), (1.5, 0.52, 0.04), (0, 0, 0), C('steel'))
    base.boxb((0, 0, 0.35), (1.0, 0.8, 0.3), (0, 0, 0), C('dark'))
    base.to_object('base')

    tz = 0.65
    tu = Model('turret', 226)
    tu.boxb((-0.15, 0, 0), (1.9, 1.45, 0.5), (0, 0, 0), C('yellow'))
    tu.cham((-0.95, 0, 0), (0.55, 1.45, 0.82), 0.18, C('yellow'))                          # contrepoids
    tu.box((-1.23, 0, 0.42), (0.02, 1.2, 0.14), (0, 0, 0), C('dark'))
    tu.boxb((-0.45, 0.25, 0.5), (0.85, 0.85, 0.28), (0, 0, 0), C('yellow'))                # capot moteur
    tu.cylb((-0.6, 0.45, 0.78), 0.05, 0.35, C('dark'), 6)
    tu.boxb((0.3, -0.38, 0.5), (0.8, 0.62, 0.88), (0, 0, 0), C('yellow'))                  # cabine
    tu.box((0.71, -0.38, 1.0), (0.03, 0.5, 0.55), (0, 0, 0), C('glass_light'))
    tu.box((0.32, -0.7, 1.0), (0.6, 0.03, 0.5), (0, 0, 0), C('glass_light'))
    tu.boxb((0.3, -0.38, 1.38), (0.86, 0.68, 0.07), (0, 0, 0), C('cap_light'))
    tu.cylb((0.1, -0.38, 1.45), 0.1, 0.18, C('orange'), 6)
    tu.to_object('turret', (0, 0, tz))

    bp = (0.72, 0.22, 0.4)
    bo = Model('boom', 227)
    k1, k2 = (1.3, 0, 1.15), (2.45, 0, 0.75)
    bar(bo, (0, 0, 0), k1, 0.26, 0.3, C('yellow'))
    bar(bo, k1, k2, 0.24, 0.26, C('yellow'))
    bo.tube((0.1, 0, -0.25), (0.95, 0, 0.75), 0.06, C('steel'), 6)
    bo.tube((1.35, 0, 1.35), (2.2, 0, 1.15), 0.05, C('steel'), 6)
    bo.to_object('boom', bp)

    ar = Model('arm', 228)
    bar(ar, (-0.2, 0, 0.35), (0.55, 0, -1.2), 0.2, 0.24, C('yellow'))
    ar.prism_y([(0.47, -1.05), (0.87, -1.25), (0.89, -1.65), (0.6, -1.78), (0.3, -1.52)], -0.32, 0.32, C('dark'))
    for y in (-0.2, 0.0, 0.2):
        ar.box((0.66, y, -1.8), (0.12, 0.09, 0.12), (0, 0.6, 0), C('steel'))
    ar.to_object('arm', k2)
    ob = bpy.data.objects
    ob['boom'].parent = ob['turret']
    ob['arm'].parent = ob['boom']
    bpy.context.view_layer.update()
    lift = 'rotation.z (> 0 : lève, < 0 : abaisse)'
    return {'nodes': {
        'turret': {'pivot': to_godot((0, 0, tz)), 'rotate': 'rotation.y (orientation de la tourelle)'},
        'boom': {'parent': 'turret', 'pivot': to_godot(bp), 'rotate': lift, 'range_deg': [-35, 25]},
        'arm': {'parent': 'boom', 'pivot': to_godot(k2), 'rotate': 'rotation.z (> 0 : le bras s\'ouvre vers l\'avant)',
                'range_deg': [-30, 60]}}}


def dust_pile():
    """Tas de gravats et de sable : dune de sable chaud, tas de gravier, blocs de béton et de brique, planche, fer rouillé,
    pelle plantée."""
    m = Model('dust_pile', 229)
    m.cham((0.2, 0.1, 0), (4.0, 3.0, 0.04), 0.6, C('earth'))
    m.ico((-0.4, 0, 0), (1.7, 1.35, 0.95), (0, 0, 0.3), C('sand_warm'), 1, 0.2)
    m.ico((1.15, 0.55, 0), (1.05, 0.95, 0.7), (0, 0, 1.1), C('gravel'), 1, 0.25)
    chunks = ((C('concrete'), 0.45), (C('brick'), 0.35), (C('concrete_dark'), 0.4), (C('kerb'), 0.3),
              (C('brick'), 0.3), (C('concrete'), 0.35), (C('gravel_dark'), 0.4), (C('concrete_dark'), 0.3))
    for i, (c, s) in enumerate(chunks):
        a = i * 0.8 + 0.3
        r = 1.1 + (i % 3) * 0.35
        m.box((0.4 + math.cos(a) * r, math.sin(a) * r * 0.8, s * 0.35 + 0.2 * (i % 2)), (s * 1.3, s, s * 0.7),
              (0.3 * i, 0.2 * (i % 3), a), c)
    m.box((1.6, -0.9, 0.18), (1.6, 0.26, 0.07), (0.1, -0.15, 0.4), C('wood'))
    m.tube((0.9, 0.9, 0.2), (1.8, 1.2, 0.9), 0.03, C('rust'), 4)
    m.tube((-0.6, -0.3, 0.6), (-0.95, -0.55, 1.9), 0.04, C('wood'), 5)                    # pelle
    m.box((-0.52, -0.25, 0.55), (0.24, 0.05, 0.3), (0.25, -0.2, 0), C('steel'))
    m.to_object()


ASSETS = {
    'site_hoarding': site_hoarding, 'scaffold': scaffold, 'site_crane': site_crane, 'excavator': excavator,
    'dust_pile': dust_pile,
}
