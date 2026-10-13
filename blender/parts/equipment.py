# Engins et véhicules — registre C « industriel pop » : une couleur franche par engin, toit plus clair que les flancs,
# feux arrière rouges, vitres claires, bandes jaune-noir. Pièces séparées pour l'animation dans Godot (aucun rig) :
# chaque pièce est un objet de premier niveau placé sur son pivot ; Godot les retrouve par leur nom (boom, hook, trolley…).
# Budget : ≤ 600 triangles par véhicule, ≤ 2 500 par grue (crane_mobile, crane_sts, rtg).
import math
from lib import Model, empty, tail_lights, emblem_beacon, hazard_band, mul
from palette import C


def _wheels(m, xs, y, z=0.45, r=0.45, w=0.35, hub=True):
    for x in xs:
        for s in (-1, 1):
            m.cyl((x, s * y, z), (r, r, w), (math.pi / 2, 0, 0), C('dark'), 8)
            if hub:
                m.cyl((x, s * y, z), (r * 0.45, r * 0.45, w + 0.04), (math.pi / 2, 0, 0), C('steel'), 6)


def _cab(m, p, s, body, glass_dx=None, roof=None):
    """Cabine : caisson coloré, toit clair, pare-brise clair sur la face +X (ou -X si glass_dx < 0)."""
    x, y, z = p
    w, d, h = s
    m.boxb((x, y, z), (w, d, h), (0, 0, 0), body)
    m.boxb((x, y, z + h), (w + 0.1, d + 0.1, 0.1), (0, 0, 0), roof or mul(body, 1.18))
    sgn = 1 if (glass_dx is None or glass_dx > 0) else -1
    m.box((x + sgn * (w / 2 + 0.01), y, z + h * 0.62), (0.05, d * 0.8, h * 0.4), (0, 0, 0), C('glass_light'))


# --- grue mobile portuaire (T1) : base, flèche (boom), crochet (hook) ---------
def crane_mobile():
    base = Model('base', 41)
    base.boxb((0, 0, 0.5), (6.0, 3.0, 1.1), (0, 0, 0), C('orange'))
    base.boxb((0, 0, 1.6), (6.2, 3.2, 0.1), (0, 0, 0), mul(C('orange'), 1.18))
    _wheels(base, (-2.0, -1.0, 1.0, 2.0), 1.3)
    for sx in (-1, 1):
        for sy in (-1, 1):
            base.box((sx * 2.3, sy * 2.2, 0.9), (0.35, 1.6, 0.25), (0, 0, 0), C('hazard'))
            base.boxb((sx * 2.3, sy * 2.9, 0.0), (0.7, 0.7, 0.25), (0, 0, 0), C('dark'))
    base.cylb((0, 0, 1.7), 1.0, 3.5, C('orange'), 10)
    base.cylb((0, 0, 1.7), 1.06, 0.35, C('dark'), 10)                                   # couronne d'orientation
    _cab(base, (0.2, -0.9, 3.4), (1.6, 1.2, 1.3), C('white'))
    base.boxb((-1.4, 0, 3.6), (1.6, 1.8, 1.2), (0, 0, 0), C('dark'))                     # contrepoids
    hazard_band(base, '-x', -2.2, 0, 1.8, 3.65, 0.3, 0.0)
    emblem_beacon(base, 0.2, -0.9, 4.8, C('orange'), 0.8)
    tail_lights(base, -3.0, 1.5, 1.2)
    base.to_object('base')

    boom = Model('boom', 42)
    ang = math.radians(32)
    L = 13.0
    tip = (math.cos(ang) * L, 0, math.sin(ang) * L)
    for s in (-1, 1):
        boom.beam((0, s * 0.45, 0), (tip[0], s * 0.2, tip[2]), 0.12, C('yellow'))
    n = 8
    for i in range(n):
        t0, t1 = i / n, (i + 1) / n
        a = (tip[0] * t0, 0.45 - 0.25 * t0, tip[2] * t0)
        b = (tip[0] * t1, -(0.45 - 0.25 * t1), tip[2] * t1)
        boom.beam(a, b, 0.06, C('yellow'))
        boom.beam((a[0], -a[1], a[2]), (b[0], -b[1], b[2]), 0.06, C('yellow'))
    boom.box(tip, (0.6, 0.6, 0.4), (0, -ang, 0), C('orange'))
    boom.ico((tip[0] + 0.1, 0, tip[2] + 0.35), (0.14, 0.14, 0.14), (0, 0, 0), C('sign_red'), 0)
    boom.to_object('boom', (0, 0, 5.0))

    hook = Model('hook', 43)
    hook.boxb((0, 0, -0.5), (0.5, 0.5, 0.5), (0, 0, 0), C('yellow'))
    hook.boxb((0, 0, -0.9), (1.6, 0.9, 0.25), (0, 0, 0), C('dark'))
    hook.to_object('hook', (tip[0], 0, 5.0 + tip[2] - 3.0))
    return {'boom_tip': [round(tip[0], 3), round(tip[2], 3), 0.0], 'boom_pivot_y': 5.0}


