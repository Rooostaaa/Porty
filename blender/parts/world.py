# Arrière-pays : aire d'attente, village (registre B : toits de couleurs variées, cheminée, volets), zone logistique
# (silo, registre C), relief, trafic civil (voitures saturées, toit clair, feux rouges).
# Repère Blender : X = longueur, Y = profondeur (la façade regarde -Y), Z = haut. Le dessus des dalles est en z = 0.
# Les maisons sont posées à 0°, 90°, -90° et 180° dans layout.gd : leurs quatre faces sont traitées.
import math
from lib import Model, wood_block, b_window, b_door, awning, gable_roof, tail_lights, mul, SCALE_PROPS
from palette import C
from terrain import _layers
from equipment import _wheels

ALL_SIDES = ('-y', '+x', '-x', '+y')


def ground_parking():
    """Dalle d'aire d'attente poids lourds : asphalte violet, deux places de 3 u par dalle, marquages épais, ligne d'arrêt."""
    m = Model('ground_parking', 31)
    _layers(m, C('asphalt_violet'))
    for x in (-2.9, 0.0, 2.9):
        m.box((x, 0, 0.012), (0.22, 5.4, 0.03), (0, 0, 0), C('marking_thick'))
    m.box((0, -2.6, 0.012), (5.9, 0.22, 0.03), (0, 0, 0), C('marking_thick'))
    m.box((-1.45, 2.2, 0.014), (1.0, 0.5, 0.03), (0, 0, 0), C('mark_yellow'))
    m.to_object()


def _chimney(m, x, y, z, c=None):
    m.boxb((x, y, z), (0.5, 0.5, 1.2), (0, 0, 0), c or C('kerb'))
    m.boxb((x, y, z + 1.2), (0.6, 0.6, 0.12), (0, 0, 0), C('dark'))


def house_a():
    """Maison de pêcheur (B) : bois crème, toit rouge falun, cheminée, porte bleue, fenêtres à volets verts."""
    m = Model('house_a', 61)
    w, d, h = 4.4, 3.6, 2.4
    b = wood_block(m, w, d, h, 0.2, roof=C('falun'), rise=1.5, sides=ALL_SIDES, lap=0.32)
    b_door(m, '-y', -d / 2, -0.2, 0.2, c=C('roof_b_blue'), h=1.6)
    for t in (1.3,):
        b_window(m, '-y', -d / 2, t, 1.1, shutters=C('roof_b_green'))
    for side, plane in (('+x', w / 2), ('-x', -w / 2), ('+y', d / 2)):
        b_window(m, side, plane, 0, 1.1, shutters=C('roof_b_green'))
    _chimney(m, 1.1, 0.7, b['top'] + 0.7)
    m.to_object()


def house_b():
    """Maison à étage (B) : bois crème, toit bleu, balcon à garde-corps blanc, fenêtres à volets rouges."""
    m = Model('house_b', 62)
    w, d, h = 4.0, 3.4, 4.3
    b = wood_block(m, w, d, h, 0.2, roof=C('roof_b_blue'), rise=1.5, sides=ALL_SIDES, lap=0.32)
    m.boxb((0, 0, 0.2 + 2.2), (w + 0.1, d + 0.1, 0.12), (0, 0, 0), C('wood_trim'))          # bandeau d'étage
    b_door(m, '-y', -d / 2, -1.1, 0.2, c=C('falun'), h=1.6)
    b_window(m, '-y', -d / 2, 1.0, 1.0, shutters=C('falun'))
    for side, plane in (('+x', w / 2), ('-x', -w / 2), ('+y', d / 2)):
        b_window(m, side, plane, 0, 1.0, shutters=C('falun'))
        b_window(m, side, plane, 0, 3.0, shutters=C('falun'))
    b_window(m, '-y', -d / 2, 1.0, 3.0)
    m.boxb((-0.6, -d / 2 - 0.45, 2.75), (1.9, 0.9, 0.1), (0, 0, 0), C('wood'))             # balcon
    b_door(m, '-y', -d / 2, -0.6, 2.85, c=C('wood_cream'), h=1.3, w=0.8)
    for x in (-1.5, -0.6, 0.3):
        m.boxb((x, -d / 2 - 0.85, 2.85), (0.06, 0.06, 0.8), (0, 0, 0), C('wood_trim'))
    m.box((-0.6, -d / 2 - 0.85, 3.65), (1.9, 0.06, 0.06), (0, 0, 0), C('wood_trim'))
    _chimney(m, -1.0, 0.6, b['top'] + 0.7)
    m.to_object()


def shop():
    """Épicerie du village (B) : bois crème, toit vert, vitrine, auvent rayé jaune / blanc, cageots devant."""
    m = Model('shop', 63)
    w, d, h = 5.0, 3.6, 2.7
    b = wood_block(m, w, d, h, 0.2, roof=C('roof_b_green'), rise=1.3, sides=ALL_SIDES, lap=0.32)
    b_window(m, '-y', -d / 2, 0.9, 0.75, length=2.0, height=1.3, n=3)                    # vitrine
    b_door(m, '-y', -d / 2, -1.4, 0.2, c=C('roof_b_green'), h=1.65)
    awning(m, '-y', -d / 2, 0.5, 2.45, 3.6, depth=0.7, drop=0.18, c=C('yellow'), c2=C('wood_trim'), n=8, valance=0.14)
    for side, plane in (('+x', w / 2), ('-x', -w / 2)):
        b_window(m, side, plane, 0, 1.0, length=1.2, n=3)
    for i, c in enumerate((C('box_red'), C('box_green'), C('box_yellow'))):             # cageots de fruits
        m.cham((0.3 + i * 0.75, -d / 2 - 0.85, 0), (0.6, 0.5, 0.35), 0.04, C('wood'))
        m.ico((0.3 + i * 0.75, -d / 2 - 0.85, 0.4), (0.26, 0.22, 0.14), (0, 0, 0), c, 0)
    _chimney(m, -1.6, 0.8, b['top'] + 0.6)
    m.to_object()


