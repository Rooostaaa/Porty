# Lot G — la Crique complète et la marina (docs/ORDRE_BLENDER_G.md § 2, docs/CADRAGE_DEBUT.md § 5) : registre B, bois,
# couleurs chaudes. Services à quai (pompe, lavage), grande jetée des thoniers, ponton de plaisance et ses voiliers, Marcel,
# caboteur de Corsaire & Fils vu de loin.
# Repère Blender : X = longueur, Y = profondeur (+Y = côté mer, -Y = face principale), Z = haut.
# Bateaux : étrave vers +X, origine sur la ligne de flottaison (le jeu les pose à WATER_Y). Pontons et jetée : origine sur
# la ligne de flottaison (plancher à deck_z). Pompe, lavage, Marcel : origine au sol. Couleurs : palette.json seulement.
import math
import bpy
from lib import Model, SCALE_PROPS, to_godot, emblem_life_ring
from palette import C
from crique import strip, bar, hull_strip, tyre, cleat

S = SCALE_PROPS


# =============================================================== services à quai =====================================

def fuel_pump():
    """Pompe à carburant de quai : dalle, borne rouge à goutte blanche peinte (emblème), tuyau noir enroulé sur son
    support, pistolet, petit auvent rouge et blanc sur deux poteaux, bidon jaune."""
    m = Model('fuel_pump', 260)
    m.boxb((0, 0, 0), (2.6, 2.0, 0.12), (0, 0, 0), C('kerb'))
    m.boxb((0, 0, 0.12), (2.2, 1.6, 0.03), (0, 0, 0), C('apron_warm'))
    # borne rouge, face -Y
    bx, by = 0.3, 0.1
    m.boxb((bx, by, 0.15), (0.9, 0.5, 0.1), (0, 0, 0), C('dark'))
    m.cham((bx, by, 0.25), (0.8, 0.42, 1.45), 0.06, C('sign_red'), top=C('white'))
    m.box((bx, by - 0.22, 1.25), (0.5, 0.03, 0.32), (0, 0, 0), C('white'))                   # cadran
    m.box((bx - 0.1, by - 0.235, 1.25), (0.22, 0.02, 0.1), (0, 0, 0), C('dark'))
    # goutte peinte : boule + pointe
    m.ico((bx, by - 0.225, 0.72), (0.17, 0.02, 0.17), (0, 0, 0), C('white'), 0)
    m.cyl((bx, by - 0.225, 0.95), (0.13, 0.015, 0.3), (0, 0, math.pi / 2), C('white'), 3, 0.0)
    # tuyau enroulé sur le flanc +X de la borne, pistolet
    hx = bx + 0.43
    m.cyl((hx, by, 0.9), (0.3, 0.3, 0.16), (0, math.pi / 2, 0), C('dark'), 10, cap=False)
    m.cyl((hx + 0.02, by, 0.9), (0.24, 0.24, 0.2), (0, math.pi / 2, 0), C('dark'), 10, cap=False)
    m.tube((hx + 0.1, by - 0.1, 0.65), (hx + 0.4, by - 0.42, 0.42), 0.04, C('dark'), 5)
    m.box((hx + 0.4, by - 0.45, 0.42), (0.2, 0.08, 0.14), (0, 0, 0), C('steel'))
    m.box((hx + 0.52, by - 0.45, 0.4), (0.12, 0.06, 0.06), (0, 0.3, 0), C('steel'))
    m.boxb((hx + 0.2, by + 0.2, 0.15), (0.3, 0.25, 0.4), (0, 0, 0), C('steel'))                  # support
    # auvent rouge / blanc sur deux poteaux
    for x in (-0.9, 0.9):
        m.cylb((x, 0.55, 0.15), 0.06, 2.3, C('wood_trim'), 6)
    m.boxb((0, 0.3, 2.45), (2.4, 1.3, 0.08), (0, 0, 0), C('wood_trim'))
    n = 4
    for i in range(n):
        x = -1.2 + (i + 0.5) * 2.4 / n
        m.box((x, 0.25, 2.55), (2.4 / n, 1.45, 0.06), (0.12, 0, 0), C('sign_red') if i % 2 == 0 else C('white'))
    # bidon jaune et bollard
    m.cylb((-0.75, -0.35, 0.15), 0.19, 0.5, C('yellow'), 7)
    m.cylb((-0.75, -0.35, 0.65), 0.07, 0.08, C('dark'), 5)
    m.to_object()


