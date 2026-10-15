# Lot F — forêt et golfe (docs/ORDRE_BLENDER_F.md § 2, docs/PLAN_LOT_F.md F-D3) : la carte s'arrête sur une forêt dense
# où la route entre sous les arbres, et la rive d'en face ferme le golfe au large.
# Repère Blender : X = longueur, Y = profondeur (-Y = côté caméra / port), Z = haut ; origine au sol.
import math
import bmesh
from mathutils import Matrix
from lib import Model
from palette import C


def _pine_crowns(m, crowns):
    for p, s, c, sub in crowns:
        m.ico(p, s, (0, 0, m.rnd.uniform(0, 3)), C(c), sub, 0.25)


def tree_pine():
    """Pin maritime : tronc rouge-brun penché et nu, couronne en parasol large et plate (vert pin, dessous sombre)."""
    m = Model('tree_pine', 240)
    m.cylb((0, 0, 0), 0.24, 0.15, C('earth_dark'), 6)
    m.tube((0, 0, 0), (0.35, 0.1, 2.7), 0.17, C('rust'), 6)
    m.tube((0.35, 0.1, 2.7), (0.8, 0.2, 4.4), 0.13, C('rust'), 6)
    m.tube((0.45, 0.12, 3.1), (-0.5, -0.25, 4.1), 0.08, C('rust'), 5)
    _pine_crowns(m, (((0.85, 0.2, 4.75), (1.95, 1.65, 0.62), 'pine', 2),
                     ((-0.55, -0.25, 4.3), (1.05, 0.95, 0.45), 'pine_dark', 2),
                     ((1.6, 0.75, 4.4), (0.95, 0.85, 0.42), 'pine_dark', 0),
                     ((0.6, 0.0, 5.2), (1.05, 0.95, 0.36), 'pine', 0)))
    m.to_object()


def tree_pine_b():
    """Pin maritime, deuxième silhouette : plus haut et élancé, tronc en S, couronne étagée en trois nuages décalés."""
    m = Model('tree_pine_b', 241)
    m.cylb((0, 0, 0), 0.22, 0.15, C('earth_dark'), 6)
    pts = ((0, 0, 0), (-0.25, 0, 2.1), (0.1, 0.1, 4.1), (0.5, 0.1, 5.8))
    for a, b, r in zip(pts, pts[1:], (0.16, 0.13, 0.1)):
        m.tube(a, b, r, C('rust'), 6)
    m.tube((-0.15, 0.05, 3.2), (-1.0, -0.1, 4.0), 0.07, C('rust'), 5)
    _pine_crowns(m, (((0.45, 0.1, 6.0), (1.45, 1.25, 0.55), 'pine', 2),
                     ((0.95, -0.2, 5.15), (0.85, 0.75, 0.38), 'pine_dark', 2),
                     ((-1.05, -0.1, 4.15), (0.9, 0.8, 0.38), 'pine_dark', 0),
                     ((0.25, 0.25, 6.55), (0.75, 0.65, 0.32), 'pine', 0)))
    m.to_object()


def tree_oak():
    """Feuillu rond (chêne) : tronc court et trapu, deux branches, houppier en boule de quatre masses (clair dessus,
    sombre dessous)."""
    m = Model('tree_oak', 242)
    m.cylb((0, 0, 0), 0.3, 1.6, C('earth_dark'), 6, 0.8)
    m.tube((0, 0, 1.4), (0.65, 0.2, 2.5), 0.12, C('earth_dark'), 5)
    m.tube((0, 0, 1.4), (-0.55, -0.15, 2.4), 0.12, C('earth_dark'), 5)
    for p, s, c in (((0, 0, 3.1), (1.9, 1.8, 1.45), 'grass_dark'), ((0.95, -0.6, 2.6), (1.0, 0.9, 0.8), 'pine'),
                    ((-1.0, 0.5, 2.7), (1.0, 0.9, 0.8), 'pine'), ((0.2, -0.25, 3.95), (1.1, 1.0, 0.7), 'grass')):
        m.ico(p, s, (0, 0, m.rnd.uniform(0, 3)), C(c), 2, 0.15)
    m.to_object()


