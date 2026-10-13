# Environnement portuaire (docs/ORDRE_BLENDER_D.md § 5) : accessoires de quai ×1,35, plan d'eau, dalles de marquage,
# gate (voies, totem P, empreinte fantôme), bateau de pêche, mouettes.
# Repère Blender : X = longueur, Y = profondeur (+Y = côté mer, -Y = face principale), Z = haut.
import math
from lib import Model, bollard as _bollard, emblem_life_ring, SCALE_PROPS, mul
from palette import C

S = SCALE_PROPS


# --- quai -----------------------------------------------------------------------------------------------------------

def bollard():
    """Bollard noir à chapeau, ×1,35, embase sombre."""
    m = Model('bollard', 101)
    m.cylb((0, 0, 0), 0.34 * S, 0.06, C('plinth'), 8)
    _bollard(m, 0, 0, S, 0.06)
    m.to_object()


def fender():
    """Défense pneu noir suspendue : à poser contre le mur de quai (face +Y), pivot au bord supérieur du quai."""
    m = Model('fender', 102)
    m.cyl((0, 0.35, -0.9), (0.55 * S, 0.55 * S, 0.4 * S), (math.pi / 2, 0, 0), C('dark'), 10)
    m.cyl((0, 0.35, -0.9), (0.3 * S, 0.3 * S, 0.42 * S), (math.pi / 2, 0, 0), C('plinth'), 8)
    m.tube((0, 0.3, -0.25), (0, 0.05, 0.08), 0.04, C('steel'), 4)
    m.boxb((0, 0, 0), (0.4, 0.3, 0.12), (0, 0, 0), C('steel'))
    m.to_object()


def ladder():
    """Échelle de quai : montants acier et barreaux, descend sous le niveau du quai côté +Y."""
    m = Model('ladder', 103)
    for s in (-1, 1):
        m.boxb((s * 0.28, 0.12, -1.9), (0.09, 0.09, 2.4), (0, 0, 0), C('steel'))
        m.box((s * 0.28, 0.0, 0.3), (0.09, 0.4, 0.09), (0, 0, 0), C('steel'))
    for k in range(6):
        m.box((0, 0.12, -1.7 + k * 0.38), (0.56, 0.07, 0.07), (0, 0, 0), C('mark_yellow') if k == 5 else C('steel'))
    m.to_object()


def cleat():
    """Taquet d'amarrage ×1,35 : socle, deux cornes."""
    m = Model('cleat', 104)
    m.boxb((0, 0, 0), (0.5 * S, 0.3 * S, 0.12 * S), (0, 0, 0), C('plinth'))
    m.cylb((0, 0, 0.1 * S), 0.09 * S, 0.3 * S, C('dark'), 6)
    m.box((0, 0, 0.4 * S), (0.9 * S, 0.14 * S, 0.14 * S), (0, 0, 0), C('dark'))
    m.to_object()


def crane_rail():
    """Bande de rails de portique sur le tablier : dalle 12 × 1,2, deux rails acier, bande sombre."""
    m = Model('crane_rail', 105)
    m.boxb((0, 0, 0), (12.0, 1.2, 0.03), (0, 0, 0), C('asphalt_dark'))
    for dy in (-0.3, 0.3):
        m.box((0, dy, 0.06), (12.0, 0.12, 0.07), (0, 0, 0), C('steel'))
    for i in range(6):
        m.box((-5.5 + i * 2.2, 0, 0.035), (0.3, 1.0, 0.01), (0, 0, 0), C('mark_yellow'))
    m.to_object()


def breakwater():
    """Brise-lames en enrochement (segment 12 u, axe X) : blocs posés sur un noyau, feu vert en bout."""
    m = Model('breakwater', 106)
    m.boxb((0, 0, -2.0), (12.0, 3.2, 2.6), (0, 0, 0), C('rock_dark'))
    for i in range(16):
        x = -5.4 + i * 0.72 + m.rnd.uniform(-0.15, 0.15)
        y = m.rnd.uniform(-1.1, 1.1)
        s = m.rnd.uniform(0.7, 1.15)
        m.ico((x, y, 0.3 + m.rnd.uniform(-0.1, 0.3)), (1.1 * s, 1.0 * s, 0.9 * s), (0, 0, m.rnd.uniform(0, 3)),
              C('rock') if i % 3 else C('rock_dark'), 0, 0.3)
    m.boxb((0, 0, 0.6), (11.4, 1.1, 0.25), (0, 0, 0), C('concrete'))                   # chemin de ronde
    m.cylb((5.4, 0, 0.85), 0.3, 1.6, C('white'), 8)
    m.cylb((5.4, 0, 2.45), 0.34, 0.3, C('green'), 8)
    m.to_object()