def wash_bay():
    """Aire de lavage des coques : dalle à rigole, portique bleu à jets (emblème) sur deux montants, buses, jets d'eau
    clairs qui tombent, flaque et mousse, brosses rotatives bleu / jaune, tuyau et enrouleur, cônes."""
    m = Model('wash_bay', 261)
    w, d = 6.0, 4.2
    m.boxb((0, 0, 0), (w + 0.4, d + 0.4, 0.12), (0, 0, 0), C('kerb'))
    m.boxb((0, 0, 0.12), (w, d, 0.04), (0, 0, 0), C('concrete'))
    m.box((0, 0, 0.165), (w - 0.8, 0.3, 0.01), (0, 0, 0), C('steel'))                             # rigole
    for i in range(5):
        m.box((-2.2 + i * 1.1, 0, 0.17), (0.5, 0.26, 0.012), (0, 0, 0), C('dark'))
    # portique bleu : deux montants, traverse, bandeau blanc, buses
    H = 3.4
    for x in (-1.9, 1.9):
        m.boxb((x, 0, 0.12), (0.5, 0.5, 0.16), (0, 0, 0), C('dark'))
        m.boxb((x, 0, 0.28), (0.3, 0.3, H), (0, 0, 0), C('blue'))
    m.boxb((0, 0, H + 0.1), (4.4, 0.42, 0.42), (0, 0, 0), C('blue'))
    m.box((0, -0.22, H + 0.31), (3.4, 0.03, 0.14), (0, 0, 0), C('white'))
    for i in range(4):
        x = -1.2 + i * 0.8
        m.cylb((x, 0, H - 0.2), 0.08, 0.3, C('steel'), 6)
        m.cyl((x, 0, H - 0.75), (0.26, 0.26, 1.0), (0, 0, 0), C('glass_light'), 5, 0.1)               # jet
        m.cyl((x, 0, H - 1.95), (0.5, 0.5, 1.45), (0, 0, 0), C('glass_light'), 5, 0.4)
    # buses latérales sur les montants
    for x in (-1.9, 1.9):
        s = -1 if x < 0 else 1
        for z in (1.2, 2.2):
            m.box((x - s * 0.25, 0, z), (0.2, 0.12, 0.12), (0, 0, 0), C('steel'))
            m.cyl((x - s * 0.7, 0, z - 0.05), (0.16, 0.16, 0.8), (0, s * math.pi / 2, 0), C('glass_light'), 5, 0.3)
    # flaque et mousse
    m.ico((0.3, -0.4, 0.16), (2.3, 1.5, 0.03), (0, 0, 0.2), C('glass_light'), 1)
    for i, (x, y) in enumerate(((-0.9, 0.5), (0.6, -0.9), (1.4, 0.3), (-0.2, -0.2))):
        m.ico((x, y, 0.18), (0.35 + 0.1 * (i % 2), 0.3, 0.1), (0, 0, i), C('foam'), 0)
    # brosses rotatives (bleu, jaune) sur bras
    for x, c in ((-2.55, C('blue')), (2.55, C('yellow'))):
        s = -1 if x < 0 else 1
        m.boxb((x, -1.2, 0.12), (0.5, 0.5, 0.14), (0, 0, 0), C('dark'))
        m.cylb((x, -1.2, 0.26), 0.09, 1.9, C('steel'), 6)
        m.box((x - s * 0.3, -1.2, 2.1), (0.7, 0.1, 0.1), (0, 0, 0), C('steel'))
        m.cylb((x - s * 0.6, -1.2, 0.4), 0.4, 1.7, c, 8)
        for z in (0.75, 1.15, 1.55):
            m.cylb((x - s * 0.6, -1.2, z), 0.44, 0.06, C('white'), 8)
    # enrouleur et tuyau au fond, cônes devant
    m.cyl((-1.4, d / 2 - 0.3, 0.6), (0.45, 0.45, 0.3), (math.pi / 2, 0, 0), C('yellow'), 10)
    m.cyl((-1.4, d / 2 - 0.3, 0.6), (0.5, 0.5, 0.08), (math.pi / 2, 0, 0), C('dark'), 10)
    m.boxb((-1.4, d / 2 - 0.3, 0.12), (0.16, 0.3, 0.45), (0, 0, 0), C('steel'))
    m.tube((-1.0, d / 2 - 0.45, 0.3), (0.4, 0.8, 0.2), 0.05, C('yellow'), 5)
    m.tube((0.4, 0.8, 0.2), (1.6, -0.2, 0.2), 0.05, C('yellow'), 5)
    for x in (-2.4, 2.4):
        m.boxb((x, -d / 2 + 0.4, 0.16), (0.5 * S, 0.5 * S, 0.05), (0, 0, 0), C('orange'))
        m.cylb((x, -d / 2 + 0.4, 0.2), 0.2 * S, 0.6 * S, C('orange'), 6, 0.25)
        m.cylb((x, -d / 2 + 0.4, 0.2 + 0.28 * S), 0.15 * S, 0.12 * S, C('white'), 6)
    m.to_object()


