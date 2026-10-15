# Lot F — Acte 0 « La Crique » (docs/ORDRE_BLENDER_F.md § 2, docs/PLAN_LOT_F.md § 5) : registre B, bois, couleurs chaudes.
# Repère Blender : X = longueur, Y = profondeur (+Y = côté mer, -Y = face principale), Z = haut.
# Bateaux : étrave vers +X, origine sur la ligne de flottaison (le jeu les pose à WATER_Y), comme fishing_boat.
# Pontons : origine sur la ligne de flottaison, plancher à z = 0,45. Bâtiments et estacade : origine au sol (z = 0).
# Couleurs : uniquement palette.json (aucune teinte calculée). Accessoires ×1,35.
import math
import bmesh
from mathutils import Matrix, Vector
from lib import (Model, emblem_life_ring, gable_roof, hard_block, b_window, b_door, ac_unit, tail_lights, _face, _size,
                 SCALE_PROPS, to_godot)
from palette import C

S = SCALE_PROPS


# --- aides communes au lot F --------------------------------------------------------------------------------------------

def strip(m, a, b, z0, h, th, c):
    """Planche verticale posée de a à b (points au sol x, y), hauteur h à partir de z0, épaisseur th."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    m.boxb(((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, z0), (math.hypot(dx, dy), th, h), (0, 0, math.atan2(dy, dx)), c)


def bar(m, a, b, w, th, c):
    """Poutre rectangulaire de a à b ; à utiliser dans un plan vertical XZ ou horizontal (largeur w selon Y ou à plat)."""
    a, b = Vector(a), Vector(b)
    d = b - a
    L = d.length
    if L < 1e-6:
        return
    q = Vector((1, 0, 0)).rotation_difference(d.normalized()).to_matrix().to_4x4()
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    m._add(bm, Matrix.Translation((a + b) / 2) @ q @ Matrix.Diagonal((L, w, th, 1)), c)


def fish_shape(m, cx, cz, plane, k, c, eye=None, axis='y', head=-1):
    """Poisson peint (silhouette plate) : corps à 5 pans + queue, dans un plan vertical. axis='y' : plan YZ (face ±X,
    extrudé de plane à plane + 0,04·signe) ; axis='x' : plan XZ (face ±Y). head = sens de la tête le long du plan."""
    body = [(0.75, 0), (0.3, 0.36), (-0.4, 0.2), (-0.4, -0.2), (0.3, -0.36)]
    tail = [(-0.3, 0), (-0.78, 0.34), (-0.78, -0.34)]
    for poly in (body, tail):
        pts = [(cx + head * u * k, cz + v * k) for u, v in poly]
        if head < 0:
            pts = list(reversed(pts))
        (m.prism_x if axis == 'y' else m.prism_y)(pts, plane[0], plane[1], c)
    if eye is not None:
        e = (cx + head * 0.42 * k, cz + 0.06 * k)
        if axis == 'y':
            m.box((plane[1] if plane[1] > plane[0] else plane[1], e[0], e[1]), (0.03, 0.1 * k, 0.1 * k), (0, 0, 0), eye)
        else:
            m.box((e[0], plane[1], e[1]), (0.1 * k, 0.03, 0.1 * k), (0, 0, 0), eye)


def _outline(L, W, bow):
    """Contour du pont d'une coque Model.hull (moitié +Y), de l'arrière à l'étrave."""
    hw = W / 2
    return [(-L / 2, hw), (L / 2 - L * bow, hw), (L / 2 - L * bow * 0.45, 0.55 * hw), (L / 2, 0.0)]


def hull_strip(m, L, W, bow, z0, h, c, th=0.06, out=0.025, transom=True):
    """Bande colorée (liston, préceinte, pavois) qui suit le bordé d'une coque, tableau arrière compris."""
    o = _outline(L, W, bow)
    for s in (-1, 1):
        pts = [(x, s * (y + (out if y > 0 else 0))) for x, y in o]
        for a, b in zip(pts, pts[1:]):
            strip(m, a, b, z0, h, th, c)
    if transom:
        m.boxb((-L / 2 - out, 0, z0), (th, W + 2 * out, h), (0, 0, 0), c)


def tyre(m, x, y, z, r=0.2):
    """Pneu pare-battage sur le bordé."""
    m.cyl((x, y, z), (r, r, 0.12), (math.pi / 2, 0, 0), C('dark'), 6)


def cleat(m, x, y, z, s=S, c=None):
    """Taquet ×1,35 : socle, fût, cornes."""
    c = c or C('dark')
    m.boxb((x, y, z), (0.3 * s, 0.12 * s, 0.06 * s), (0, 0, 0), C('plinth'))
    m.boxb((x, y, z + 0.06 * s), (0.09 * s, 0.09 * s, 0.1 * s), (0, 0, 0), c)
    m.box((x, y, z + 0.2 * s), (0.45 * s, 0.1 * s, 0.08 * s), (0, 0, 0), c)


# =============================================================== bateaux ==============================================