def forest_block():
    """Massif forestier dense ≈ 20 × 20 u pour la lisière : sous-bois sombre à bord irrégulier, une quinzaine d'arbres
    fusionnés (pins en parasol, feuillus, quelques sapins), canopée de remplissage sombre au centre (on ne voit pas à
    travers). Hauteur 4,5 à 6,5 u."""
    m = Model('forest_block', 243)
    n = 16
    rad = [9.4 + m.rnd.uniform(-1.6, 0.8) for _ in range(n)]
    pts = [(math.cos(i * math.tau / n) * rad[i], math.sin(i * math.tau / n) * rad[i]) for i in range(n)]
    m.prism(pts, -0.05, 0.05, C('pine_dark'))

    def r_at(a):
        i = int((a % math.tau) / (math.tau / n))
        return min(rad[i], rad[(i + 1) % n])

    trees = []
    for gx in (-7.0, -2.4, 2.4, 7.0):
        for gy in (-7.0, -2.4, 2.4, 7.0):
            x, y = gx + m.rnd.uniform(-1.2, 1.2), gy + m.rnd.uniform(-1.2, 1.2)
            if math.hypot(x, y) < r_at(math.atan2(y, x)) - 1.6:
                trees.append((x, y))
    crown_c = ('pine', 'pine_dark', 'grass_dark', 'pine')
    for i, (x, y) in enumerate(trees):
        kind = i % 5
        ht = m.rnd.uniform(1.8, 2.8)
        if kind == 4:                                                                       # sapin
            m.cylb((x, y, 0), 0.2, 1.0, C('earth_dark'), 5)
            for j, (r, z, h) in enumerate(((1.7, 0.8, 2.4), (1.25, 2.4, 2.2), (0.8, 3.9, 1.9))):
                m.cyl((x, y, z + h / 2), (r, r, h), (0, 0, j * 0.4), C('pine') if j % 2 == 0 else C('pine_dark'), 7, 0.0)
            continue
        pine = kind in (0, 3)
        m.cylb((x, y, 0), 0.2, ht + 0.6, C('rust') if pine else C('earth_dark'), 5)
        sx = m.rnd.uniform(2.2, 2.9)
        sz = 0.9 if pine else 1.6
        m.ico((x, y, ht + sz + 0.3), (sx, sx * 0.9, sz), (0, 0, m.rnd.uniform(0, 3)), C(crown_c[kind]), 2, 0.2)
        m.ico((x + 0.9, y - 0.6, ht + 0.5), (1.3, 1.1, sz * 0.6), (0, 0, 0), C('pine_dark'), 0, 0.2)
    for k in range(9):                                                                    # canopée de remplissage
        a = k * math.tau / 9 + 0.3
        r = 2.0 + (k % 3) * 2.0
        m.ico((math.cos(a) * r, math.sin(a) * r, 3.8 + (k % 2) * 0.8), (3.0, 2.8, 1.6), (0, 0, a), C('pine_dark'), 0, 0.2)
    m.to_object()
    return {'trees': len(trees)}


