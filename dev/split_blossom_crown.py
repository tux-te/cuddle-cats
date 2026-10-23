# Splits Princess Blossom's baked-in crown out of her cut-out so it can fall
# off while she naps. The crown sits between her ears in a fixed box (found by
# colour analysis); everything in that box becomes the crown piece and is
# removed from the body picture. Prints the crown box as fractions of the
# full picture for FRIENDS["blossom"]["crown"]["box"].
from PIL import Image
import numpy as np

SRC = "Sprites/friend_blossom.png"
BOX = (0.22, 0.0, 0.45, 0.17)  # x0, y0, x1, y1 as fractions

im = Image.open(SRC).convert("RGBA")
W, H = im.size
x0, y0, x1, y1 = int(BOX[0] * W), int(BOX[1] * H), int(BOX[2] * W), int(BOX[3] * H)
a = np.array(im)
crown = a[y0:y1, x0:x1].copy()
ys, xs = np.nonzero(crown[..., 3] > 10)
cx0, cx1, cy0, cy1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
Image.fromarray(crown[cy0:cy1, cx0:cx1]).save("Sprites/friend_blossom_crown.png")
a[y0:y1, x0:x1, 3] = 0
Image.fromarray(a).save("Sprites/friend_blossom_nocrown.png")
print("crown pixels", int((crown[..., 3] > 10).sum()), "piece size", cx1 - cx0, cy1 - cy0)
print("box fractions: x %.3f y %.3f w %.3f h %.3f" % ((x0 + cx0) / W, (y0 + cy0) / H, (cx1 - cx0) / W, (cy1 - cy0) / H))
