# Terrain : dalles de diorama 6×6 (terre en couches), quai 12 u, routes, rails, décor du littoral.
# Repère Blender : X = longueur, Y = profondeur (+Y = côté mer), Z = haut. Le dessus des dalles est en z = 0.
# Direction D (docs/ETUDE_STYLE.md § 3) : asphalte violet sombre à marquages épais clairs pour le terminal et les routes,
# béton chaud à bordure sombre pour le quai, sable chaud pour le T1, herbe moyenne ; accessoires ×1,35.
import math
from lib import Model, V, mix, mul, bollard, emblem_life_ring, SCALE_PROPS
from palette import C


def _layers(m, top, w=6.0, d=6.0, depth=2.4, bevel=0.12, top_th=0.35):
    """Dalle à couches : dessus coloré, puis terre claire et foncée (bords visibles du diorama)."""
    m.cham((0, 0, -depth), (w, d, depth - 1.15), bevel, C('earth_dark'))
    m.cham((0, 0, -1.15), (w, d, 1.15 - top_th), bevel, C('earth'))
    m.cham((0, 0, -top_th), (w, d, top_th), bevel, top)


def ground_gravel():
    """Terre-plein du Vieux Quai : sable chaud à quelques plaques plus foncées."""
    m = Model('ground_gravel', 3)
    _layers(m, C('sand_warm'))
    for i in range(5):
        x, y = m.rnd.uniform(-2.5, 2.5), m.rnd.uniform(-2.5, 2.5)
        m.box((x, y, 0.01), (m.rnd.uniform(0.4, 0.9), m.rnd.uniform(0.3, 0.7), 0.04), (0, 0, m.rnd.uniform(0, 3)), C('gravel'))
    m.to_object()


def ground_asphalt():
    """Terminal : asphalte violet sombre, marquages épais clairs (travées)."""
    m = Model('ground_asphalt', 4)
    _layers(m, C('asphalt_violet'))
    for i in range(3):
        x = -2 + i * 2
        m.box((x, 0, 0.012), (0.22, 5.4, 0.03), (0, 0, 0), C('marking_thick'))
    m.to_object()


def ground_grass():
    m = Model('ground_grass', 5)
    _layers(m, C('grass'))
    for i in range(4):
        x, y = m.rnd.uniform(-2.6, 2.6), m.rnd.uniform(-2.6, 2.6)
        m.ico((x, y, 0.04), (0.4, 0.4, 0.16), (0, 0, 0), C('grass_dark'), 0)
    m.to_object()


def ground_sand():
    m = Model('ground_sand', 6)
    _layers(m, C('sand'), top_th=0.3)
    m.to_object()


def _fender(m, x, y, z=-0.9, s=1.0):
    """Défense pneu noir suspendue au mur de quai (+Y), chaîne."""
    m.cyl((x, y, z), (0.55 * s, 0.55 * s, 0.4 * s), (math.pi / 2, 0, 0), C('dark'), 10)
    m.cyl((x, y, z), (0.3 * s, 0.3 * s, 0.42 * s), (math.pi / 2, 0, 0), C('plinth'), 8)
    m.tube((x, y - 0.1, z + 0.5 * s), (x, y - 0.3, 0.1), 0.04, C('steel'), 4)


def quay():
    """Segment de quai 12 × 6 : béton chaud, bordure sombre, ligne de sécurité jaune, rails de portique, bollards ×1,35,
    défenses, échelle de quai."""
    m = Model('quay', 7)
    w, d = 12.0, 6.0
    m.boxb((0, 0, -3.4), (w, d, 3.4), (0, 0, 0), C('concrete_dark'))           # corps du quai (descend sous l'eau)
    m.boxb((0, 0, -0.3), (w, d, 0.3), (0, 0, 0), C('apron_warm'))              # dalle
    m.boxb((0, d / 2 - 0.3, -0.3), (w, 0.6, 0.3), (0, 0, 0), C('asphalt_dark'))   # bordure sombre côté mer
    m.box((0, d / 2 - 0.85, 0.01), (w, 0.26, 0.03), (0, 0, 0), C('mark_yellow'))  # ligne de sécurité
    m.boxb((0, d / 2 - 0.06, 0.0), (w, 0.12, 0.22), (0, 0, 0), C('plinth'))       # chasse-roue
    for i in range(3):
        bollard(m, -4 + i * 4, d / 2 - 0.6)
    for i in range(4):
        _fender(m, -4.5 + i * 3, d / 2 + 0.3)
    # échelle de quai
    for s in (-1, 1):
        m.boxb((1.8 + s * 0.25, d / 2 + 0.12, -1.6), (0.08, 0.08, 1.9), (0, 0, 0), C('steel'))
    for k in range(5):
        m.box((1.8, d / 2 + 0.12, -1.4 + k * 0.35), (0.5, 0.06, 0.06), (0, 0, 0), C('steel'))
    # rails de portique : bande sombre et deux rails acier
    for y in (-1.6, 1.6):
        m.box((0, y, 0.005), (w, 0.6, 0.012), (0, 0, 0), C('asphalt_dark'))
        for dy in (-0.14, 0.14):
            m.box((0, y + dy, 0.03), (w, 0.1, 0.06), (0, 0, 0), C('steel'))
    m.to_object()


