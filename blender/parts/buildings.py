# Bâtiments — direction D (docs/ORDRE_BLENDER_D.md § 4) :
# - registre B « port nordique jouet » (wood_block) : capitainerie, douane T1, hangar ouvert ;
# - registre « B en dur » (hard_block) : tour de contrôle, bureaux, atelier, douane T2, guérite de gate ;
# - registre C « industriel pop » (steel_shed) : scanner, halle d'inspection, informatique, sous-station, IMO, rail, entrepôt.
# Chaque bâtiment est identifiable SANS lire : un objet emblème + la couleur de son département (capitainerie bleu,
# douane marine + jaune, gate orange, parc et engins jaune, logistique vert, informatique teal, énergie acier + jaune).
# Face principale en -Y (vue aux rotations 0° et 90° du plan), faces ±X traitées, fond +Y nu. La place du responsable
# embauché, (3, -3) devant à droite, reste libre. Accessoires ×1,35.
# Règle de lisibilité des auvents : la caméra (plongée 35°, lacet 45°) voit un objet saillant de s devant une face
# masquer le mur sur ~s sous son bord bas : portes et guichets doivent finir sous (bord bas − saillie).
import math
from lib import (Model, wood_block, hard_block, steel_shed, b_window, b_door, door, roll_door, window_band, awning,
                 planter, gable_roof, hazard_band, lap_siding, bollard, cone, ac_unit, tail_lights, SIDES_VISIBLE,
                 emblem_life_ring, emblem_belvedere, emblem_flag_mast, emblem_clock, emblem_radar, emblem_beacon,
                 emblem_antenna, emblem_dish, emblem_tire_pile, emblem_stop_sign, emblem_traffic_light,
                 emblem_checker_barrier, emblem_table_suitcase, _face, _size, mul)
from palette import C


def _wheels(m, xs, y, z=0.45, r=0.45, w=0.35):
    for x in xs:
        for s in (-1, 1):
            m.cyl((x, s * y, z), (r, r, w), (math.pi / 2, 0, 0), C('dark'), 8)


def _carton_stack(m, x, y, z, cols):
    """Palette de cartons surdimensionnés (couleurs franches, ruban clair)."""
    m.boxb((x, y, z), (1.25, 1.05, 0.16), (0, 0, 0), C('wood'))
    for k, c in enumerate(cols):
        hh = 0.62
        m.boxb((x, y, z + 0.16 + k * hh), (1.12, 0.94, hh - 0.03), (0, 0, 0), c)
        m.boxb((x, y, z + 0.16 + k * hh + hh - 0.035), (0.22, 0.95, 0.02), (0, 0, 0), C('white'))


def _fish_crates(m, x, y, z, n=3, c=None):
    """Pile de caisses de poisson (bleu clair) avec une caisse de travers."""
    c = c or C('blue_light')
    for k in range(n):
        m.cham((x + (k % 2) * 0.05, y, z + k * 0.34), (0.9, 0.65, 0.3), 0.04, c if k % 2 == 0 else C('white'))
    m.cham((x + 0.3, y - 0.2, z + n * 0.34), (0.9, 0.65, 0.3), 0.04, c, (0, 0, 0.5))


def _net_pile(m, x, y, s=1.0):
    """Tas de filets verts avec flotteurs orange."""
    m.ico((x, y, 0.3 * s), (1.0 * s, 0.8 * s, 0.4 * s), (0, 0, 0.3), C('net_green'), 1, 0.3)
    m.ico((x + 0.5 * s, y + 0.2 * s, 0.22 * s), (0.6 * s, 0.5 * s, 0.3 * s), (0, 0, 1.0), mul(C('net_green'), 0.85), 0, 0.3)
    for i in range(3):
        m.ico((x - 0.4 * s + i * 0.4 * s, y - 0.3 * s, 0.45 * s + (i % 2) * 0.15), (0.11, 0.11, 0.11), (0, 0, 0), C('orange'), 0)


# =============================================================== T1 : registre B ==================================

def harbor_office():
    """Capitainerie T1 (B, bleu) : bois crème, toit bleu à deux pentes, belvédère vitré sur le faîte, mât à pavois,
    bouée couronne, porte rouge sous auvent rayé bleu/blanc."""
    m = Model('harbor_office', 21)
    w, d, h, z0 = 4.6, 3.8, 2.6, 0.2
    b = wood_block(m, w, d, h, z0, roof=C('roof_b_blue'), rise=1.45)
    for t in (-1.45, 1.45):
        b_window(m, '-y', -d / 2, t, z0 + 1.0)
    b_window(m, '+x', w / 2, 0.9, z0 + 1.0)
    b_window(m, '-x', -w / 2, 0.0, z0 + 1.0, length=1.4, n=3)
    b_door(m, '-y', -d / 2, 0, z0)
    # bord bas de l'auvent à z0 + 2,04, saillie 0,5 : la porte (1,7) reste entière
    awning(m, '-y', -d / 2, 0, z0 + 2.18, 1.5, depth=0.5, drop=0.14, c=C('roof_b_blue'), c2=C('wood_trim'), n=5, valance=0.12)
    emblem_life_ring(m, (w / 2 + 0.1, -1.0, z0 + 1.5), 0.42, '+x')
    # belvédère sur le faîte et mât à pavois
    bx, bz = -0.9, b['ridge'] - 0.55
    top = emblem_belvedere(m, bx, 0, bz, C('roof_b_blue'))
    emblem_flag_mast(m, bx, 0, top - 0.1, 1.9)
    planter(m, (-1.3, -d / 2 - 0.75, 0), 0.65, pot=C('wood_trim'), shrub=C('pine'))
    planter(m, (1.3, -d / 2 - 0.75, 0), 0.65, pot=C('wood_trim'), shrub=C('pine'))
    bollard(m, w / 2 + 0.8, -0.2)                    # hors de la place du responsable (3, -3)
    m.to_object()