# =============================================================== jetée et marina =====================================

def pier_long():
    """Grande jetée des thoniers (axe X, 14 × 2,5, tablier à z = 0,9 sur pieux béton) : tablier béton chaud à bordure
    sombre et chasse-roue, défenses pneus noirs sur le bordé +Y (emblème), lampadaire ×1,35 en bout (emblème), bittes
    ×1,35 à chapeau jaune, échelle, bouée couronne sur poteau, caisse et bidon ; musoir à l'extrémité +X."""
    m = Model('pier_long', 262)
    L, Wd, top = 14.0, 2.5, 0.9
    th = 0.35
    # pieux béton (descendent sous l'eau, sans fond)
    for i in range(8):
        x = -6.3 + i * 1.8
        for y in (-0.85, 0.85):
            m.cyl((x, y, -1.4), (0.2, 0.2, 2.1), (0, 0, 0), C('concrete_dark'), 6, cap=False)
            m.boxb((x, y, top - th - 0.3), (0.5, 0.5, 0.3), (0, 0, 0), C('concrete_dark'))
    for y in (-0.85, 0.85):
        m.boxb((0, y, top - th - 0.22), (L - 0.4, 0.3, 0.22), (0, 0, 0), C('concrete_dark'))       # longrines
    # tablier
    m.boxb((0, 0, top - th), (L, Wd, th), (0, 0, 0), C('apron_warm'))
    m.boxb((0, Wd / 2 - 0.2, top - th), (L, 0.4, th + 0.01), (0, 0, 0), C('asphalt_dark'))         # bordure côté mer
    m.boxb((0, Wd / 2 - 0.05, top), (L, 0.1, 0.16), (0, 0, 0), C('plinth'))                        # chasse-roue
    m.box((0, Wd / 2 - 0.62, top + 0.01), (L - 0.6, 0.2, 0.02), (0, 0, 0), C('mark_yellow'))        # ligne de sécurité
    m.boxb((0, -Wd / 2 + 0.1, top), (L, 0.2, 0.08), (0, 0, 0), C('kerb'))
    # garde-corps bois côté -Y (le côté terre, sans amarrage)
    for i in range(8):
        x = -6.5 + i * 13.0 / 7
        m.boxb((x, -Wd / 2 + 0.12, top), (0.1, 0.1, 1.0), (0, 0, 0), C('wood_trim'))
    m.box((0, -Wd / 2 + 0.12, top + 0.98), (L, 0.08, 0.08), (0, 0, 0), C('wood_trim'))
    m.box((0, -Wd / 2 + 0.12, top + 0.55), (L, 0.05, 0.05), (0, 0, 0), C('wood_trim'))
    # défenses pneus (emblème) sur le bordé +Y, bittes à chapeau jaune
    for i in range(6):
        x = -5.5 + i * 2.2
        tyre(m, x, Wd / 2 + 0.08, top - 0.35, 0.3)
        tyre(m, x + 0.02, Wd / 2 + 0.1, top - 0.35, 0.2)
        m.tube((x, Wd / 2 + 0.02, top - 0.05), (x, Wd / 2 + 0.08, top - 0.12), 0.03, C('steel'), 4)
    for x in (-5.0, -1.6, 1.8, 5.2):
        m.cylb((x, Wd / 2 - 0.55, top), 0.2 * S, 0.45 * S, C('dark'), 8)
        m.cylb((x, Wd / 2 - 0.55, top + 0.45 * S), 0.3 * S, 0.14 * S, C('yellow'), 8)
    # échelle côté mer
    for s in (-1, 1):
        m.boxb((3.5 + s * 0.26, Wd / 2 + 0.1, top - 1.6), (0.08, 0.08, 1.9), (0, 0, 0), C('steel'))
    for k in range(5):
        m.box((3.5, Wd / 2 + 0.1, top - 1.4 + k * 0.35), (0.52, 0.06, 0.06), (0, 0, 0), C('steel'))
    # lampadaire ×1,35 en bout (emblème), bouée couronne, caisse et bidon
    lx = L / 2 - 0.6
    m.cylb((lx, -0.6, top), 0.22 * S, 0.12, C('dark'), 8)
    m.cylb((lx, -0.6, top + 0.12), 0.1 * S, 3.6 * S, C('wood_trim'), 6)
    m.box((lx, -0.6 + 0.45 * S, top + 3.7 * S), (0.16 * S, 1.0 * S, 0.14 * S), (0, 0, 0), C('wood_trim'))
    m.box((lx, -0.6 + 0.85 * S, top + 3.58 * S), (0.34 * S, 0.5 * S, 0.14 * S), (0, 0, 0), C('cap_light'))
    m.box((lx, -0.6 + 0.85 * S, top + 3.48 * S), (0.28 * S, 0.42 * S, 0.08 * S), (0, 0, 0), C('yellow'))
    m.boxb((-3.2, -Wd / 2 + 0.35, top), (0.12, 0.12, 1.7), (0, 0, 0), C('wood_trim'))
    emblem_life_ring(m, (-3.2, -Wd / 2 + 0.3, top + 1.25), 0.36, '-y')
    m.cham((-0.3, -0.5, top), (0.6 * S, 0.42 * S, 0.3), 0.04, C('blue_light'))
    m.cylb((0.5, -0.55, top), 0.17, 0.45, C('sign_red'), 7)
    m.to_object()
    return {'deck_z': top, 'span_x': [-L / 2, L / 2], 'moor_side': '+y', 'lamp': to_godot((lx, -0.6, top))}


