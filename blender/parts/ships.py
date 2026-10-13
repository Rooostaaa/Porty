# Navires (étrave vers +X, origine sur la ligne de flottaison) + empties slot_### pour poser les conteneurs.
# Registre C : coque colorée par classe de navire (le jeu ne teinte pas la coque : ship_view.gd pose seulement un
# pavillon à la couleur de l'armateur), château blanc à toit clair, cheminée de la couleur de la coque, canot orange,
# bouées, mât. Les conteneurs du pont sont posés par le jeu sur les slots : rien n'est modelé ici.
from lib import Model, empty, to_godot, mul
from palette import C

CW, CL, CH = 1.3, 4.0, 1.3      # conteneur 40' : largeur, longueur, hauteur


def _ship(name, L, W, H, wl, hull_low, hull_high, bays, rows, tiers, x0, bridge_x, bridge_levels, seed):
    m = Model(name, seed)
    keel = -H * wl
    m.hull(L, W, H, 0.22, 0.06, (0, 0, keel), hull_low, hull_high, wl, C('deck'))
    deck = keel + H
    # liston clair à la lisse et hiloires de cale
    m.boxb((0, 0, deck - 0.3), (L * 0.82, W * 0.985, 0.14), (0, 0, 0), C('white'))
    m.boxb((x0 + bays * CL / 2, 0, deck), (bays * CL + 0.4, rows * CW + 0.3, 0.25), (0, 0, 0), C('concrete_dark'))
    # château arrière : blanc, bandeau de la couleur de coque, toit clair, baies claires
    bw = W * 0.8
    m.boxb((bridge_x, 0, deck), (L * 0.09, bw, 0.6), (0, 0, 0), C('white'))
    for i in range(bridge_levels):
        m.boxb((bridge_x, 0, deck + 0.6 + i * 1.1), (L * 0.08, bw * (0.95 - i * 0.04), 1.1), (0, 0, 0), C('white'))
        m.box((bridge_x + L * 0.04 + 0.01, 0, deck + 1.2 + i * 1.1), (0.05, bw * 0.7, 0.4), (0, 0, 0), C('glass_light'))
    m.box((bridge_x, 0, deck + 0.9), (L * 0.09 + 0.02, bw + 0.02, 0.3), (0, 0, 0), hull_high)
    top = deck + 0.6 + bridge_levels * 1.1
    m.boxb((bridge_x, 0, top), (L * 0.1, W * 0.95, 0.25), (0, 0, 0), C('white'))     # ailerons de passerelle
    m.boxb((bridge_x, 0, top + 0.25), (L * 0.1 + 0.1, W * 0.95 + 0.1, 0.08), (0, 0, 0), C('cap_light'))
    m.cylb((bridge_x - L * 0.05, 0, top - 0.5), 0.45, 1.6, hull_high, 8)             # cheminée
    m.cylb((bridge_x - L * 0.05, 0, top + 0.8), 0.48, 0.35, C('dark'), 8)
    m.cylb((bridge_x + 0.2, 0, top + 0.33), 0.05, 1.4, C('steel'), 4)                # mât radar
    m.box((bridge_x + 0.2, 0, top + 1.6), (0.08, 0.9, 0.12), (0, 0, 0), C('white'))
    # canot de sauvetage orange et bouées
    m.cyl((bridge_x + L * 0.02, bw / 2 + 0.3, top - 0.9), (0.35, 0.9, 0.3), (0, 0, 0), C('orange'), 6)
    for y in (-1, 1):
        m.cyl((bridge_x - L * 0.045 + 0.05, y * (bw / 2 + 0.01), deck + 1.5), (0.22, 0.22, 0.06), (1.5708, 0, 0), C('sign_red'), 8)
    # mât avant et feux
    m.cylb((L / 2 - L * 0.12, 0, deck), 0.1, 2.5, C('yellow'), 5)
    m.ico((L / 2 - L * 0.12, 0, deck + 2.55), (0.12, 0.12, 0.12), (0, 0, 0), C('sign_red'), 0)
    m.to_object(name)
    slots = []
    for t in range(tiers):
        for b in range(bays):
            for r in range(rows):
                x = x0 + CL / 2 + b * CL
                y = (r - (rows - 1) / 2) * CW
                z = deck + 0.25 + t * CH
                e = empty('slot_%03d' % len(slots), (x, y, z))
                slots.append(to_godot((x, y, z)))
    return {'slots': slots, 'length': L, 'width': W, 'deck': round(deck, 3), 'keel': round(keel, 3)}


def ship_mini():
    # petit porte-conteneurs côtier : une cale de 2 × 2 conteneurs, une passerelle basse (premier navire du jeu)
    return _ship('ship_mini', 14.0, 4.2, 2.4, 0.45, C('hull_red'), C('hull_orange'), 2, 2, 1, -2.6, -5.0, 1, 60)


def ship_coaster():
    return _ship('ship_coaster', 22.0, 5.4, 3.0, 0.45, C('hull_red'), C('hull_green'), 3, 3, 2, -6.0, -8.3, 2, 61)


def ship_feeder():
    return _ship('ship_feeder', 36.0, 8.0, 3.8, 0.45, C('hull_red'), C('hull_navy'), 5, 5, 2, -9.5, -14.0, 3, 62)


def ship_panamax():
    return _ship('ship_panamax', 58.0, 11.0, 5.0, 0.42, C('hull_red'), C('hull_pink'), 9, 7, 2, -17.0, -23.0, 4, 63)


ASSETS = {'ship_mini': ship_mini, 'ship_coaster': ship_coaster, 'ship_feeder': ship_feeder, 'ship_panamax': ship_panamax}