def customs_hut():
    """Douane T1 (B, marine + jaune) : bois crème, toit marine à faîtage et rives jaunes, long auvent marine à liseré
    jaune sur la porte et le guichet, table d'inspection à valise orange ouverte devant, barrière à damier."""
    m = Model('customs_hut', 22)
    w, d, h, z0 = 4.0, 3.2, 2.5, 0.2
    b = wood_block(m, w, d, h, z0, roof=C('navy'), rise=1.2, edge=C('yellow'))
    m.boxb((0, 0, b['ridge'] - 0.04), (w + 0.8, 0.2, 0.1), (0, 0, 0), C('yellow'))              # faîtage jaune
    b_door(m, '-y', -d / 2, -1.0, z0, c=C('navy'), h=1.6)
    window_band(m, '-y', -d / 2, 1.0, z0 + 0.8, 1.2, 0.7, n=2, glass=C('glass_light'), mullion=C('wood_trim'), sill=False)
    m.boxb((1.0, -d / 2 - 0.2, z0 + 0.68), (1.4, 0.4, 0.1), (0, 0, 0), C('navy'))                 # tablette du guichet
    b_window(m, '+x', w / 2, 0.0, z0 + 0.95, length=1.2, n=3)
    b_window(m, '-x', -w / 2, 0.0, z0 + 0.95, length=1.2, n=3)
    # bord bas de l'auvent à z0 + 1,94, saillie 0,5 : porte (1,6) et guichet (1,5) entiers
    az, ad, adr, av = z0 + 2.2, 0.5, 0.12, 0.14
    awning(m, '-y', -d / 2, 0, az, w - 0.2, depth=ad, drop=adr, c=C('navy'), valance=av)
    m.boxb((0, -d / 2 - ad - 0.03, az - adr - av + 0.03), (w - 0.2, 0.06, 0.06), (0, 0, 0), C('yellow'))   # liseré
    emblem_table_suitcase(m, w / 2 + 1.0, -0.4)      # le douanier est posé devant, en (3, -1,4) (diorama.gd)
    emblem_checker_barrier(m, -1.4, -d / 2 - 1.1)
    cone(m, -w / 2 - 0.8, -0.3)
    planter(m, (0.0, -d / 2 - 0.75, 0), 0.6, pot=C('wood_trim'), shrub=C('pine'))
    m.to_object()


def hangar():
    """Hangar T1 (B ouvert, rouge falun) : toit à deux pentes rouge sur poteaux bois, sans murs (lisible à 90°) ;
    caisses de poisson, filets et tonneaux dessous."""
    m = Model('hangar', 23)
    w, d, h = 9.0, 6.0, 3.4
    m.boxb((0, 0, 0), (w + 0.5, d + 0.5, 0.2), (0, 0, 0), C('kerb'))
    for x in (-4.2, 0, 4.2):
        for y in (-2.7, 2.7):
            m.boxb((x, y, 0.2), (0.32, 0.32, h), (0, 0, 0), C('wood'))
            m.boxb((x, y, 0.2), (0.44, 0.44, 0.5), (0, 0, 0), C('navy'))                    # pied marine
    for y in (-2.7, 2.7):
        m.boxb((0, y, 0.2 + h), (w + 0.2, 0.3, 0.3), (0, 0, 0), C('wood'))                  # sablières
    for x in (-4.2, 0, 4.2):
        m.boxb((x, 0, 0.2 + h), (0.3, d + 0.2, 0.3), (0, 0, 0), C('wood'))                  # entraits
        m.box((x, 0, 0.2 + h + 0.9), (0.2, 0.2, 1.25), (0, 0, 0), C('wood'))                # poinçons
    gable_roof(m, w, d, 0.2 + h + 0.3, 1.7, C('falun'), over=0.55, axis='x')
    m.boxb((0, 0, 0.2 + h + 0.3 + 1.7 + 0.1), (w + 1.2, 0.2, 0.1), (0, 0, 0), C('wood_trim'))    # faîtage blanc
    _fish_crates(m, -2.8, 1.3, 0.2, 3)
    _fish_crates(m, -1.6, 1.6, 0.2, 2)
    _fish_crates(m, 2.6, 1.4, 0.2, 4, C('white'))
    _net_pile(m, 0.6, 1.2, 1.2)
    for i, x in enumerate((-3.4, -2.7)):
        m.cylb((x, -1.6, 0.2), 0.36, 1.0, C('blue') if i == 0 else C('box_teal'), 8)
        m.cylb((x, -1.6, 0.55), 0.37, 0.08, C('dark'), 8)
    emblem_life_ring(m, (w / 2 + 0.17, 0, 2.2), 0.4, '+x')
    m.to_object()


# =============================================================== T2 : registre « B en dur » ========================

