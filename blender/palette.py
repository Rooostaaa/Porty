# Palette partagée Blender / Godot / UI : lecture de palette.json (couleurs sRGB hexadécimales).
import json, os

HERE = os.path.dirname(os.path.abspath(__file__))
PATH = os.path.join(HERE, 'palette.json')

_cache = None


def load():
    global _cache
    if _cache is None:
        with open(PATH, encoding='utf-8') as f:
            _cache = json.load(f)
    return _cache


def hexc(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def C(name):
    """Couleur sRGB (0..1) d'une entrée de palette. Aucune couleur n'est écrite à la main dans les modèles."""
    return hexc(load()[name])


def copy_to(dst):
    """Copie la palette vers le projet Godot (UI et matériaux)."""
    with open(dst, 'w', encoding='utf-8') as f:
        json.dump(load(), f, indent=2)