def quay_end():
    """Musoir de fin de quai (bloc de 6 × 6 avec enrochement)."""
    m = Model('quay_end', 8)
    m.boxb((0, 0, -3.4), (6, 6, 3.4), (0, 0, 0), C('concrete_dark'))
    m.boxb((0, 0, -0.3), (6, 6, 0.3), (0, 0, 0), C('apron_warm'))
    m.boxb((0, 2.7, -0.3), (6, 0.6, 0.3), (0, 0, 0), C('asphalt_dark'))
    m.box((0, 2.15, 0.01), (6, 0.26, 0.03), (0, 0, 0), C('mark_yellow'))
    for i in range(6):
        m.ico((m.rnd.uniform(-2.8, 2.8), 3.4 + m.rnd.uniform(0, 0.6), -1.6), (0.9, 0.8, 0.7), (0, 0, m.rnd.uniform(0, 3)), C('rock'), 0, 0.3)
    bollard(m, 0, 2.3)
    m.to_object()


def road():
    """Route : asphalte violet sombre, ligne axiale épaisse claire, bordures de trottoir claires."""
    m = Model('road', 9)
    _layers(m, C('asphalt_violet'))
    for i in range(3):
        m.box((-2 + i * 2, 0, 0.012), (1.2, 0.26, 0.03), (0, 0, 0), C('marking_thick'))
    for y in (-2.85, 2.85):
        m.box((0, y, 0.06), (6, 0.3, 0.14), (0, 0, 0), C('sidewalk'))
    m.to_object()


def rail():
    m = Model('rail', 10)
    m.boxb((0, 0, -0.05), (6, 2.6, 0.2), (0, 0, 0), C('gravel_dark'))
    for i in range(8):
        m.boxb((-2.6 + i * 0.75, 0, 0.15), (0.3, 2.0, 0.1), (0, 0, 0), C('wood'))
    for y in (-0.6, 0.6):
        m.boxb((0, y, 0.25), (6, 0.12, 0.12), (0, 0, 0), C('steel'))
    m.to_object()


def rock():
    m = Model('rock', 11)
    m.ico((0, 0, 0.3), (1.2, 1.0, 0.9), (0, 0, 0.4), C('rock'), 1, 0.35)
    m.ico((0.9, 0.5, 0.1), (0.6, 0.5, 0.5), (0, 0, 1.0), C('rock_dark'), 0, 0.3)
    m.to_object()


def tree():
    """Sapin à facettes (cônes empilés)."""
    m = Model('tree', 12)
    m.cylb((0, 0, 0), 0.22, 0.9, C('earth_dark'), 6)
    for i, (r, z, h) in enumerate([(1.4, 0.7, 1.6), (1.1, 1.6, 1.4), (0.75, 2.4, 1.3)]):
        col = C('pine') if i % 2 == 0 else C('pine_dark')
        m.cyl((0, 0, z + h / 2), (r, r, h), (0, 0, i * 0.4), col, 7, 0.0)
    m.to_object()


def bush():
    m = Model('bush', 13)
    m.ico((0, 0, 0.35), (0.8, 0.7, 0.55), (0, 0, 0), C('grass_dark'), 1, 0.3)
    m.ico((0.5, 0.3, 0.3), (0.5, 0.45, 0.4), (0, 0, 0), C('grass'), 0, 0.3)
    m.to_object()