def control_tower():
    """Tour de contrôle T2 (B dur, bleu) : fût crème à chanfreins et planches d'angle, cabine vitrée inclinée sur
    couronne claire, casquette bleue, radar."""
    m = Model('control_tower', 24)
    s, H = 2.6, 8.4
    m.boxb((0, 0, 0), (s + 1.2, s + 1.2, 0.2), (0, 0, 0), C('plinth'))
    m.cham((0, 0, 0.2), (s, s, H), 0.3, C('wood_cream'))
    m.boxb((0, 0, 0.2), (s + 0.06, s + 0.06, 0.6), (0, 0, 0), C('navy'))
    for sx in (-1, 1):
        for sy in (-1, 1):
            m.boxb((sx * (s / 2 - 0.1), sy * (s / 2 - 0.1), 0.2), (0.2, 0.2, H), (0, 0, 0), C('wood_trim'))
    for z in (2.6, 4.8, 7.0):
        for side, plane in (('-y', -s / 2), ('+x', s / 2), ('-x', -s / 2)):
            window_band(m, side, plane, 0, z, 1.0, 0.6, n=2, glass=C('glass_light'), mullion=C('wood_trim'), sill=False)
    b_door(m, '-y', -s / 2, 0, 0.2, c=C('roof_b_blue'))
    top = 0.2 + H
    m.cham((0, 0, top), (s + 1.8, s + 1.8, 0.45), 0.5, C('cap_light'))                 # couronne claire
    m.cyl((0, 0, top + 0.45 + 0.9), (2.1, 2.1, 1.8), (0, 0, math.pi / 4), C('glass_light'), 4, 1.3)   # cabine évasée
    for u, v in ((1, 0), (0, 1), (-1, 0), (0, -1)):
        m.tube((u * 2.05, v * 2.05, top + 0.45), (u * 2.65, v * 2.65, top + 2.25), 0.06, C('wood_trim'), 4)
    m.cham((0, 0, top + 2.25), (s + 3.0, s + 3.0, 0.4), 0.7, C('roof_b_blue'))         # casquette bleue
    m.cham((0, 0, top + 2.65), (s + 2.2, s + 2.2, 0.05), 0.6, C('roof_light'))
    emblem_radar(m, 0, 0, top + 2.7, 1.3)
    ac_unit(m, 1.5, 1.5, top + 2.7)
    bollard(m, s / 2 + 1.2, -0.3)
    planter(m, (-1.9, -1.9, 0), 0.6, pot=C('wood_trim'), shrub=C('pine'))
    m.to_object()


def office():
    """Bureaux T2 (B dur, bleu clair) : deux niveaux de grandes baies, casquette claire à bandeau bleu clair, fronton
    central portant une grande horloge ronde, porte vitrée."""
    m = Model('office', 28)
    w, d, h, z0 = 6.0, 4.0, 5.2, 0.2
    b = hard_block(m, w, d, h, z0, dept=C('blue_light'), levels=2, skip={'-y': [(0, 1.3)]})
    door(m, '-y', -d / 2, 0, z0, w=1.1, h=1.85, glass=C('glass_light'), frame=C('wood_trim'))
    awning(m, '-y', -d / 2, 0, z0 + 2.35, 1.8, depth=0.5, drop=0.1, c=C('blue_light'), valance=0.1)
    fz = b['cap_top']
    m.boxb((0, -d / 2 - 0.1, fz), (2.4, 0.9, 1.4), (0, 0, 0), C('wood_cream'))              # fronton
    m.boxb((0, -d / 2 - 0.1, fz + 1.4), (2.6, 1.1, 0.14), (0, 0, 0), C('blue_light'))
    emblem_clock(m, '-y', -d / 2 - 0.55, 0, fz + 0.7, 0.5)
    ac_unit(m, -1.6, 0.8, b['roof'])
    ac_unit(m, 1.6, 0.8, b['roof'])
    emblem_antenna(m, 2.4, 1.4, b['roof'], 1.6)
    planter(m, (-1.5, -d / 2 - 0.8, 0), 0.65, pot=C('wood_trim'), shrub=C('pine'))
    planter(m, (1.5, -d / 2 - 0.8, 0), 0.65, pot=C('wood_trim'), shrub=C('pine'))
    m.to_object()


def workshop():
    """Atelier engins T2 (B dur ouvert, jaune) : grande porte ouverte sur un chariot, pile de pneus géants, bras de
    levage, casquette jaune."""
    m = Model('workshop', 29)
    w, d, h, z0 = 6.0, 5.0, 3.2, 0.2
    dx, dw = -0.9, 2.8
    b = hard_block(m, w, d, h, z0, dept=C('yellow'), win_z=1.5, win_h=0.9, skip={'-y': [(dx, dw + 0.4)]})
    roll_door(m, '-y', -d / 2, dx, z0, dw, 2.5, C('yellow'), open=True)
    # chariot élévateur à moitié sorti de la porte
    fx, fy = dx, -d / 2 - 0.6
    m.boxb((fx, fy, z0 + 0.3), (1.3, 1.9, 0.8), (0, 0, 0), C('orange'))
    m.boxb((fx, fy + 0.3, z0 + 1.1), (1.1, 0.9, 1.0), (0, 0, 0), C('dark'))
    m.boxb((fx, fy + 0.3, z0 + 2.1), (1.2, 1.0, 0.1), (0, 0, 0), C('cap_light'))
    for sx in (-0.4, 0.4):
        m.boxb((fx + sx, fy - 1.0, z0), (0.12, 0.12, 2.3), (0, 0, 0), C('steel'))
        m.box((fx + sx, fy - 1.45, z0 + 0.12), (0.15, 0.9, 0.08), (0, 0, 0), C('steel'))
    for sx in (-0.75, 0.75):
        for yy in (fy - 0.55, fy + 0.6):
            m.cyl((fx + sx, yy, z0 + 0.32), (0.32, 0.32, 0.25), (0, math.pi / 2, 0), C('dark'), 8)
    emblem_tire_pile(m, -w / 2 - 1.0, -0.9, 4)
    emblem_tire_pile(m, -w / 2 - 1.0, 0.4, 2)
    # bras de levage (potence) à droite, hors de la place du responsable
    px, py = w / 2 + 0.5, 0.9
    m.cylb((px, py, 0), 0.14, 3.6, C('yellow'), 8)
    m.box((px, py - 1.0, 3.5), (0.16, 2.2, 0.22), (0, 0, 0), C('yellow'))
    m.tube((px, py - 1.0, 3.4), (px, py - 1.0, 2.3), 0.03, C('dark'), 4)
    m.boxb((px, py - 1.0, 2.0), (0.3, 0.2, 0.3), (0, 0, 0), C('dark'))
    hazard_band(m, '-y', -d / 2, 2.0, 1.6, z0 + 0.02, 0.3)
    cone(m, -w / 2 - 0.6, -d / 2 - 0.8)
    m.to_object()


