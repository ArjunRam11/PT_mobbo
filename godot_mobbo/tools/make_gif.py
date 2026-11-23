"""Assembles captured frames into an animated GIF.

    python tools/make_gif.py tests/screenshots/login_anim tests/screenshots/login_animation.gif [fps]
"""
import glob
import os
import sys

from PIL import Image

src, out = sys.argv[1], sys.argv[2]
fps = float(sys.argv[3]) if len(sys.argv) > 3 else 10.0
files = sorted(glob.glob(os.path.join(src, "frame_*.png")))
frames = [Image.open(f).convert("RGB").quantize(colors=200, method=Image.Quantize.MEDIANCUT) for f in files]
frames[0].save(out, save_all=True, append_images=frames[1:], duration=int(1000 / fps), loop=0, optimize=True)
print("wrote", out, len(frames), "frames")