def boat_dinghy():
    """Barque de pêche à moteur hors-bord, 2,2 × 0,9 : coque orange à large préceinte bleue (bicolore vive), plat-bord blanc,
    moteur noir capot blanc, caisse de poisson bleu clair ×1,35 pleine de poissons, banc, nourrice rouge."""
    m = Model('boat_dinghy', 201)
    L, W, H, keel, bow = 2.2, 0.9, 0.6, -0.25, 0.3
    deck = keel + H
    m.hull(L, W, H, bow, 0.08, (0, 0, keel), C('hull_red'), C('hull_orange'), 0.5, C('wood'))
    hull_strip(m, L, W, bow, 0.14, 0.17, C('blue'))                                   # préceinte bleue
    hull_strip(m, L, W, bow, deck - 0.02, 0.08, C('white'), th=0.1, out=0.02)          # plat-bord
    # moteur hors-bord
    x = -L / 2 - 0.16
    m.boxb((x, 0, -0.32), (0.07, 0.07, 0.62), (0, 0, 0), C('steel'))
    m.cham((x - 0.02, 0, deck - 0.05), (0.32, 0.26, 0.36), 0.06, C('dark'), top=C('white'))
    bar(m, (x + 0.1, 0, deck + 0.18), (x + 0.5, 0, deck + 0.3), 0.06, 0.06, C('dark'))
    m.boxb((-0.72, 0.22, deck - 0.04), (0.22, 0.16, 0.16), (0, 0, 0), C('sign_red'))    # nourrice
    m.box((-0.32, 0, deck + 0.06), (0.18, W * 0.86, 0.06), (0, 0, 0), C('wood'))        # banc
    # caisse de poisson ×1,35 et sa pêche
    cx = 0.28
    m.cham((cx, 0, deck - 0.06), (0.58, 0.46, 0.26), 0.04, C('blue_light'))
    m.box((cx, 0, deck + 0.2), (0.5, 0.38, 0.02), (0, 0, 0), C('foam'))
    for i, (dy, rz, c) in enumerate(((-0.1, 0.35, C('gull_grey')), (0.06, -0.25, C('steel')), (0.13, 0.5, C('gull_grey')))):
        m.box((cx - 0.02 + i * 0.03, dy, deck + 0.23), (0.34, 0.1, 0.06), (0, 0, rz), c)
        m.box((cx - 0.19 + i * 0.03, dy - 0.06 * rz, deck + 0.23), (0.09, 0.09, 0.05), (0, 0, rz + 0.78), c)
    m.to_object()


def boat_trawler():
    """Chalutier ≈ 5 u : coque verte à préceinte jaune, liston de flottaison rouge, pavois vert à lisse blanche,
    timonerie blanche à l'avant (bandeau rouge falun, toit clair), mât et radar. Emblème : portique de chalut orange à
    l'arrière, enrouleur de filet vert, panneaux de chalut sombres, filet qui retombe à la mer avec ses flotteurs."""
    m = Model('boat_trawler', 202)
    L, W, H, keel, bow = 5.0, 1.9, 1.25, -0.5, 0.3
    deck = keel + H
    m.hull(L, W, H, bow, 0.06, (0, 0, keel), C('hull_red'), C('hull_green'), 0.4, C('wood'))
    hull_strip(m, L, W, bow, 0.0, 0.12, C('hull_red'))                                # liston de flottaison
    hull_strip(m, L, W, bow, 0.42, 0.2, C('yellow'))                                  # préceinte
    hull_strip(m, L, W, bow, deck, 0.3, C('hull_green'), th=0.08, out=0.0)            # pavois
    hull_strip(m, L, W, bow, deck + 0.3, 0.05, C('white'), th=0.12, out=0.0)          # lisse
    # timonerie à l'avant
    wx = 0.75
    m.boxb((wx, 0, deck), (1.3, 1.3, 1.0), (0, 0, 0), C('white'))
    m.box((wx, 0, deck + 0.9), (1.33, 1.33, 0.14), (0, 0, 0), C('falun'))
    m.box((wx + 0.66, 0, deck + 0.62), (0.05, 1.05, 0.32), (0, 0, 0), C('glass_light'))
    for s in (-1, 1):
        m.box((wx + 0.1, s * 0.66, deck + 0.62), (0.75, 0.05, 0.28), (0, 0, 0), C('glass_light'))
    m.boxb((wx, 0, deck + 1.0), (1.45, 1.45, 0.1), (0, 0, 0), C('cap_light'))
    emblem_life_ring(m, (wx - 0.67, 0, deck + 0.5), 0.22, '-x')
    m.cylb((wx + 0.25, 0, deck + 1.1), 0.05, 1.6, C('white'), 6)                      # mât
    m.box((wx + 0.25, 0, deck + 2.3), (0.06, 0.9, 0.06), (0, 0, 0), C('white'))
    m.ico((wx + 0.25, 0, deck + 2.75), (0.09, 0.09, 0.09), (0, 0, 0), C('sign_red'), 0)
    m.boxb((wx - 0.35, 0, deck + 1.1), (0.08, 0.08, 0.3), (0, 0, 0), C('steel'))       # radar
    m.box((wx - 0.35, 0, deck + 1.45), (0.12, 0.8, 0.08), (0, 0, 0.4), C('white'))
    # enrouleur de filet
    dx = -1.05
    m.cyl((dx, 0, deck + 0.5), (0.36, 0.36, 1.15), (math.pi / 2, 0, 0), C('net_green'), 10)
    for s in (-1, 1):
        m.cyl((dx, s * 0.6, deck + 0.5), (0.44, 0.44, 0.06), (math.pi / 2, 0, 0), C('steel'), 8)
        m.boxb((dx, s * 0.66, deck), (0.16, 0.08, 0.5), (0, 0, 0), C('steel'))
    # portique de chalut (emblème) légèrement incliné vers l'arrière
    gx, gh, ga = -2.1, 2.3, -0.16
    xt = gx + math.sin(ga) * gh
    zt = deck + math.cos(ga) * gh
    for s in (-1, 1):
        m.box((gx + math.sin(ga) * gh / 2, s * 0.78, deck + math.cos(ga) * gh / 2), (0.17, 0.17, gh), (0, ga, 0), C('hull_orange'))
        m.ico((xt, s * 0.45, zt - 0.28), (0.12, 0.12, 0.16), (0, 0, 0), C('dark'), 0)             # poulies
        m.boxb((gx + 0.05, s * 1.05, deck + 0.05), (0.75, 0.08, 0.48), (0, 0, 0), C('plinth'))    # panneaux de chalut
        m.box((gx + 0.05, s * 1.05, deck + 0.56), (0.75, 0.1, 0.07), (0, 0, 0), C('yellow'))
    m.box((xt, 0, zt), (0.24, 1.82, 0.24), (0, 0, 0), C('hull_orange'))
    m.ico((xt + 0.02, 0, zt + 0.2), (0.1, 0.1, 0.1), (0, 0, 0), C('yellow'), 0)
    # filet : de l'enrouleur au portique, puis à la mer
    bar(m, (dx - 0.05, 0, deck + 0.85), (xt + 0.05, 0, zt - 0.08), 0.95, 0.07, C('net_green'))
    bar(m, (xt - 0.05, 0, zt - 0.1), (-L / 2 - 0.55, 0, -0.1), 1.1, 0.07, C('net_green'))
    for k in range(4):
        t = 0.15 + k * 0.22
        p = Vector((xt, 0, zt - 0.1)).lerp(Vector((-L / 2 - 0.55, 0, -0.1)), t)
        m.ico((p.x - 0.06, -0.38 + k * 0.25, p.z + 0.05), (0.1, 0.1, 0.1), (0, 0, 0), C('orange'), 0)
    # caisses de poisson
    for i in range(2):
        m.cham((-0.15 + i * 0.05, -0.45, deck + i * 0.28), (0.62, 0.45, 0.26), 0.04, C('blue_light') if i == 0 else C('white'))
    for x in (-1.3, 0.2, 1.4):
        for s in (-1, 1):
            tyre(m, x, s * (W / 2 + 0.07), 0.62, 0.18)
    m.to_object()