def customs_office():
    """Douane T2 (B dur, marine + jaune) : façade claire à grandes baies, casquette à rayure marine / jaune,
    scanner mobile (van à bras) garé devant à gauche."""
    m = Model('customs_office', 30)
    w, d, h, z0 = 5.0, 4.0, 2.9, 0.2
    b = hard_block(m, w, d, h, z0, dept=C('navy'), skip={'-y': [(1.1, 1.3)]})
    m.boxb((0, 0, b['cap_top']), (w + 0.66, d + 0.66, 0.1), (0, 0, 0), C('yellow'))          # rayure jaune sur marine
    door(m, '-y', -d / 2, 1.1, z0, w=1.0, h=1.8, glass=C('glass_light'), frame=C('wood_trim'))
    awning(m, '-y', -d / 2, 1.1, z0 + 2.3, 1.6, depth=0.5, drop=0.12, c=C('navy'), c2=C('yellow'), n=4, valance=0.12)
    ac_unit(m, -1.3, 0.9, b['roof'])
    emblem_antenna(m, 1.8, 1.2, b['roof'], 1.4)
    # van scanner : blanc à bande marine, bras jaune replié sur le toit, gyrophare
    vx, vy = -1.2, -d / 2 - 1.9
    m.boxb((vx, vy, 0.4), (3.4, 1.7, 1.5), (0, 0, 0), C('white'))
    m.boxb((vx, vy, 1.9), (3.0, 1.5, 0.1), (0, 0, 0), C('cap_light'))
    m.box((vx + 1.71, vy, 1.4), (0.05, 1.3, 0.5), (0, 0, 0), C('glass'))
    m.box((vx, vy - 0.86, 1.0), (2.4, 0.04, 0.3), (0, 0, 0), C('navy'))
    m.box((vx, vy - 0.86, 0.7), (2.4, 0.04, 0.1), (0, 0, 0), C('yellow'))
    _wheels(m, (vx - 1.1, vx + 1.1), 0.85, 0.36, 0.36, 0.28)
    m.boxb((vx - 1.2, vy + 0.4, 2.0), (0.3, 0.3, 1.4), (0, 0, 0), C('yellow'))
    m.box((vx - 0.1, vy + 0.4, 3.4), (2.6, 0.22, 0.22), (0, 0, 0), C('yellow'))
    m.box((vx + 1.1, vy + 0.4, 2.8), (0.22, 0.22, 1.1), (0, 0, 0), C('yellow'))
    emblem_beacon(m, vx + 1.2, vy - 0.4, 2.0, C('orange'), 1.1)
    tail_lights(m, vx - 1.7, 0.85, 1.0)
    cone(m, -w / 2 - 0.8, 0.2)
    m.to_object()


def gate_booth():
    """Guérite de gate (B dur, orange) : cabine vitrée à casquette orange, feu rouge / vert sur mât, panneau STOP.
    La barrière est un asset séparé (animée dans Godot)."""
    m = Model('gate_booth', 25)
    s, h, z0 = 2.0, 2.5, 0.2
    b = hard_block(m, s, s, h, z0, dept=C('orange'), win_z=1.0, win_h=1.2, bay=1.4, sides=('-y', '+x', '-x', '+y'))
    m.boxb((0, 0, b['roof']), (1.4, 1.2, 0.3), (0, 0, 0), C('cap_light'))
    emblem_beacon(m, 0, 0, b['roof'] + 0.3, C('orange'), 1.2)
    emblem_traffic_light(m, 1.6, -1.2, 2.4)
    emblem_stop_sign(m, -1.6, -1.1, 2.3)
    cone(m, 1.3, 0.9)
    m.to_object()


def barrier():
    """Bras de barrière rouge / blanc ×1,35 (pivot à l'origine, s'étend vers +X)."""
    m = Model('barrier', 26)
    m.cylb((0, 0, 0), 0.26, 1.0, C('dark'), 8)
    m.boxb((0, 0, 1.0), (0.5, 0.4, 0.3), (0, 0, 0), C('dark'))
    for i in range(5):
        m.box((0.55 + i * 0.75, 0, 1.12), (0.75, 0.16, 0.16), (0, 0, 0), C('sign_red') if i % 2 == 0 else C('white'))
    m.to_object()


def reefer_rack():
    """Rack frigo T2 (C, blanc / bleu givré) : portiques acier à prises, conteneurs blancs givrés branchés,
    groupe froid à ventilateur en bout."""
    m = Model('reefer_rack', 27)
    L, D = 11.4, 3.6
    m.boxb((0, 0, 0), (L + 0.6, D + 0.6, 0.2), (0, 0, 0), C('apron_dark'))
    for x in (-5.5, 0, 5.5):
        for y in (-1.6, 1.6):
            m.boxb((x, y, 0.2), (0.24, 0.24, 3.6), (0, 0, 0), C('clad_steel_dark'))
            hazard_band(m, '-y', y - 0.12, x, 0.5, 0.22, 0.35, 0.0)
    m.boxb((0, 0, 3.8), (L + 0.3, D + 0.3, 0.2), (0, 0, 0), C('cap_light'))
    m.boxb((0, 0, 3.6), (L, D, 0.2), (0, 0, 0), C('blue_light'))
    m.boxb((0, 0, 2.0), (L, 0.5, 0.12), (0, 0, 0), C('yellow'))                          # rampe de prises
    for i in range(8):
        x = -4.9 + i * 1.4
        m.box((x, 0, 2.3), (0.3, 0.26, 0.3), (0, 0, 0), C('dark'))
        m.ico((x, -0.16, 2.45), (0.08, 0.08, 0.08), (0, 0, 0), C('green'), 0)
    for i, x in enumerate((-3.6, 0.6, 3.4)):                                             # conteneurs givrés
        y = -0.95 if i % 2 == 0 else 0.95
        m.boxb((x, y, 0.2), (4.0 if i != 1 else 2.0, 1.3, 1.3), (0, 0, 0), C('reefer'))
        m.box((x, y - 0.66 if i % 2 == 0 else y + 0.66, 0.85), (3.0 if i != 1 else 1.4, 0.04, 0.5), (0, 0, 0), C('blue_light'))
    # groupe froid en bout : caisson blanc, grille, ventilateur
    m.boxb((L / 2 + 0.9, 0, 0.2), (1.2, 1.6, 2.0), (0, 0, 0), C('white'))
    m.cyl((L / 2 + 1.52, 0, 1.3), (0.55, 0.55, 0.1), (0, math.pi / 2, 0), C('dark'), 10)
    m.cyl((L / 2 + 1.58, 0, 1.3), (0.4, 0.4, 0.08), (0, math.pi / 2, 0), C('blue_light'), 10)
    m.boxb((L / 2 + 0.9, 0, 2.2), (1.3, 1.7, 0.1), (0, 0, 0), C('cap_light'))
    m.to_object()