# --- portique STS : base, flèche, chariot (trolley), palonnier (spreader) -------
def crane_sts():
    H = 13.0
    base = Model('base', 44)
    for x in (-2.4, 2.4):
        for y in (-1.6, 1.6):
            base.boxb((x, y, 0.0), (0.5, 0.5, H), (0, 0, 0), C('blue'))
            base.boxb((x, y, 0.0), (1.1, 0.9, 0.5), (0, 0, 0), C('dark'))
            for i in range(3):
                base.boxb((x, y, 0.55 + i * 0.4), (0.56, 0.56, 0.2), (0, 0, 0), C('hazard'))
        base.boxb((x, 0, H * 0.45), (0.4, 3.6, 0.5), (0, 0, 0), C('white'))
        base.beam((x, -1.6, 1.0), (x, 1.6, H * 0.45), 0.1, C('white'))
    for y in (-1.6, 1.6):
        base.boxb((0, y, H - 0.6), (5.3, 0.5, 0.6), (0, 0, 0), C('blue'))
    base.boxb((0, -4.6, H + 0.2), (4.0, 3.0, 2.0), (0, 0, 0), C('white'))      # salle des machines
    base.boxb((0, -4.6, H + 2.2), (4.2, 3.2, 0.12), (0, 0, 0), C('cap_light'))
    base.box((0, -4.6, H + 1.0), (3.2, 3.02, 0.5), (0, 0, 0), C('blue'))
    base.boxb((0, 1.6, H), (0.6, 0.6, 5.0), (0, 0, 0), C('blue'))               # mât (A-frame)
    base.beam((0, 1.6, H + 5.0), (0, 12.0, H + 1.2), 0.08, C('steel'))
    base.beam((0, 1.6, H + 5.0), (0, -6.0, H + 1.2), 0.08, C('steel'))
    base.ico((0, 1.6, H + 5.1), (0.16, 0.16, 0.16), (0, 0, 0), C('sign_red'), 0)
    base.to_object('base')

    boom = Model('boom', 45)
    y0, y1 = -9.0, 14.5          # relatif au pivot (y = 1.6)
    for x in (-1.0, 1.0):
        boom.box((x, (y0 + y1) / 2, 0), (0.45, y1 - y0, 0.8), (0, 0, 0), C('blue'))
    for i in range(10):
        y = y0 + 0.5 + i * (y1 - y0 - 1) / 9
        boom.box((0, y, 0.3), (2.4, 0.2, 0.2), (0, 0, 0), C('white'))
    boom.box((0, y1 - 0.3, 0.1), (2.6, 0.6, 0.6), (0, 0, 0), C('hazard'))
    boom.to_object('boom', (0, 1.6, H + 0.4))

    tr = Model('trolley', 46)
    tr.box((0, 0, 0), (2.4, 1.6, 0.5), (0, 0, 0), C('white'))
    tr.boxb((0.6, 0, -1.3), (1.0, 1.2, 1.1), (0, 0, 0), C('white'))
    tr.box((1.12, 0, -0.8), (0.05, 0.9, 0.6), (0, 0, 0), C('glass_light'))
    tr.to_object('trolley', (0, 8.0, H - 0.1))

    sp = Model('spreader', 47)
    sp.box((0, 0, -0.15), (4.2, 1.4, 0.3), (0, 0, 0), C('yellow'))
    sp.box((0, 0, 0.1), (0.5, 0.5, 0.3), (0, 0, 0), C('dark'))
    for sx in (-1, 1):
        sp.box((sx * 1.95, 0, -0.15), (0.3, 1.5, 0.34), (0, 0, 0), C('dark'))
    sp.to_object('spreader', (0, 8.0, 4.0))
    return {'height': H, 'boom_y': [round(1.6 + y0, 2), round(1.6 + y1, 2)]}


