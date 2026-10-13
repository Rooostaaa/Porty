# Empile verticalement plusieurs PNG (planches) en une seule image, du premier (en haut) au dernier (en bas).
#   blender -b -P montage.py -- <sortie.png> <entree1.png> <entree2.png> ...
import bpy, sys
import numpy as np

args = sys.argv[sys.argv.index('--') + 1:]
out, srcs = args[0], args[1:]
imgs = []
for p in srcs:
    im = bpy.data.images.load(p)
    w, h = im.size
    px = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)
    imgs.append(px)
W = max(a.shape[1] for a in imgs)
rows = []
for a in reversed(imgs):                       # les pixels Blender commencent en bas : le premier fini en haut
    h, w = a.shape[:2]
    if w < W:
        pad = np.zeros((h, W - w, 4), dtype=np.float32)
        pad[..., :3] = a[0, 0, :3]
        pad[..., 3] = 1.0
        a = np.concatenate([a, pad], axis=1)
    rows.append(a)
    rows.append(np.full((6, W, 4), (0.17, 0.18, 0.26, 1.0), dtype=np.float32))     # filet sombre entre planches
full = np.concatenate(rows[:-1], axis=0)
res = bpy.data.images.new('montage', W, full.shape[0], alpha=True)
res.pixels = full.ravel().tolist()
res.filepath_raw = out
res.file_format = 'PNG'
res.save()
print('montage', out, W, full.shape[0])
