# Bibliothèque de modèles low-poly colorés par sommet (adaptée de Rush/blender/lib.py).
# Export : un .glb par asset (glTF, Y-up), couleurs de sommet en linéaire (attribut FLOAT_COLOR « Color »).
import bpy, bmesh, math, random, json, os
from mathutils import Matrix, Vector, Euler


def V(fn):
    """Marque une fonction de couleur comme « par sommet » (sinon : par centre de face, donc des aplats nets)."""
    fn.vert = True
    return fn


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def mul(a, k):
    return tuple(min(1, max(0, v * k)) for v in a)


FONTS = (r'C:\Windows\Fonts\ariblk.ttf', r'C:\Windows\Fonts\arialbd.ttf')   # Arial Black, sinon Arial gras
CAP_HEIGHT = 0.716                                                          # hauteur des capitales (em) de ces polices


def srgb_to_lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


class Model:
    """Accumulateur de primitives dans un seul bmesh. Coordonnées Blender : X = longueur, Y = profondeur, Z = haut."""

    def __init__(self, name, seed=1):
        self.name = name
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.float_color.new('Color')
        self.rnd = random.Random(seed)

    def _add(self, src, mat, color, smooth=False, shade=None):
        src.transform(mat)
        vmap = {}
        for v in src.verts:
            vmap[v] = self.bm.verts.new(v.co)
        byvert = getattr(color, 'vert', False)
        for f in src.faces:
            try:
                nf = self.bm.faces.new([vmap[v] for v in f.verts])
            except ValueError:
                continue
            nf.smooth = smooth
            cc = f.calc_center_median()
            fc = color(cc.x, cc.y, cc.z) if callable(color) and not byvert else color
            for l in nf.loops:
                p = l.vert.co
                c = color(p.x, p.y, p.z) if byvert else fc
                if shade:
                    c = mul(c, shade(p.x, p.y, p.z))
                l[self.col] = (srgb_to_lin(c[0]), srgb_to_lin(c[1]), srgb_to_lin(c[2]), 1.0)
        src.free()

    def _mat(self, p=(0, 0, 0), s=(1, 1, 1), r=(0, 0, 0)):
        return Matrix.Translation(p) @ Euler(r, 'XYZ').to_matrix().to_4x4() @ Matrix.Diagonal((s[0], s[1], s[2], 1))

    # --- primitives ---------------------------------------------------------
    def box(self, p=(0, 0, 0), s=(1, 1, 1), r=(0, 0, 0), c=(1, 1, 1), shade=None):
        """Boîte centrée en p, dimensions s (taille totale)."""
        b = bmesh.new()
        bmesh.ops.create_cube(b, size=1.0)
        self._add(b, self._mat(p, s, r), c, False, shade)

    def boxb(self, p=(0, 0, 0), s=(1, 1, 1), r=(0, 0, 0), c=(1, 1, 1), shade=None):
        """Boîte posée : p = centre de la face du bas."""
        self.box((p[0], p[1], p[2] + s[2] / 2), s, r, c, shade)

    def cham(self, p=(0, 0, 0), s=(1, 1, 1), bevel=0.15, c=(1, 1, 1), r=(0, 0, 0), top=None):
        """Boîte posée aux arêtes verticales chanfreinées (silhouette « jouet »). top = couleur du dessus."""
        b = bmesh.new()
        hx, hy, h = s[0] / 2, s[1] / 2, s[2]
        e = min(bevel, hx * 0.9, hy * 0.9)
        pts = [(hx - e, -hy), (hx, -hy + e), (hx, hy - e), (hx - e, hy), (-hx + e, hy), (-hx, hy - e), (-hx, -hy + e), (-hx + e, -hy)]
        lo = [b.verts.new((x, y, 0)) for x, y in pts]
        hi = [b.verts.new((x, y, h)) for x, y in pts]
        n = len(pts)
        for i in range(n):
            j = (i + 1) % n
            b.faces.new([lo[i], lo[j], hi[j], hi[i]])
        b.faces.new(list(reversed(lo)))
        b.faces.new(hi)
        bmesh.ops.recalc_face_normals(b, faces=b.faces)
        if top is not None:
            base = c
            col = lambda x, y, z: top if z > h - 1e-3 else base
        else:
            col = c
        self._add(b, self._mat(p, (1, 1, 1), r), col, False)

    def cyl(self, p=(0, 0, 0), s=(1, 1, 1), r=(0, 0, 0), c=(1, 1, 1), seg=10, r2=1.0, h=1.0, smooth=False, cap=True, shade=None):
        """Cylindre/cône centré en p, axe Z, hauteur h*s.z, rayon bas s.xy, rayon haut r2*s.xy."""
        b = bmesh.new()
        bmesh.ops.create_cone(b, cap_ends=cap, cap_tris=False, segments=seg, radius1=1.0, radius2=r2, depth=h)
        self._add(b, self._mat(p, s, r), c, smooth, shade)

    def cylb(self, p, rad, h, c, seg=10, r2=1.0, r=(0, 0, 0)):
        """Cylindre posé (base en p)."""
        self.cyl((p[0], p[1], p[2] + h / 2), (rad, rad, h), r, c, seg, r2, 1.0)

    def ico(self, p=(0, 0, 0), s=(1, 1, 1), r=(0, 0, 0), c=(1, 1, 1), sub=1, jitter=0.0, shade=None):
        b = bmesh.new()
        bmesh.ops.create_icosphere(b, subdivisions=sub, radius=1.0)
        if jitter:
            for v in b.verts:
                v.co *= 1 + (self.rnd.random() - 0.5) * jitter
        self._add(b, self._mat(p, s, r), c, False, shade)

    def sphere(self, p=(0, 0, 0), s=(1, 1, 1), r=(0, 0, 0), c=(1, 1, 1), seg=10, ring=6, smooth=False):
        b = bmesh.new()
        bmesh.ops.create_uvsphere(b, u_segments=seg, v_segments=ring, radius=1.0)
        self._add(b, self._mat(p, s, r), c, smooth)

    def tube(self, a, b2, rad, c, seg=6):
        """Barre cylindrique de a à b2."""
        a, bb = Vector(a), Vector(b2)
        d = bb - a
        L = d.length
        if L < 1e-6:
            return
        b = bmesh.new()
        bmesh.ops.create_cone(b, cap_ends=True, cap_tris=False, segments=seg, radius1=rad, radius2=rad, depth=L)
        q = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
        self._add(b, Matrix.Translation((a + bb) / 2) @ q, c, False)

    def beam(self, a, b2, w, c):
        """Poutre carrée de a à b2 (treillis de grue)."""
        self.tube(a, b2, w, c, seg=4)

    def prism(self, pts, z0, z1, c, top=None):
        """Extrusion verticale d'un polygone (x, y) convexe ou simple."""
        b = bmesh.new()
        lo = [b.verts.new((x, y, z0)) for x, y in pts]
        hi = [b.verts.new((x, y, z1)) for x, y in pts]
        n = len(pts)
        for i in range(n):
            j = (i + 1) % n
            b.faces.new([lo[i], lo[j], hi[j], hi[i]])
        b.faces.new(list(reversed(lo)))
        b.faces.new(hi)
        bmesh.ops.recalc_face_normals(b, faces=b.faces)
        col = (lambda x, y, z: top if z > z1 - 1e-3 else c) if top is not None else c
        self._add(b, Matrix.Identity(4), col, False)

    def prism_x(self, pts, x0, x1, c):
        """Extrusion le long de X d'un polygone (y, z) simple (coin, joues de shed)."""
        b = bmesh.new()
        lo = [b.verts.new((x0, y, z)) for y, z in pts]
        hi = [b.verts.new((x1, y, z)) for y, z in pts]
        n = len(pts)
        for i in range(n):
            j = (i + 1) % n
            b.faces.new([lo[i], lo[j], hi[j], hi[i]])
        b.faces.new(list(reversed(lo)))
        b.faces.new(hi)
        bmesh.ops.recalc_face_normals(b, faces=b.faces)
        self._add(b, Matrix.Identity(4), c, False)

    def prism_y(self, pts, y0, y1, c):
        """Extrusion le long de Y d'un polygone (x, z) simple (toit dont le faîte suit Y)."""
        b = bmesh.new()
        lo = [b.verts.new((x, y0, z)) for x, z in pts]
        hi = [b.verts.new((x, y1, z)) for x, z in pts]
        n = len(pts)
        for i in range(n):
            j = (i + 1) % n
            b.faces.new([lo[i], lo[j], hi[j], hi[i]])
        b.faces.new(list(reversed(lo)))
        b.faces.new(hi)
        bmesh.ops.recalc_face_normals(b, faces=b.faces)
        self._add(b, Matrix.Identity(4), c, False)

    def hull(self, length, width, height, bow=0.25, stern=0.08, p=(0, 0, 0), c_low=(1, 0, 0), c_high=(0, 0, 0), waterline=0.45, deck=None):
        """Coque de navire : section en U, étrave en pointe (+X), tableau arrière. Couleur : œuvres vives / mortes."""
        b = bmesh.new()
        hw = width / 2
        L = length / 2
        xs = [-L, -L + length * stern, L - length * bow, L - length * bow * 0.45, L]
        rings = []
        for i, x in enumerate(xs):
            if i == len(xs) - 1:
                f = 0.0
            elif i == len(xs) - 2:
                f = 0.55
            else:
                f = 1.0
            fb = 0.75 if i == 0 else f
            prof = [(-hw * fb * 0.8, 0.0), (-hw * f, height * 0.35), (-hw * f, height), (hw * f, height), (hw * f, height * 0.35), (hw * fb * 0.8, 0.0)]
            if f == 0.0:
                prof = [(0.0, height * 0.15), (0.0, height * 0.35), (0.0, height * 1.05), (0.0, height * 1.05), (0.0, height * 0.35), (0.0, height * 0.15)]
            rings.append([b.verts.new((x, y, z)) for (y, z) in prof])
        for k in range(len(rings) - 1):
            A, B = rings[k], rings[k + 1]
            for i in range(len(A) - 1):
                try:
                    b.faces.new([A[i], A[i + 1], B[i + 1], B[i]])
                except ValueError:
                    pass
            try:
                b.faces.new([A[-1], A[0], B[0], B[-1]])
            except ValueError:
                pass
        b.faces.new(list(reversed(rings[0])))
        bmesh.ops.recalc_face_normals(b, faces=b.faces)
        wl = height * waterline
        dk = deck

        def col(x, y, z):
            if dk is not None and z > height - 0.02 and abs(y) < hw * 0.98:
                return dk
            return c_low if z < wl else c_high
        self._add(b, Matrix.Translation(p), col, False)

    def grid(self, p, w, d, tile, c_a, c_b):
        """Dallage plat (dessus seul) de w × d centré en p, damier de carreaux de côté ~tile (2 triangles par carreau)."""
        nx, ny = max(1, round(w / tile)), max(1, round(d / tile))
        b = bmesh.new()
        vs = [[b.verts.new((-w / 2 + i * w / nx, -d / 2 + j * d / ny, 0)) for j in range(ny + 1)] for i in range(nx + 1)]
        for i in range(nx):
            for j in range(ny):
                b.faces.new([vs[i][j], vs[i + 1][j], vs[i + 1][j + 1], vs[i][j + 1]])
        px, py = p[0] - w / 2, p[1] - d / 2
        sx, sy = w / nx, d / ny
        col = lambda x, y, z: c_a if (int((x - px) // sx) + int((y - py) // sy)) % 2 == 0 else c_b
        self._add(b, Matrix.Translation(p), col, False)

    def text(self, body, p, height, c, depth=0.15, r=(0, 0, 0), font=None):
        """Lettres extrudées (police Windows grasse si disponible). Base des lettres en p, texte centré, face avant vers +Z
        avant rotation (r). Hauteur = hauteur des capitales. Renvoie (largeur, bas, haut) : étendue réelle des glyphes
        par rapport à la ligne de base (accents et jambages compris)."""
        cu = bpy.data.curves.new('txt', 'FONT')
        cu.body = body
        cu.align_x = 'CENTER'
        cu.extrude = depth / 2
        cu.resolution_u = 2
        path = font or next((f for f in FONTS if os.path.exists(f)), None)
        if path:
            cu.font = bpy.data.fonts.load(path, check_existing=True)
        ob = bpy.data.objects.new('txt', cu)
        bpy.context.scene.collection.objects.link(ob)
        dg = bpy.context.evaluated_depsgraph_get()
        ev = ob.evaluated_get(dg)
        me = ev.to_mesh()
        b = bmesh.new()
        b.from_mesh(me)
        ev.to_mesh_clear()
        bpy.data.objects.remove(ob, do_unlink=True)
        bpy.data.curves.remove(cu)
        bmesh.ops.dissolve_limit(b, angle_limit=0.02, verts=b.verts[:], edges=b.edges[:])
        # mise à l'échelle en X/Y seulement (l'épaisseur reste `depth`) ; ligne de base du texte sur y = 0
        x0, x1 = min(v.co.x for v in b.verts), max(v.co.x for v in b.verts)
        k = height / CAP_HEIGHT
        for v in b.verts:
            v.co.x = (v.co.x - (x0 + x1) / 2) * k
            v.co.y *= k
        y0, y1 = min(v.co.y for v in b.verts), max(v.co.y for v in b.verts)
        self._add(b, self._mat(p, (1, 1, 1), r), c, False)
        return (x1 - x0) * k, y0, y1

    def tris(self):
        bm = self.bm.copy()
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        n = len(bm.faces)
        bm.free()
        return n

    def to_object(self, name=None, loc=(0, 0, 0), parent=None):
        me = bpy.data.meshes.new((name or self.name) + '_m')
        bm = self.bm.copy()

        bm.to_mesh(me)
        bm.free()
        me.update()
        if me.color_attributes.get('Color') is not None:
            me.color_attributes.active_color = me.color_attributes['Color']
            me.color_attributes.render_color_index = me.color_attributes.active_color_index
        ob = bpy.data.objects.new(name or self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        ob.location = loc
        if parent is not None:
            ob.parent = parent
        return ob


# --- pièces de style (docs/BRIEF_STYLE_PORTS.md) ----------------------------------
# Une façade est repérée par `side` (normale sortante : '+x', '-x', '+y', '-y'), `plane` (coordonnée du plan de la face)
# et `t` (abscisse le long de la façade : X pour les faces ±y, Y pour les faces ±x).
# La caméra regarde depuis +X / -Y : ce sont les murs bas ; -X et +Y sont les murs du fond, hauts.

def _face(side, plane, t, out, z):
    """Point à l'abscisse t, décalé de `out` hors de la face, à la hauteur z."""
    s = 1 if side[0] == '+' else -1
    return (t, plane + s * out, z) if side[1] == 'y' else (plane + s * out, t, z)


def _size(side, along, across, h):
    return (along, across, h) if side[1] == 'y' else (across, along, h)


def wall_cutaway_thick(m, w, d, h, front_h=1.1, th=None, z0=0.2, wall=None, inner=None, cap=None, tiles=None,
                       tile=1.0, gaps=(), cap_h=0.24, over=0.07, skirt=None):
    """Pièce en coupe à murs épais : dalle (socle sombre) + dallage en damier, murs du fond (-X, +Y) de hauteur h,
    murs avant (+X, -Y) bas, chape sombre débordante sur tous les murs. gaps = [(side, t_centre, largeur)] pour les
    ouvertures dans les murs avant. skirt = couleur de la plinthe intérieure des murs du fond.
    Renvoie les cotes utiles (intérieur, hauteur des chapes).
    Réservée (brief § 3 bis, règle 1) : aucun bâtiment ne l'utilise tant que le jeu ne fait rien vivre à l'intérieur."""
    from palette import C
    th = th or max(0.3, min(0.5, w / 12))
    wall, inner, cap = wall or C('facade'), inner or C('wall_in'), cap or C('wall_cap')
    ta, tb = tiles or (C('tile_a'), C('tile_b'))
    m.boxb((0, 0, 0), (w, d, z0), (0, 0, 0), C('plinth'))
    m.grid((0, 0, z0 + 0.003), w, d, tile, ta, tb)
    runs = [  # side, plan, t0, t1, hauteur, débord de chape au début / à la fin
        ('-x', -w / 2, -d / 2, d / 2, h, over, over),
        ('+y', d / 2, -w / 2 + th, w / 2, h, -over, over),
        ('-y', -d / 2, -w / 2 + th, w / 2, front_h, 0, over),
        ('+x', w / 2, -d / 2 + th, d / 2 - th, front_h, -over, 0),
    ]
    for side, plane, t0, t1, hh, e0, e1 in runs:
        cuts = sorted((tc - gw / 2, tc + gw / 2) for (gs, tc, gw) in gaps if gs == side)
        segs, a = [], t0
        for g0, g1 in cuts:
            segs.append((a, g0, e0 if a == t0 else 0, 0))
            a = g1
        segs.append((a, t1, e0 if a == t0 else 0, e1))
        s = 1 if side[0] == '+' else -1
        ac = plane - s * th / 2
        ax = 1 if side[1] == 'y' else 0
        col = lambda x, y, z, ax=ax, ac=ac, s=s: wall if ((y, x)[1 - ax] - ac) * s > th / 4 else inner
        for a, b, ea, eb in segs:
            if b - a < 1e-3:
                continue
            tc = (a + b) / 2
            m.boxb(_face(side, ac, tc, 0, z0), _size(side, b - a, th, hh - cap_h), (0, 0, 0), col)
            ct = (a - ea + b + eb) / 2
            m.boxb(_face(side, ac, ct, 0, z0 + hh - cap_h), _size(side, b - a + ea + eb, th + 2 * over, cap_h), (0, 0, 0), cap)
            if skirt is not None and hh == h:
                m.boxb(_face(side, plane - s * th, tc, -0.02, z0), _size(side, b - a, 0.05, 0.22), (0, 0, 0), skirt)
    return {'th': th, 'z0': z0, 'x0': -w / 2 + th, 'x1': w / 2 - th, 'y0': -d / 2 + th, 'y1': d / 2 - th,
            'top': z0 + h, 'front_top': z0 + front_h}


def pilaster(m, p, h, w=0.42, brick=None, plinth=None, capital=None):
    """Pilier carré posé en p : socle sombre élargi, fût de brique, chapiteau crème."""
    from palette import C
    brick, plinth, capital = brick or C('brick'), plinth or C('plinth'), capital or C('capital')
    ph, chh = min(0.55, h * 0.25), 0.16
    m.boxb(p, (w + 0.12, w + 0.12, ph), (0, 0, 0), plinth)
    m.boxb((p[0], p[1], p[2] + ph), (w, w, h - ph - chh), (0, 0, 0), brick)
    m.boxb((p[0], p[1], p[2] + h - chh), (w + 0.1, w + 0.1, chh), (0, 0, 0), capital)


def window_band(m, side, plane, t, z, length, height, n=None, glass=None, mullion=None, frame=0.07, sill=True):
    """Vitrine à meneaux sur une face : verre bleu légèrement en saillie, n travées, appui crème."""
    from palette import C
    glass, mullion = glass or C('vitrine'), mullion or C('mullion')
    n = n or max(1, round(length / 0.9))
    m.boxb(_face(side, plane, t, 0.015, z), _size(side, length, 0.06, height), (0, 0, 0), glass)
    for i in range(n + 1):
        tt = t - length / 2 + i * length / n
        m.boxb(_face(side, plane, tt, 0.04, z), _size(side, frame, 0.08, height), (0, 0, 0), mullion)
    for zz in (z, z + height - frame):
        m.boxb(_face(side, plane, t, 0.04, zz), _size(side, length + frame, 0.08, frame), (0, 0, 0), mullion)
    if sill:
        m.boxb(_face(side, plane, t, 0.08, z - 0.08), _size(side, length + 0.16, 0.18, 0.08), (0, 0, 0), C('capital'))


def awning(m, side, plane, t, z, length, depth=0.9, drop=0.35, c=None, c2=None, n=None, valance=0.2):
    """Auvent incliné accroché à la face à la hauteur z ; rayé si c2 est donné (n bandes), avec lambrequin."""
    from palette import C
    c = c or C('red')
    n = n or (max(2, round(length / 0.45)) if c2 is not None else 1)
    a = math.atan2(drop, depth)
    rot = {'-y': (a, 0, 0), '+y': (-a, 0, 0), '+x': (0, a, 0), '-x': (0, -a, 0)}[side]
    sl = math.hypot(depth, drop)
    for i in range(n):
        tt = t - length / 2 + (i + 0.5) * length / n
        cc = c if (c2 is None or i % 2 == 0) else c2
        m.box(_face(side, plane, tt, depth / 2, z - drop / 2), _size(side, length / n, sl, 0.08), rot, cc)
        m.boxb(_face(side, plane, tt, depth, z - drop - valance), _size(side, length / n, 0.06, valance), (0, 0, 0), cc)


def sign3d(m, text, side, plane, t, z, height, c=None, depth=0.18, board=None, pad=0.12):
    """Enseigne en lettres 3D extrudées sur une face (lisible depuis l'extérieur de cette face), base des lettres à z.
    board = couleur d'un panneau de fond (facultatif)."""
    from palette import C
    c = c or C('sign_red')
    rot = {'-y': (math.pi / 2, 0, 0), '+x': (math.pi / 2, 0, math.pi / 2),
           '+y': (math.pi / 2, 0, math.pi), '-x': (math.pi / 2, 0, -math.pi / 2)}[side]
    off = 0.12 if board is not None else 0.02
    tw, lo, hi = m.text(text, _face(side, plane, t, off + depth / 2, z), height, c, depth, rot)
    if board is not None:
        # panneau calé sur l'étendue réelle des glyphes : un accent (Ô) ou un jambage ne dépasse pas
        lo, hi = min(lo, 0.0), max(hi, height)
        m.boxb(_face(side, plane, t, 0.06, z + lo - pad), _size(side, tw + 2 * pad, 0.12, hi - lo + 2 * pad), (0, 0, 0), board)
    return tw


def planter(m, p, s=0.7, pot=None, shrub=None):
    """Jardinière cubique et arbuste taillé en cube (exagérés)."""
    from palette import C
    pot, shrub = pot or C('pot'), shrub or C('shrub')
    m.cham(p, (s, s, s * 0.42), s * 0.08, pot)
    m.cham((p[0], p[1], p[2] + s * 0.36), (s * 0.88, s * 0.88, s * 0.95), s * 0.14, shrub)


def facade(m, side, plane, t0, t1, z0, h, bay=2.2, pil_w=0.42, win=True, pil_h=None, ends=True, skip=(), n=None,
           win_lo=None):
    """Façade structurée sur un mur (côté extérieur) : socle sombre filant, piliers toutes les `bay` unités (et aux
    extrémités si ends), vitrines à meneaux entre les piliers. pil_h permet aux piliers de dépasser le mur.
    skip = [(t_centre, largeur)] : travées laissées sans vitrine (portes, enseignes, quais)."""
    from palette import C
    pil_h = pil_h or h
    L = t1 - t0
    nb = max(1, round(L / bay))
    ph = min(0.3, h * 0.25)
    m.boxb(_face(side, plane, (t0 + t1) / 2, 0.03, z0), _size(side, L, 0.1, ph), (0, 0, 0), C('plinth'))
    for i in range(nb + 1):
        tt = t0 + i * L / nb
        if ends or 0 < i < nb:
            pilaster(m, _face(side, plane, tt, pil_w / 2 - 0.08, z0), pil_h, pil_w)
        if win and i < nb:
            a, b = tt, tt + L / nb
            if any(a < sc + sw / 2 and sc - sw / 2 < b for sc, sw in skip):
                continue
            gl = L / nb - pil_w - 0.35
            if gl > 0.3:
                zb = z0 + (win_lo if win_lo is not None else ph + 0.12)
                window_band(m, side, plane, (a + b) / 2, zb, gl, max(0.3, h - (zb - z0) - 0.32), n=n)


def closed_block(m, w, d, h, z0=0.2, wall=None, roof=None, cap=None, sides=('-y', '+x', '-x'), bay=2.2, pil_w=0.46,
                 parapet=0.42, over=0.1, skip=None, win=True, n=None, win_lo=None):
    """Bâtiment fermé au langage ISM : dalle-socle sombre, corps en façade ocre, toit-terrasse clair cerné d'une
    chape-acrotère sombre débordante, piliers d'angle, façades structurées sur `sides` (le fond +Y, jamais vu
    avec les rotations 0° et 90° du plan, reste nu). skip = {side: [(t, largeur)]} pour réserver portes et quais."""
    from palette import C
    wall, roof, cap = wall or C('facade'), roof or C('roof_flat'), cap or C('wall_cap')
    skip = skip or {}
    top = z0 + h
    m.boxb((0, 0, 0), (w + 0.3, d + 0.3, z0), (0, 0, 0), C('plinth'))
    m.boxb((0, 0, z0), (w, d, h), (0, 0, 0), wall)
    m.boxb((0, 0, top), (w - 0.1, d - 0.1, 0.03), (0, 0, 0), roof)
    tp, zc, hc = 0.3, top - 0.14, parapet + 0.14
    m.boxb((0, -(d / 2 + over - (tp + over) / 2), zc), (w + 2 * over, tp + over, hc), (0, 0, 0), cap)
    m.boxb((0, d / 2 + over - (tp + over) / 2, zc), (w + 2 * over, tp + over, hc), (0, 0, 0), cap)
    for sx in (-1, 1):
        m.boxb((sx * (w / 2 + over - (tp + over) / 2), 0, zc), (tp + over, d - 2 * tp, hc), (0, 0, 0), cap)
    k = pil_w / 2 - 0.1
    for sx in (-1, 1):
        for sy in (-1, 1):
            pilaster(m, (sx * (w / 2 - k), sy * (d / 2 - k), z0), h - 0.14, pil_w)
    for side in sides:
        L, plane = (w, -d / 2 if side == '-y' else d / 2) if side[1] == 'y' else (d, w / 2 if side == '+x' else -w / 2)
        facade(m, side, plane, -L / 2, L / 2, z0, h - 0.14, bay, pil_w * 0.9, win, ends=False, skip=skip.get(side, ()), n=n,
               win_lo=win_lo)
    for side in ('-y', '+y', '+x', '-x'):
        if side not in sides:
            L, plane = (w, -d / 2 if side == '-y' else d / 2) if side[1] == 'y' else (d, w / 2 if side == '+x' else -w / 2)
            m.boxb(_face(side, plane, 0, 0.03, z0), _size(side, L, 0.1, 0.3), (0, 0, 0), C('plinth'))
    return {'top': top, 'roof': top + 0.03, 'parapet_top': zc + hc}


def door(m, side, plane, t, z0, w=1.0, h=1.75, glass=None, frame=None):
    """Porte vitrée à deux battants, cadre clair, imposte."""
    from palette import C
    glass, frame = glass or C('vitrine'), frame or C('mullion')
    m.boxb(_face(side, plane, t, 0.02, z0), _size(side, w, 0.06, h), (0, 0, 0), glass)
    for tt in (t - w / 2, t, t + w / 2):
        m.boxb(_face(side, plane, tt, 0.05, z0), _size(side, 0.09, 0.09, h), (0, 0, 0), frame)
    for zz in (z0 + h - 0.09, z0 + h - 0.45):
        m.boxb(_face(side, plane, t, 0.05, zz), _size(side, w + 0.09, 0.09, 0.09), (0, 0, 0), frame)


def roll_door(m, side, plane, t, z0, w, h, c, open=False):
    """Porte sectionnelle de quai : fermée (lames striées) ou ouverte (baie sombre, tambour en haut)."""
    from palette import C
    for tt in (t - w / 2 - 0.08, t + w / 2 + 0.08):
        m.boxb(_face(side, plane, tt, 0.06, z0), _size(side, 0.16, 0.12, h + 0.1), (0, 0, 0), C('dark'))
    if open:
        m.boxb(_face(side, plane, t, 0.01, z0), _size(side, w, 0.04, h - 0.3), (0, 0, 0), C('plinth'))
        m.boxb(_face(side, plane, t, 0.08, z0 + h - 0.3), _size(side, w + 0.1, 0.16, 0.36), (0, 0, 0), c)
    else:
        m.boxb(_face(side, plane, t, 0.03, z0), _size(side, w, 0.06, h), (0, 0, 0), c)
        for i in range(1, 5):
            m.boxb(_face(side, plane, t, 0.06, z0 + i * h / 5 - 0.03), _size(side, w, 0.04, 0.06), (0, 0, 0), mul(c, 0.8))


# --- direction D (docs/ETUDE_STYLE.md § 3, docs/ORDRE_BLENDER_D.md) --------------------------------------------------
# Deux registres : B « port nordique jouet » (wood_block : bois crème à bardage, chanfreins, bandeau marine, toit à pente
# coloré) pour le village, le T1 et les services ; « B en dur » (hard_block : façades claires, toit plat à casquette claire,
# grandes baies) pour le T2 ; C « industriel pop » (steel_shed : bardage nervuré, bandes jaune-noir, casquette claire) pour
# le T3, les hangars et les entrepôts. La couleur du département se pose sur le toit, la casquette ou l'auvent.
# Les faces vues par la caméra aux rotations 0° et 90° du plan sont -Y, +X et -X ; le fond +Y reste nu.
SIDES_VISIBLE = ('-y', '+x', '-x')
SCALE_PROPS = 1.35          # accessoires et personnages exagérés (brief § 3, règle 5)


def _side_geom(side, w, d):
    """Longueur et plan d'une face d'un bloc w × d centré à l'origine."""
    if side[1] == 'y':
        return w, (-d / 2 if side == '-y' else d / 2)
    return d, (w / 2 if side == '+x' else -w / 2)


def gable_roof(m, w, d, z, rise, c, over=0.35, axis='x', body=None, edge=None):
    """Toit à deux pentes débordant (faîte le long de `axis`), rives sombres aux pignons, pignons en couleur du corps.
    Renvoie la hauteur du faîte."""
    edge = edge or mul(c, 0.8)
    a, b = (w, d) if axis == 'x' else (d, w)
    ha, hb = a / 2 + over, b / 2 + over
    ext = m.prism_x if axis == 'x' else m.prism_y
    if body is not None:                                                             # pignons pleins
        ext([(-b / 2, z - 0.02), (b / 2, z - 0.02), (0, z + rise + 0.05)], -a / 2, a / 2, body)
    shell = [(-hb, z - 0.06), (-hb, z + 0.07), (0, z + rise + 0.13), (hb, z + 0.07), (hb, z - 0.06), (0, z + rise)]
    ext(shell, -ha, ha, c)
    rim = [(-hb - 0.05, z - 0.08), (-hb - 0.05, z + 0.09), (0, z + rise + 0.17), (hb + 0.05, z + 0.09), (hb + 0.05, z - 0.08), (0, z + rise)]
    for x0, x1 in ((-ha - 0.04, -ha + 0.1), (ha - 0.1, ha + 0.04)):
        ext(rim, x0, x1, edge)
    return z + rise + 0.13


def lap_siding(m, side, plane, t, L, z0, z1, c, lap=0.3):
    """Lames horizontales en léger relief sur une face (bardage bois)."""
    n = int((z1 - z0) / lap)
    for i in range(1, n + 1):
        m.boxb(_face(side, plane, t, 0.015, z0 + i * lap), _size(side, L, 0.03, 0.04), (0, 0, 0), c)


def wood_block(m, w, d, h, z0=0.2, body=None, band=None, trim=None, roof=None, rise=None, over=0.35, bevel=0.08,
               sides=SIDES_VISIBLE, lap=0.3, axis='x', band_h=0.35, kerb=None, gable=True, edge=None):
    """Registre B : socle clair, corps crème chanfreiné à bardage horizontal, planches d'angle blanches, bandeau bas
    marine, toit à deux pentes débordant de la couleur du département. Renvoie top (haut des murs) et ridge (faîte)."""
    from palette import C
    body, band, trim = body or C('wood_cream'), band or C('navy'), trim or C('wood_trim')
    roof, kerb = roof or C('roof_b_blue'), kerb or C('kerb')
    rise = rise if rise is not None else min(w, d) * 0.38
    m.boxb((0, 0, 0), (w + 0.5, d + 0.5, z0), (0, 0, 0), kerb)
    m.cham((0, 0, z0), (w, d, h), bevel, body)
    m.boxb((0, 0, z0), (w + 0.06, d + 0.06, band_h), (0, 0, 0), band)
    for sx in (-1, 1):
        for sy in (-1, 1):
            m.boxb((sx * (w / 2 - 0.08), sy * (d / 2 - 0.08), z0), (0.22, 0.22, h), (0, 0, 0), trim)
    lap_c = mul(body, 0.88)
    for side in sides:
        L, plane = _side_geom(side, w, d)
        lap_siding(m, side, plane, 0, L - 0.3, z0 + band_h, z0 + h - 0.12, lap_c, lap)
    top = z0 + h
    ridge = gable_roof(m, w, d, top, rise, roof, over, axis, body, edge) if gable else top
    return {'top': top, 'ridge': ridge, 'z0': z0}


def b_window(m, side, plane, t, z, length=0.9, height=0.95, n=2, shutters=None):
    """Fenêtre B : verre clair, meneaux et appui blancs ; volets colorés facultatifs."""
    from palette import C
    window_band(m, side, plane, t, z, length, height, n=n, glass=C('glass_light'), mullion=C('wood_trim'), sill=False)
    m.boxb(_face(side, plane, t, 0.06, z - 0.08), _size(side, length + 0.15, 0.12, 0.08), (0, 0, 0), C('wood_trim'))
    if shutters is not None:
        for s in (-1, 1):
            m.boxb(_face(side, plane, t + s * (length / 2 + 0.2), 0.03, z), _size(side, 0.3, 0.05, height), (0, 0, 0), shutters)


def b_door(m, side, plane, t, z0, c=None, w=0.95, h=1.7):
    """Porte B pleine et colorée (rouge falun par défaut), cadre blanc, hublot."""
    from palette import C
    c, tr = c or C('falun'), C('wood_trim')
    m.boxb(_face(side, plane, t, 0.02, z0), _size(side, w, 0.06, h), (0, 0, 0), c)
    for tt in (t - w / 2 - 0.05, t + w / 2 + 0.05):
        m.boxb(_face(side, plane, tt, 0.05, z0), _size(side, 0.08, 0.08, h + 0.05), (0, 0, 0), tr)
    m.boxb(_face(side, plane, t, 0.05, z0 + h), _size(side, w + 0.18, 0.08, 0.08), (0, 0, 0), tr)
    m.boxb(_face(side, plane, t, 0.06, z0 + h * 0.58), _size(side, w * 0.5, 0.05, 0.3), (0, 0, 0), C('glass_light'))


def hard_block(m, w, d, h, z0=0.2, wall=None, cap=None, dept=None, roof=None, sides=SIDES_VISIBLE, over=0.3,
               levels=1, win_h=1.1, win_z=0.85, bay=1.6, skip=None, cap_h=0.3, win=True):
    """Registre « B en dur » (T2) : socle sombre, corps clair, bandes de baies à meneaux blancs par niveau,
    toit plat à casquette claire débordante, bandeau de la couleur du département sur la casquette."""
    from palette import C
    wall, cap, dept, roof = wall or C('wood_cream'), cap or C('cap_light'), dept or C('blue'), roof or C('roof_light')
    skip = skip or {}
    m.boxb((0, 0, 0), (w + 0.3, d + 0.3, z0), (0, 0, 0), C('plinth'))
    m.boxb((0, 0, z0), (w, d, h), (0, 0, 0), wall)
    m.boxb((0, 0, z0), (w + 0.06, d + 0.06, 0.3), (0, 0, 0), C('plinth'))
    fh = h / levels
    for side in sides:
        L, plane = _side_geom(side, w, d)
        usable = L - 0.8
        nb = max(1, round(usable / bay))
        gl = usable / nb - 0.3
        for lv in range(levels):
            z = z0 + lv * fh + win_z
            if lv > 0:
                m.boxb(_face(side, plane, 0, 0.03, z0 + lv * fh - 0.06), _size(side, L + 0.06, 0.1, 0.12), (0, 0, 0), C('wood_trim'))
            if not win:
                continue
            for i in range(nb):
                t = -usable / 2 + (i + 0.5) * usable / nb
                if any(abs(t - sc) < sw / 2 + gl / 2 for sc, sw in skip.get(side, ())):
                    continue
                window_band(m, side, plane, t, z, gl, win_h, n=2, glass=C('glass_light'), mullion=C('wood_trim'), sill=False)
    top = z0 + h
    m.boxb((0, 0, top), (w + 2 * over, d + 2 * over, cap_h), (0, 0, 0), cap)
    m.boxb((0, 0, top + cap_h), (w + 2 * over + 0.04, d + 2 * over + 0.04, 0.16), (0, 0, 0), dept)
    m.boxb((0, 0, top + cap_h + 0.16), (w + 2 * over - 0.3, d + 2 * over - 0.3, 0.03), (0, 0, 0), roof)
    return {'top': top, 'roof': top + cap_h + 0.19, 'cap_top': top + cap_h + 0.16, 'z0': z0}


def hazard_band(m, side, plane, t, L, z, h=0.38, out=0.03):
    """Bande de sécurité jaune à segments noirs le long d'une face."""
    from palette import C
    m.boxb(_face(side, plane, t, out, z), _size(side, L, 0.05, h), (0, 0, 0), C('hazard'))
    tc = t - L / 2 + 0.6
    while tc + 0.2 <= t + L / 2:
        m.boxb(_face(side, plane, tc, out + 0.02, z), _size(side, 0.4, 0.05, h), (0, 0, 0), C('dark'))
        tc += 0.8


def steel_shed(m, w, d, h, z0=0.2, clad=None, clad_dark=None, cap=None, roof=None, dept=None, sides=SIDES_VISIBLE,
               rib=0.5, hazard=True, over=0.15, apron=None, skip=None, cap_h=0.28):
    """Registre C : dalle sombre, corps en bardage métallique nervuré, bande jaune-noir en bas, bandeau de la couleur
    du département sous une casquette claire, toit technique clair. skip = {side: [(t, largeur)]} pour les portes."""
    from palette import C
    clad, clad_dark = clad or C('clad_steel'), clad_dark or C('clad_steel_dark')
    cap, roof, apron = cap or C('cap_light'), roof or C('roof_light'), apron or C('apron_dark')
    skip = skip or {}
    m.boxb((0, 0, 0), (w + 0.4, d + 0.4, z0), (0, 0, 0), apron)
    m.boxb((0, 0, z0), (w, d, h), (0, 0, 0), clad)
    hz = 0.4 if hazard else 0.0
    for side in sides:
        L, plane = _side_geom(side, w, d)
        n = max(1, int(L / rib))
        for i in range(n):
            t = -L / 2 + (i + 0.5) * L / n
            if any(abs(t - sc) < sw / 2 + 0.08 for sc, sw in skip.get(side, ())):
                continue
            m.boxb(_face(side, plane, t, 0.02, z0 + hz + 0.05), _size(side, 0.08, 0.04, h - hz - 0.4), (0, 0, 0), clad_dark)
        if hazard:
            hazard_band(m, side, plane, 0, L, z0 + 0.02)
    top = z0 + h
    if dept is not None:
        m.boxb((0, 0, top - 0.3), (w + 0.08, d + 0.08, 0.3), (0, 0, 0), dept)
    m.boxb((0, 0, top), (w + 2 * over, d + 2 * over, cap_h), (0, 0, 0), cap)
    m.boxb((0, 0, top + cap_h), (w - 0.2, d - 0.2, 0.03), (0, 0, 0), roof)
    return {'top': top, 'roof': top + cap_h + 0.03, 'z0': z0}


# --- emblèmes : objets reconnaissables en petit, un par bâtiment (ordre § 4) -------------------------------------------

def emblem_life_ring(m, p, rad, side='-y'):
    """Bouée couronne rouge et blanche (8 quartiers) accrochée sur une face orientée `side`."""
    from palette import C
    for i in range(8):
        a = (i + 0.5) * math.tau / 8
        c = C('red') if i % 2 == 0 else C('white')
        u, v = math.cos(a) * rad, math.sin(a) * rad
        q = (p[0] + u, p[1], p[2] + v) if side[1] == 'y' else (p[0], p[1] + u, p[2] + v)
        r = (0, -a, 0) if side[1] == 'y' else (a, 0, 0)
        m.box(q, (0.22, 0.2, rad * 0.86) if side[1] == 'y' else (0.2, 0.22, rad * 0.86), r, c)


def emblem_belvedere(m, x, y, z, roof=None, size=1.5):
    """Belvédère vitré à toit pyramidal (capitainerie). Renvoie le haut du toit."""
    from palette import C
    roof = roof or C('roof_b_blue')
    m.boxb((x, y, z), (size, size, 0.5), (0, 0, 0), C('wood_cream'))
    m.boxb((x, y, z + 0.5), (size - 0.2, size - 0.2, 0.8), (0, 0, 0), C('glass_light'))
    k = size / 2 - 0.15
    for u, v in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
        m.boxb((x + u * k, y + v * k, z + 0.5), (0.1, 0.1, 0.8), (0, 0, 0), C('wood_trim'))
    m.boxb((x, y, z + 1.3), (size + 0.2, size + 0.2, 0.1), (0, 0, 0), C('wood_trim'))
    m.cyl((x, y, z + 1.4 + 0.45), ((size + 0.1) * 0.72, (size + 0.1) * 0.72, 0.9), (0, 0, math.pi / 4), roof, 4, 0.0)
    return z + 2.3


def emblem_flag_mast(m, x, y, z, h=2.0, flags=None, pole=None):
    """Mât à vergue avec pavois (drapeaux en drisse) et pomme rouge."""
    from palette import C
    pole = pole or C('wood_trim')
    flags = flags or (C('red'), C('yellow'), C('blue'), C('white'), C('green'))
    m.cylb((x, y, z), 0.06, h, pole, 6)
    m.box((x + 0.3, y, z + h - 0.3), (0.7, 0.08, 0.08), (0, 0, 0), pole)
    m.ico((x, y, z + h + 0.1), (0.15, 0.15, 0.15), (0, 0, 0), C('red'), 0)
    for i, c in enumerate(flags):
        t = (i + 0.5) / len(flags)
        m.box((x + 0.08 + 0.72 * t, y, z + h - 0.4 - 0.55 * t), (0.24, 0.04, 0.28), (0, 0, 0), c)
    return z + h + 0.25


def emblem_clock(m, side, plane, t, z, rad=0.7):
    """Grande horloge ronde sur une face : cadran blanc, cerclage marine, aiguilles."""
    from palette import C
    r = {'-y': (math.pi / 2, 0, 0), '+y': (math.pi / 2, 0, 0), '+x': (0, math.pi / 2, 0), '-x': (0, math.pi / 2, 0)}[side]
    m.cyl(_face(side, plane, t, 0.06, z), (rad + 0.12, rad + 0.12, 0.12), r, C('navy'), 12)
    m.cyl(_face(side, plane, t, 0.13, z), (rad, rad, 0.06), r, C('white'), 12)
    m.box(_face(side, plane, t, 0.17, z + rad * 0.3), _size(side, 0.08, 0.04, rad * 0.6), (0, 0, 0), C('dark'))
    m.box(_face(side, plane, t + rad * 0.22, 0.17, z), _size(side, rad * 0.45, 0.04, 0.08), (0, 0, 0), C('dark'))


def emblem_radar(m, x, y, z, h=1.6):
    """Mât avec antenne radar en barre et feu rouge."""
    from palette import C
    m.cylb((x, y, z), 0.06, h, C('steel'), 6)
    m.cylb((x, y, z + h), 0.14, 0.18, C('white'), 8)
    m.box((x, y, z + h + 0.3), (1.3, 0.08, 0.22), (0, 0, 0.5), C('white'))
    m.ico((x, y, z + h + 0.55), (0.12, 0.12, 0.12), (0, 0, 0), C('red'), 0)
    return z + h + 0.6


def emblem_beacon(m, x, y, z, c=None, s=1.0):
    """Feu tournant (gyrophare) orange sur embase sombre."""
    from palette import C
    c = c or C('orange')
    m.cylb((x, y, z), 0.22 * s, 0.1 * s, C('dark'), 8)
    m.cylb((x, y, z + 0.1 * s), 0.17 * s, 0.32 * s, c, 8)
    m.cylb((x, y, z + 0.42 * s), 0.2 * s, 0.05 * s, C('dark'), 8)


def emblem_antenna(m, x, y, z, h=2.4, c=None):
    """Antenne radio : mât fin et traverses."""
    from palette import C
    c = c or C('steel')
    m.cylb((x, y, z), 0.06, h, c, 6)
    for k, zz in ((0.5, 0.55), (0.35, 0.8)):
        m.box((x, y, z + h * zz), (k * 1.6, 0.05, 0.05), (0, 0, 0), c)
    m.ico((x, y, z + h), (0.1, 0.1, 0.1), (0, 0, 0), C('red'), 0)


def emblem_dish(m, x, y, z, rad=0.8, c=None):
    """Parabole inclinée sur pied."""
    from palette import C
    c = c or C('white')
    m.cylb((x, y, z), 0.07, 0.9, C('steel'), 6)
    m.cyl((x, y - 0.1, z + 1.0), (rad, rad, 0.35), (0.7, 0, 0), c, 10, 0.25)
    m.cylb((x, y - 0.45, z + 1.0), 0.04, 0.6, C('steel'), 4, r=(0.7, 0, 0))


def emblem_tire_pile(m, x, y, n=4, r=0.55, h=0.3):
    """Pile de pneus géants (atelier)."""
    from palette import C
    for i in range(n):
        m.cylb((x + (i % 2) * 0.06, y, i * h), r, h - 0.02, C('dark'), 10)
        m.cylb((x + (i % 2) * 0.06, y, i * h + 0.03), r + 0.05, h - 0.08, C('dark'), 10)


def emblem_stop_sign(m, x, y, h=2.4, c=None):
    """Panneau STOP octogonal orange sur poteau, face vers -Y."""
    from palette import C
    c = c or C('orange')
    m.cylb((x, y, 0), 0.06, h, C('steel'), 6)
    m.cyl((x, y, h + 0.1), (0.55, 0.55, 0.08), (math.pi / 2, 0, 0), c, 8)
    m.cyl((x, y - 0.05, h + 0.1), (0.42, 0.42, 0.04), (math.pi / 2, 0, 0), C('white'), 8)
    m.cyl((x, y - 0.08, h + 0.1), (0.3, 0.3, 0.03), (math.pi / 2, 0, 0), c, 8)


def emblem_traffic_light(m, x, y, h=2.6):
    """Feu rouge / vert sur mât, boîtier sombre, lanternes vers -Y."""
    from palette import C
    m.cylb((x, y, 0), 0.07, h, C('steel'), 6)
    m.boxb((x, y, h), (0.5, 0.35, 1.0), (0, 0, 0), C('dark'))
    m.cylb((x, y - 0.18, h + 0.7), 0.16, 0.1, C('red'), 8, r=(math.pi / 2, 0, 0))
    m.cylb((x, y - 0.18, h + 0.25), 0.16, 0.1, C('green'), 8, r=(math.pi / 2, 0, 0))


def emblem_checker_barrier(m, x, y, L=1.6, c1=None, c2=None):
    """Barrière à damier (tréteau) posée au sol, face vers -Y."""
    from palette import C
    c1, c2 = c1 or C('navy'), c2 or C('yellow')
    for s in (-1, 1):
        m.boxb((x + s * (L / 2 - 0.1), y, 0), (0.1, 0.5, 1.0), (0, 0, 0), C('steel'))
    n = 4
    for i in range(n):
        m.boxb((x - L / 2 + (i + 0.5) * L / n, y, 0.55), (L / n, 0.1, 0.4), (0, 0, 0), c1 if i % 2 == 0 else c2)


def emblem_table_suitcase(m, x, y, open=True):
    """Table d'inspection à pieds acier, valise orange ouverte, paquet violet."""
    from palette import C
    for sx in (-1, 1):
        for sy in (-1, 1):
            m.boxb((x + sx * 0.5, y + sy * 0.35, 0), (0.08, 0.08, 0.7), (0, 0, 0), C('steel'))
    m.boxb((x, y, 0.7), (1.2, 0.9, 0.08), (0, 0, 0), C('steel'))
    m.cham((x, y - 0.1, 0.78), (0.8, 0.55, 0.22), 0.05, C('orange'))
    if open:
        m.box((x, y + 0.2, 1.05), (0.8, 0.08, 0.5), (0.45, 0, 0), C('orange'))
    m.boxb((x - 0.1, y - 0.1, 1.0), (0.3, 0.25, 0.12), (0, 0, 0), C('box_purple'))


# --- accessoires exagérés (×1,35) ------------------------------------------------------------------------------------

def bollard(m, x, y, s=SCALE_PROPS, z=0.0):
    """Bollard noir à chapeau."""
    from palette import C
    m.cylb((x, y, z), 0.2 * s, 0.45 * s, C('dark'), 8)
    m.cylb((x, y, z + 0.45 * s), 0.3 * s, 0.14 * s, C('dark'), 8)


def cone(m, x, y, s=SCALE_PROPS):
    """Cône de chantier orange à bande blanche."""
    from palette import C
    m.boxb((x, y, 0), (0.5 * s, 0.5 * s, 0.06), (0, 0, 0), C('orange'))
    m.cylb((x, y, 0.06), 0.2 * s, 0.6 * s, C('orange'), 6, 0.25)
    m.cylb((x, y, 0.28 * s), 0.15 * s, 0.12 * s, C('white'), 6)


def ac_unit(m, x, y, z):
    """Groupe de climatisation de toiture."""
    from palette import C
    m.boxb((x, y, z), (0.9, 0.7, 0.5), (0, 0, 0), C('steel'))
    m.cylb((x, y, z + 0.5), 0.25, 0.04, C('dark'), 8)


def tail_lights(m, x, hw, z, c=None):
    """Feux arrière rouges (deux petites boîtes) sur la face -X d'un véhicule de demi-largeur hw."""
    from palette import C
    c = c or C('sign_red')
    for s in (-1, 1):
        m.box((x - 0.02, s * (hw - 0.2), z), (0.06, 0.28, 0.16), (0, 0, 0), c)


# --- export -------------------------------------------------------------------

def clear_scene():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me)


def empty(name, loc=(0, 0, 0), parent=None):
    ob = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = loc
    if parent is not None:
        ob.parent = parent
    return ob


def export_glb(path):
    for ob in bpy.context.scene.objects:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=path, export_format='GLB', use_selection=True,
        export_vertex_color='ACTIVE', export_all_vertex_colors=False,
        export_normals=True, export_tangents=False, export_yup=True,
        export_animations=False, export_extras=False, export_apply=False,
    )


def to_godot(v):
    """Position Blender → Godot (glTF Y-up) : (x, y, z) → (x, z, -y)."""
    return [round(v[0], 4), round(v[2], 4), round(-v[1], 4)]