def silo():
    """Deux silos (C, logistique vert) : cylindres clairs à bandeau vert, échelle, passerelle à garde-corps, convoyeur."""
    m = Model('silo', 64)
    m.boxb((0, 0, 0), (6.0, 3.6, 0.2), (0, 0, 0), C('apron_dark'))
    for x in (-1.4, 1.4):
        m.cylb((x, 0, 0.2), 1.25, 5.5, C('cap_light'), 12)
        m.cylb((x, 0, 0.2), 1.28, 0.5, C('hull_green'), 12)
        m.cylb((x, 0, 4.2), 1.28, 0.4, C('hull_green'), 12)
        m.cyl((x, 0, 5.7 + 0.5), (1.25, 1.25, 1.0), (0, 0, 0), C('clad_steel'), 12, 0.15)
    m.boxb((0, 0, 6.3), (3.6, 0.5, 0.25), (0, 0, 0), C('clad_steel_dark'))                # passerelle
    for x in (-1.7, -0.6, 0.6, 1.7):
        m.boxb((x, -0.25, 6.55), (0.05, 0.05, 0.8), (0, 0, 0), C('yellow'))
    m.box((0, -0.25, 7.35), (3.6, 0.05, 0.05), (0, 0, 0), C('yellow'))
    for s in (-1, 1):                                                                      # échelle
        m.boxb((1.4 + s * 0.22, -1.3, 0.2), (0.06, 0.06, 6.2), (0, 0, 0), C('steel'))
    for k in range(12):
        m.box((1.4, -1.3, 0.5 + k * 0.5), (0.44, 0.05, 0.05), (0, 0, 0), C('steel'))
    m.boxb((0, -2.0, 0), (4.4, 1.0, 1.0), (0, 0, 0), C('clad_steel'))                     # trémie / convoyeur
    m.boxb((0, -2.0, 1.0), (4.6, 1.2, 0.12), (0, 0, 0), C('cap_light'))
    m.box((-2.4, -2.0, 1.6), (0.9, 0.7, 0.5), (0.0, 0.5, 0), C('hull_green'))
    m.to_object()


def hill():
    """Colline basse à deux étages, avec quelques rochers."""
    m = Model('hill', 65)
    m.cyl((0, 0, 1.4), (9.0, 9.0, 2.8), (0, 0, 0.2), C('grass'), 9, 0.55)
    m.cyl((0.8, 0.5, 3.6), (5.2, 5.2, 2.2), (0, 0, 0.7), C('grass_dark'), 8, 0.4)
    m.ico((-3.2, -2.2, 0.5), (1.1, 0.9, 0.8), (0, 0, 0.5), C('rock'), 0, 0.3)
    m.ico((3.6, -1.0, 0.4), (0.8, 0.7, 0.6), (0, 0, 1.2), C('rock_dark'), 0, 0.3)
    m.to_object()


def _car(name, seed, body):
    """Voiture : une couleur franche, toit nettement plus clair, vitres claires, feux arrière rouges, phares."""
    m = Model(name, seed)
    m.boxb((0, 0, 0.3), (3.2, 1.5, 0.7), (0, 0, 0), body)
    m.boxb((-0.2, 0, 1.0), (1.7, 1.3, 0.6), (0, 0, 0), body)
    m.boxb((-0.2, 0, 1.6), (1.8, 1.4, 0.1), (0, 0, 0), mul(body, 1.3))
    m.box((0.66, 0, 1.3), (0.05, 1.1, 0.4), (0, 0, 0), C('glass_light'))
    m.box((-1.06, 0, 1.3), (0.05, 1.1, 0.4), (0, 0, 0), C('glass_light'))
    for s in (-1, 1):
        m.box((-0.2, s * 0.66, 1.3), (1.4, 0.05, 0.4), (0, 0, 0), C('glass_light'))
        m.box((1.61, s * 0.5, 0.7), (0.05, 0.3, 0.16), (0, 0, 0), C('yellow'))
    tail_lights(m, -1.6, 0.75, 0.7)
    _wheels(m, (-1.0, 1.0), 0.75, 0.3, 0.3, 0.22)
    m.to_object()


def car_a():
    _car('car_a', 66, C('blue'))


def car_b():
    _car('car_b', 67, C('yellow'))


def car_c():
    _car('car_c', 69, C('teal'))


def stack():
    """Pile décorative de conteneurs (2 × 3, deux étages) pour la zone logistique."""
    m = Model('stack', 68)
    cols = ['box_red', 'box_blue', 'box_green', 'box_orange', 'box_teal', 'box_yellow']
    k = 0
    for i in range(3):
        for j in range(2):
            m.boxb((i * 4.2 - 4.2, j * 1.6 - 0.8, 0.0), (4.0, 1.4, 1.3), (0, 0, 0), C(cols[k % len(cols)]))
            if (i + j) % 2 == 0:
                m.boxb((i * 4.2 - 4.2, j * 1.6 - 0.8, 1.3), (4.0, 1.4, 1.3), (0, 0, 0), C(cols[(k + 2) % len(cols)]))
            k += 1
    m.to_object()


ASSETS = {
    'ground_parking': ground_parking, 'house_a': house_a, 'house_b': house_b, 'shop': shop, 'silo': silo,
    'hill': hill, 'car_a': car_a, 'car_b': car_b, 'car_c': car_c, 'stack': stack,
}