def boat_tuna():
    """Thonier-senneur ≈ 8 u : coque marine à préceinte blanche et liston rouge, gaillard d'avant, château blanc à deux
    niveaux (bandeau bleu, toit clair). Emblèmes : grand mât blanc et son nid-de-pie jaune, skiff orange sur la plage
    arrière ; senne verte en tas, flotteurs jaunes, mât de charge à poulie motrice."""
    m = Model('boat_tuna', 203)
    L, W, H, keel, bow = 8.0, 2.6, 1.7, -0.7, 0.3
    deck = keel + H
    hw = W / 2
    m.hull(L, W, H, bow, 0.06, (0, 0, keel), C('hull_red'), C('hull_navy'), 0.4, C('wood'))
    hull_strip(m, L, W, bow, 0.0, 0.16, C('sign_red'))                                 # liston de flottaison
    hull_strip(m, L, W, bow, 0.62, 0.18, C('white'))                                   # préceinte
    hull_strip(m, L, W, bow, deck, 0.32, C('hull_navy'), th=0.09, out=0.0)             # pavois
    hull_strip(m, L, W, bow, deck + 0.32, 0.05, C('white'), th=0.13, out=0.0)
    # gaillard d'avant
    o = _outline(L, W, bow)
    pts = [(0.6, -hw)] + [(x, -y) for x, y in o[1:]][:-1] + [(L / 2, 0.0)] + [(x, y) for x, y in reversed(o[1:-1])] + [(0.6, hw)]
    m.prism(pts, deck, deck + 0.45, C('hull_navy'), top=C('wood'))
    # château
    sx = 1.25
    m.boxb((sx, 0, deck + 0.45), (2.0, 2.0, 1.0), (0, 0, 0), C('white'))
    m.box((sx, 0, deck + 1.32), (2.03, 2.03, 0.16), (0, 0, 0), C('roof_b_blue'))
    for s in (-1, 1):
        m.box((sx + 0.1, s * 1.01, deck + 0.95), (1.3, 0.05, 0.3), (0, 0, 0), C('glass_light'))
    m.boxb((sx + 0.15, 0, deck + 1.45), (1.5, 1.8, 0.85), (0, 0, 0), C('white'))
    m.box((sx + 0.91, 0, deck + 1.95), (0.05, 1.5, 0.4), (0, 0, 0), C('glass_light'))
    for s in (-1, 1):
        m.box((sx + 0.15, s * 0.91, deck + 1.95), (1.1, 0.05, 0.35), (0, 0, 0), C('glass_light'))
    m.boxb((sx + 0.15, 0, deck + 2.3), (1.7, 2.1, 0.1), (0, 0, 0), C('cap_light'))
    m.boxb((sx + 0.3, 0, deck + 2.4), (0.08, 0.08, 0.35), (0, 0, 0), C('steel'))
    m.box((sx + 0.3, 0, deck + 2.8), (0.14, 1.0, 0.08), (0, 0, 0.5), C('white'))
    emblem_life_ring(m, (sx - 1.01, 0.5, deck + 1.0), 0.25, '-x')
    # grand mât et nid-de-pie (emblème)
    mx = -0.1
    m.cylb((mx, 0, deck), 0.09, 6.6, C('white'), 6)
    m.box((mx, 0, deck + 3.4), (0.08, 1.8, 0.08), (0, 0, 0), C('white'))
    nz = deck + 4.9
    m.cylb((mx, 0, nz), 0.38, 0.55, C('yellow'), 8)
    m.cylb((mx, 0, nz + 0.55), 0.44, 0.08, C('dark'), 8)
    m.ico((mx, 0, deck + 6.7), (0.11, 0.11, 0.11), (0, 0, 0), C('sign_red'), 0)
    for b in ((L / 2 - 0.1, 0, deck + 0.6), (-L / 2 + 0.3, 0, deck + 0.5)):
        m.tube((mx, 0, deck + 6.2), b, 0.02, C('dark'), 4)                              # étais
    # mât de charge et poulie motrice
    bar(m, (mx, 0, deck + 0.8), (-2.6, 0, deck + 3.3), 0.14, 0.14, C('white'))
    m.ico((-2.65, 0, deck + 3.05), (0.24, 0.16, 0.24), (0, 0, 0), C('dark'), 0)
    m.tube((-2.65, 0, deck + 2.85), (-2.4, 0, deck + 0.9), 0.03, C('dark'), 4)
    # senne en tas et flotteurs
    m.ico((-1.55, 0.05, deck + 0.3), (1.15, 0.95, 0.55), (0, 0, 0.2), C('net_green'), 1, 0.25)
    m.ico((-2.2, -0.4, deck + 0.25), (0.6, 0.55, 0.4), (0, 0, 0.8), C('pine_dark'), 0, 0.25)
    for k in range(6):
        a = -0.9 + k * 0.36
        m.ico((-1.55 + math.cos(a) * 0.85, math.sin(a) * 0.75, deck + 0.68 - abs(a) * 0.12), (0.11, 0.11, 0.11),
              (0, 0, 0), C('yellow'), 0)
    # skiff orange sur la plage arrière (emblème)
    sk = [(-4.55, -0.52), (-3.35, -0.58), (-2.85, 0.0), (-3.35, 0.58), (-4.55, 0.52)]
    m.prism(sk, deck + 0.08, deck + 0.62, C('hull_orange'))
    inner = [(-4.4, -0.38), (-3.4, -0.43), (-3.05, 0.0), (-3.4, 0.43), (-4.4, 0.38)]
    m.prism(inner, deck + 0.5, deck + 0.64, C('navy'))                                  # intérieur sombre
    for a, b in zip(sk, sk[1:]):
        strip(m, a, b, deck + 0.62, 0.06, 0.1, C('white'))                              # plat-bord blanc
    strip(m, sk[-1], sk[0], deck + 0.62, 0.06, 0.1, C('white'))
    m.boxb((-3.75, 0, deck + 0.62), (0.3, 0.3, 0.35), (0, 0, 0), C('yellow'))         # bitte de remorquage
    for x in (-3.0, -1.0, 1.0, 2.6):
        for s in (-1, 1):
            tyre(m, x, s * (hw + 0.07), 0.85, 0.22)
    m.to_object()


