"""
Cuts the Persian Blue bath comic sheet (4 columns x 2 rows of panels, dark
divider lines between them) into 8 full-picture frames for the "bath_comic"
animation under Sprites/persian_blue/bath/.

Usage: python3 dev/slice_persian_bath.py ~/Downloads
"""
import os
import sys

from PIL import Image

COLS = [(6, 254), (259, 510), (515, 766), (771, 1020)]
ROWS = [(11, 243), (280, 552)]
FRAME = (248, 272)
UPSCALE = 3

def main(src: str) -> None:
    sheet = Image.open(os.path.join(src, "persoin cat bath .jpeg")).convert("RGB")
    out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Sprites", "persian_blue", "bath")
    os.makedirs(out_dir, exist_ok=True)
    i = 0
    for y0, y1 in ROWS:
        for x0, x1 in COLS:
            panel = sheet.crop((x0, y0, x1, y1))
            # Shorter panels sit centred on their own edge colour so all frames match in size.
            fill = panel.resize((1, 1), Image.BOX).getpixel((0, 0))
            canvas = Image.new("RGB", FRAME, fill)
            canvas.paste(panel, ((FRAME[0] - panel.width) // 2, (FRAME[1] - panel.height) // 2))
            canvas = canvas.resize((FRAME[0] * UPSCALE, FRAME[1] * UPSCALE), Image.LANCZOS)
            canvas.save(os.path.join(out_dir, "frame_%02d.png" % i))
            i += 1
    print(i, "frames", FRAME[0] * UPSCALE, "x", FRAME[1] * UPSCALE)

if __name__ == "__main__":
    main(os.path.expanduser(sys.argv[1]))