def straddle():
    """Cavalier (T3) : portique orange sur roues, cabine blanche perchée, bandes jaune-noir."""
    m = Model('straddle', 48)
    for x in (-1.8, 1.8):
        for y in (-1.0, 1.0):
            m.boxb((x, y, 0.6), (0.3, 0.3, 4.4), (0, 0, 0), C('orange'))
        m.boxb((x, 0, 0), (0.5, 2.6, 0.6), (0, 0, 0), C('dark'))
        m.boxb((x, 0, 4.6), (0.5, 2.4, 0.5), (0, 0, 0), C('orange'))
        m.boxb((x, 0, 5.1), (0.6, 2.5, 0.08), (0, 0, 0), mul(C('orange'), 1.18))
        for sy in (-1, 1):
            m.cyl((x, sy * 1.0, 0.45), (0.45, 0.45, 0.4), (math.pi / 2, 0, 0), C('dark'), 8)
    for y in (-0.9, 0.9):
        m.boxb((0, y, 4.6), (3.6, 0.4, 0.5), (0, 0, 0), C('orange'))
        m.boxb((0, y, 5.1), (3.7, 0.5, 0.08), (0, 0, 0), mul(C('orange'), 1.18))
    m.box((0, -0.9, 4.85), (1.6, 0.42, 0.52), (0, 0, 0), C('hazard'))
    _cab(m, (1.8, -1.3, 4.0), (0.9, 0.8, 1.0), C('white'))
    m.box((0, 0, 1.2), (3.0, 1.3, 0.25), (0, 0, 0), C('yellow'))                    # palonnier
    tail_lights(m, -2.05, 1.0, 4.9)
    m.to_object()


def reach_stacker():
    """Gerbeur à mât télescopique (T2) : jaune, cabine sombre à toit clair, bras jaune, palonnier sombre."""
    m = Model('reach_stacker', 49)
    m.boxb((0, 0, 0.6), (5.0, 2.4, 1.2), (0, 0, 0), C('yellow'))
    m.boxb((0, 0, 1.8), (5.1, 2.5, 0.1), (0, 0, 0), mul(C('yellow'), 1.15))
    _wheels(m, (-1.6, 1.6), 1.05, 0.65, 0.65, 0.4)
    _cab(m, (-0.4, 0, 1.9), (1.2, 1.4, 1.5), C('dark'), roof=C('cap_light'))
    m.beam((-1.8, 0, 2.2), (3.5, 0, 4.4), 0.25, C('yellow'))
    m.box((3.6, 0, 4.0), (0.6, 3.6, 0.3), (0, 0, 0), C('dark'))
    hazard_band(m, '-y', -1.2, -1.6, 1.6, 0.65, 0.3)
    tail_lights(m, -2.5, 1.2, 1.3)
    emblem_beacon(m, -0.4, 0, 3.5, C('orange'), 0.7)
    m.to_object()