def marina_pontoon():
    """Ponton flottant de plaisance, module 10 × 1,8 sur X (se raccorde bout à bout), origine à la flottaison, plancher à
    z = 0,45 : flotteurs blancs, plancher clair à lisses blanches, 8 catways (doigts perpendiculaires, 4 par côté) avec
    leur anneau d'amarrage ; bornes eau / électricité bleu-blanc (emblème) ; pare-battage bleu."""
    m = Model('marina_pontoon', 263)
    L, Wd, z = 10.0, 1.8, 0.45
    for x in (-3.4, 0.0, 3.4):
        m.boxb((x, 0, -0.3), (1.6, 1.5, 0.5), (0, 0, 0), C('white'))
    for y in (-0.6, 0.6):
        m.boxb((0, y, 0.2), (L, 0.16, 0.14), (0, 0, 0), C('steel'))
    n = 6
    for i in range(n):
        x = -L / 2 + (i + 0.5) * L / n
        m.boxb((x, 0, 0.34), (L / n - 0.05, Wd, 0.1), (0, 0, 0), C('wood_cream') if i % 2 == 0 else C('kerb'))
    for s in (-1, 1):
        m.boxb((0, s * (Wd / 2 + 0.04), 0.22), (L, 0.08, 0.26), (0, 0, 0), C('wood_trim'))
    # catways : 4 par côté, 2,6 u de long, flotteur blanc, anneau d'amarrage (plot sombre) au bout
    cx = (-3.75, -1.25, 1.25, 3.75)
    for x in cx:
        for s in (-1, 1):
            yc = s * (Wd / 2 + 1.3)
            m.boxb((x, yc, -0.25), (0.5, 2.4, 0.4), (0, 0, 0), C('white'))
            m.boxb((x, yc, 0.33), (0.55, 2.6, 0.11), (0, 0, 0), C('wood_cream'))
            m.boxb((x, s * (Wd / 2 + 2.45), 0.44), (0.18, 0.18, 0.12), (0, 0, 0), C('dark'))
    # bornes eau / électricité (emblème) entre les catways, pare-battage bleu aux bouts
    for x in (-2.5, 0.0, 2.5):
        m.boxb((x, 0.0, z), (0.3, 0.3, 0.55), (0, 0, 0), C('white'))
        m.boxb((x, 0.0, z + 0.55), (0.34, 0.34, 0.34), (0, 0, 0), C('blue'))
        m.box((x, -0.18, z + 0.3), (0.14, 0.04, 0.14), (0, 0, 0), C('yellow'))
    for x in (-4.8, 4.8):
        m.box((x, 0, 0.3), (0.12, 1.4, 0.35), (0, 0, 0), C('blue'))
    m.to_object()
    # places : entre deux catways, bateau perpendiculaire au ponton (axe Y), étrave vers le ponton
    return {'deck_z': z, 'module': [L, Wd], 'catway_x': list(cx), 'catway_y': [-(Wd / 2 + 1.3), Wd / 2 + 1.3],
            'berths': [to_godot((x, s * (Wd / 2 + 1.5), 0)) for x in (-2.5, 0.0, 2.5) for s in (-1, 1)]}


