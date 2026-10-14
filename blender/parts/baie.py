# Plan « La baie et le terre-plein » (docs/PROMPT_PLAN_PORT.md, lot Blender) : barge à sable du chantier de terre-plein,
# feux de passe rouge et vert, pancarte de zone (face vierge pour la surcouche Godot), blocs d'enrochement.
# Repère Blender : X = longueur, Y = profondeur (-Y = face vue par la caméra), Z = haut. Godot (glTF Y-up) : (x, z, -y).
# Navires et barges : z = 0 est la ligne de flottaison (comme `tug`, `pilot_boat`), étrave vers +X.
# Budget : ≤ 600 triangles par modèle. Couleurs : palette.json uniquement (C) ; mul() n'éclaircit ou n'assombrit qu'une
# teinte de la palette.
import math
import bmesh
from mathutils import Vector, Matrix
from lib import Model, SCALE_PROPS, mul, to_godot
from palette import C

S = SCALE_PROPS


# --- barge à sable (registre C) ---------------------------------------------------------------------------------------
# Deux pièces : « hull » (coque, hiloire, timonerie ; cale vide sombre) et « sand » (chargement, pivot au pont, au
# centre de la cale). Pour « déverser », Godot écrase « sand » en hauteur (scale.y 1 → 0) : la cale vide apparaît.

BL, BW = 12.0, 4.4            # longueur, largeur
ZB, ZW, ZD = -0.7, 0.05, 0.9  # quille, ligne de flottaison peinte, pont
HOLD_X0, HOLD_X1 = -3.6, 4.4  # cale (le long de X)
HOLD_HW = 1.6                 # demi-largeur intérieure de la cale


def _bow_x(z):
    """Étrave relevée (avant +X) : 1,2 u de quête entre la quille et le pont."""
    return BL / 2 - 1.2 * (ZD - z) / (ZD - ZB)


def _stern_x(z):
    """Arrière à faible quête (0,6 u)."""
    return -BL / 2 + 0.6 * (ZD - z) / (ZD - ZB)


def _hull_band(m, z0, z1, c):
    m.prism_y([(_stern_x(z0), z0), (_bow_x(z0), z0), (_bow_x(z1), z1), (_stern_x(z1), z1)], -BW / 2, BW / 2, c)