def rtg():
    """Portique de cour sur pneus (T3) : jaune, bandes jaune-noir sur les pieds, cabine blanche."""
    m = Model('rtg', 50)
    W, H = 9.0, 7.5
    for x in (-2.5, 2.5):
        for y in (-W / 2, W / 2):
            m.boxb((x, y, 0.5), (0.4, 0.4, H - 0.5), (0, 0, 0), C('yellow'))
            m.boxb((x, y, 0), (0.9, 0.8, 0.8), (0, 0, 0), C('dark'))
            m.boxb((x, y, 0.85), (0.46, 0.46, 0.3), (0, 0, 0), C('dark'))
            m.boxb((x, y, 1.15), (0.46, 0.46, 0.3), (0, 0, 0), C('hazard'))
            for sx in (-1, 1):
                m.cyl((x + sx * 0.3, y, 0.4), (0.4, 0.4, 0.3), (0, math.pi / 2, 0), C('dark'), 8)
    for y in (-W / 2, W / 2):
        m.boxb((0, y, H - 0.6), (5.4, 0.5, 0.7), (0, 0, 0), C('yellow'))
        m.boxb((0, y, H + 0.1), (5.5, 0.6, 0.08), (0, 0, 0), mul(C('yellow'), 1.15))
        m.boxb((0, y, 0.6), (5.4, 0.4, 0.4), (0, 0, 0), C('yellow'))
    for x in (-2.5, 2.5):
        m.box((x, 0, H - 0.2), (0.5, W, 0.5), (0, 0, 0), C('yellow'))
        m.box((x, 0, H + 0.09), (0.6, W + 0.2, 0.08), (0, 0, 0), mul(C('yellow'), 1.15))
    _cab(m, (0, 1.0, H - 1.8), (1.4, 1.2, 1.3), C('white'))
    m.box((0, 1.0, H - 0.5), (1.2, 2.0, 0.4), (0, 0, 0), C('dark'))                 # chariot
    emblem_beacon(m, 1.8, -W / 2, H + 0.15, C('orange'), 0.9)
    m.to_object()


def truck():
    """Camion : cabine (cab) rouge à toit clair + remorque porte-conteneur (trailer). Avant vers +X."""
    cab = Model('cab', 51)
    cab.boxb((0, 0, 0.45), (2.0, 2.2, 0.6), (0, 0, 0), C('dark'))
    cab.boxb((0.25, 0, 1.05), (1.5, 2.2, 1.6), (0, 0, 0), C('sign_red'))
    cab.box((1.01, 0, 2.0), (0.05, 1.8, 0.6), (0, 0, 0), C('glass_light'))
    cab.box((0.25, 0, 2.7), (1.6, 2.3, 0.12), (0, 0, 0), C('white'))
    cab.box((1.0, 0, 0.85), (0.1, 2.0, 0.3), (0, 0, 0), C('steel'))                # pare-chocs
    for s in (-1, 1):
        cab.box((1.02, s * 0.8, 1.1), (0.05, 0.25, 0.14), (0, 0, 0), C('yellow'))  # phares
    cab.cylb((-0.4, 0.95, 2.65), 0.08, 0.6, C('steel'), 5)                        # cheminée d'échappement
    _wheels(cab, (-0.5, 0.6), 0.9, 0.45, 0.45, 0.3)
    cab.to_object('cab', (2.4, 0, 0))

    tr = Model('trailer', 52)
    tr.boxb((0, 0, 0.75), (4.4, 1.6, 0.25), (0, 0, 0), C('dark'))
    tr.boxb((2.0, 0, 0.5), (0.6, 0.8, 0.25), (0, 0, 0), C('dark'))
    tr.box((-2.2, 0, 0.75), (0.08, 1.7, 0.3), (0, 0, 0), C('hazard'))
    tail_lights(tr, -2.2, 0.85, 0.95)
    _wheels(tr, (-1.7, -1.0), 0.75, 0.42, 0.42, 0.3)
    tr.to_object('trailer', (-0.6, 0, 0))
    return {'container_z': 1.0, 'container_x': -0.6}


def tractor():
    """Tracteur de terminal + châssis (T2) : jaune, cabine à toit clair, feux rouges."""
    m = Model('tractor', 53)
    m.boxb((2.2, 0, 0.4), (1.6, 2.0, 0.6), (0, 0, 0), C('yellow'))
    _cab(m, (2.5, 0, 1.0), (1.0, 1.8, 1.4), C('yellow'))
    m.box((3.0, 0, 0.7), (0.1, 1.9, 0.25), (0, 0, 0), C('dark'))
    m.boxb((-0.6, 0, 0.6), (4.2, 1.8, 0.25), (0, 0, 0), C('dark'))
    m.box((-2.7, 0, 0.72), (0.06, 1.85, 0.28), (0, 0, 0), C('hazard'))
    tail_lights(m, -2.7, 0.95, 0.9)
    _wheels(m, (-2.0, -1.2, 2.0, 2.8), 0.85, 0.4, 0.4, 0.3)
    emblem_beacon(m, 2.5, 0, 2.5, C('orange'), 0.7)
    m.to_object()