def life_ring_post():
    """Bouée couronne sur poteau blanc, face vers -Y, ×1,35."""
    m = Model('life_ring_post', 107)
    m.cylb((0, 0, 0), 0.2, 0.08, C('plinth'), 8)
    m.boxb((0, 0, 0.08), (0.14, 0.14, 1.9), (0, 0, 0), C('wood_trim'))
    m.boxb((0, 0, 1.98), (0.34, 0.2, 0.08), (0, 0, 0), C('wood_trim'))
    emblem_life_ring(m, (0, -0.12, 1.35), 0.42, '-y')
    m.to_object()


def net_pile():
    """Tas de filets de pêche verts à flotteurs orange, ×1,35."""
    m = Model('net_pile', 108)
    m.ico((0, 0, 0.32 * S), (1.0 * S, 0.8 * S, 0.42 * S), (0, 0, 0.3), C('net_green'), 1, 0.3)
    m.ico((0.5 * S, 0.25 * S, 0.22 * S), (0.6 * S, 0.5 * S, 0.3 * S), (0, 0, 1.0), mul(C('net_green'), 0.85), 0, 0.3)
    for i in range(4):
        m.ico((-0.5 * S + i * 0.35 * S, -0.3 * S, 0.5 * S + (i % 2) * 0.18), (0.12, 0.12, 0.12), (0, 0, 0), C('orange'), 0)
    m.to_object()


def crate_fish():
    """Pile de caisses de poisson bleu clair et blanches, ×1,35, une caisse de travers."""
    m = Model('crate_fish', 109)
    for k in range(3):
        m.cham((0 + (k % 2) * 0.05, 0, k * 0.34 * S), (0.9 * S, 0.65 * S, 0.3 * S), 0.04, C('blue_light') if k % 2 == 0 else C('white'))
    m.cham((0.3, -0.2, 3 * 0.34 * S), (0.9 * S, 0.65 * S, 0.3 * S), 0.04, C('blue_light'), (0, 0, 0.5))
    m.to_object()


def _gull(name, seed, wings):
    """Mouette posée ×1,35 : corps blanc, dos gris, bec et pattes orange ; ailes fermées ou déployées."""
    m = Model(name, seed)
    s = S * 0.9
    m.ico((0, 0, 0.3 * s), (0.34 * s, 0.22 * s, 0.2 * s), (0, 0, 0), C('white'), 1)
    m.ico((0, 0, 0.34 * s), (0.3 * s, 0.2 * s, 0.14 * s), (0, 0, 0), C('gull_grey'), 0)
    m.ico((0.3 * s, 0, 0.5 * s), (0.15 * s, 0.14 * s, 0.14 * s), (0, 0, 0), C('white'), 1)
    m.cyl((0.46 * s, 0, 0.48 * s), (0.04 * s, 0.04 * s, 0.14 * s), (0, math.pi / 2, 0), C('orange'), 5, 0.3)
    m.box((-0.34 * s, 0, 0.34 * s), (0.2 * s, 0.1 * s, 0.03 * s), (0, -0.3, 0), C('dark'))
    for y in (-0.07, 0.07):
        m.cylb((0.02 * s, y * s, 0), 0.02 * s, 0.14 * s, C('orange'), 4)
    if wings:
        for sy in (-1, 1):
            m.box((-0.05 * s, sy * 0.38 * s, 0.42 * s), (0.42 * s, 0.6 * s, 0.03 * s), (sy * 0.35, 0, sy * 0.15), C('gull_grey'))
    else:
        for sy in (-1, 1):
            m.box((-0.08 * s, sy * 0.17 * s, 0.33 * s), (0.4 * s, 0.1 * s, 0.1 * s), (0, 0.15, 0), C('gull_grey'))
    m.to_object()