def barge_sand():
    """Barge de chantier chargée de sable : coque verte à carène rouge, liston blanc, lisse claire, hiloire jaune à
    segments sombres, timonerie blanche à toit clair à l'arrière, bollards et pneus ; tas de sable en deux dômes."""
    m = Model('hull', 401)
    _hull_band(m, ZB, ZW, C('hull_red'))                                     # carène (sous l'eau dans le jeu)
    _hull_band(m, ZW, ZD, C('hull_green'))                                   # œuvres mortes
    for s in (-1, 1):
        m.box((0.0, s * (BW / 2 + 0.02), 0.6), (BL - 1.6, 0.06, 0.12), (0, 0, 0), C('wood_trim'))     # liston
        m.boxb((0.0, s * (BW / 2 - 0.13), ZD), (BL - 0.3, 0.3, 0.2), (0, 0, 0), C('cap_light'))        # lisse
    for x in (_stern_x(ZD) + 0.15, _bow_x(ZD) - 0.15):
        m.boxb((x, 0, ZD), (0.3, BW, 0.2), (0, 0, 0), C('cap_light'))
    # cale : fond sombre, hiloire jaune à segments sombres (bande de sécurité du registre C)
    hl, hc = HOLD_X1 - HOLD_X0, (HOLD_X0 + HOLD_X1) / 2
    m.boxb((hc, 0, ZD), (hl, 2 * HOLD_HW, 0.03), (0, 0, 0), C('apron_dark'))
    t = 0.18
    for s in (-1, 1):
        m.boxb((hc, s * (HOLD_HW + t / 2), ZD), (hl + 2 * t, t, 0.42), (0, 0, 0), C('hazard'))
        m.boxb((HOLD_X0 - t / 2 if s < 0 else HOLD_X1 + t / 2, 0, ZD), (t, 2 * HOLD_HW, 0.42), (0, 0, 0), C('hazard'))
    for i in range(5):                                                       # segments sombres, face -Y vue
        x = HOLD_X0 + 0.8 + i * 1.6
        m.boxb((x, -(HOLD_HW + t + 0.01), ZD + 0.04), (0.5, 0.04, 0.34), (0, 0, 0), C('dark'))
    # timonerie à l'arrière (vitres vers l'avant +X et vers la caméra -Y)
    wx = -4.95
    m.boxb((wx, 0, ZD), (1.3, 1.9, 1.25), (0, 0, 0), C('white'))
    m.boxb((wx, 0, ZD + 1.25), (1.55, 2.15, 0.14), (0, 0, 0), C('cap_light'))
    m.box((wx + 0.66, 0, ZD + 0.9), (0.05, 1.5, 0.4), (0, 0, 0), C('glass_light'))
    m.box((wx + 0.1, -0.96, ZD + 0.9), (0.8, 0.05, 0.36), (0, 0, 0), C('glass_light'))
    m.cylb((wx - 0.3, 0.55, ZD + 1.39), 0.06, 0.9, C('steel'), 4)                          # mât
    m.boxb((wx - 0.3, 0.55, ZD + 2.29), (0.22, 0.22, 0.22), (0, 0, 0), C('orange'))         # feu de travail
    m.cylb((wx - 0.35, -0.5, ZD + 1.39), 0.13, 0.45, C('dark'), 6)                          # échappement
    # bollards (avant et entre timonerie et cale) et pneus de défense
    for x in (5.0, -4.0):
        for s in (-1, 1):
            m.cylb((x, s * 1.5, ZD), 0.17, 0.32, C('dark'), 6)
    for x in (-3.2, 0.4, 4.0):
        for s in (-1, 1):
            m.cyl((x, s * (BW / 2 + 0.12), 0.45), (0.3, 0.3, 0.2), (math.pi / 2, 0, 0), C('dark'), 6)
    m.to_object('hull')

    # chargement : pivot au pont, au centre de la cale ; deux dômes allongés (dessus clair) sur une couche arasée
    sd = Model('sand', 402)
    sand_top, sand_side = C('sand'), C('sand_warm')
    sd.boxb((0, 0, 0.0), (hl - 0.04, 2 * HOLD_HW - 0.04, 0.4), (0, 0, 0), sand_side)
    for x, rx, ry, h in ((-1.5, 2.5, 1.45, 1.15), (1.9, 1.9, 1.3, 0.85)):
        sd.cyl((x, 0, 0.35 + h / 2), (rx, ry, h), (0, 0, 0), lambda X, Y, Z, top=0.35 + h - 0.01: sand_top if Z > top else sand_side,
               8, 0.32)
    sd.to_object('sand', (hc, 0, ZD))
    return {'parts': ['hull', 'sand'], 'sand_pivot': to_godot((hc, 0, ZD)), 'deck_y': ZD, 'waterline_y': 0.0,
            'bow': '+x'}


# --- feux de passe (×1,35) ---------------------------------------------------------------------------------------------
# Deux pièces : « pole » (socle, fût, galerie) et « lamp » (lanterne) : Godot peut faire clignoter « lamp » seule.