# =============================================================== T3 : registre C ==================================

def scanner():
    """Scanner à portique T3 (C, marine + jaune, posé à 90°) : piliers à bandes jaune-noir, traverse jaune à bandeau
    marine, feu orange tournant, cabine d'opérateur en bardage."""
    m = Model('scanner', 31)
    m.boxb((0, 0, 0), (7.0, 3.0, 0.1), (0, 0, 0), C('apron_dark'))
    for x in (-2.0, 2.0):
        for i in range(5):
            m.boxb((x, 0, 0.1 + i * 1.0), (0.7, 1.5, 1.0), (0, 0, 0), C('hazard') if i % 2 == 0 else C('dark'))
    m.boxb((0, 0, 5.1), (4.8, 1.7, 0.9), (0, 0, 0), C('hazard'))
    m.boxb((0, 0, 6.0), (5.0, 1.9, 0.3), (0, 0, 0), C('navy'))
    m.box((0, -0.87, 5.5), (3.4, 0.06, 0.4), (0, 0, 0), C('navy'))                         # capteur
    for x in (-1.2, 0, 1.2):
        m.cyl((x, -0.92, 5.5), (0.12, 0.12, 0.06), (math.pi / 2, 0, 0), C('green'), 6)
    emblem_beacon(m, 0, 0, 6.3, C('orange'), 1.4)
    # cabine d'opérateur (bardage acier, casquette claire, bandeau marine)
    cx = 3.6
    m.boxb((cx, 0.3, 0.1), (1.7, 1.6, 2.3), (0, 0, 0), C('clad_steel'))
    m.boxb((cx, 0.3, 2.4), (1.9, 1.8, 0.2), (0, 0, 0), C('cap_light'))
    m.boxb((cx, 0.3, 2.1), (1.74, 1.64, 0.3), (0, 0, 0), C('navy'))
    window_band(m, '-y', -0.5, cx, 1.2, 1.1, 0.7, n=2, glass=C('glass_light'), mullion=C('wood_trim'), sill=False)
    hazard_band(m, '-y', -0.5, cx, 1.7, 0.12, 0.3)
    m.box((0, 1.6, 0.11), (6.0, 0.3, 0.02), (0, 0, 0), C('mark_yellow'))                    # ligne d'arrêt
    m.box((0, -1.6, 0.11), (6.0, 0.3, 0.02), (0, 0, 0), C('mark_yellow'))
    m.to_object()


def inspection_hall():
    """Halle d'inspection T3 (C ouvert, marine + jaune) : halle en bardage ouverte sur le long côté -Y, poteaux à bandes
    jaune-noir, toit clair à bandeau marine, conteneur ouvert en cours d'inspection, cartons et table."""
    m = Model('inspection_hall', 32)
    w, d, h, z0 = 10.0, 6.0, 4.4, 0.2
    m.boxb((0, 0, 0), (w + 0.4, d + 0.4, z0), (0, 0, 0), C('apron_dark'))
    m.boxb((0, d / 2 - 0.15, z0), (w, 0.3, h), (0, 0, 0), C('clad_steel'))                   # fond +Y
    m.boxb((-w / 2 + 0.15, 0, z0), (0.3, d, h), (0, 0, 0), C('clad_steel'))                  # pignon -X
    m.boxb((w / 2 - 0.15, 0, z0), (0.3, d, h), (0, 0, 0), C('clad_steel'))                   # pignon +X
    for side, plane in (('-x', -w / 2), ('+x', w / 2)):
        for i in range(int(d / 0.5)):
            t = -d / 2 + (i + 0.5) * 0.5
            m.boxb(_face(side, plane, t, 0.02, z0 + 0.45), _size(side, 0.08, 0.04, h - 0.85), (0, 0, 0), C('clad_steel_dark'))
        hazard_band(m, side, plane, 0, d, z0 + 0.02)
        window_band(m, side, plane, 0, z0 + 2.6, 2.0, 0.7, n=3, glass=C('glass_light'), mullion=C('wood_trim'), sill=False)
    for x in (-w / 2 + 0.3, -w / 6, w / 6, w / 2 - 0.3):                                    # poteaux du côté ouvert
        m.boxb((x, -d / 2 + 0.2, z0), (0.36, 0.36, h), (0, 0, 0), C('clad_steel_dark'))
        for i in range(3):
            m.boxb((x, -d / 2 + 0.2, z0 + 0.05 + i * 0.4), (0.4, 0.4, 0.2), (0, 0, 0), C('hazard'))
    top = z0 + h
    m.boxb((0, 0, top - 0.35), (w + 0.1, d + 0.1, 0.35), (0, 0, 0), C('navy'))
    m.boxb((0, 0, top), (w + 0.6, d + 0.6, 0.3), (0, 0, 0), C('cap_light'))
    m.boxb((0, 0, top + 0.3), (w - 0.3, d - 0.3, 0.04), (0, 0, 0), C('roof_light'))
    m.boxb((0, -d / 2 - 0.3, top + 0.3), (w + 0.6, 0.1, 0.12), (0, 0, 0), C('yellow'))       # liseré jaune
    ac_unit(m, -3.0, 1.5, top + 0.34)
    emblem_beacon(m, 3.5, -1.0, top + 0.34, C('orange'), 1.3)
    # conteneur bleu ouvert (portes battantes) et sa cargaison
    cx, cy = -1.2, 0.6
    m.boxb((cx, cy, z0), (4.0, 1.3, 1.3), (0, 0, 0), C('box_blue'))
    m.box((cx - 1.98, cy, z0 + 0.65), (0.05, 1.1, 1.2), (0, 0, 0), C('dark'))
    for s in (-1, 1):
        m.box((cx + 2.3, cy + s * 1.0, z0 + 0.65), (0.6, 0.06, 1.25), (0, 0, s * 0.3), mul(C('box_blue'), 0.85))
    _carton_stack(m, 2.6, 0.4, z0, [C('box_yellow'), C('box_red')])
    _carton_stack(m, 3.9, 0.9, z0, [C('box_green')])
    emblem_table_suitcase(m, -3.7, -1.2, open=False)
    cone(m, w / 2 + 0.8, -d / 2 + 0.6)
    m.box((0, -d / 2 - 0.1, z0 + 0.01), (w - 1.0, 0.25, 0.02), (0, 0, 0), C('mark_yellow'))
    m.to_object()