def forklift():
    """Chariot élévateur : orange, cabine sombre à toit clair, mât acier, feux rouges."""
    m = Model('forklift', 54)
    m.boxb((0, 0, 0.3), (2.2, 1.3, 0.9), (0, 0, 0), C('orange'))
    m.boxb((-0.4, 0, 1.2), (1.0, 1.1, 1.2), (0, 0, 0), C('dark'))
    m.boxb((-0.4, 0, 2.4), (1.2, 1.2, 0.1), (0, 0, 0), C('cap_light'))
    m.box((-1.1, 0, 0.9), (0.08, 1.2, 0.5), (0, 0, 0), C('dark'))                   # contrepoids
    for y in (-0.4, 0.4):
        m.boxb((1.3, y, 0), (0.12, 0.12, 2.6), (0, 0, 0), C('steel'))
        m.box((1.8, y, 0.15), (1.0, 0.15, 0.08), (0, 0, 0), C('steel'))
    _wheels(m, (-0.6, 0.7), 0.6, 0.3, 0.3, 0.25)
    tail_lights(m, -1.12, 0.6, 1.0)
    emblem_beacon(m, -0.4, 0, 2.5, C('orange'), 0.6)
    m.to_object()


def locomotive():
    """Locomotive : rouge à nez jaune, toit clair, bandes jaune-noir à l'avant, feux."""
    m = Model('locomotive', 55)
    m.boxb((0, 0, 0.6), (9.0, 2.4, 0.4), (0, 0, 0), C('dark'))
    m.boxb((-0.5, 0, 1.0), (7.0, 2.2, 2.0), (0, 0, 0), C('sign_red'))
    m.boxb((-0.5, 0, 3.0), (7.2, 2.3, 0.14), (0, 0, 0), C('cap_light'))
    m.boxb((3.5, 0, 1.0), (1.8, 2.4, 2.4), (0, 0, 0), C('yellow'))
    m.boxb((3.5, 0, 3.4), (1.9, 2.5, 0.12), (0, 0, 0), mul(C('yellow'), 1.15))
    m.box((4.42, 0, 2.8), (0.05, 1.8, 0.6), (0, 0, 0), C('glass_light'))
    m.box((4.42, 0, 1.4), (0.05, 2.2, 0.5), (0, 0, 0), C('dark'))
    for i in range(3):
        m.box((4.44, -0.7 + i * 0.7, 1.4), (0.04, 0.35, 0.5), (0, 0, 0), C('hazard'))
    m.box((4.46, 0, 2.2), (0.05, 0.3, 0.2), (0, 0, 0), C('yellow'))                  # phare
    m.boxb((-0.5, 0, 3.14), (3.0, 1.2, 0.2), (0, 0, 0), C('steel'))
    m.cylb((1.5, 0, 3.3), 0.2, 0.3, C('dark'), 8)
    for x in (-3.2, -2.2, 2.2, 3.2):
        for s in (-1, 1):
            m.cyl((x, s * 1.0, 0.45), (0.45, 0.45, 0.2), (math.pi / 2, 0, 0), C('steel'), 8)
    tail_lights(m, -4.5, 1.2, 1.5)
    m.to_object()


def wagon():
    """Wagon porte-conteneurs : châssis gris acier, cornières jaunes."""
    m = Model('wagon', 56)
    m.boxb((0, 0, 0.6), (9.0, 2.2, 0.35), (0, 0, 0), C('hull_grey'))
    for x in (-2.1, 2.1):
        for sx in (-1, 1):
            m.boxb((x + sx * 1.9, 0, 0.95), (0.2, 2.0, 0.08), (0, 0, 0), C('yellow'))
    for x in (-3.4, -2.6, 2.6, 3.4):
        for s in (-1, 1):
            m.cyl((x, s * 0.95, 0.42), (0.42, 0.42, 0.2), (math.pi / 2, 0, 0), C('steel'), 8)
    m.to_object()
    return {'container_z': 0.95, 'slots_x': [-2.1, 2.1]}