# =============================================================== pontons =============================================

def _pontoon_frame(m, planks, floats, cleats):
    """Ponton flottant 6 × 1,6 : flotteurs marine, longerons, planches, lisses de rive, taquets ×1,35.
    planks = [(x, longueur, décalage y, rotation z, couleur, levée)] ; floats = abscisses des flotteurs."""
    L, Wd = 6.0, 1.6
    for x in floats:
        m.boxb((x, 0, -0.32), (1.15, 1.3, 0.52), (0, 0, 0), C('navy'))
    for y in (-0.55, 0.55):
        m.boxb((0, y, 0.2), (L, 0.18, 0.15), (0, 0, 0), C('earth_dark'))
    for x, ln, dy, rz, c, lift in planks:
        m.boxb((x, dy, 0.35 + lift), (L / 12 - 0.06, ln, 0.1), (0, 0, rz), c)
    for s in (-1, 1):
        m.boxb((0, s * (Wd / 2 + 0.05), 0.2), (L, 0.1, 0.24), (0, 0, 0), C('earth_dark'))
    for x, y, c in cleats:
        cleat(m, x, y, 0.45, c=c)


def pontoon():
    """Ponton flottant en planches, module 6 × 1,6 (axe X) : se raccorde bout à bout. Taquets ×1,35, pneus côté +Y."""
    m = Model('pontoon', 204)
    cols = (C('wood'), C('earth'))
    planks = [(-3 + (i + 0.5) * 0.5, 1.6, 0, 0, cols[i % 2], 0) for i in range(12)]
    _pontoon_frame(m, planks, (-2.2, -0.75, 0.75, 2.2), [(x, s * 0.62, None) for x in (-2.0, 2.0) for s in (-1, 1)])
    for x in (-1.5, 1.5):
        tyre(m, x, 0.92, 0.2, 0.2)
    m.to_object()
    return {'deck_z': 0.45, 'module': [6.0, 1.6]}


def pontoon_ruin():
    """Le même ponton, pourri : planches manquantes, grises ou noircies, une soulevée de travers, un flotteur coulé (le
    module penche, son bout +X trempe), algues vertes à la flottaison, une planche à la dérive."""
    m = Model('pontoon_ruin', 205)
    rot = (C('gravel_dark'), C('earth'), C('earth_dark'), C('wood'), C('gravel_dark'), C('earth_dark'))
    missing = (2, 5, 6, 10)
    planks = []
    for i in range(12):
        if i in missing:
            continue
        x = -3 + (i + 0.5) * 0.5
        ln, dy, rz, lift = 1.6, 0.0, 0.0, 0.0
        if i == 4:
            rz, lift = 0.28, 0.06
        if i == 9:
            ln, dy = 0.95, -0.32
        if i == 11:
            ln, dy = 1.2, 0.2
        planks.append((x, ln, dy, rz, rot[i % 6], lift))
    _pontoon_frame(m, planks, (-2.2, -0.75, 0.75), [(-2.0, -0.62, None), (2.0, 0.62, C('rust'))])
    # penche : le bout +X, sans flotteur, s'enfonce
    bmesh.ops.rotate(m.bm, cent=(0, 0, 0), matrix=Matrix.Rotation(0.09, 3, 'Y') @ Matrix.Rotation(-0.06, 3, 'X'),
                     verts=m.bm.verts[:])
    bmesh.ops.translate(m.bm, vec=(0, 0, 0.02), verts=m.bm.verts[:])
    # algues à la flottaison et filaments pendants
    for i in range(7):
        x = -2.8 + i * 0.85 + m.rnd.uniform(-0.2, 0.2)
        s = -1 if i % 2 else 1
        z = 0.06 - x * 0.09
        m.ico((x, s * 0.88, z), (0.38, 0.14, 0.11), (0, 0, m.rnd.uniform(-0.3, 0.3)), C('net_green') if i % 3 else C('pine_dark'), 0)
    for x in (-2.4, -0.6, 1.1):
        m.box((x, -0.9, 0.0 - x * 0.09), (0.06, 0.03, 0.4), (0.1, 0, 0), C('net_green'))
    m.box((3.7, 1.25, 0.0), (0.42, 1.4, 0.08), (0.05, 0.08, 0.6), C('gravel_dark'))      # planche à la dérive
    m.to_object()
    return {'deck_z': 0.45, 'module': [6.0, 1.6]}


# =============================================================== bâtiments ===========================================