def it_center():
    """Centre informatique T3 (C, teal) : bardage nervuré, bandeau teal, baie-vitrine sombre à LED, antennes,
    parabole et clims en toiture, porte roulante teal."""
    m = Model('it_center', 36)
    w, d, h, z0 = 6.0, 5.0, 3.0, 0.2
    b = steel_shed(m, w, d, h, z0, dept=C('teal'), skip={'-y': [(-1.6, 2.6), (1.5, 1.3)]})
    # baie sombre à racks et LED teal (lisible comme une salle serveurs)
    m.boxb((-1.6, -d / 2 - 0.03, z0 + 0.6), (2.6, 0.06, 1.9), (0, 0, 0), C('dark'))
    m.boxb((-1.6, -d / 2 - 0.08, z0 + 0.5), (2.8, 0.1, 0.1), (0, 0, 0), C('wood_trim'))
    m.boxb((-1.6, -d / 2 - 0.08, z0 + 2.5), (2.8, 0.1, 0.1), (0, 0, 0), C('wood_trim'))
    for i in range(3):
        x = -2.4 + i * 0.8
        for k in range(4):
            m.box((x, -d / 2 - 0.07, z0 + 0.9 + k * 0.4), (0.5, 0.03, 0.08), (0, 0, 0), C('teal') if (i + k) % 2 else C('green'))
    roll_door(m, '-y', -d / 2, 1.5, z0, 1.1, 2.0, C('teal'))
    window_band(m, '+x', w / 2, 0, z0 + 1.6, 2.2, 0.7, n=3, glass=C('glass_light'), mullion=C('wood_trim'), sill=False)
    emblem_antenna(m, -2.0, 1.4, b['roof'], 3.0, C('wood_trim'))
    emblem_antenna(m, -1.3, 1.6, b['roof'], 2.2, C('wood_trim'))
    emblem_dish(m, 1.8, 1.0, b['roof'], 0.9)
    ac_unit(m, 1.4, -1.4, b['roof'])
    ac_unit(m, 0.2, -1.4, b['roof'])
    m.boxb((-2.6, -1.8, b['roof']), (0.7, 0.7, 0.4), (0, 0, 0), C('teal'))
    cone(m, -w / 2 - 0.7, -d / 2 - 0.5)
    m.to_object()