def _sailboat(name, seed, L, hull_low, hull_high, deck, stripe, sail, mast_h, cabin):
    """Voilier : coque Model.hull fine, liston, plat-bord blanc, roof et cockpit, safran ; mât (objet `mast`, pivot au
    pied : léger roulis) portant bôme, voile ferlée (emblème), étais et girouette."""
    W, H, keel, bow = L * 0.3, L * 0.17, -L * 0.06, 0.38
    dz = keel + H
    m = Model(name + '_hull', seed)
    m.hull(L, W, H, bow, 0.05, (0, 0, keel), hull_low, hull_high, 0.45, deck)
    hull_strip(m, L, W, bow, 0.0, 0.08, stripe)
    hull_strip(m, L, W, bow, dz - 0.03, 0.07, C('white'), th=0.08, out=0.02)
    m.boxb((0, 0, -0.65 * H), (L * 0.22, 0.06, 0.65 * H), (0, 0, 0), hull_low)                   # quille
    m.box((-L / 2 + 0.1, 0, -0.1), (0.05, 0.05, 0.55), (0, 0, 0), hull_low)                      # safran
    # roof et cockpit
    m.cham((L * 0.05, 0, dz), (L * 0.36, W * 0.62, cabin), 0.06, C('white'), top=C('wood_cream'))
    for s in (-1, 1):
        m.box((L * 0.05, s * W * 0.31, dz + cabin * 0.6), (L * 0.24, 0.03, cabin * 0.38), (0, 0, 0), C('glass_light'))
    m.box((-L * 0.3, 0, dz + 0.02), (L * 0.26, W * 0.55, 0.04), (0, 0, 0), C('wood'))             # cockpit
    m.cyl((-L * 0.42, 0, dz + 0.3), (0.16, 0.16, 0.03), (0, math.pi / 2, 0), C('steel'), 8)       # barre à roue
    m.cylb((-L * 0.44, 0, dz), 0.025, 0.3, C('steel'), 4)
    m.box((L / 2 - 0.08, 0, dz + 0.22), (0.05, 0.3, 0.3), (0, 0, 0), C('steel'))                  # balcon avant
    m.to_object(name + '_hull')
    # mât : objet nommé, pivot au pied
    mx = L * 0.12
    k = Model('mast', seed + 1)
    k.cylb((0, 0, 0), 0.05, mast_h, C('white'), 6)
    k.box((0, 0, mast_h * 0.62), (0.03, 0.9, 0.03), (0, 0, 0), C('white'))                        # barre de flèche
    k.box((-L * 0.2, 0, 0.5), (L * 0.46, 0.08, 0.08), (0, 0, 0), C('wood'))                       # bôme
    k.cham((-L * 0.19, 0, 0.56), (L * 0.42, 0.22, 0.24), 0.07, sail)                               # voile ferlée
    for t in (0.3, 0.6):
        k.box((-L * 0.19 - L * 0.42 * (t - 0.5), 0, 0.66), (0.05, 0.3, 0.05), (0, 0, 0), C('navy'))   # rabans
    k.cyl((0.02, 0, mast_h * 0.55), (0.09, 0.09, mast_h * 1.05), (0, 0, 0), sail, 4, 0.3)          # génois enroulé (avant)
    bmx = (L / 2 - 0.1) - mx
    k.tube((0, 0, mast_h - 0.05), (bmx, 0, 0.25), 0.012, C('dark'), 3)                            # étai
    k.tube((0, 0, mast_h - 0.05), (-L / 2 + 0.15 - mx, 0, 0.25), 0.012, C('dark'), 3)             # pataras
    k.box((0.1, 0, mast_h + 0.08), (0.3, 0.03, 0.06), (0, 0.3, 0), C('sign_red'))                  # girouette
    k.to_object('mast', (mx, 0, dz))
    return {'mast_foot': to_godot((mx, 0, dz)), 'nodes': {'mast': {'pivot': to_godot((mx, 0, dz)),
            'rotate': 'rotation.z (léger roulis, ±3°)'}}, 'length': L, 'width': round(W, 2)}


