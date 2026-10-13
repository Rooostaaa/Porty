# Conteneurs (blancs pour être teintés par instance dans Godot), personnages et accessoires.
# Direction D : personnages à 1,35 u (grosse tête, corps capsule, gilets saturés), accessoires ×1,35.
import math
from lib import Model, SCALE_PROPS, cone as _cone
from palette import C

WHITE = (1.0, 1.0, 1.0)
RIB = (0.82, 0.82, 0.84)
FRAME = (0.62, 0.63, 0.66)
S = SCALE_PROPS


def _container(name, L, seed, body=WHITE, end=None):
    m = Model(name, seed)
    W, H = 1.3, 1.3
    m.boxb((0, 0, 0.04), (L - 0.12, W - 0.06, H - 0.08), (0, 0, 0), body)
    for sx in (-1, 1):
        for sy in (-1, 1):
            m.boxb((sx * (L / 2 - 0.06), sy * (W / 2 - 0.05), 0), (0.12, 0.1, H), (0, 0, 0), FRAME)
    m.boxb((0, 0, H - 0.07), (L, W, 0.07), (0, 0, 0), RIB)

    if end is not None:
        m.box((-L / 2 + 0.03, 0, H / 2), (0.08, W * 0.7, H * 0.6), (0, 0, 0), end)
    else:
        for y in (-0.25, 0.25):
            m.box((L / 2 - 0.02, y, H / 2), (0.06, 0.06, H * 0.8), (0, 0, 0), RIB)
    return m


def container40():
    _container('container40', 4.0, 71).to_object()


def container20():
    _container('container20', 2.0, 72).to_object()


def reefer40():
    m = _container('reefer40', 4.0, 73, C('reefer'), C('steel'))
    m.box((-1.99, 0.4, 1.05), (0.06, 0.12, 0.12), (0, 0, 0), C('green'))
    m.to_object()


def flatrack():
    """Plateau hors-gabarit avec une pale d'éolienne."""
    m = Model('flatrack', 74)
    m.boxb((0, 0, 0), (4.0, 1.3, 0.25), (0, 0, 0), C('steel'))
    for x in (-1.9, 1.9):
        m.boxb((x, 0, 0.25), (0.15, 1.3, 1.0), (0, 0, 0), C('oog'))
    m.cyl((0, 0, 0.75), (0.4, 0.4, 5.2), (0, math.pi / 2, 0), C('white'), 8, 0.35)
    m.to_object()


def _person(name, seed, body, legs, hat=None, vest=None, cap=None, arms=None):
    """Personnage de 1,35 u : jambes courtes, corps capsule, grosse tête, casque / casquette ; face vers +X."""
    m = Model(name, seed)
    arms = arms or body
    for y in (-0.12, 0.12):
        m.boxb((0, y, 0), (0.2, 0.17, 0.42), (0, 0, 0), legs)
        m.boxb((0.03, y, 0), (0.28, 0.18, 0.08), (0, 0, 0), C('dark'))                     # chaussures
    m.cylb((0, 0, 0.42), 0.27, 0.5, vest or body, 8, 0.86)
    m.cylb((0, 0, 0.42), 0.2, 0.08, body, 8)                                               # ceinture / bas du t-shirt
    for y in (-0.3, 0.3):
        m.cyl((0.02, y, 0.7), (0.08, 0.08, 0.42), (0.15 * (1 if y > 0 else -1), 0, 0), arms, 6)
        m.ico((0.03, y * 1.1, 0.48), (0.08, 0.08, 0.08), (0, 0, 0), C('skin'), 0)
    m.ico((0, 0, 1.1), (0.24, 0.24, 0.25), (0, 0, 0), C('skin'), 1)
    if hat is not None:
        m.cyl((0, 0, 1.3), (0.27, 0.27, 0.14), (0, 0, 0), hat, 8, 0.75)
        m.cyl((0.02, 0, 1.22), (0.3, 0.3, 0.05), (0, 0, 0), hat, 8)
    if cap is not None:
        m.cyl((0, 0, 1.3), (0.24, 0.24, 0.12), (0, 0, 0), cap, 8, 1.0)
        m.box((0.22, 0, 1.25), (0.2, 0.3, 0.04), (0, 0, 0), cap)
    m.to_object()


def docker():
    _person('docker', 81, C('blue'), C('navy'), hat=C('yellow'), vest=C('orange'), arms=C('blue'))


def customs_officer():
    _person('customs_officer', 82, C('navy'), C('navy'), cap=C('navy'), vest=C('navy'), arms=C('white'))


def inspector():
    _person('inspector', 83, C('white'), C('dark'), hat=C('white'), vest=C('hazard'), arms=C('white'))


def manager():
    _person('manager', 84, C('ui_indigo'), C('dark'), vest=C('ui_indigo'), arms=C('ui_indigo'))


def cone():
    m = Model('cone', 85)
    _cone(m, 0, 0, S)
    m.to_object()


def barrel():
    """Fût bleu ×1,35 à cerclages sombres."""
    m = Model('barrel', 86)
    m.cylb((0, 0, 0), 0.3 * S, 0.9 * S, C('blue'), 8)
    for z in (0.25, 0.6):
        m.cylb((0, 0, z * S), 0.31 * S, 0.08 * S, C('dark'), 8)
    m.cylb((0, 0, 0.9 * S), 0.26 * S, 0.03, C('dark'), 8)
    m.to_object()


def pallet():
    """Palette ×1,35 chargée de cartons colorés et d'un ruban clair."""
    m = Model('pallet', 87)
    m.boxb((0, 0, 0), (1.2 * S, 1.0 * S, 0.15 * S), (0, 0, 0), C('wood'))
    m.boxb((0, 0, 0.15 * S), (1.1 * S, 0.9 * S, 0.5 * S), (0, 0, 0), C('box_yellow'))
    m.boxb((0, 0, 0.65 * S), (0.9 * S, 0.8 * S, 0.4 * S), (0, 0, 0), C('box_red'))
    m.boxb((0, 0, 0.64 * S), (0.2, 0.92 * S, 0.02), (0, 0, 0), C('white'))
    m.to_object()


def sign():
    """Panneau indigo sur mât ×1,35 (face vers -Y)."""
    m = Model('sign', 88)
    m.cylb((0, 0, 0), 0.06 * S, 1.6 * S, C('steel'), 5)
    m.box((0, 0, 1.95 * S), (1.1 * S, 0.06, 0.6 * S), (0, 0, 0), C('ui_indigo'))
    m.box((0, -0.04, 1.95 * S), (0.8 * S, 0.04, 0.3 * S), (0, 0, 0), C('white'))
    m.to_object()


ASSETS = {
    'container40': container40, 'container20': container20, 'reefer40': reefer40, 'flatrack': flatrack,
    'docker': docker, 'customs_officer': customs_officer, 'inspector': inspector, 'manager': manager,
    'cone': cone, 'barrel': barrel, 'pallet': pallet, 'sign': sign,
}


def swatch():
    """Nuancier de contrôle sRGB/linéaire : une dalle par couleur clé, alignées sur X."""
    m = Model('swatch', 99)
    for i, k in enumerate(SWATCH_KEYS):
        m.boxb((i * 1.2, 0, 0), (1.0, 1.0, 0.2), (0, 0, 0), C(k))
    m.to_object()


SWATCH_KEYS = ['red', 'yellow', 'blue', 'green', 'grass', 'water', 'gravel', 'asphalt', 'white', 'dark']
ASSETS['swatch'] = swatch
