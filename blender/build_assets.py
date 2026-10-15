# Construit tous les assets et les exporte en .glb.
#   blender -b -P build_assets.py -- --out C:\Nadir\tycoon_V2\godot\assets\models [--only nom1,nom2]
# Budget de triangles (docs/ORDRE_BLENDER_D.md § 3, règle 6) : ≤ 2 500 par bâtiment, ≤ 600 par accessoire ou véhicule,
# ≤ 2 500 par navire et grue. Un modèle au-dessus de son budget n'est PAS exporté et le script sort en erreur (code 2).
# assets_meta.json reçoit pour chaque modèle : tris, footprint [largeur X, profondeur Y] et anchor_y (sommet + 0,4 u :
# hauteur où poser la bulle d'information), plus les champs propres au modèle (slots, boom_tip…).
import sys, os, json, importlib
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, 'parts'))
import lib, palette
import terrain, buildings, equipment, ships, cargo, world, harbour, baie, crique, chantier, foret, marina, nuages, terreplein
MODULES = (terrain, buildings, equipment, ships, cargo, world, harbour, baie, crique, chantier, foret, marina, nuages, terreplein)
for mod in (lib, palette) + MODULES:
    importlib.reload(mod)

BUILDING = 2500
PROP = 600
BIG = 2500                 # navires et grues (portiques compris)
TERRAIN = 1200             # dalles de sol, de quai et de marquage
BUDGET = {
    'ship_': BIG, 'crane_': BIG, 'rtg': BIG, 'fishing_boat': BIG, 'breakwater': TERRAIN,
    'container': 100, 'reefer40': 100, 'flatrack': 150,
    'ground_': TERRAIN, 'quay': TERRAIN, 'road': TERRAIN, 'rail': TERRAIN, 'hill': TERRAIN, 'sidewalk': TERRAIN,
    'crosswalk': TERRAIN, 'yard_marks': TERRAIN, 'gate_lanes': TERRAIN, 'ghost_lot': TERRAIN, 'crane_rail': TERRAIN,
    'stack': TERRAIN,
}
VEHICLES = ('truck', 'tractor', 'forklift', 'locomotive', 'wagon', 'tug', 'pilot_boat', 'van', 'reach_stacker', 'straddle',
            'car_', 'barge')
PROPS = ('docker', 'customs_officer', 'inspector', 'manager', 'cone', 'barrel', 'pallet', 'sign', 'bollard', 'fender',
         'ladder', 'cleat', 'buoy', 'net_pile', 'crate_fish', 'gull', 'life_ring_post', 'lamp', 'fence', 'tree', 'bush',
         'rock', 'barrier', 'swatch', 'light_', 'zone_sign', 'riprap')


# Lot F (docs/ORDRE_BLENDER_F.md § 2) : budgets donnés modèle par modèle, prioritaires sur les préfixes.
EXACT = {
    'boat_dinghy': PROP, 'boat_trawler': BIG, 'boat_tuna': BIG, 'pontoon': PROP, 'pontoon_ruin': PROP,
    'fish_hall': BUILDING, 'ice_plant': BUILDING, 'odette_hut': BUILDING, 'jetty_ruin': BUILDING, 'fish_van': PROP,
    'site_hoarding': PROP, 'scaffold': PROP, 'site_crane': BIG, 'excavator': PROP, 'dust_pile': PROP,
    'tree_pine': PROP, 'tree_pine_b': PROP, 'tree_oak': PROP, 'forest_block': BUILDING, 'forest_road': BUILDING,
    'far_shore': BUILDING,
    # Lot G (docs/ORDRE_BLENDER_G.md § 2)
    'fuel_pump': PROP, 'wash_bay': BUILDING, 'pier_long': BUILDING, 'marina_pontoon': PROP, 'sailboat_a': PROP,
    'sailboat_b': PROP, 'yacht_small': PROP, 'marcel': PROP, 'ship_passing': 1200,
    'cloud_bank': PROP, 'cloud_puff': 200,
    'ground_platform': 200, 'quay_small': BUILDING, 'track_dirt': 200, 'track_dirt_turn': 200, 'barrier_post': PROP,
    'coaster_crane': PROP, 'container_wait': 200, 'container_ok': 200,
}


def budget(name):
    if name in EXACT:
        return EXACT[name]
    for k in VEHICLES + PROPS:
        if name.startswith(k):
            return PROP
    for k, v in BUDGET.items():
        if name.startswith(k):
            return v
    return BUILDING


def tri_count():
    n = 0
    for ob in bpy.context.scene.objects:
        if ob.type == 'MESH':
            me = ob.data
            me.calc_loop_triangles()
            n += len(me.loop_triangles)
    return n


def bounds():
    """Boîte englobante (repère Blender) de tous les maillages de la scène."""
    lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
    for ob in bpy.context.scene.objects:
        if ob.type != 'MESH':
            continue
        for c in ob.bound_box:
            w = ob.matrix_world @ Vector(c)
            lo = Vector(min(lo[i], w[i]) for i in range(3))
            hi = Vector(max(hi[i], w[i]) for i in range(3))
    return lo, hi


def main():
    args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    out = os.path.join(HERE, '..', 'godot', 'assets', 'models')
    only = None
    for i, a in enumerate(args):
        if a == '--out':
            out = args[i + 1]
        if a == '--only':
            only = set(args[i + 1].split(','))
    os.makedirs(out, exist_ok=True)
    all_assets = {}
    for mod in MODULES:
        all_assets.update(mod.ASSETS)
    meta_path = os.path.join(out, 'assets_meta.json')
    meta = {}
    if os.path.exists(meta_path):
        with open(meta_path, encoding='utf-8') as f:
            meta = json.load(f)
    over = []
    total = 0
    for name, fn in all_assets.items():
        if only and name not in only:
            continue
        lib.clear_scene()
        info = fn() or {}
        n = tri_count()
        total += n
        b = budget(name)
        lo, hi = bounds()
        flag = '' if n <= b else '  <-- DÉPASSE LE BUDGET %d : NON EXPORTÉ' % b
        if flag:
            over.append(name)
        print('ASSET %-18s %5d tris%s' % (name, n, flag))
        if flag:
            continue
        lib.export_glb(os.path.join(out, name + '.glb'))
        info['tris'] = n
        info['footprint'] = [round(hi.x - lo.x, 2), round(hi.y - lo.y, 2)]
        info.setdefault('anchor_y', round(hi.z + 0.4, 2))
        meta[name] = info
    with open(meta_path, 'w', encoding='utf-8') as f:
        json.dump(meta, f, indent=1)
    # la copie Godot de la palette n'est réécrite que si son contenu change (évite de toucher godot/data pour rien)
    dst = os.path.join(HERE, '..', 'godot', 'data', 'palette.json')
    try:
        with open(dst, encoding='utf-8') as f:
            same = json.load(f) == palette.load()
    except (OSError, ValueError):
        same = False
    if not same:
        palette.copy_to(dst)
    print('TOTAL %d assets, %d tris, hors budget : %s' % (len(meta), total, over or 'aucun'))
    if over:
        sys.exit(2)


main()