def tug():
    """Remorqueur : coque rouge à liston noir, château blanc à toit clair, cheminée rouge à bande noire, pneus."""
    m = Model('tug', 57)
    m.hull(8.0, 3.2, 2.0, 0.3, 0.05, (0, 0, -0.9), C('hull_red'), C('dark'), 0.45, C('deck'))
    m.boxb((0.2, 0, 1.1), (3.0, 2.2, 1.4), (0, 0, 0), C('white'))
    m.boxb((0.6, 0, 2.5), (1.8, 1.8, 1.0), (0, 0, 0), C('white'))
    m.boxb((0.6, 0, 3.5), (2.0, 2.0, 0.12), (0, 0, 0), C('cap_light'))
    m.box((1.52, 0, 3.0), (0.05, 1.4, 0.5), (0, 0, 0), C('glass_light'))
    m.cylb((-0.6, 0, 2.5), 0.3, 1.2, C('sign_red'), 8)
    m.cylb((-0.6, 0, 3.4), 0.32, 0.3, C('dark'), 8)
    m.cylb((0.6, 0, 3.62), 0.05, 0.9, C('steel'), 4)
    for x in (-3, -1.5, 0, 1.5):
        for s in (-1, 1):
            m.cyl((x, s * 1.65, 0.8), (0.35, 0.35, 0.3), (math.pi / 2, 0, 0), C('dark'), 8)
    m.cylb((2.6, 0, 1.1), 0.1, 1.2, C('yellow'), 5)
    m.to_object()


def pilot_boat():
    """Pilotine : coque orange à bande sombre, cabine blanche à toit clair, mât."""
    m = Model('pilot_boat', 58)
    m.hull(6.0, 2.2, 1.4, 0.35, 0.05, (0, 0, -0.5), C('dark'), C('hull_orange'), 0.4, C('white'))
    m.boxb((-0.2, 0, 0.9), (2.0, 1.6, 1.0), (0, 0, 0), C('white'))
    m.boxb((-0.2, 0, 1.9), (2.2, 1.8, 0.1), (0, 0, 0), C('cap_light'))
    m.box((0.82, 0, 1.5), (0.05, 1.2, 0.4), (0, 0, 0), C('glass_light'))
    m.box((-0.2, 0, 2.1), (1.0, 0.2, 0.2), (0, 0, 0), C('sign_red'))
    m.cylb((-0.6, 0, 2.0), 0.04, 1.0, C('steel'), 4)
    m.to_object()


def van():
    """Fourgon blanc à bande marine, toit clair, feux rouges."""
    m = Model('van', 59)
    m.boxb((0, 0, 0.35), (3.2, 1.6, 1.5), (0, 0, 0), C('white'))
    m.boxb((0, 0, 1.85), (3.0, 1.5, 0.1), (0, 0, 0), C('cap_light'))
    m.box((1.61, 0, 1.3), (0.05, 1.3, 0.5), (0, 0, 0), C('glass_light'))
    m.box((0, -0.81, 1.0), (2.0, 0.04, 0.3), (0, 0, 0), C('navy'))
    m.box((0, 0.81, 1.0), (2.0, 0.04, 0.3), (0, 0, 0), C('navy'))
    _wheels(m, (-1.0, 1.0), 0.75, 0.32, 0.32, 0.25)
    tail_lights(m, -1.6, 0.8, 0.9)
    m.to_object()


ASSETS = {
    'crane_mobile': crane_mobile, 'crane_sts': crane_sts, 'straddle': straddle, 'reach_stacker': reach_stacker,
    'rtg': rtg, 'truck': truck, 'tractor': tractor, 'forklift': forklift, 'locomotive': locomotive, 'wagon': wagon,
    'tug': tug, 'pilot_boat': pilot_boat, 'van': van,
}