def lighthouse():
    """Phare T1 (B, rouge) : socle de rocher, fût rayé rouge / blanc, galerie à garde-corps, lanterne vitrée à meneaux
    blancs, chapeau rouge, porte rouge et bouée au pied."""
    m = Model('lighthouse', 14)
    m.cylb((0, 0, 0), 2.4, 0.8, C('rock'), 9)
    m.cylb((0, 0, 0.8), 1.6, 0.25, C('kerb'), 10)
    rings = 5
    for i in range(rings):
        r0 = 1.3 - i * 0.12
        m.cylb((0, 0, 1.05 + i * 1.3), r0, 1.3, C('white') if i % 2 == 0 else C('sign_red'), 10, (r0 - 0.12) / r0)
    top = 1.05 + rings * 1.3
    m.cylb((0, 0, top), 1.15, 0.22, C('white'), 10)                                     # galerie
    for i in range(10):
        a = i * math.tau / 10
        m.cylb((math.cos(a) * 1.05, math.sin(a) * 1.05, top + 0.22), 0.04, 0.6, C('wood_trim'), 4)
    m.cylb((0, 0, top + 0.78), 1.1, 0.06, C('wood_trim'), 10)
    m.cylb((0, 0, top + 0.22), 0.72, 1.1, C('glass_light'), 8)                          # lanterne
    for i in range(8):
        a = i * math.tau / 8
        m.cylb((math.cos(a) * 0.72, math.sin(a) * 0.72, top + 0.22), 0.05, 1.1, C('wood_trim'), 4)
    m.cylb((0, 0, top + 0.55), 0.3, 0.45, C('yellow'), 8)                               # optique
    m.cylb((0, 0, top + 1.32), 0.95, 0.12, C('sign_red'), 10)
    m.cyl((0, 0, top + 1.44 + 0.4), (0.85, 0.85, 0.8), (0, 0, 0), C('sign_red'), 8, 0.0)
    m.ico((0, 0, top + 2.3), (0.12, 0.12, 0.12), (0, 0, 0), C('dark'), 0)
    m.boxb((0, -1.32, 1.05), (0.8, 0.1, 1.5), (0, 0, 0), C('sign_red'))                  # porte
    m.boxb((0, -1.36, 1.05), (1.0, 0.08, 0.08), (0, 0, 0), C('wood_trim'))
    for s in (-1, 1):
        m.boxb((s * 0.45, -1.36, 1.05), (0.08, 0.08, 1.55), (0, 0, 0), C('wood_trim'))
    m.boxb((0, -1.36, 2.6), (1.0, 0.08, 0.08), (0, 0, 0), C('wood_trim'))
    m.box((0, -1.18, 4.3), (0.5, 0.08, 0.6), (0, 0, 0), C('glass_light'))                # fenêtre
    emblem_life_ring(m, (1.0, -0.95, 1.9), 0.36, '-y')
    m.to_object()


def lamp():
    """Lampadaire ×1,35 : mât acier, crosse, lanterne jaune."""
    m = Model('lamp', 15)
    s = SCALE_PROPS
    m.cylb((0, 0, 0), 0.22 * s, 0.12, C('dark'), 8)
    m.cylb((0, 0, 0.12), 0.11 * s, 4.4 * s, C('steel'), 6)
    m.box((0.5 * s, 0, 4.5 * s), (1.1 * s, 0.16 * s, 0.14 * s), (0, 0, 0), C('steel'))
    m.box((0.95 * s, 0, 4.38 * s), (0.5 * s, 0.34 * s, 0.14 * s), (0, 0, 0), C('cap_light'))
    m.box((0.95 * s, 0, 4.28 * s), (0.42 * s, 0.28 * s, 0.08 * s), (0, 0, 0), C('yellow'))
    m.to_object()


def fence():
    """Clôture de 6 u : poteaux acier à pied sombre, lisses, grillage."""
    m = Model('fence', 16)
    for i in range(4):
        m.cylb((-3 + i * 2, 0, 0), 0.07, 1.6, C('steel'), 5)
        m.boxb((-3 + i * 2, 0, 0), (0.2, 0.2, 0.2), (0, 0, 0), C('dark'))
    for z in (0.3, 1.5):
        m.box((0, 0, z), (6, 0.05, 0.07), (0, 0, 0), C('steel'))
    m.box((0, 0, 0.9), (6, 0.02, 1.15), (0, 0, 0), C('rock'))
    m.to_object()


def _buoy(name, seed, c):
    """Bouée de chenal ×1,35 : flotteur conique coloré, voyant, feu."""
    m = Model(name, seed)
    s = SCALE_PROPS
    m.cyl((0, 0, 0.1), (0.6 * s, 0.6 * s, 0.7 * s), (0, 0, 0), c, 8, 0.7)
    m.cylb((0, 0, 0.45 * s), 0.12 * s, 1.0 * s, C('dark'), 5)
    m.cyl((0, 0, 1.35 * s), (0.3 * s, 0.3 * s, 0.35 * s), (0, 0, 0), c, 4, 0.0)
    m.ico((0, 0, 1.62 * s), (0.2 * s, 0.2 * s, 0.2 * s), (0, 0, 0), C('yellow'), 0)
    m.to_object()


def buoy():
    _buoy('buoy', 17, C('sign_red'))


def buoy_green():
    _buoy('buoy_green', 18, C('green'))


ASSETS = {
    'ground_gravel': ground_gravel, 'ground_asphalt': ground_asphalt, 'ground_grass': ground_grass, 'ground_sand': ground_sand,
    'quay': quay, 'quay_end': quay_end, 'road': road, 'rail': rail, 'rock': rock, 'tree': tree, 'bush': bush,
    'lighthouse': lighthouse, 'lamp': lamp, 'fence': fence, 'buoy': buoy, 'buoy_green': buoy_green,
}