def fish_hall():
    """La criée : halle ouverte 8 × 5,4 sous un grand toit à deux pentes rayé bleu et blanc (emblème), poteaux blancs sur
    semelles marine, bacs bleus de poisson sur glace, tableau d'enchères à barres lumineuses devant à gauche (emblème),
    poisson bleu peint au pignon +X, lanterneau, comptoir de pesée, caisses."""
    m = Model('fish_hall', 210)
    w, d, z0, hp = 8.0, 5.4, 0.2, 3.0
    m.boxb((0, 0, 0), (w + 0.9, d + 0.9, z0), (0, 0, 0), C('kerb'))
    m.boxb((0, 0, z0), (w + 0.5, d + 0.5, 0.02), (0, 0, 0), C('apron_warm'))
    top = z0 + hp
    for x in (-3.75, -1.25, 1.25, 3.75):
        for s in (-1, 1):
            y = s * (d / 2 - 0.15)
            m.boxb((x, y, z0), (0.44, 0.44, 0.42), (0, 0, 0), C('navy'))
            m.boxb((x, y, z0), (0.27, 0.27, hp), (0, 0, 0), C('wood_trim'))
        m.boxb((x, 0, top - 0.26), (0.2, d, 0.24), (0, 0, 0), C('wood_trim'))          # entraits
    for s in (-1, 1):
        m.boxb((0, s * (d / 2 - 0.15), top - 0.3), (w + 0.1, 0.3, 0.3), (0, 0, 0), C('wood_trim'))
    # toit rayé bleu / blanc (faîte selon X)
    rise, over = 1.75, 0.55
    hb, ha = d / 2 + over, w / 2 + over
    shell = [(-hb, top - 0.06), (-hb, top + 0.08), (0, top + rise + 0.14), (hb, top + 0.08), (hb, top - 0.06), (0, top + rise)]
    n = 9
    for i in range(n):
        x0 = -ha + i * 2 * ha / n
        m.prism_x(shell, x0, x0 + 2 * ha / n, C('roof_b_blue') if i % 2 == 0 else C('white'))
    rim = [(-hb - 0.05, top - 0.08), (-hb - 0.05, top + 0.1), (0, top + rise + 0.18), (hb + 0.05, top + 0.1), (hb + 0.05, top - 0.08), (0, top + rise)]
    for x0, x1 in ((-ha - 0.05, -ha + 0.1), (ha - 0.1, ha + 0.05)):
        m.prism_x(rim, x0, x1, C('navy'))
    for sx in (-1, 1):                                                                 # pignons hauts fermés
        m.prism_x([(-d / 2, top - 0.02), (d / 2, top - 0.02), (0, top + rise - 0.05)], sx * w / 2 - 0.05, sx * w / 2 + 0.05, C('white'))
    fish_shape(m, 0.0, top + 0.62, (w / 2 + 0.05, w / 2 + 0.1), 0.95, C('roof_b_blue'), C('white'), axis='y', head=-1)
    # lanterneau de faîtage
    m.boxb((0, 0, top + rise), (w * 0.45, 0.5, 0.42), (0, 0, 0), C('white'))
    m.boxb((0, 0, top + rise + 0.42), (w * 0.45 + 0.25, 0.8, 0.09), (0, 0, 0), C('roof_b_blue'))
    # bacs bleus de poisson sur glace
    fish = (C('gull_grey'), C('steel'))
    for j, y in enumerate((-1.05, 1.0)):
        for i, x in enumerate((-2.5, 0.0, 2.5)):
            m.cham((x, y, z0), (1.35, 0.92, 0.62), 0.06, C('blue'))
            m.box((x, y, z0 + 0.6), (1.15, 0.72, 0.03), (0, 0, 0), C('foam'))
            for k in range(2):
                m.box((x - 0.2 + k * 0.4, y + (k - 0.5) * 0.2, z0 + 0.64), (0.5, 0.15, 0.08), (0, 0, 0.3 - k * 0.6), fish[(i + j + k) % 2])
    # comptoir de pesée et caisses
    m.boxb((-0.6, d / 2 - 0.65, z0), (3.6, 0.6, 0.85), (0, 0, 0), C('steel'))
    m.boxb((-0.6, d / 2 - 0.65, z0 + 0.85), (3.7, 0.7, 0.06), (0, 0, 0), C('white'))
    for k in range(3):
        m.cham((3.6 + (k % 2) * 0.05, 1.9, z0 + k * 0.4), (0.9 * S * 0.9, 0.62 * S * 0.9, 0.36), 0.04,
               C('blue_light') if k % 2 == 0 else C('white'))
    # tableau d'enchères (emblème), devant à gauche, face -Y
    bx, by = -2.7, -d / 2 - 1.45
    for s in (-1, 1):
        m.boxb((bx + s * 1.2, by, 0), (0.14, 0.14, 3.15), (0, 0, 0), C('navy'))
        m.boxb((bx + s * 1.2, by, 0), (0.34, 0.34, 0.14), (0, 0, 0), C('plinth'))
    m.boxb((bx, by, 1.6), (2.5, 0.16, 1.42), (0, 0, 0), C('plinth'))
    m.boxb((bx, by, 3.0), (2.72, 0.24, 0.24), (0, 0, 0), C('roof_b_blue'))
    m.boxb((bx, by, 1.48), (2.72, 0.24, 0.14), (0, 0, 0), C('roof_b_blue'))
    rows = ((C('green'), 0.85), (C('yellow'), 0.6), (C('sign_red'), 0.75), (C('green'), 0.45))
    for i, (c, ln) in enumerate(rows):
        z = 2.62 - i * 0.3
        m.box((bx - 0.62, by - 0.09, z), (0.9, 0.04, 0.16), (0, 0, 0), C('white'))
        m.box((bx + 0.2 + ln / 2, by - 0.09, z), (ln, 0.04, 0.16), (0, 0, 0), c)
    m.to_object()