def substation():
    """Sous-station T3 (C, acier + jaune) : dalle gravillonnée, deux transformateurs à ailettes et isolateurs blancs,
    pylône à bandes jaune-noir, clôture, panneau de danger jaune."""
    m = Model('substation', 35)
    w, d = 6.0, 4.5
    m.boxb((0, 0, 0), (w, d, 0.2), (0, 0, 0), C('gravel_dark'))
    for side, plane in (('-y', -d / 2), ('+x', w / 2), ('-x', -w / 2)):
        L = w if side[1] == 'y' else d
        hazard_band(m, side, plane, 0, L, 0.0, 0.2, 0.0)
    for x in (-1.5, 1.5):
        m.boxb((x, -0.3, 0.2), (1.7, 1.5, 1.7), (0, 0, 0), C('clad_steel'))
        for k in range(4):
            m.box((x - 0.6 + k * 0.4, -1.08, 1.0), (0.12, 0.08, 1.4), (0, 0, 0), C('clad_steel_dark'))      # ailettes
        for i in range(3):
            m.cylb((x - 0.5 + i * 0.5, -0.3, 1.9), 0.1, 0.9, C('white'), 6)
            m.cylb((x - 0.5 + i * 0.5, -0.3, 2.2), 0.16, 0.08, C('white'), 6)
            m.cylb((x - 0.5 + i * 0.5, -0.3, 2.5), 0.16, 0.08, C('white'), 6)
        m.boxb((x, -0.3, 1.9), (1.8, 1.6, 0.08), (0, 0, 0), C('cap_light'))
    # pylône : quatre montants, traverses, bandes jaune-noir au pied
    px, py = 0, 1.5
    for sx in (-1, 1):
        for sy in (-1, 1):
            m.tube((px + sx * 0.5, py + sy * 0.4, 0.2), (px + sx * 0.18, py + sy * 0.15, 5.0), 0.05, C('steel'), 4)
            for i in range(3):
                m.boxb((px + sx * 0.5, py + sy * 0.4, 0.2 + i * 0.3), (0.16, 0.16, 0.15), (0, 0, 0), C('hazard') if i % 2 == 0 else C('dark'))
    for z, L in ((2.6, 2.4), (4.2, 1.8)):
        m.box((px, py, z), (L, 0.12, 0.12), (0, 0, 0), C('steel'))
        for s in (-1, 1):
            m.cylb((px + s * (L / 2 - 0.15), py, z - 0.4), 0.06, 0.4, C('white'), 5)
    m.box((px, py, 5.0), (0.5, 0.5, 0.1), (0, 0, 0), C('steel'))
    m.ico((px, py, 5.1), (0.1, 0.1, 0.1), (0, 0, 0), C('red'), 0)
    for i in range(7):                                                                        # clôture avant
        x = -w / 2 + i * w / 6
        m.cylb((x, -d / 2 + 0.1, 0.2), 0.05, 1.3, C('steel'), 5)
    m.box((0, -d / 2 + 0.1, 1.45), (w, 0.05, 0.05), (0, 0, 0), C('steel'))
    m.box((0, -d / 2 + 0.1, 0.9), (w, 0.02, 0.9), (0, 0, 0), C('rock'))
    m.boxb((1.6, -d / 2 - 0.15, 0.6), (0.8, 0.06, 0.8), (0, 0, 0), C('yellow'))               # panneau de danger
    m.box((1.6, -d / 2 - 0.19, 1.0), (0.12, 0.04, 0.45), (0, 0.0, 0.35), C('dark'))
    m.to_object()


def imo_fence():
    """Enclos IMO 12 × 12 (C, rouge / orange) : poteaux orange, grillage, losanges rouges géants, extincteur."""
    m = Model('imo_fence', 33)
    s = 12.0
    for side in range(4):
        for i in range(7):
            t = -s / 2 + i * s / 6
            x, y = (t, -s / 2) if side == 0 else (s / 2, t) if side == 1 else (t, s / 2) if side == 2 else (-s / 2, t)
            m.cylb((x, y, 0), 0.08, 1.7, C('orange'), 6)
    for (x, y, l, r) in [(0, -s / 2, s, 0), (s / 2, 0, s, 1.5708), (0, s / 2, s, 0), (-s / 2, 0, s, 1.5708)]:
        m.box((x, y, 1.65), (l, 0.06, 0.08), (0, 0, r), C('orange'))
        m.box((x, y, 0.9), (l, 0.02, 1.4), (0, 0, r), C('rock'))
        m.box((x, y, 0.15), (l, 0.06, 0.08), (0, 0, r), C('orange'))
    for x in (-3.2, 3.2):                                                                      # losanges rouges géants
        m.box((x, -s / 2 - 0.08, 2.2), (1.3, 0.06, 1.3), (0, 0.785, 0), C('sign_red'))
        m.box((x, -s / 2 - 0.12, 2.2), (0.9, 0.06, 0.9), (0, 0.785, 0), C('white'))
        m.box((x, -s / 2 - 0.16, 2.2), (0.3, 0.06, 0.3), (0, 0.785, 0), C('sign_red'))
    m.box((s / 2 + 0.08, 0, 2.2), (0.06, 1.3, 1.3), (0.785, 0, 0), C('sign_red'))
    m.box((s / 2 + 0.12, 0, 2.2), (0.06, 0.9, 0.9), (0.785, 0, 0), C('white'))
    # extincteur géant sur socle, près de l'entrée
    ex, ey = -s / 2 - 0.9, -s / 2 + 1.0
    m.boxb((ex, ey, 0), (0.8, 0.8, 0.1), (0, 0, 0), C('dark'))
    m.cylb((ex, ey, 0.1), 0.3, 1.3, C('sign_red'), 8)
    m.cylb((ex, ey, 1.4), 0.12, 0.3, C('dark'), 6)
    m.tube((ex, ey, 1.6), (ex + 0.45, ey, 1.2), 0.05, C('dark'), 4)
    m.to_object()


def rail_terminal():
    """Terminal rail T3 (C, vert) : dalle à rails, auvent clair à bandeau vert sur poteaux, butoir, panneau de voie."""
    m = Model('rail_terminal', 34)
    L, D = 18.0, 3.0
    m.boxb((0, 0, 0), (L, D, 0.6), (0, 0, 0), C('apron_warm'))
    m.boxb((0, 0, 0.0), (L, D + 0.1, 0.12), (0, 0, 0), C('asphalt_dark'))
    for y in (-0.55, 0.55):
        m.box((0, y, 0.63), (L, 0.14, 0.08), (0, 0, 0), C('steel'))
    for i in range(12):
        m.box((-L / 2 + 0.9 + i * 1.5, 0, 0.6), (0.5, 1.6, 0.06), (0, 0, 0), C('wood'))
    for i in range(4):
        x = -7.5 + i * 5
        m.boxb((x, 1.2, 0.6), (0.3, 0.3, 3.4), (0, 0, 0), C('clad_steel_dark'))
        for k in range(3):
            m.boxb((x, 1.2, 0.62 + k * 0.4), (0.34, 0.34, 0.2), (0, 0, 0), C('hazard'))
    m.box((0, 0.6, 4.1), (L + 0.5, 3.2, 0.26), (0.12, 0, 0), C('cap_light'))
    m.box((0, -0.93, 3.93), (L + 0.5, 0.1, 0.32), (0.12, 0, 0), C('hull_green'))             # bandeau vert
    m.boxb((-L / 2 + 0.5, 0, 0.6), (0.6, 1.5, 0.9), (0, 0, 0), C('dark'))                   # butoir
    m.box((-L / 2 + 0.19, 0, 1.2), (0.05, 1.3, 0.4), (0, 0, 0), C('sign_red'))
    m.cylb((L / 2 - 0.6, -1.3, 0.6), 0.07, 2.2, C('steel'), 6)                             # panneau de voie
    m.box((L / 2 - 0.6, -1.3, 3.0), (0.9, 0.06, 0.6), (0, 0, 0), C('hull_green'))
    m.box((L / 2 - 0.6, -1.34, 3.0), (0.5, 0.04, 0.3), (0, 0, 0), C('white'))
    m.boxb((7, 0.4, 0.6), (2.5, 1.6, 2.2), (0, 0, 0), C('clad_steel'))                       # cabine
    m.boxb((7, 0.4, 2.8), (2.7, 1.8, 0.2), (0, 0, 0), C('cap_light'))
    window_band(m, '-y', -0.4, 7, 1.7, 1.6, 0.7, n=3, glass=C('glass_light'), mullion=C('wood_trim'), sill=False)
    hazard_band(m, '-y', -0.4, 7, 2.5, 0.62, 0.3)
    m.to_object()