def gull():
    _gull('gull', 110, False)


def gull_b():
    _gull('gull_b', 111, True)


def fishing_boat():
    """Petit chalutier B : coque colorée à liston blanc, timonerie crème à toit rouge, mât et bôme, filets et caisses."""
    m = Model('fishing_boat', 112)
    m.hull(7.0, 2.6, 1.5, 0.32, 0.06, (0, 0, -0.6), C('hull_navy'), C('roof_b_blue'), 0.4, C('wood'))
    for s in (-1, 1):
        m.box((0.2, s * 1.25, 0.85), (5.6, 0.08, 0.1), (0, 0, 0), C('wood_trim'))        # listons
    m.boxb((-1.4, 0, 0.9), (1.8, 1.7, 1.2), (0, 0, 0), C('wood_cream'))                  # timonerie
    m.boxb((-1.4, 0, 2.1), (2.1, 2.0, 0.14), (0, 0, 0), C('falun'))
    m.box((-0.49, 0, 1.65), (0.05, 1.3, 0.45), (0, 0, 0), C('glass_light'))
    m.cylb((-1.4, 0.5, 2.24), 0.1, 0.5, C('dark'), 6)                                    # cheminée
    m.cylb((0.8, 0, 0.9), 0.08, 3.2, C('wood'), 6)                                       # mât
    m.box((1.4, 0, 3.0), (1.6, 0.08, 0.08), (0, -0.35, 0), C('wood'))                    # bôme
    m.box((0.8, 0, 4.15), (0.5, 0.03, 0.3), (0, 0, 0), C('sign_red'))
    m.ico((1.6, 0.4, 1.15), (0.8, 0.6, 0.35), (0, 0, 0.3), C('net_green'), 1, 0.3)       # filets
    for i in range(2):
        m.cham((1.5 + i * 0.1, -0.5, 0.9 + i * 0.3), (0.8, 0.55, 0.28), 0.04, C('blue_light') if i == 0 else C('white'))
    for x in (-2.6, 2.4):
        m.cyl((x, 1.35, 0.5), (0.22, 0.22, 0.2), (math.pi / 2, 0, 0), C('dark'), 8)       # pare-battages
    emblem_life_ring(m, (-2.3, -0.9, 1.6), 0.3, '-y')
    m.to_object()


# --- sols et marquages ---------------------------------------------------------------------------------------------

def sidewalk():
    """Trottoir 6 × 1,2 : dalle claire à bordure, légèrement surélevée."""
    m = Model('sidewalk', 113)
    m.boxb((0, 0, 0), (6.0, 1.2, 0.14), (0, 0, 0), C('sidewalk'))
    m.boxb((0, -0.55, 0), (6.0, 0.1, 0.16), (0, 0, 0), C('kerb'))
    for i in range(3):
        m.box((-2 + i * 2, 0.1, 0.141), (0.04, 1.0, 0.01), (0, 0, 0), C('kerb'))
    m.to_object()


def crosswalk():
    """Passage piétons 6 × 2,4 : bandes épaisses claires sur l'asphalte violet."""
    m = Model('crosswalk', 114)
    m.boxb((0, 0, 0), (6.0, 2.4, 0.02), (0, 0, 0), C('asphalt_violet'))
    for i in range(6):
        m.box((-2.5 + i * 1.0, 0, 0.03), (0.55, 2.2, 0.02), (0, 0, 0), C('marking_thick'))
    m.to_object()


def yard_marks():
    """Dalle de marquage de parc 12 × 6 : travées de conteneurs cernées de bandes jaunes, bande de circulation."""
    m = Model('yard_marks', 115)
    m.boxb((0, 0, 0), (12.0, 6.0, 0.02), (0, 0, 0), C('asphalt_violet'))
    for i in range(4):
        m.box((-5.25 + i * 3.5, 0.3, 0.03), (0.2, 5.0, 0.01), (0, 0, 0), C('mark_yellow'))
    m.box((0, 2.8, 0.03), (12.0, 0.2, 0.01), (0, 0, 0), C('mark_yellow'))
    m.box((0, -2.2, 0.03), (12.0, 0.2, 0.01), (0, 0, 0), C('mark_yellow'))
    for i in range(3):
        m.box((-3.5 + i * 3.5, 2.3, 0.035), (0.9, 0.5, 0.01), (0, 0, 0), C('marking_thick'))   # repères de travée
    m.to_object()