def sailboat_a():
    """Voilier A, 3,5 u : coque blanche à liston bleu, pont crème, voile ferlée blanche."""
    return _sailboat('sailboat_a', 264, 3.5, C('white'), C('white'), C('wood_cream'), C('blue'), C('white'), 4.6, 0.32)


def sailboat_b():
    """Voilier B, 4,5 u : coque rouge falun, pont crème, liston blanc, voile ferlée crème."""
    return _sailboat('sailboat_b', 266, 4.5, C('falun'), C('falun'), C('wood_cream'), C('white'), C('wood_cream'), 5.8, 0.38)


def yacht_small():
    """Petit yacht à moteur 5 u : coque blanche à liston marine, pont crème, cabine vitrée, flybridge blanc (emblème) à
    pare-brise et bain de soleil, antennes, plage arrière à échelle de bain, bouées."""
    m = Model('yacht_small', 268)
    L, W, H, keel, bow = 5.0, 1.75, 0.95, -0.35, 0.32
    dz = keel + H
    m.hull(L, W, H, bow, 0.08, (0, 0, keel), C('white'), C('white'), 0.4, C('wood_cream'))
    hull_strip(m, L, W, bow, 0.08, 0.1, C('navy'))
    hull_strip(m, L, W, bow, dz - 0.04, 0.08, C('white'), th=0.1, out=0.02)
    # cabine vitrée
    m.cham((0.2, 0, dz), (2.4, 1.35, 0.7), 0.1, C('white'))
    m.box((1.41, 0, dz + 0.42), (0.05, 1.0, 0.3), (0, 0, 0), C('glass_light'))
    for s in (-1, 1):
        m.box((0.3, s * 0.68, dz + 0.4), (1.7, 0.03, 0.28), (0, 0, 0), C('glass_light'))
    # flybridge (emblème)
    fz = dz + 0.7
    m.boxb((-0.1, 0, fz), (2.0, 1.25, 0.1), (0, 0, 0), C('cap_light'))
    m.box((0.85, 0, fz + 0.32), (0.05, 1.1, 0.45), (-0.0, -0.35, 0), C('glass_light'))               # pare-brise incliné
    m.boxb((0.85, 0, fz + 0.1), (0.08, 1.14, 0.1), (0, 0, 0), C('white'))
    m.boxb((-0.5, 0, fz + 0.1), (0.9, 1.0, 0.24), (0, 0, 0), C('navy'))                             # bain de soleil
    m.boxb((0.2, 0, fz + 0.1), (0.3, 0.5, 0.35), (0, 0, 0), C('white'))                             # console
    m.cyl((0.3, 0, fz + 0.5), (0.14, 0.14, 0.03), (0, 0.9, 0), C('dark'), 8)                        # barre
    m.boxb((-0.9, 0, fz + 0.1), (0.1, 1.1, 0.5), (0, 0, 0), C('white'))                             # arceau
    m.boxb((-1.0, 0, fz + 0.6), (0.9, 1.2, 0.06), (0, 0, 0), C('white'))
    m.cylb((-1.3, 0.3, fz + 0.66), 0.03, 0.6, C('steel'), 4)
    m.cylb((-1.3, -0.3, fz + 0.66), 0.08, 0.1, C('white'), 6)
    # plage arrière, échelle de bain, bouées, mât de pavillon
    m.boxb((-2.0, 0, dz - 0.3), (0.5, 1.3, 0.3), (0, 0, 0), C('wood_cream'))
    for s in (-1, 1):
        m.boxb((-2.5, s * 0.15, dz - 0.75), (0.05, 0.05, 0.75), (0, 0, 0), C('steel'))
    for k in range(3):
        m.box((-2.5, 0, dz - 0.65 + k * 0.25), (0.05, 0.36, 0.04), (0, 0, 0), C('steel'))
    for x in (0.0, 1.2):
        m.cyl((x, 0.86, dz - 0.25), (0.14, 0.14, 0.3), (math.pi / 2, 0, 0), C('navy'), 6)
    m.cylb((-1.9, 0, dz), 0.025, 0.7, C('steel'), 4)
    m.box((-1.78, 0, dz + 0.58), (0.24, 0.02, 0.16), (0, 0, 0), C('sign_red'))
    m.box((2.2, 0, dz + 0.2), (0.05, 0.5, 0.3), (0, 0, 0), C('steel'))                              # balcon avant
    m.to_object()
    return {'length': L, 'width': W}