def ice_plant():
    """Fabrique de glace : petit bloc blanc (socle sombre, casquette givrée bleu clair), grand flocon bleu peint en façade
    (emblème), porte isotherme bleue, stalactites et givre sous la casquette, groupes froids en toiture. Emblème : goulotte
    inclinée bleue sur tréteaux, le long de la face +X, qui descend vers le quai (+Y), glaçons dedans, bac au bout."""
    m = Model('ice_plant', 211)
    w, d, h, z0 = 3.8, 3.2, 3.0, 0.2
    b = hard_block(m, w, d, h, z0, wall=C('white'), cap=C('reefer'), dept=C('blue_light'), roof=C('foam'), win=False)
    top = b['top']
    # flocon peint (3 branches, 6 pointes en V)
    cx, cz, R = -0.55, z0 + 1.85, 0.85
    y = -d / 2 - 0.035
    for k in range(3):
        m.box((cx, y, cz), (2 * R, 0.05, 0.15), (0, k * math.pi / 3, 0), C('roof_b_blue'))
    for j in range(6):
        a = j * math.pi / 3
        px, pz = cx + math.cos(a) * 0.58 * R, cz - math.sin(a) * 0.58 * R
        for s in (-1, 1):
            aa = a + s * 0.75
            m.box((px + math.cos(aa) * 0.15, y, pz - math.sin(aa) * 0.15), (0.32, 0.05, 0.11), (0, aa, 0), C('roof_b_blue'))
    b_door(m, '-y', -d / 2, 1.15, z0, c=C('blue'), w=0.95, h=1.75)
    # stalactites sous la casquette (-Y et +X) et givre sur le bord du toit
    for i in range(7):
        x = -w / 2 + 0.25 + i * (w - 0.5) / 6
        hh = 0.3 + 0.15 * ((i * 5) % 3)
        m.cyl((x, -d / 2 - 0.22, top - hh / 2), (0.07, 0.07, hh), (math.pi, 0, 0), C('glass_light'), 4, 0.0)
    for i in range(5):
        yy = -d / 2 + 0.3 + i * (d - 0.6) / 4
        hh = 0.25 + 0.15 * ((i * 7) % 3)
        m.cyl((w / 2 + 0.22, yy, top - hh / 2), (0.07, 0.07, hh), (math.pi, 0, 0), C('glass_light'), 4, 0.0)
    for x, yy in ((-1.4, -d / 2 - 0.15), (0.5, -d / 2 - 0.15), (w / 2 + 0.15, 0.6), (-w / 2 - 0.1, 0.2)):
        m.ico((x, yy, top + 0.5), (0.55, 0.32, 0.14), (0, 0, 0), C('foam'), 0)
    ac_unit(m, -0.9, 0.5, b['roof'])
    ac_unit(m, 0.4, 0.7, b['roof'])
    # goulotte (emblème) : trémie sur la face +X, descend vers +Y
    gx = w / 2 + 0.55
    A = Vector((gx, -0.6, top - 0.45))
    B = Vector((gx, d / 2 + 2.4, 0.95))
    m.boxb((w / 2 + 0.22, -0.6, top - 0.75), (0.45, 0.6, 0.5), (0, 0, 0), C('white'))     # capot de sortie
    m.boxb((gx, -0.85, top - 0.75), (0.72, 0.62, 0.9), (0, 0, 0), C('steel'))              # trémie
    m.boxb((gx, -0.85, top + 0.15), (0.82, 0.72, 0.08), (0, 0, 0), C('blue_light'))
    dv = B - A
    Lc, a = dv.length, math.atan2(dv.z, dv.y)
    nrm = Vector((0, -math.sin(a), math.cos(a)))
    mid = (A + B) / 2
    m.box(mid, (0.62, Lc, 0.07), (a, 0, 0), C('reefer'))
    for s in (-1, 1):
        m.box(mid + Vector((s * 0.31, 0, 0)) + nrm * 0.13, (0.07, Lc, 0.32), (a, 0, 0), C('blue'))
    for t in (0.3, 0.55, 0.8):
        p = A.lerp(B, t) + nrm * 0.14
        m.box(p, (0.3, 0.3, 0.2), (a, 0, 0.3 * t), C('glass_light'))
    for t in (0.45, 0.9):
        p = A.lerp(B, t)
        m.boxb((gx, p.y, 0), (0.14, 0.14, p.z - 0.05), (0, 0, 0), C('steel'))
        m.boxb((gx, p.y, 0), (0.9, 0.14, 0.12), (0, 0, 0), C('steel'))
    m.cham((gx, B.y + 0.45, 0), (0.95, 0.8, 0.55), 0.06, C('blue_light'))                 # bac à glace
    for i in range(3):
        m.box((gx - 0.2 + i * 0.2, B.y + 0.4 + (i % 2) * 0.15, 0.6), (0.24, 0.24, 0.18), (0, 0, i * 0.5), C('reefer'))
    m.box((0.8, -d / 2 - 0.6, 0.01), (1.4, 0.8, 0.02), (0, 0, 0.2), C('foam'))             # givre au sol
    m.to_object()
    return {'chute_end': to_godot((B.x, B.y + 0.45, 0.55))}