def gate_lanes():
    """Dalle de voies de gate 12 × 6 : voie d'entrée et de sortie, flèches, lignes d'arrêt, îlot central."""
    m = Model('gate_lanes', 116)
    m.boxb((0, 0, 0), (12.0, 6.0, 0.02), (0, 0, 0), C('asphalt_violet'))
    m.boxb((0, 0, 0.02), (1.0, 6.0, 0.14), (0, 0, 0), C('sidewalk'))                     # îlot
    for s in (-1, 1):
        m.box((s * 3.0, 2.2, 0.03), (5.0, 0.3, 0.01), (0, 0, 0), C('marking_thick'))       # ligne d'arrêt
        m.box((s * 3.0, -2.6, 0.03), (0.3, 2.8, 0.01), (0, 0, 0), C('marking_thick'))      # flèche : hampe
        m.cyl((s * 3.0, -0.7, 0.03), (0.9, 0.9, 0.01), (0, 0, math.pi / 2), C('marking_thick'), 3)   # flèche : pointe
    m.box((-5.0, 0, 0.03), (0.12, 6.0, 0.01), (0, 0, 0), C('mark_yellow'))
    m.box((5.0, 0, 0.03), (0.12, 6.0, 0.01), (0, 0, 0), C('mark_yellow'))
    m.to_object()


def sign_p():
    """Totem P de l'aire d'attente : mât, panneau bleu à lettre P, face plane claire en dessous où Godot affiche le
    nombre de places (le texte n'est jamais porteur d'information : la lettre est un pictogramme)."""
    m = Model('sign_p', 117)
    m.boxb((0, 0, 0), (0.9, 0.5, 0.15), (0, 0, 0), C('plinth'))
    m.boxb((0, 0, 0.15), (0.22, 0.22, 3.2), (0, 0, 0), C('steel'))
    m.boxb((0, 0, 3.2), (1.6, 0.3, 1.5), (0, 0, 0), C('blue'))
    m.text('P', (0, -0.18, 3.5), 0.95, C('white'), 0.06, (math.pi / 2, 0, 0))
    m.boxb((0, 0, 1.6), (1.6, 0.28, 1.5), (0, 0, 0), C('white'))                         # face pour le compteur
    m.boxb((0, -0.15, 1.6), (1.7, 0.04, 0.08), (0, 0, 0), C('blue'))
    m.to_object()
    return {'counter_face': [0.0, 2.35, 0.2], 'counter_size': [1.5, 1.4]}


def ghost_lot():
    """Empreinte fantôme 6 × 6 (lot C) : dalle plate claire, bordure en pointillés plus clairs ; Godot la met à l'échelle."""
    m = Model('ghost_lot', 118)
    m.boxb((0, 0, 0), (6.0, 6.0, 0.03), (0, 0, 0), C('sidewalk'))
    n = 6
    for i in range(n):
        t = -3 + 0.5 + i * 1.0
        m.box((t, -2.85, 0.035), (0.6, 0.18, 0.01), (0, 0, 0), C('marking_thick'))
        m.box((t, 2.85, 0.035), (0.6, 0.18, 0.01), (0, 0, 0), C('marking_thick'))
        m.box((-2.85, t, 0.035), (0.18, 0.6, 0.01), (0, 0, 0), C('marking_thick'))
        m.box((2.85, t, 0.035), (0.18, 0.6, 0.01), (0, 0, 0), C('marking_thick'))
    m.to_object()


ASSETS = {
    'bollard': bollard, 'fender': fender, 'ladder': ladder, 'cleat': cleat, 'crane_rail': crane_rail, 'breakwater': breakwater,
    'life_ring_post': life_ring_post, 'net_pile': net_pile, 'crate_fish': crate_fish, 'gull': gull, 'gull_b': gull_b,
    'fishing_boat': fishing_boat, 'sidewalk': sidewalk, 'crosswalk': crosswalk, 'yard_marks': yard_marks,
    'gate_lanes': gate_lanes, 'sign_p': sign_p, 'ghost_lot': ghost_lot,
}