def forest_road():
    """Entrée de route sous les arbres : chaussée de 6 u (axe Y, 14 u de long) qui part ouverte côté -Y et s'enfonce vers
    +Y sous une voûte de feuillage, de plus en plus sombre, jusqu'à un fond noir où la route disparaît. Deux rangées de
    troncs de chaque côté, balises blanches et rouges à l'entrée. Le trafic apparaît / disparaît vers y = +6 (fond)."""
    m = Model('forest_road', 244)
    m.boxb((0, 0, 0), (14.0, 14.0, 0.03), (0, 0, 0), C('pine_dark'))
    for i, c in enumerate(('asphalt_violet', 'asphalt_violet', 'asphalt_violet_shadow', 'plinth')):
        m.boxb((0, -7 + 1.75 + i * 3.5, 0.03), (6.0, 3.5, 0.04), (0, 0, 0), C(c))
    for y, c in ((-6.2, 'marking_thick'), (-4.2, 'marking_thick'), (-2.2, 'marking_thick'), (-0.2, 'kerb')):
        m.box((0, y, 0.08), (0.26, 1.2, 0.02), (0, 0, 0), C(c))
    for s in (-1, 1):
        m.boxb((s * 3.1, -4.8, 0.03), (0.22, 4.4, 0.12), (0, 0, 0), C('kerb'))
        for y in (-6.3, -3.6):                                                             # balises
            m.boxb((s * 3.5, y, 0), (0.14, 0.14, 1.0), (0, 0, 0), C('white'))
            m.boxb((s * 3.5, y - 0.005, 0.72), (0.16, 0.16, 0.16), (0, 0, 0), C('sign_red'))
    # troncs : deux rangées par côté, plus sombres au fond
    for s in (-1, 1):
        for j, y in enumerate((-5.2, -2.8, -0.4, 2.0, 4.4, 6.4)):
            for xr, dy in ((3.95, 0.0), (5.6, 1.1)):
                yy = min(6.6, y + dy)
                col = 'earth_dark' if yy < 0.5 else 'plinth'
                m.cylb((s * (xr + m.rnd.uniform(-0.25, 0.25)), yy, 0), 0.22, 4.3, C(col), 5)
    # parois sombres derrière les troncs et fond noir où la route disparaît
    for s in (-1, 1):
        m.boxb((s * 4.9, 2.6, 0), (0.15, 8.8, 4.6), (0, 0, 0), C('pine_dark'))
    m.boxb((0, 6.9, 0), (10.0, 0.2, 5.4), (0, 0, 0), C('dark'))
    # voûte de feuillage
    for y in (-2.6, 0.5, 3.5, 6.3):
        for s in (-1, 1):
            m.ico((s * 4.1, y, 4.6), (2.6, 2.0, 2.2), (0, 0, m.rnd.uniform(0, 3)), C('pine'), 2, 0.15)
            m.ico((s * 6.3, y + 0.8, 2.7), (1.6, 1.8, 1.6), (0, 0, 0), C('pine_dark'), 0, 0.2)
        m.ico((0, y + 0.3, 5.8), (4.2, 2.3, 1.6), (0, 0, m.rnd.uniform(0, 3)), C('pine' if y < 0 else 'pine_dark'), 2, 0.15)
    m.to_object()
    return {'road_width': 6.0, 'road_y': [-7.0, 7.0], 'vanish_y_godot': -6.0}


def _band_strip(m, xs, rows, cols):
    """Bande de terrain : grille de sommets (x ∈ xs, une rangée (y, z(x)) par ligne), faces vers le haut ;
    cols[k] = couleur de la bande entre les rangées k et k+1."""
    b = bmesh.new()
    grid = [[b.verts.new((x, y, zf(x))) for x in xs] for (y, zf) in rows]
    for r in range(len(rows) - 1):
        for i in range(len(xs) - 1):
            b.faces.new([grid[r][i], grid[r][i + 1], grid[r + 1][i + 1], grid[r + 1][i]])
    ys = [y for y, _ in rows]

    def col(x, y, z):
        for k in range(len(ys) - 1):
            if y <= ys[k + 1]:
                return cols[k]
        return cols[-1]
    m._add(b, Matrix.Identity(4), col)