def warehouse():
    """Entrepôt (C, vert ; logistique ×2 et T3 à 90°) : halle en bardage nervuré, bande jaune-noir, bandeau vert sous
    casquette claire, quai à deux portes roulantes vertes dont une ouverte sur des cartons, sheds vitrés en toiture."""
    m = Model('warehouse', 37)
    w, d, h, z0 = 14.0, 7.0, 4.6, 0.2
    g = C('hull_green')
    bays = (-2.8, 2.8)
    b = steel_shed(m, w, d, h, z0, dept=g, rib=0.6, skip={'-y': [(x, 2.3) for x in bays]})
    m.boxb((0, -d / 2 - 0.65, 0), (8.6, 1.3, z0), (0, 0, 0), C('asphalt_dark'))               # quai
    for i, x in enumerate(bays):
        # casquette de 2,2 : bord bas à z0 + 2,97, saillie 0,65 : porte visible jusqu'à z0 + 2,33
        roll_door(m, '-y', -d / 2, x, z0, 1.8, 2.2, g, open=(i == 0))
        awning(m, '-y', -d / 2, x, z0 + 3.3, 2.2, depth=0.65, drop=0.15, c=g, valance=0.18)
        for sx in (-1, 1):
            m.boxb((x + sx * 1.3, -d / 2 - 1.33, 0.1), (0.25, 0.1, 0.4), (0, 0, 0), C('dark'))   # butoirs
            m.cylb((x + sx * 1.75, -d / 2 - 1.65, 0), 0.2, 1.1, C('yellow'), 8)               # bornes ×1,35
            m.cylb((x + sx * 1.75, -d / 2 - 1.65, 0.55), 0.21, 0.18, C('dark'), 8)
    _carton_stack(m, -2.8, -d / 2 - 0.65, z0, [C('box_red'), C('box_blue')])
    _carton_stack(m, -1.5, -d / 2 - 0.6, z0, [C('box_yellow')])
    window_band(m, '-y', -d / 2, 0, z0 + 3.0, 2.0, 0.6, n=3, glass=C('glass_light'), mullion=C('wood_trim'), sill=False)
    for side, plane in (('+x', w / 2), ('-x', -w / 2)):
        window_band(m, side, plane, 0, z0 + 3.0, 3.0, 0.6, n=4, glass=C('glass_light'), mullion=C('wood_trim'), sill=False)
    sa, sl = 0.45, 0.9                                                                 # pente et longueur du vitrage
    sy0, sy1 = 0.9 - sl / 2 * math.cos(sa), 0.9 + sl / 2 * math.cos(sa)
    sz0, sz1 = b['roof'] + 0.12, b['roof'] + 0.32 + sl / 2 * math.sin(sa)
    for x in (-4.5, 0, 4.5):                                                           # sheds vitrés
        m.boxb((x, 0.9, b['roof']), (3.0, 1.0, 0.12), (0, 0, 0), C('cap_light'))
        m.prism_x([(sy0, sz0), (sy1, sz0), (sy1, sz1)], x - 1.42, x + 1.42, C('cap_light'))
        m.box((x, 0.9, b['roof'] + 0.32), (2.9, sl, 0.06), (sa, 0, 0), C('glass_light'))
    for x in (-5.8, 5.8):
        m.cylb((x, 2.0, b['roof']), 0.25, 0.6, C('steel'), 8)
        m.cylb((x, 2.0, b['roof'] + 0.6), 0.35, 0.12, C('steel'), 8)
    ac_unit(m, 2.5, -1.8, b['roof'])
    m.boxb((-w / 2 - 0.2, -d / 2 - 0.5, 0), (0.8, 0.8, 1.6), (0, 0, 0), g)                    # bloc-emblème vert
    m.boxb((-w / 2 - 0.2, -d / 2 - 0.5, 1.6), (0.9, 0.9, 0.12), (0, 0, 0), C('white'))
    cone(m, w / 2 + 0.7, -d / 2 - 0.5)
    m.to_object()


ASSETS = {
    'harbor_office': harbor_office, 'customs_hut': customs_hut, 'hangar': hangar, 'control_tower': control_tower,
    'gate_booth': gate_booth, 'barrier': barrier, 'reefer_rack': reefer_rack, 'office': office, 'workshop': workshop,
    'customs_office': customs_office, 'scanner': scanner, 'inspection_hall': inspection_hall, 'imo_fence': imo_fence,
    'rail_terminal': rail_terminal, 'substation': substation, 'it_center': it_center, 'warehouse': warehouse,
}