def odette_hut():
    """Cabane de la pêcheuse Odette : socle de pierres, bardage vertical usé (planches dépareillées, certaines courtes),
    toit de tôle rouille rapiécé, porte verte délavée, fenêtre à volets bleu clair (un de travers), tuyau de poêle.
    Emblèmes : filets qui sèchent sur une perche devant à gauche, bouées colorées pendues au mur +X et en tas ; banc, rame."""
    m = Model('odette_hut', 212)
    w, d, h, z0 = 3.4, 2.6, 2.0, 0.25
    m.boxb((0, 0, 0), (w + 0.3, d + 0.3, z0), (0, 0, 0), C('rock'))
    m.boxb((0, 0, z0), (w, d, h), (0, 0, 0), C('earth_dark'))
    woods = (C('wood'), C('gravel_dark'), C('earth'), C('gravel'), C('wood'), C('earth'))
    for side in ('-y', '+x', '-x'):
        L, plane = (w, -d / 2) if side == '-y' else (d, w / 2 if side == '+x' else -w / 2)
        n = int(L / 0.32)
        for i in range(n):
            t = -L / 2 + (i + 0.5) * L / n
            r = m.rnd.random()
            if r < 0.08:
                continue                                                               # planche manquante
            lo = 0.25 if r > 0.85 else 0.0                                             # planche rongée en bas
            m.boxb(_face(side, plane, t, 0.03, z0 + lo), _size(side, L / n - 0.04, 0.06, h - lo), (0, 0, 0), woods[m.rnd.randrange(6)])
    top = z0 + h
    rise, over = 1.05, 0.3
    gable_roof(m, w, d, top, rise, C('rust'), over, 'x', C('gravel_dark'), C('earth_dark'))
    a = math.atan2(rise + 0.07, d / 2 + over)
    hb = d / 2 + over
    for x, c, f in ((-0.7, C('steel'), 0.45), (0.9, C('falun'), 0.6)):
        m.box((x, -hb * f, top + 0.09 + (rise + 0.06) * (1 - f) + 0.02), (0.75, 0.6, 0.04), (a, 0, 0), c)
    m.cylb((-1.0, 0.45, top + 0.3), 0.09, 1.25, C('dark'), 6)                          # tuyau de poêle
    m.cylb((-1.0, 0.45, top + 1.55), 0.16, 0.1, C('dark'), 6)
    # porte et fenêtre
    b_door(m, '-y', -d / 2 - 0.03, 0.8, z0, c=C('net_green'), w=0.82, h=1.6)
    b_window(m, '-y', -d / 2 - 0.03, -0.65, z0 + 0.95, 0.72, 0.62, 2)
    m.boxb((-0.65 - 0.53, -d / 2 - 0.08, z0 + 0.95), (0.3, 0.05, 0.62), (0, 0, 0), C('blue_light'))
    m.box((-0.65 + 0.56, -d / 2 - 0.12, z0 + 1.2), (0.3, 0.05, 0.62), (0, 0.32, 0.25), C('blue_light'))
    # banc et rame
    m.boxb((-0.55, -d / 2 - 0.5, 0.42), (1.25, 0.4, 0.08), (0, 0, 0), C('wood'))
    for s in (-1, 1):
        m.boxb((-0.55 + s * 0.5, -d / 2 - 0.5, 0), (0.08, 0.34, 0.42), (0, 0, 0), C('earth_dark'))
    m.box((w / 2 + 0.12, -0.95, 1.1), (0.08, 0.1, 2.0), (0.0, 0.25, 0), C('wood'))
    m.box((w / 2 + 0.2, -0.95, 0.3), (0.06, 0.22, 0.5), (0.0, 0.25, 0), C('falun'))
    # filets qui sèchent (emblème)
    x0, x1, yy, ph = -3.75, -1.2, -d / 2 - 0.95, 2.45
    for x in (x0, x1):
        m.cylb((x, yy, 0), 0.07, ph, C('wood'), 6)
    m.box(((x0 + x1) / 2, yy, ph - 0.05), (x1 - x0 + 0.25, 0.09, 0.09), (0, 0, 0), C('earth_dark'))
    for i, (hh, c, rz) in enumerate(((1.75, C('net_green'), 0.06), (1.45, C('pine'), -0.08), (1.9, C('net_green'), 0.04))):
        xc = x0 + 0.5 + i * 0.78
        m.boxb((xc, yy + 0.04 * (i - 1), ph - 0.1 - hh), (0.74, 0.05, hh), (0, 0, rz), c)
    m.ico((x0 + 1.25, yy - 0.15, 0.12), (0.8, 0.45, 0.2), (0, 0, 0.2), C('net_green'), 0, 0.2)
    for i in range(5):
        m.ico((x0 + 0.35 + i * 0.52, yy - 0.06, ph - 0.22), (0.1, 0.1, 0.1), (0, 0, 0), C('orange'), 0)
    # bouées colorées (emblème) : au mur +X et en tas
    m.box((w / 2 + 0.06, 0.15, 2.0), (0.08, 1.9, 0.08), (0, 0, 0), C('earth_dark'))
    buoys = (C('orange'), C('sign_red'), C('yellow'), C('white'), C('blue'))
    for i, c in enumerate(buoys[:4]):
        yy2 = -0.55 + i * 0.45
        zz = 1.45 - (i % 2) * 0.22
        m.box((w / 2 + 0.2, yy2, (zz + 2.0) / 2), (0.03, 0.03, 2.0 - zz), (0, 0, 0), C('dark'))
        m.ico((w / 2 + 0.25, yy2, zz - 0.18), (0.22, 0.22, 0.22), (0, 0, 0), c, 0)
    for i, c in enumerate((buoys[4], buoys[0], buoys[2])):
        m.ico((w / 2 + 0.55 + (i % 2) * 0.38, -1.75 + i * 0.3, 0.22 + (i == 2) * 0.32), (0.24, 0.24, 0.24), (0, 0, i), c, 0)
    m.cham((1.1, -d / 2 - 0.55, 0), (0.6 * S, 0.42 * S, 0.3), 0.04, C('blue_light'))   # caisse
    m.to_object()