def _passe_light(name, seed, c):
    """Feu de passe sur poteau : socle de béton à deux gradins, fût conique de la couleur du feu à bande blanche,
    échelle, petite porte sombre côté caméra, galerie sombre à garde-corps blanc, lanterne à lentille vive et chapeau."""
    m = Model('pole', seed)
    m.cylb((0, 0, 0), 0.78 * S, 0.3, C('concrete_dark'), 8)
    m.cylb((0, 0, 0.3), 0.6 * S, 0.22, C('concrete'), 8)
    z0, h, r0 = 0.52, 2.7 * S, 0.3 * S
    m.cyl((0, 0, z0 + h / 2), (r0, r0, h), (0, 0, 0), c, 8, 0.72)
    zb = z0 + h * 0.42                                                       # bande blanche
    rb = r0 * (1 - 0.28 * 0.42) + 0.04
    m.cylb((0, 0, zb), rb, 0.5, C('white'), 8)
    m.box((0, -r0 + 0.02, z0 + 0.4), (0.34, 0.08, 0.66), (0, 0, 0), C('dark'))          # porte
    m.beam((r0 + 0.05, 0, z0), (r0 * 0.72 + 0.05, 0, z0 + h), 0.05, C('steel'))             # échelle
    zg = z0 + h
    m.cylb((0, 0, zg), 0.6 * S, 0.12, C('dark'), 8)                                       # galerie
    k = 0.5 * S                                                                           # garde-corps carré
    for s in (-1, 1):
        m.box((0, s * k, zg + 0.5), (2 * k + 0.06, 0.06, 0.06), (0, 0, 0), C('white'))
        m.box((s * k, 0, zg + 0.5), (0.06, 2 * k, 0.06), (0, 0, 0), C('white'))
        for s2 in (-1, 1):
            m.boxb((s * k, s2 * k, zg + 0.12), (0.06, 0.06, 0.38), (0, 0, 0), C('white'))
    m.to_object('pole')

    lp = Model('lamp', seed + 1)
    lp.cylb((0, 0, 0), 0.3 * S, 0.12, C('dark'), 8)
    lp.cylb((0, 0, 0.12), 0.25 * S, 0.75, mul(c, 1.3), 8)                                 # lentille
    lp.cylb((0, 0, 0.87), 0.33 * S, 0.08, C('dark'), 8)
    lp.cyl((0, 0, 0.95 + 0.2), (0.3 * S, 0.3 * S, 0.4), (0, 0, 0), c, 8, 0.0)             # chapeau
    lp.ico((0, 0, 1.4), (0.09, 0.09, 0.09), (0, 0, 0), C('dark'), 0)
    zl = zg + 0.12
    lp.to_object('lamp', (0, 0, zl))
    return {'parts': ['pole', 'lamp'], 'lamp_pos': to_godot((0, 0, zl + 0.12 + 0.375))}


def light_red():
    return _passe_light('light_red', 411, C('sign_red'))


def light_green():
    return _passe_light('light_green', 413, C('green'))


# --- pancarte de zone ------------------------------------------------------------------------------------------------

SIGN_FACE = (2.45, 1.3)       # face vierge (largeur, hauteur)
SIGN_Z0 = 1.15                # bas du panneau


def zone_sign():
    """Pancarte de zone (registre B) : socle sombre, deux poteaux blancs, panneau à cadre marine et face blanche vierge
    vers -Y (la surcouche y dessine l'icône, le nom et le prix : aucun texte 3D), chapeau doré à deux pentes."""
    m = Model('zone_sign', 421)
    bw, bh = SIGN_FACE[0] + 0.25, SIGN_FACE[1] + 0.25
    m.boxb((0, 0, 0), (bw + 0.5, 0.6, 0.15), (0, 0, 0), C('plinth'))
    for s in (-1, 1):
        m.boxb((s * (bw / 2 - 0.2), 0, 0.15), (0.2, 0.2, SIGN_Z0 + bh - 0.15), (0, 0, 0), C('wood_trim'))
    m.boxb((0, 0, SIGN_Z0), (bw, 0.16, bh), (0, 0, 0), C('navy'))
    m.boxb((0, -0.09, SIGN_Z0 + 0.125), (SIGN_FACE[0], 0.04, SIGN_FACE[1]), (0, 0, 0), C('white'))     # face vierge
    zt = SIGN_Z0 + bh
    m.prism_x([(-0.26, zt - 0.02), (0.26, zt - 0.02), (0, zt + 0.34)], -bw / 2 - 0.15, bw / 2 + 0.15, C('mark_yellow'))
    m.ico((0, 0, zt + 0.42), (0.13, 0.13, 0.13), (0, 0, 0), C('mark_yellow'), 0)                      # pommeau
    m.to_object()
    face_front = 0.09 + 0.02
    return {'counter_face': to_godot((0, -(face_front + 0.04), SIGN_Z0 + 0.125 + SIGN_FACE[1] / 2)),
            'counter_size': list(SIGN_FACE), 'counter_normal': [0.0, 0.0, 1.0]}


# --- enrochement (3 variantes) -----------------------------------------------------------------------------------------
# Une seule pièce par modèle (utilisable en MultiMesh, Assets.mesh). Base à z = 0, blocs légèrement enfoncés ;
# Godot les tourne au hasard autour de la verticale. Dessus clair, flancs bas sombres.

def _rock_col(h):
    top, low = C('rock'), C('rock_dark')
    return lambda x, y, z: top if z > h * 0.45 else low