# =============================================================== Marcel ==============================================

def marcel():
    """Marcel, patron pêcheur (1,35 u, même gabarit que `docker`) : bottes, pantalon marine, ciré jaune (emblème) à
    capuche rabattue, bras croisés, grosse tête, barbe grise, casquette marine, pipe. Face vers +X."""
    m = Model('marcel', 270)
    for y in (-0.12, 0.12):
        m.boxb((0, y, 0), (0.2, 0.17, 0.42), (0, 0, 0), C('navy'))
        m.boxb((0.03, y, 0), (0.28, 0.18, 0.1), (0, 0, 0), C('dark'))                     # bottes
        m.boxb((0, y, 0.1), (0.21, 0.18, 0.14), (0, 0, 0), C('dark'))
    m.cylb((0, 0, 0.42), 0.29, 0.52, C('yellow'), 8, 0.82)                                 # ciré
    m.cylb((0, 0, 0.42), 0.22, 0.06, C('yellow'), 8)
    m.box((0.21, 0, 0.78), (0.03, 0.08, 0.3), (0, 0, 0), C('dark'))                        # fermeture
    m.cylb((0, 0, 0.92), 0.2, 0.1, C('yellow'), 8, 0.7)                                    # col
    m.box((-0.12, 0, 0.98), (0.2, 0.34, 0.1), (0.0, -0.2, 0), C('yellow'))                 # capuche rabattue
    # bras croisés sur la poitrine
    for s, z in ((-1, 0.8), (1, 0.72)):
        m.box((0.25, s * 0.08, z), (0.11, 0.44, 0.11), (0, 0, s * 0.35), C('yellow'))
        m.ico((0.27, -s * 0.24, z + 0.02), (0.08, 0.08, 0.08), (0, 0, 0), C('skin'), 0)
    m.ico((0, 0, 1.1), (0.24, 0.24, 0.25), (0, 0, 0), C('skin'), 1)
    m.ico((0.12, 0, 0.98), (0.17, 0.2, 0.12), (0, 0, 0), C('gull_grey'), 0)                # barbe
    m.cyl((0, 0, 1.3), (0.25, 0.25, 0.12), (0, 0, 0), C('navy'), 8, 1.0)                   # casquette
    m.cyl((0, 0, 1.36), (0.26, 0.26, 0.04), (0, 0, 0), C('navy'), 8, 0.8)
    m.box((0.23, 0, 1.25), (0.2, 0.3, 0.04), (0, 0, 0), C('navy'))
    m.tube((0.2, -0.06, 1.05), (0.4, -0.12, 0.98), 0.02, C('earth_dark'), 4)               # pipe
    m.cylb((0.41, -0.12, 0.95), 0.045, 0.08, C('earth_dark'), 6)
    m.to_object()


# =============================================================== caboteur de Corsaire au large ======================

