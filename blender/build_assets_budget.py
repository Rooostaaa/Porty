# Budget de triangles par modèle (mêmes règles que build_assets.py, sans lancer la construction) : importé par
# preview_g.py pour la planche g_budget.png.
import os, re, ast

HERE = os.path.dirname(os.path.abspath(__file__))


def _load():
    """Lit BUDGET / EXACT / VEHICLES / PROPS et les constantes dans build_assets.py sans l'exécuter."""
    with open(os.path.join(HERE, 'build_assets.py'), encoding='utf-8') as f:
        src = f.read()
    ns = {}
    for name in ('BUILDING', 'PROP', 'BIG', 'TERRAIN'):
        ns[name] = int(re.search(r'^%s = (\d+)' % name, src, re.M).group(1))
    for name in ('BUDGET', 'EXACT', 'VEHICLES', 'PROPS'):
        m = re.search(r'^%s = (\{.*?^\}|\(.*?\))' % name, src, re.M | re.S)
        ns[name] = eval(m.group(1), dict(ns))
    return ns


_NS = _load()


def budget(name):
    if name in _NS['EXACT']:
        return _NS['EXACT'][name]
    for k in _NS['VEHICLES'] + _NS['PROPS']:
        if name.startswith(k):
            return _NS['PROP']
    for k, v in _NS['BUDGET'].items():
        if name.startswith(k):
            return v
    return _NS['BUILDING']