def riprap():
    """Gros bloc d'enrochement arrondi (≈ 2,3 × 2,0 × 1,4)."""
    m = Model('riprap', 431)
    m.ico((0, 0, 0.55), (1.15, 1.0, 0.85), (0, 0, 0.4), _rock_col(1.4), 2, 0.3)
    m.to_object()


def riprap_b():
    """Bloc plat et long (dalle couchée) avec un éclat posé contre lui."""
    m = Model('riprap_b', 432)
    m.ico((0, 0, 0.35), (1.45, 0.85, 0.55), (0.12, 0, -0.3), _rock_col(0.9), 2, 0.28)
    m.ico((1.25, -0.55, 0.2), (0.5, 0.45, 0.4), (0, 0, 0.8), C('rock_dark'), 0, 0.25)
    m.to_object()


def riprap_c():
    """Deux blocs moyens serrés et un galet : sert à boucher les vides entre les gros blocs."""
    m = Model('riprap_c', 433)
    m.ico((-0.45, 0.1, 0.45), (0.85, 0.8, 0.7), (0, 0, 1.1), _rock_col(1.1), 2, 0.3)
    m.ico((0.75, -0.2, 0.32), (0.7, 0.6, 0.5), (0, 0, 2.3), _rock_col(0.8), 1, 0.35)
    m.ico((0.2, -0.85, 0.15), (0.35, 0.3, 0.25), (0, 0, 0.5), C('rock'), 0, 0.2)
    m.to_object()


# --- sphère GNL (palier 3, registre industriel) -----------------------------------------------------------------------
# Une seule pièce. Base à z = 0 au centre de la sphère. Repère du terminal : le sommet dépasse la poutre (flèche) du
# portique `crane_sts` (13,8) : la sphère marque la silhouette du T3.
# Face vue : l'échelle et l'escalier hélicoïdal sont du côté caméra (-Y / +X) ; les tuyaux partent vers +X.

LNG_R = 3.7                   # rayon de la sphère (diamètre 7,4)
LNG_ZC = 10.25                # centre de la sphère (= haut des poteaux, à l'équateur)
LNG_LEGS = 8


def _seg_box(m, a, b, w, t, c):
    """Planche de a à b (largeur w, épaisseur t), posée à plat contre la sphère : sa normale est radiale."""
    a, b = Vector(a), Vector(b)
    d = b - a
    mid = (a + b) / 2
    n = Vector((mid.x, mid.y, mid.z - LNG_ZC)).normalized()
    x = d.normalized()
    z = (n - x * n.dot(x)).normalized()
    y = z.cross(x)
    rot = Matrix((x, y, z)).transposed().to_euler('XYZ')
    m.box(tuple(mid), (d.length + 0.08, w, t), tuple(rot), c)