def jetty_ruin():
    """Vieille estacade sur pieux (axe X, 24 × 3,2, plancher à z = 0,25), à l'emplacement du futur quai T1 : tronçons
    ouest et est debout mais troués, milieu effondré (un pan de plancher glisse à la mer, pieux cassés qui dépassent, de
    travers : l'emblème), algues sombres sous la flottaison, garde-corps en ruine, bitte rouillée, planches à la dérive."""
    m = Model('jetty_ruin', 213)
    Wd, top = 3.2, 0.25
    wood = (C('gravel_dark'), C('wood'), C('earth'), C('gravel'), C('gravel_dark'))
    bents = [-12 + i * 2 for i in range(13)]
    gone = (-2, 0, 2)
    for x in bents:
        for y in (-1.3, 1.3):
            m.cyl((x, y, -1.8), (0.17, 0.17, 2.1), (0, 0, 0), C('pine_dark'), 6, cap=False)  # algues sous l'eau
            if x in gone:
                ht = top + m.rnd.uniform(0.3, 1.3)
                tilt = (m.rnd.uniform(-0.25, 0.25), m.rnd.uniform(-0.3, 0.3), 0)
                m.cyl((x, y, (-0.75 + ht) / 2), (0.16, 0.16, ht + 0.75), tilt, C('earth_dark'), 6)
            else:
                ht = top + 0.4
                m.cyl((x, y, (-0.75 + ht) / 2), (0.16, 0.16, ht + 0.75), (0, 0, 0), C('earth_dark'), 6)
        if x not in gone:
            m.boxb((x, 0, top - 0.42), (0.28, Wd + 0.3, 0.2), (0, 0, 0), C('earth_dark'))
    for x0, x1 in ((-12.2, -3.0), (3.0, 12.2)):
        for y in (-1.0, 0.0, 1.0):
            m.boxb(((x0 + x1) / 2, y, top - 0.24), (x1 - x0, 0.18, 0.16), (0, 0, 0), C('earth'))
    # planches : tronçons ouest et est
    for x0 in (-12.0, 3.0):
        for i in range(18):
            x = x0 + 0.25 + i * 0.5
            r = m.rnd.random()
            if r < 0.18 or (x0 > 0 and 7.6 < x < 9.0):
                continue
            ln, dy = Wd, 0.0
            if r > 0.86 or abs(x) < 3.6:
                ln = m.rnd.uniform(1.4, 2.4)
                dy = (Wd - ln) / 2 * (1 if m.rnd.random() < 0.5 else -1)
            m.boxb((x, dy, top - 0.08), (0.44, ln, 0.08), (0, 0, m.rnd.uniform(-0.03, 0.03)), wood[m.rnd.randrange(5)])
    # pan effondré qui glisse à la mer
    A, B = Vector((-3.0, 0, top - 0.1)), Vector((0.6, 0, -1.25))
    th = -math.atan2(B.z - A.z, B.x - A.x)
    for y in (-0.9, 0.9):
        bar(m, A + Vector((0, y, -0.12)), B + Vector((0, y, -0.12)), 0.16, 0.16, C('earth'))
    for k in range(6):
        p = A.lerp(B, (k + 0.5) / 6)
        m.box((p.x, 0.1 * (k % 2), p.z), (0.44, Wd - 0.5 - 0.2 * (k % 3), 0.08), (0, th, 0.05 * (k - 2)), wood[k % 5])
    # garde-corps en ruine (côté mer), bitte rouillée, débris
    for x in (4.0, 6.0, 8.0, 10.0, 12.0):
        if x == 8.0:
            continue
        m.boxb((x, Wd / 2 - 0.05, top), (0.13, 0.13, 1.0), (0, 0, 0), C('gravel_dark'))
    m.boxb((5.0, Wd / 2 - 0.05, top + 0.85), (2.2, 0.1, 0.1), (0, 0, 0), C('gravel_dark'))
    bar(m, (10.0, Wd / 2 - 0.05, top + 0.85), (8.4, Wd / 2 - 0.05, top + 0.1), 0.1, 0.1, C('gravel_dark'))
    m.cylb((-10.0, 1.0, top), 0.24, 0.42, C('rust'), 8)
    m.cylb((-10.0, 1.0, top + 0.42), 0.33, 0.12, C('rust'), 8)
    for p, rz in (((1.8, 2.6, -0.98), 0.7), ((-1.2, -2.4, -0.98), -0.4)):
        m.box(p, (2.2, 0.44, 0.08), (0, 0, rz), C('gravel_dark'))
    m.to_object()
    return {'deck_z': top, 'span_x': [-12.2, 12.2], 'collapsed_x': [-3.0, 3.0]}


def fish_van():
    """Camionnette frigorifique du mareyeur : cabine bleue à toit bleu clair, caisson blanc à liseré bleu et gros poisson
    bleu peint sur les deux flancs (emblème), groupe froid au-dessus de la cabine, feux arrière rouges. Avant en +X."""
    m = Model('fish_van', 214)
    m.boxb((0, 0, 0.28), (4.0, 1.5, 0.16), (0, 0, 0), C('dark'))                         # châssis
    bx0, bx1 = -2.0, 0.72
    m.boxb(((bx0 + bx1) / 2, 0, 0.42), (bx1 - bx0, 1.72, 1.8), (0, 0, 0), C('white'))     # caisson
    m.boxb(((bx0 + bx1) / 2, 0, 2.22), (bx1 - bx0 - 0.1, 1.62, 0.04), (0, 0, 0), C('cap_light'))
    for s in (-1, 1):
        m.box(((bx0 + bx1) / 2, s * 0.87, 0.62), (bx1 - bx0, 0.03, 0.18), (0, 0, 0), C('roof_b_blue'))
        y0 = s * 0.86
        fish_shape(m, -0.62, 1.42, (y0, y0 + s * 0.04), 0.82, C('roof_b_blue'), None, axis='x', head=1)
        m.box((-0.62 + 0.42 * 0.82, y0 + s * 0.045, 1.47), (0.1, 0.03, 0.1), (0, 0, 0), C('white'))
    # cabine
    m.boxb((1.35, 0, 0.42), (1.25, 1.62, 0.9), (0, 0, 0), C('roof_b_blue'))
    m.boxb((1.22, 0, 1.32), (1.0, 1.58, 0.6), (0, 0, 0), C('roof_b_blue'))
    m.boxb((1.22, 0, 1.92), (1.05, 1.62, 0.08), (0, 0, 0), C('blue_light'))
    m.box((1.73, 0, 1.6), (0.04, 1.36, 0.46), (0, 0, 0), C('glass_light'))
    for s in (-1, 1):
        m.box((1.3, s * 0.8, 1.6), (0.6, 0.04, 0.4), (0, 0, 0), C('glass_light'))
        m.box((1.8, s * 0.95, 1.45), (0.08, 0.16, 0.22), (0, 0, 0), C('dark'))           # rétroviseurs
        m.box((1.99, s * 0.55, 0.85), (0.04, 0.3, 0.16), (0, 0, 0), C('yellow'))          # phares
    m.boxb((2.0, 0, 0.3), (0.12, 1.66, 0.28), (0, 0, 0), C('dark'))                       # pare-chocs
    m.boxb((0.86, 0, 1.92), (0.3, 1.1, 0.42), (0, 0, 0), C('steel'))                      # groupe froid
    m.box((0.86, 0, 2.2), (0.32, 0.8, 0.12), (0, 0, 0), C('dark'))
    for x in (-1.25, 1.35):
        for s in (-1, 1):
            m.cyl((x, s * 0.76, 0.34), (0.34, 0.34, 0.26), (math.pi / 2, 0, 0), C('dark'), 8)
    tail_lights(m, bx0, 0.86, 0.75)
    m.to_object()


ASSETS = {
    'boat_dinghy': boat_dinghy, 'boat_trawler': boat_trawler, 'boat_tuna': boat_tuna, 'pontoon': pontoon,
    'pontoon_ruin': pontoon_ruin, 'fish_hall': fish_hall, 'ice_plant': ice_plant, 'odette_hut': odette_hut,
    'jetty_ruin': jetty_ruin, 'fish_van': fish_van,
}
