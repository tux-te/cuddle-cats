"""
Cuts the green-screen "Persian Blue" cat sheets (1024x559, several poses each) into
transparent frames under Sprites/persian_blue/.

Usage: python3 dev/slice_persian_blue.py ~/Downloads

Each pose animation is a list of cells (x0, x1, y0, y1) read left-to-right,
top-to-bottom. The green is keyed out, each frame is cropped to the figure,
and every frame of one animation shares a canvas (feet on the bottom edge,
centred) scaled so the tallest figure is FIGURE_H pixels high.
"""
import os
import sys

import numpy as np
from PIL import Image

KEY = np.array([33, 114, 38])
FIGURE_H = 400
INSET = 8
EDGE = 12  # the sheets have a JPEG noise line right at their border

def quad(split_y=280):
    return [(EDGE, 512, EDGE, split_y), (512, 1024 - EDGE, EDGE, split_y),
            (EDGE, 512, split_y, 559 - EDGE), (512, 1024 - EDGE, split_y, 559 - EDGE)]

def six(c3_top_split, c3_bottom_x=654):
    cols = [(EDGE, 332), (332, 654), (c3_bottom_x, 1024 - EDGE)]
    splits = [280, 265, c3_top_split]
    top = [(x0, x1, EDGE, s) for (x0, x1), s in zip(cols, splits)]
    bottom = [(x0, x1, s, 559 - EDGE) for (x0, x1), s in zip(cols, splits)]
    return top + bottom

SHEETS = {
    "stand": ("blue grey puersun .jpeg", [(EDGE, 1024 - EDGE, EDGE, 559 - EDGE)]),
    "walk": ("walk .jpeg", quad()),
    "jump": ("persoin biue jump.jpeg", quad()),
    "dance": ("persoin cats dances .jpeg", quad()),
    "eat": ("persoin eats in 4 imiges .jpeg", six(256)),
    "sleep": ("person goes to sleep.jpeg", six(262)),
}

def cut(img, cell):
    x0, x1, y0, y1 = cell
    # The sheets have thin dark divider lines between panels; stay clear of them.
    x0, x1, y0, y1 = x0 + INSET, x1 - INSET, y0 + INSET, y1 - INSET
    rgb = np.array(img.crop((x0, y0, x1, y1)).convert("RGB")).astype(int)
    dist = np.abs(rgb - KEY).sum(axis=2)
    # Soft edge: fully clear near the key colour, fully kept well away from it.
    alpha = np.clip((dist - 50) / 60.0, 0, 1)
    # Despill: pull leftover green off the edge pixels.
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    g = np.minimum(g, np.maximum(r, b) + 10)
    out = np.dstack([r, g, b, alpha * 255]).astype(np.uint8)
    frame = Image.fromarray(out)
    # Drop stray specks: keep only rows/cols that hold real figure pixels.
    solid = alpha > 0.5
    ys, xs = np.where(solid)
    if len(ys) < 200:
        return None
    box = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
    return frame.crop(box)

def main(src: str) -> None:
    dest = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Sprites", "persian_blue")
    for name, (filename, cells) in SHEETS.items():
        sheet = Image.open(os.path.join(src, filename))
        frames = [f for f in (cut(sheet, c) for c in cells) if f is not None]
        top = max(f.height for f in frames)
        scale = FIGURE_H / top
        frames = [f.resize((max(1, round(f.width * scale)), max(1, round(f.height * scale))), Image.LANCZOS) for f in frames]
        width = max(f.width for f in frames)
        out_dir = os.path.join(dest, name)
        os.makedirs(out_dir, exist_ok=True)
        for i, f in enumerate(frames):
            canvas = Image.new("RGBA", (width, FIGURE_H), (0, 0, 0, 0))
            canvas.paste(f, ((width - f.width) // 2, FIGURE_H - f.height), f)
            canvas.save(os.path.join(out_dir, "frame_%02d.png" % i))
        print(name, len(frames), "frames", width, "x", FIGURE_H)

if __name__ == "__main__":
    main(os.path.expanduser(sys.argv[1]))