def lng_sphere():
    """Réservoir sphérique de GNL : sphère blanche à ceinture bleue posée sur une couronne de 8 poteaux acier
    contreventés en zigzag, socle octogonal sombre ; échelle jaune jusqu'à un palier à l'équateur, puis escalier
    hélicoïdal jaune sur la sphère jusqu'à une plateforme sommitale à garde-corps jaune et feu d'obstacle rouge ;
    tuyauterie au pied (descente sous la sphère, deux conduites vers +X, vanne rouge)."""
    m = Model('lng_sphere', 441)
    R, zc = LNG_R, LNG_ZC
    # socle (registre D : socle sombre)
    m.cylb((0, 0, 0), R + 1.0, 0.25, C('plinth'), 8)
    z0 = 0.25
    # poteaux (tangents à la sphère à l'équateur) et contreventement en zigzag sous la sphère
    rl = R + 0.12
    legs = []
    for i in range(LNG_LEGS):
        a = 2 * math.pi * (i + 0.5) / LNG_LEGS
        legs.append((rl * math.cos(a), rl * math.sin(a)))
        m.boxb((legs[-1][0], legs[-1][1], z0), (0.42, 0.42, zc - z0 + 0.3), (0, 0, a), C('clad_steel'))
    for i in range(LNG_LEGS):
        (x0, y0), (x1, y1) = legs[i], legs[(i + 1) % LNG_LEGS]
        lo, hi = (z0 + 0.6, zc - R + 0.3) if i % 2 == 0 else (zc - R + 0.3, z0 + 0.6)
        m.tube((x0, y0, lo), (x1, y1, hi), 0.09, C('steel'), 3)
    # sphère blanche (12 × 8 facettes, sans les deux calottes polaires : la haute est sous la plateforme, la basse ne
    # se voit jamais d'en haut), ceinture bleue à l'équateur (anneau porteur)
    sb = bmesh.new()
    bmesh.ops.create_uvsphere(sb, u_segments=12, v_segments=8, radius=1.0)
    bmesh.ops.delete(sb, geom=[f for f in sb.faces if any(abs(v.co.z) > 0.999 for v in f.verts)], context='FACES')
    m._add(sb, m._mat((0, 0, zc), (R, R, R)), C('white'))
    m.cyl((0, 0, zc), (R + 0.06, R + 0.06, 0.5), (0, 0, 0), C('blue'), 12, cap=False)
    # échelle jaune côté caméra jusqu'au palier de l'équateur
    th0 = math.radians(-80)
    ux, uy = math.cos(th0), math.sin(th0)
    vx, vy = -uy, ux
    rlad = R + 0.75
    for s in (-1, 1):
        m.boxb((rlad * ux + s * 0.28 * vx, rlad * uy + s * 0.28 * vy, z0), (0.08, 0.08, zc - z0 + 0.9), (0, 0, th0),
               C('hazard'))
    m.boxb((rlad * ux, rlad * uy, z0 + 0.3), (0.06, 0.5, zc - z0 - 0.3), (0, 0, th0), C('dark'))         # barreaux
    m.boxb(((R + 0.45) * ux, (R + 0.45) * uy, zc - 0.12), (1.0, 1.1, 0.12), (0, 0, th0), C('hazard'))    # palier
    # escalier hélicoïdal : de l'équateur (azimut -80°) au bord de la plateforme (azimut +25°), posé sur la sphère
    P = 1.45                                                                 # demi-côté de la plateforme carrée
    rs = R + 0.08
    el_top = math.acos(P / rs)
    n = 4
    pts = []
    for k in range(n + 1):
        t = k / n
        el = el_top * t
        az = th0 + math.radians(105) * t
        pts.append((rs * math.cos(el) * math.cos(az), rs * math.cos(el) * math.sin(az), zc + rs * math.sin(el)))
    for k in range(n):
        _seg_box(m, pts[k], pts[k + 1], 0.7, 0.14, C('hazard'))
    # plateforme sommitale carrée (couvre l'ouverture polaire) à garde-corps plein jaune, feu d'obstacle rouge
    zp = zc + R * math.cos(math.pi / 8) - 0.03
    m.boxb((0, 0, zp), (2 * P, 2 * P, 0.25), (0, 0, 0), C('clad_steel'))
    zt = zp + 0.25
    k = P - 0.035
    for s in (-1, 1):
        m.boxb((0, s * k, zt), (2 * P, 0.07, 0.5), (0, 0, 0), C('hazard'))
        m.boxb((s * k, 0, zt), (0.07, 2 * P - 0.14, 0.5), (0, 0, 0), C('hazard'))
    m.boxb((-k + 0.15, k - 0.15, zt), (0.24, 0.24, 0.7), (0, 0, 0), C('sign_red'))
    # tuyauterie au pied : descente sous la sphère, deux conduites vers +X sur un support, vanne rouge
    zpipe = z0 + 0.55
    m.cyl((0, 0, (zc - R + zpipe) / 2 + 0.1), (0.22, 0.22, zc - R - zpipe + 0.2), (0, 0, 0), C('steel'), 6)
    m.tube((-0.2, 0, zpipe), (R + 1.0, 0, zpipe), 0.22, C('steel'), 6)
    m.tube((0.0, 0.6, zpipe), (R + 1.0, 0.6, zpipe), 0.15, C('steel'), 4)
    m.boxb((R + 0.5, 0.3, z0), (0.3, 1.2, zpipe - z0 - 0.15), (0, 0, 0), C('dark'))
    m.box((2.6, -0.02, zpipe), (0.16, 0.5, 0.5), (0, 0, 0), C('sign_red'))
    m.to_object()
    return {'height': round(zt + 0.5, 2), 'sphere_center_y': zc, 'sphere_radius': R}


ASSETS = {
    'barge_sand': barge_sand, 'light_red': light_red, 'light_green': light_green, 'zone_sign': zone_sign,
    'riprap': riprap, 'riprap_b': riprap_b, 'riprap_c': riprap_c, 'lng_sphere': lng_sphere,
}
