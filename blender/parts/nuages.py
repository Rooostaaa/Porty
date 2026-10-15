# Lot G — les nuages (docs/ORDRE_BLENDER_G.md § 2, docs/CADRAGE_DEBUT.md § 5.1 et § 12 Q5) : le verrou visuel qui cache
# le reste de la carte jusqu'à la Concession. Le jeu pose plusieurs bancs, les fait dériver et les dissout par shader
# (fondu + montée) : couleur de sommet uniforme (une seule teinte à gérer), face du dessous plate, aucune face intérieure.
# Construction : un seul maillage par nuage = champ de hauteur (dômes en grappe) sur une grille, bord rabattu à z = 0 sur
# le contour de l'union des dômes, puis une face de dessous unique sur ce contour.
# Repère Blender : origine au centre de la face du dessous (z = 0), X = longueur, Y = profondeur.
import math
import bmesh
from mathutils import Matrix
from lib import Model
from palette import C


def _cloud(m, bumps, cell, c, size=None):
    """bumps = [(cx, cy, rayon, hauteur)] : dômes elliptiques (profil en demi-ellipse) dont l'union fait le nuage.
    size = (L, l, h) : le maillage fini est ramené exactement à ces cotes (module du jeu)."""
    x0 = min(b[0] - b[2] for b in bumps) - cell
    x1 = max(b[0] + b[2] for b in bumps) + cell
    y0 = min(b[1] - b[2] for b in bumps) - cell
    y1 = max(b[1] + b[2] for b in bumps) + cell
    nx, ny = int(math.ceil((x1 - x0) / cell)), int(math.ceil((y1 - y0) / cell))

    def height(x, y):
        h = 0.0
        for bx, by, r, hh in bumps:
            d = math.hypot(x - bx, y - by) / r
            if d < 1.0:
                h = max(h, hh * math.sqrt(1.0 - d * d))
        return h

    def snap(x, y):
        """Point extérieur ramené sur le contour de l'union (le cercle le plus proche)."""
        best, bp = 1e9, (x, y)
        for bx, by, r, hh in bumps:
            d = math.hypot(x - bx, y - by)
            if d - r < best:
                best = d - r
                bp = (bx + (x - bx) / d * r, by + (y - by) / d * r) if d > 1e-6 else (bx + r, by)
        return bp

    b = bmesh.new()
    pts = {}
    inside = {}
    for i in range(nx + 1):
        for j in range(ny + 1):
            x, y = x0 + i * cell, y0 + j * cell
            h = height(x, y)
            inside[(i, j)] = h > 0.02
            pts[(i, j)] = (x, y, h)
    verts = {}

    def vert(i, j):
        if (i, j) not in verts:
            x, y, h = pts[(i, j)]
            if inside[(i, j)]:
                verts[(i, j)] = b.verts.new((x, y, h))
            else:
                sx, sy = snap(x, y)
                verts[(i, j)] = b.verts.new((sx, sy, 0.0))
        return verts[(i, j)]

    for i in range(nx):
        for j in range(ny):
            corners = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
            n_in = sum(1 for cnr in corners if inside[cnr])
            if n_in == 0:
                continue
            vs = [vert(*cnr) for cnr in corners]
            try:
                b.faces.new(vs)
            except ValueError:
                pass
    # faces dégénérées (deux sommets rabattus au même point) : on fusionne les doublons
    bmesh.ops.remove_doubles(b, verts=b.verts[:], dist=0.02)
    # contour : arêtes de bord, mises bout à bout, puis face du dessous
    edges = [e for e in b.edges if e.is_boundary]
    nxt = {}
    for e in edges:
        a, c2 = e.verts
        nxt.setdefault(a, []).append(c2)
        nxt.setdefault(c2, []).append(a)
    loop, seen = [], set()
    v = edges[0].verts[0]
    while v not in seen:
        seen.add(v)
        loop.append(v)
        cands = [w for w in nxt.get(v, []) if w not in seen]
        if not cands:
            break
        v = cands[0]
    if len(loop) >= 3:
        # sens : la normale doit pointer vers -Z (vue de dessous)
        area = 0.0
        for k in range(len(loop)):
            p, q = loop[k].co, loop[(k + 1) % len(loop)].co
            area += p.x * q.y - q.x * p.y
        if area > 0:
            loop.reverse()
        try:
            b.faces.new(loop)
        except ValueError:
            pass
    bmesh.ops.recalc_face_normals(b, faces=b.faces[:])       # maillage fermé : normales vers l'extérieur
    if size is not None:
        lo = [min(v.co[i] for v in b.verts) for i in range(3)]
        hi = [max(v.co[i] for v in b.verts) for i in range(3)]
        k = [size[i] / max(1e-6, hi[i] - lo[i]) for i in range(3)]
        for v in b.verts:
            v.co = ((v.co.x - (lo[0] + hi[0]) / 2) * k[0], (v.co.y - (lo[1] + hi[1]) / 2) * k[1], v.co.z * k[2])
    m._add(b, Matrix.Identity(4), c, False)


def cloud_bank():
    """Banc de nuages épais, module ≈ 24 × 12 × 6 : grappe de dômes en bords arrondis, dessous plat (la caméra regarde à
    35° d'en haut), couleur de sommet uniforme (blanc de la palette ; l'ombrage par face du shader grise le dessous)."""
    m = Model('cloud_bank', 280)
    bumps = [(-7.5, -0.5, 5.0, 5.0), (-2.5, 1.5, 5.2, 6.0), (2.5, -1.5, 5.0, 5.4), (7.0, 0.8, 4.8, 4.6),
             (-9.0, 2.5, 3.2, 3.0), (-4.5, -3.5, 3.6, 3.4), (0.0, 4.0, 3.4, 3.6), (4.5, 3.0, 3.0, 3.2),
             (9.5, -2.0, 3.0, 2.8), (-0.5, -4.5, 3.2, 3.0), (11.0, 1.5, 2.4, 2.2), (-11.0, -1.5, 2.4, 2.2)]
    _cloud(m, bumps, 1.25, C('white'), (24.0, 12.0, 6.0))
    m.to_object()
    return {'module': [24.0, 12.0, 6.0], 'vcol': 'white (uniforme)'}


def cloud_puff():
    """Nuage isolé ≈ 8 × 5 × 4 pour les bords du banc et la dissipation ; même construction, même teinte uniforme."""
    m = Model('cloud_puff', 281)
    bumps = [(-2.0, -0.3, 2.4, 3.4), (1.2, 0.5, 2.5, 4.0), (3.0, -0.8, 1.6, 2.2), (-3.2, 0.9, 1.3, 1.8),
             (0.2, -1.6, 1.6, 2.0)]
    _cloud(m, bumps, 0.9, C('white'), (8.0, 5.0, 4.0))
    m.to_object()
    return {'module': [8.0, 5.0, 4.0], 'vcol': 'white (uniforme)'}


ASSETS = {'cloud_bank': cloud_bank, 'cloud_puff': cloud_puff}
