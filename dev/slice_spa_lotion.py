# Cuts the spa lotion bottle out of its red-screen picture:
# ~/Downloads/spa lotoin .jpeg -> Sprites/spa_lotion_bottle.png (cropped, 320 px tall).
from PIL import Image, ImageFilter
import numpy as np, os

SRC = os.path.expanduser("~/Downloads/spa lotoin .jpeg")
OUT = "Sprites/spa_lotion_bottle.png"

# The bottle stands in the middle with a grey shelf behind its feet; take a box
# around it, then drop the red screen and the grey shelf that touches the box edge.
BOX = (386, 50, 644, 503)
a = np.array(Image.open(SRC).convert("RGB").crop(BOX)).astype(float)
r, g, b = a[..., 0], a[..., 1], a[..., 2]
redness = r - np.maximum(g, b)
alpha = np.clip(1.0 - (redness - 50.0) / 110.0, 0.0, 1.0)
alpha[redness <= 50.0] = 1.0
grey = ((np.abs(r - g) < 12) & (np.abs(g - b) < 12) & (r > 130) & (r < 205)) | ((np.minimum(np.minimum(r, g), b) > 200) & (np.maximum(np.maximum(r, g), b) - np.minimum(np.minimum(r, g), b) < 40))
seen = np.zeros(grey.shape, bool)
stack = [(y, x) for y in range(grey.shape[0]) for x in (0, grey.shape[1] - 1)] + [(y, x) for x in range(grey.shape[1]) for y in (0, grey.shape[0] - 1)]
while stack:
    y, x = stack.pop()
    if 0 <= y < grey.shape[0] and 0 <= x < grey.shape[1] and grey[y, x] and not seen[y, x]:
        seen[y, x] = True
        stack += [(y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)]
alpha[seen] = 0.0
# (old note) The grey shelf under the bottle is not part of it: keep the largest blob only.
mask = alpha > 0.5
rows = np.nonzero(mask.any(axis=1))[0]
cols = np.nonzero(mask.any(axis=0))[0]
# Remove red fringe from the edge pixels.
spill = np.maximum(g, b) + 25.0
r2 = np.where(redness > 0, np.minimum(r, spill), r)
rgba = np.dstack([r2, g, b, alpha * 255.0]).astype(np.uint8)
img = Image.fromarray(rgba)
# Tidy the edge by 1 px so no red halo is left.
al = img.getchannel("A").filter(ImageFilter.MinFilter(3))
img.putalpha(al)
print("bbox before crop:", img.getbbox())
img = img.crop(img.getbbox())
scale = 320.0 / img.height
img = img.resize((max(1, round(img.width * scale)), 320), Image.LANCZOS)
img.save(OUT)
arr = np.array(img)
print("saved", OUT, img.size, "opaque %.2f" % (arr[..., 3] > 128).mean())
red_left = ((arr[..., 0].astype(int) - np.maximum(arr[..., 1], arr[..., 2]).astype(int)) > 60) & (arr[..., 3] > 128)
print("red-ish opaque pixels left:", int(red_left.sum()))