def far_shore():
    """Rive d'en face (silhouette très simple, à poser à 300 u et plus, face vers -Y = vers le port) : plage claire,
    collines basses vert d'eau, seconde chaîne bleutée derrière (profondeur), village de toits colorés et son clocher dans
    un creux, cap à l'est avec un petit phare blanc à lanterne rouge et sa maison de gardien. 260 × 60 u."""
    m = Model('far_shore', 245)
    X = 130.0

    def env(x):
        return max(0.0, min(1.0, (X - abs(x)) / 18.0))

    def h1(x):
        h = 9 + 4.5 * math.sin(x / 23) + 3 * math.sin(x / 9 + 1.3) + 1.5 * math.sin(x / 4.7)
        if -52 < x < -8:
            h *= 0.3                                                                       # creux du village
        if 92 < x < 116:
            h = 7.0                                                                        # cap du phare
        return max(1.5, h) * env(x)

    def h2(x):
        return (17 + 6 * math.sin(x / 31 + 0.5) + 4 * math.sin(x / 13)) * env(x)

    xs = [-X + i * 5.0 for i in range(53)]
    _band_strip(m, xs, [(-34, lambda x: -2.0), (-31, lambda x: 0.5 * env(x)), (-28, lambda x: 1.2 * env(x)),
                        (-18, lambda x: 0.55 * h1(x)), (-6, h1), (8, lambda x: 0.3 * h1(x)), (16, lambda x: -2.0)],
                [C('sand_warm'), C('sand_warm'), C('grass_dark'), C('net_green'), C('net_green'), C('net_green')])
    xs2 = [-X + i * 10.0 for i in range(27)]
    _band_strip(m, xs2, [(-4, lambda x: 0.6 * h2(x)), (14, h2), (34, lambda x: -2.0)], [C('clad_steel'), C('clad_steel')])
    # village dans le creux
    houses = ((-46, C('wood_cream'), C('falun')), (-40, C('white'), C('roof_b_blue')), (-35, C('falun'), C('rust')),
              (-29, C('wood_cream'), C('navy')), (-24, C('white'), C('falun')), (-18, C('sand_warm'), C('roof_b_blue')),
              (-13, C('wood_cream'), C('rust')))
    for i, (x, wall, roof) in enumerate(houses):
        y = -25.5 + (i % 3) * 2.2
        hh = 2.2 + (i % 2) * 0.8
        m.boxb((x, y, -0.5), (3.2, 2.6, hh + 1.7), (0, 0, 0), wall)
        m.prism_x([(y - 1.6, hh + 1.1), (y + 1.6, hh + 1.1), (y, hh + 2.9)], x - 1.85, x + 1.85, roof)
    # clocher
    m.boxb((-31.5, -21.5, -0.5), (2.2, 2.2, 7.5), (0, 0, 0), C('white'))
    m.cyl((-31.5, -21.5, 7.0 + 1.4), (1.6, 1.6, 2.8), (0, 0, math.pi / 4), C('navy'), 4, 0.0)
    m.boxb((-31.5, -26.5, -1.0), (1.2, 6.0, 1.2), (0, 0, 0), C('wood'))                      # jetée du village
    # cap et phare
    lx, ly = 104.0, -14.0
    m.cylb((lx, ly, 2.0), 3.0, 3.6, C('rock'), 7)
    m.cylb((lx, ly, 5.6), 1.0, 9.0, C('white'), 8, 0.75)
    m.cylb((lx, ly, 9.4), 0.92, 1.4, C('sign_red'), 8)
    m.cylb((lx, ly, 14.6), 0.95, 0.25, C('white'), 8)
    m.cylb((lx, ly, 14.85), 0.6, 0.9, C('yellow'), 8)
    m.cyl((lx, ly, 16.2), (0.85, 0.85, 0.9), (0, 0, 0), C('sign_red'), 8, 0.0)
    m.boxb((lx - 4.0, ly + 0.5, 3.5), (3.4, 2.6, 3.4), (0, 0, 0), C('white'))
    m.prism_x([(ly + 0.5 - 1.5, 6.8), (ly + 0.5 + 1.5, 6.8), (ly + 0.5, 8.3)], lx - 5.9, lx - 2.1, C('falun'))
    m.to_object()
    return {'lighthouse': [lx, 16.6, -ly], 'span': [2 * X, 50.0]}


ASSETS = {
    'tree_pine': tree_pine, 'tree_pine_b': tree_pine_b, 'tree_oak': tree_oak, 'forest_block': forest_block,
    'forest_road': forest_road, 'far_shore': far_shore,
}