def ship_passing():
    """Caboteur de Corsaire & Fils vu de loin (silhouette de `ship_coaster`, simplifiée) : coque verte à flottaison rouge,
    château blanc, cheminée noire à bande or, conteneurs colorés sur le pont (fixes), grand pavillon noir et or de
    Corsaire à la poupe (emblème). Étrave vers +X, origine à la flottaison."""
    m = Model('ship_passing', 272)
    L, W, H, wl = 22.0, 5.4, 3.0, 0.45
    keel = -H * wl
    m.hull(L, W, H, 0.22, 0.06, (0, 0, keel), C('hull_red'), C('hull_green'), wl, C('deck'))
    deck = keel + H
    m.boxb((0, 0, deck - 0.3), (L * 0.82, W * 0.985, 0.14), (0, 0, 0), C('white'))
    m.boxb((0, 0, deck), (12.4, 4.2, 0.25), (0, 0, 0), C('concrete_dark'))
    # château arrière
    bx = -8.3
    m.boxb((bx, 0, deck), (2.0, 4.3, 0.6), (0, 0, 0), C('white'))
    m.boxb((bx, 0, deck + 0.6), (1.8, 4.1, 2.2), (0, 0, 0), C('white'))
    m.box((bx + 0.91, 0, deck + 2.3), (0.05, 3.0, 0.4), (0, 0, 0), C('glass_light'))
    m.box((bx, 0, deck + 0.9), (2.02, 4.32, 0.3), (0, 0, 0), C('hull_green'))
    m.boxb((bx, 0, deck + 2.8), (2.2, 5.1, 0.25), (0, 0, 0), C('white'))
    m.boxb((bx, 0, deck + 3.05), (2.3, 5.2, 0.08), (0, 0, 0), C('cap_light'))
    m.cylb((bx - 1.1, 0, deck + 2.6), 0.45, 1.6, C('dark'), 8)                            # cheminée noire à bande or
    m.cylb((bx - 1.1, 0, deck + 3.4), 0.48, 0.35, C('yellow'), 8)
    m.cylb((bx + 0.2, 0, deck + 3.1), 0.05, 1.4, C('steel'), 4)
    m.box((bx + 0.2, 0, deck + 4.4), (0.08, 0.9, 0.12), (0, 0, 0), C('white'))
    m.cyl((bx + 0.4, 2.3, deck + 2.0), (0.35, 0.9, 0.3), (0, 0, 0), C('orange'), 6)
    # conteneurs fixes (2 niveaux, 3 baies × 3 rangées)
    cols = ('box_red', 'box_blue', 'box_yellow', 'box_green', 'box_orange', 'box_teal', 'box_purple', 'box_red', 'box_blue')
    k = 0
    for t in range(2):
        for b in range(3):
            for r in range(3):
                if t == 1 and (b + r) % 3 == 1:
                    continue
                x, y = -4.0 + b * 4.0, (r - 1) * 1.3
                m.boxb((x, y, deck + 0.25 + t * 1.3), (3.9, 1.24, 1.26), (0, 0, 0), C(cols[k % 9]))
                k += 1
    # mât avant, feux, pavillon de Corsaire noir et or (emblème) à la poupe
    m.cylb((L / 2 - 2.6, 0, deck), 0.1, 2.5, C('yellow'), 5)
    m.ico((L / 2 - 2.6, 0, deck + 2.55), (0.12, 0.12, 0.12), (0, 0, 0), C('sign_red'), 0)
    px = -L / 2 + 0.6
    m.cylb((px, 0, deck), 0.06, 3.6, C('white'), 5)
    m.box((px - 1.05, 0, deck + 3.0), (2.0, 0.05, 1.1), (0, 0, 0), C('dark'))
    m.box((px - 1.05, 0, deck + 3.0), (2.0, 0.07, 0.3), (0, 0, 0), C('yellow'))
    m.ico((px - 1.4, 0, deck + 3.0), (0.22, 0.09, 0.22), (0, 0, 0), C('yellow'), 0)
    m.to_object()
    return {'length': L, 'width': W, 'deck': round(deck, 3), 'keel': round(keel, 3)}


ASSETS = {
    'fuel_pump': fuel_pump, 'wash_bay': wash_bay, 'pier_long': pier_long, 'marina_pontoon': marina_pontoon,
    'sailboat_a': sailboat_a, 'sailboat_b': sailboat_b, 'yacht_small': yacht_small, 'marcel': marcel,
    'ship_passing': ship_passing,
}
