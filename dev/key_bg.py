"""
Cut a flat-colour or smooth-gradient background out of a picture by flood
filling inward from the border (interior pixels of the same colour survive).

Usage: python3 dev/key_bg.py in.jpeg out.png [--gradient] [--max 256]

Default compares each pixel with the corner colour (flat backgrounds).
--gradient compares each pixel with the neighbour it was reached from, so a
smooth rainbow background is cleared but a sharp outline stops the fill.
The result is trimmed to the subject and shrunk to --max pixels on a side.
"""
import sys
from collections import deque

from PIL import Image


def dist(a, b):
    return sum((a[i] - b[i]) ** 2 for i in range(3)) ** 0.5


def key_bg(src, dst, gradient=False, tol=None, max_side=256):
    img = Image.open(src).convert("RGBA")
    w, h = img.size
    px = img.load()
    tol = tol if tol is not None else (14 if gradient else 34)
    corner = [px[0, 0], px[w - 1, 0], px[0, h - 1], px[w - 1, h - 1]]
    ref = tuple(sum(c[i] for c in corner) // 4 for i in range(3))
    clear = [[False] * w for _ in range(h)]
    q = deque()
    for x in range(w):
        q.append((x, 0, None))
        q.append((x, h - 1, None))
    for y in range(h):
        q.append((0, y, None))
        q.append((w - 1, y, None))
    while q:
        x, y, frm = q.popleft()
        if not (0 <= x < w and 0 <= y < h) or clear[y][x]:
            continue
        p = px[x, y]
        base = frm if (gradient and frm is not None) else ref
        if frm is None and gradient:
            base = p  # border seeds always start clear in gradient mode
        if dist(p, base) > tol:
            continue
        clear[y][x] = True
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            q.append((nx, ny, p))
    # Remove the 1px halo of background-tinted edge pixels.
    out = img.copy()
    op = out.load()
    for y in range(h):
        for x in range(w):
            if clear[y][x]:
                op[x, y] = (0, 0, 0, 0)
    for _ in range(2):
        edge = []
        for y in range(h):
            for x in range(w):
                if op[x, y][3] and any(
                    0 <= nx < w and 0 <= ny < h and op[nx, ny][3] == 0
                    for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1))
                ):
                    edge.append((x, y))
        for x, y in edge:
            op[x, y] = (0, 0, 0, 0)
    box = out.getbbox()
    out = out.crop(box)
    out.thumbnail((max_side, max_side), Image.LANCZOS)
    out.save(dst)
    total = w * h
    opaque = sum(1 for a in out.getchannel("A").getdata() if a)
    print(f"{dst}: {w}x{h} -> {out.size}, subject {100 * opaque / (out.size[0] * out.size[1]):.0f}% of crop, "
          f"cleared {100 * sum(map(sum, clear)) / total:.0f}% of picture")


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    mx = 256
    if "--max" in sys.argv:
        mx = int(sys.argv[sys.argv.index("--max") + 1])
        args = [a for a in args if a != str(mx)]
    key_bg(args[0], args[1], gradient="--gradient" in sys.argv, max_side=mx)
