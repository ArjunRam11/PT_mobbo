"""Turns the AI-generated source PNGs (art_src/) into game-ready sprites (sprites/).

    python tools/prepare_art.py

- Green screen (#00FF00-ish) -> transparency, with edge de-spill, and the
  darker green of the contact shadow turned into a soft black shadow.
- Generator corner mark (bottom-right sparkle) cropped / masked out.
- Crops to content and reports the crop offset (rig_showcase.gd's anchor
  coordinates are in the *cropped* image).
art_src/ has a .gdignore, so the big originals are not imported or exported.
"""
import os
import shutil

import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SRC = os.path.join(ROOT, "art_src")
OUT = os.path.join(ROOT, "sprites")


def adopt(name):
    """Move a freshly dropped PNG from sprites/ into art_src/ (once)."""
    os.makedirs(SRC, exist_ok=True)
    open(os.path.join(SRC, ".gdignore"), "a").close()
    src, dst = os.path.join(OUT, name), os.path.join(SRC, name)
    if os.path.exists(src):
        shutil.move(src, dst)
        imp = src + ".import"
        if os.path.exists(imp):
            os.remove(imp)
    return dst


def key_green(img, mark_box=None):
    a = np.asarray(img.convert("RGB")).astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    other = np.maximum(r, b)
    greenness = g - other                         # >0 for screen pixels
    # Typical screen colour (median of clearly-green pixels) for the shadow estimate.
    screen = greenness > 120
    bg_g = float(np.median(g[screen])) if screen.any() else 235.0
    # Foreground alpha: 1 where not green, fades out over a soft band.
    alpha = np.clip(1.0 - (greenness - 25.0) / 60.0, 0.0, 1.0)
    # De-spill: pull green down to the other channels on edge/foreground pixels.
    g2 = np.where(greenness > 0, np.minimum(g, other + 8.0), g)
    # Shadow: screen pixels darker than the screen -> black with low alpha.
    shadow = np.clip((bg_g - g) / bg_g * 1.6, 0.0, 0.55) * (alpha < 0.5)
    shadow[shadow < 0.05] = 0.0
    out_rgb = np.stack([r, g2, b], -1)
    out_rgb = out_rgb * alpha[..., None]          # shadow pixels go black
    out_a = np.maximum(alpha, shadow)
    if mark_box is not None:
        x0, y0, x1, y1 = mark_box
        out_a[y0:y1, x0:x1] = 0.0
    rgba = np.dstack([out_rgb, out_a * 255.0]).clip(0, 255).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA"), alpha > 0.5


def crop_to_content(img, fg, pad=60):
    """Crop to the solid subject (not its faint shadow) plus `pad`, and fade
    the shadow out toward the crop edge so it never ends in a hard line."""
    ys, xs = np.where(fg)
    x0, y0 = max(0, xs.min() - pad), max(0, ys.min() - pad)
    x1, y1 = min(img.width, xs.max() + pad + 1), min(img.height, ys.max() + pad + 1)
    cut = img.crop((x0, y0, x1, y1))
    a = np.asarray(cut).astype(np.float32).copy()
    hh, ww = a.shape[:2]
    yy, xx = np.mgrid[0:hh, 0:ww]
    edge = np.minimum(np.minimum(xx, ww - 1 - xx), np.minimum(yy, hh - 1 - yy))
    fade = np.clip(edge / float(pad), 0.0, 1.0)
    fgc = fg[y0:y1, x0:x1]
    a[..., 3] = np.where(fgc, a[..., 3], a[..., 3] * fade)
    return Image.fromarray(a.astype(np.uint8), "RGBA"), (int(x0), int(y0))


def hero():
    src = adopt("rig_hero.png")
    img = Image.open(src)
    w, h = img.size
    keyed, fg = key_green(img, mark_box=(int(w * 0.86), int(h * 0.78), w, h))
    fg[int(h * 0.78):, int(w * 0.86):] = False
    cut, off = crop_to_content(keyed, fg)
    cut.save(os.path.join(OUT, "rig_hero_cut.png"))
    print("rig_hero_cut.png", cut.size, "crop offset", off)


def glow_sheet():
    src = adopt("sensor_glow_sheet.png")
    img = Image.open(src).convert("RGB")
    frames = 8
    cw = img.width // frames
    fw, fh = 256, 192
    strip = Image.new("RGB", (fw * (frames - 1), fh), (0, 0, 0))
    # Frame 8 carries the generator mark on the glow -> use frames 1..7.
    for i in range(frames - 1):
        cell = np.asarray(img.crop((i * cw, 0, (i + 1) * cw, img.height))).astype(np.float32)
        lum = cell.sum(-1)
        ys, xs = np.where(lum > lum.max() * 0.6)
        cx, cy = int(xs.mean()), int(ys.mean())
        box = (i * cw + cx - fw // 2, cy - fh // 2, i * cw + cx + fw // 2, cy + fh // 2)
        frame = np.asarray(img.crop(box)).astype(np.float32)
        # The sheet's "black" is a dark grey haze: subtract the frame's own
        # border level and feather to 0 at the edges, so additive blending
        # shows only the glow (no faint rectangle).
        border = np.concatenate([frame[:6].reshape(-1, 3), frame[-6:].reshape(-1, 3),
                                 frame[:, :6].reshape(-1, 3), frame[:, -6:].reshape(-1, 3)])
        frame = np.clip(frame - np.percentile(border, 90, axis=0) - 4.0, 0, 255)
        yy, xx = np.mgrid[0:fh, 0:fw]
        rr = np.sqrt(((xx - fw / 2) / (fw / 2)) ** 2 + ((yy - fh / 2) / (fh / 2)) ** 2)
        frame *= np.clip((1.0 - rr) / 0.35, 0.0, 1.0)[..., None]
        strip.paste(Image.fromarray(frame.astype(np.uint8)), (i * fw, 0))
    strip.save(os.path.join(OUT, "sensor_glow_strip.png"))
    print("sensor_glow_strip.png", strip.size, "7 frames of", (fw, fh))


def background():
    src = adopt("background.png")
    img = Image.open(src).convert("RGB")
    w, h = img.size
    # Keep 16:9, drop the bottom-right corner that holds the mark.
    cw = int(w * 0.84)
    ch = int(cw * 9 / 16)
    img.crop((0, 0, cw, ch)).save(os.path.join(OUT, "bg_main.png"))
    print("bg_main.png", (cw, ch))


def boards():
    # Not used in game (low front camera angle doesn't match rig_hero), kept as source only.
    adopt("rig_boards.png")


if __name__ == "__main__":
    hero()
    glow_sheet()
    background()
    boards()


# -- Person sway sheet + hero without the person ---------------------------------------

def _hero_person_mask(hero_rgba):
    """Pixels of the person in rig_hero_cut.png (not boards/box/cables/shadow)."""
    from scipy import ndimage
    a = np.asarray(hero_rgba).astype(np.float32)
    rgb, alpha = a[..., :3], a[..., 3]
    hsv = np.asarray(Image.fromarray(rgb.astype(np.uint8)).convert("HSV")).astype(np.float32)
    hue, sat, val = hsv[..., 0] * 360 / 255, hsv[..., 1] / 255, hsv[..., 2] / 255
    wood = (hue > 12) & (hue < 48) & (sat > 0.28) & (val > 0.28)
    h, w = alpha.shape
    yy, xx = np.mgrid[0:h, 0:w]
    upper = (yy < 470) & (xx > 196) & (xx < 412)             # head, torso, arms
    lower = (yy >= 470) & (yy < 618) & (xx > 224) & (xx < 398) & ~wood  # legs, shoes
    m = (alpha > 140) & (upper | lower)
    m = ndimage.binary_opening(m, iterations=1)
    # keep the big blob (the person)
    lab, n = ndimage.label(m)
    if n > 1:
        sizes = ndimage.sum(m, lab, range(1, n + 1))
        m = lab == (1 + int(np.argmax(sizes)))
    return ndimage.binary_dilation(m, iterations=3)


def _inpaint(rgba, mask, iters=300):
    """Fill masked pixels from their neighbours (diffusion) -- RGBA, premultiplied."""
    from scipy import ndimage
    a = rgba.astype(np.float32).copy()
    prem = a[..., :3] * (a[..., 3:4] / 255.0)
    data = np.dstack([prem, a[..., 3]])
    known = ~mask
    data[mask] = 0.0
    k = np.array([[0, 1, 0], [1, 0, 1], [0, 1, 0]], np.float32)
    for _ in range(iters):
        s = np.stack([ndimage.convolve(data[..., c] * known, k, mode="nearest") for c in range(4)], -1)
        n = ndimage.convolve(known.astype(np.float32), k, mode="nearest")
        fill = mask & (n > 0)
        data[fill] = s[fill] / n[fill][:, None]
        known = known | fill
    out_a = data[..., 3]
    out_rgb = np.where(out_a[..., None] > 0, data[..., :3] / np.maximum(out_a[..., None], 1) * 255.0, 0)
    return np.dstack([out_rgb, out_a]).clip(0, 255).astype(np.uint8)


# Board top corners in rig_hero_cut.png (same numbers as rig_photo_showcase.gd).
BOARD_CORNERS = [(236, 511), (61, 579), (220, 695), (395, 627), (380, 482), (262, 515), (397, 620), (554, 557)]
PLANK_DIR = (0.80, 0.60)   # planks run front-to-back: image down-right


def _remove_person(base, hm):
    from PIL import ImageDraw
    h, w = hm.shape
    pts = np.array(BOARD_CORNERS, np.float32)
    # convex hull of the 8 corners = both boards + the gap between them
    c = pts.mean(0)
    order = np.argsort(np.arctan2(pts[:, 1] - c[1], pts[:, 0] - c[0]))
    hull_img = Image.new("L", (w, h), 0)
    ImageDraw.Draw(hull_img).polygon([tuple(p) for p in pts[order]], fill=255)
    board = np.asarray(hull_img) > 0
    # Around the old feet, also take out the dark sole edges / contact
    # shadow (wood-coloured, so not in the person mask) -- otherwise they get
    # copied along the grain as dark streaks.
    from scipy import ndimage
    rgb = base[..., :3].astype(np.float32)
    val = rgb.max(-1) / 255.0
    near = ndimage.binary_dilation(hm, iterations=16)
    near[:500] = False
    dark = near & (val < 0.55)
    hm = ndimage.binary_dilation(hm | dark, iterations=3)
    hole = hm & board
    base[hm & ~board] = 0                       # off-board: transparent
    ys, xs = np.where(hole)
    d = np.array(PLANK_DIR, np.float32)
    acc = np.zeros((len(ys), 4), np.float32)
    wsum = np.zeros(len(ys), np.float32)
    for sign in (1.0, -1.0):
        found = np.zeros(len(ys), bool)
        for k in range(1, 260):
            sx = np.round(xs + sign * d[0] * k).astype(int)
            sy = np.round(ys + sign * d[1] * k).astype(int)
            ok = (~found) & (sx >= 0) & (sx < w) & (sy >= 0) & (sy < h)
            idx = np.where(ok)[0]
            good = board[sy[idx], sx[idx]] & ~hm[sy[idx], sx[idx]]
            hit = idx[good]
            if hit.size:
                wgt = 1.0 / k
                acc[hit] += base[sy[hit], sx[hit]].astype(np.float32) * wgt
                wsum[hit] += wgt
                found[hit] = True
            if found.all():
                break
    filled = wsum > 0
    base[ys[filled], xs[filled]] = (acc[filled] / wsum[filled][:, None]).clip(0, 255).astype(np.uint8)
    base[ys[~filled], xs[~filled]] = 0
    return base


def sway_sheet():
    """person_sway_sheet.jpg (4x3 grid on green) -> person_sway_strip.png, and
    rig_hero_cut.png with the person removed -> rig_base.png."""
    src = SRC + "/person_sway_sheet.jpg"
    if not os.path.exists(src):
        src = adopt("person_sway_sheet.jpg")
    else:
        adopt("person_sway_sheet.jpg")
    hero = Image.open(os.path.join(OUT, "rig_hero_cut.png")).convert("RGBA")
    hm = _hero_person_mask(hero)
    ys, xs = np.where(hm)
    hero_top = ys.min()
    front = xs < 300
    hero_bot = ys[front].max()
    hero_anchor = (float(xs[front & (ys > hero_bot - 6)].mean()), float(hero_bot))
    hero_h = hero_bot - hero_top

    # Base rig: person removed. Off the boards the hole just becomes
    # transparent; on the board tops each missing pixel is copied from intact
    # wood along the plank direction, so grain and the gap line continue.
    base = _remove_person(np.asarray(hero).copy(), hm)
    Image.fromarray(base, "RGBA").save(os.path.join(OUT, "rig_base.png"))

    sheet = Image.open(src).convert("RGB")
    cols, rows = 4, 3
    cw, ch = sheet.width / cols, sheet.height / rows
    FW, FH, AX, AY = 300, 640, 90, 620           # frame canvas + front-foot anchor
    frames, leans = [], []
    for j in range(rows):
        for i in range(cols):
            cell = sheet.crop((int(i * cw), int(j * ch), int((i + 1) * cw), int((j + 1) * ch)))
            keyed, fg = key_green(cell)
            arr = np.asarray(keyed).copy()
            arr[..., 3][~fg] = (arr[..., 3][~fg] * 0.0).astype(np.uint8)  # no shadow from the sheet
            ys, xs = np.where(fg)
            top, bot = ys.min(), ys.max()
            fx = float(xs[ys > bot - 6].mean())
            head_x = float(xs[ys < top + 0.12 * (bot - top)].mean())
            s = hero_h / float(bot - top)
            img = Image.fromarray(arr, "RGBA").resize((int(arr.shape[1] * s), int(arr.shape[0] * s)), Image.LANCZOS)
            canvas = Image.new("RGBA", (FW, FH), (0, 0, 0, 0))
            canvas.alpha_composite(img, (int(round(AX - fx * s)), int(round(AY - bot * s))))
            frames.append(canvas)
            leans.append((head_x - fx) * s)
    up = float(np.median([leans[k] for k in (0, 5, 6, 11)]))
    fwd_max, back_min = max(leans), min(leans)
    norm = [(l - up) / (fwd_max - up) if l >= up else -(l - up) / (back_min - up) for l in leans]
    strip = Image.new("RGBA", (FW * len(frames), FH), (0, 0, 0, 0))
    for k, f in enumerate(frames):
        strip.alpha_composite(f, (k * FW, 0))
    strip.save(os.path.join(OUT, "person_sway_strip.png"))
    print("rig_base.png", base.shape[1::-1], "hero front-foot anchor", tuple(round(v, 1) for v in hero_anchor), "person h", hero_h)
    print("person_sway_strip.png", strip.size, "frame", (FW, FH), "anchor", (AX, AY))
    print("lean px (head ahead of front foot):", [round(v, 1) for v in leans])
    print("lean norm (-1 back .. +1 forward):", [round(v, 2) for v in norm])
    print("head travel px fwd/back:", round(fwd_max - up, 1), round(up - back_min, 1))


# -- Game sprites ----------------------------------------------------------------------------

def _screen_colour(a):
    """Median of the border pixels = the flat backdrop colour."""
    border = np.concatenate([a[:4].reshape(-1, 3), a[-4:].reshape(-1, 3), a[:, :4].reshape(-1, 3), a[:, -4:].reshape(-1, 3)])
    greenish = border[(border[:, 1] - np.maximum(border[:, 0], border[:, 2])) > 100]
    return np.median(greenish if len(greenish) else border, axis=0)


def key_screen(img, lo=45.0, hi=115.0):
    """Key out the image's own flat green backdrop by colour distance (so green
    *objects* -- the marble, grass -- survive) and un-mix edge pixels."""
    a = np.asarray(img.convert("RGB")).astype(np.float32)
    scr = _screen_colour(a)
    dist = np.sqrt(((a - scr) ** 2).sum(-1))
    alpha = np.clip((dist - lo) / (hi - lo), 0.0, 1.0)
    al = np.maximum(alpha, 1e-3)[..., None]
    fg = np.clip((a - (1.0 - al) * scr) / al, 0, 255)          # un-mix the screen colour
    fg = np.where(alpha[..., None] >= 0.999, a, fg)
    return Image.fromarray(np.dstack([fg, alpha * 255]).clip(0, 255).astype(np.uint8), "RGBA")


def key_black(img, gamma=0.85):
    """Black backdrop -> alpha from brightness (for fire, smoke, sparkles)."""
    a = np.asarray(img.convert("RGB")).astype(np.float32) / 255.0
    alpha = np.clip(a.max(-1), 0, 1) ** gamma
    rgb = np.clip(a / np.maximum(alpha[..., None], 1e-3), 0, 1)
    return Image.fromarray((np.dstack([rgb, alpha]) * 255).astype(np.uint8), "RGBA")


def _trim(img, pad=2, min_alpha=12):
    al = np.asarray(img)[..., 3]
    ys, xs = np.where(al > min_alpha)
    return img.crop((max(0, xs.min() - pad), max(0, ys.min() - pad), min(img.width, xs.max() + pad + 1), min(img.height, ys.max() + pad + 1)))


def _sheet_union_trim(img, cols, rows, pad=2):
    """Crop every frame of a sheet to the union of their content boxes (keeps
    frames aligned) and rebuild the sheet. Returns (sheet, frame_size)."""
    fw, fh = img.width // cols, img.height // rows
    al = np.asarray(img)[..., 3]
    x0, y0, x1, y1 = fw, fh, 0, 0
    for j in range(rows):
        for i in range(cols):
            ys, xs = np.where(al[j * fh:(j + 1) * fh, i * fw:(i + 1) * fw] > 12)
            if len(xs):
                x0, y0 = min(x0, xs.min()), min(y0, ys.min())
                x1, y1 = max(x1, xs.max()), max(y1, ys.max())
    x0, y0 = max(0, x0 - pad), max(0, y0 - pad)
    x1, y1 = min(fw, x1 + pad + 1), min(fh, y1 + pad + 1)
    nw, nh = x1 - x0, y1 - y0
    out = Image.new("RGBA", (nw * cols, nh * rows), (0, 0, 0, 0))
    for j in range(rows):
        for i in range(cols):
            out.paste(img.crop((i * fw + x0, j * fh + y0, i * fw + x1, j * fh + y1)), (i * nw, j * nh))
    return out, (nw, nh)


GAME_SPRITES = {
    # name: (kind, extra)   kind: key = green screen, black = black backdrop,
    #                       copy = use as is (full-bleed image / tile)
    "ball": ("key", "trim"), "basket": ("key", "trim"), "heart": ("key", "trim"),
    "marble": ("key", "trim"), "paddle": ("key", "trim"), "pillar_cap": ("key", "trim"),
    "bg_bird_clouds": ("key", "trim"), "bg_bird_hills": ("key", None),
    "bg_coin_hills": ("key", None), "bg_coin_grass": ("key", None),
    "coin_sheet": ("key", (8, 1)), "bomb_sheet": ("key", (6, 1)),
    "bird_sheet": ("key", (4, 1)), "bird_robin_sheet": ("key", (4, 1)), "bird_goldfinch_sheet": ("key", (4, 1)),
    "explosion_sheet": ("black", None), "sparkle_sheet": ("black", None), "star_sparkle_sheet": ("black", None),
    "bg_bird_sky": ("copy", None), "bg_coin_sky": ("copy", None), "bg_pong_court": ("copy", None),
    "pillar_body": ("copy", None), "plank": ("copy", None),
}


def game_sprites():
    for name, (kind, extra) in GAME_SPRITES.items():
        src = os.path.join(SRC, name + ".png")
        if not os.path.exists(src):
            src = adopt(name + ".png")
        if not os.path.exists(src):
            print("missing", name)
            continue
        img = Image.open(src)
        if kind == "copy":
            out = img.convert("RGBA")
        elif kind == "black":
            out = key_black(img)
        else:
            out = key_screen(img)
        info = ""
        if extra == "trim":
            out = _trim(out)
        elif isinstance(extra, tuple):
            out, fsz = _sheet_union_trim(out, *extra)
            info = "frame %s" % (fsz,)
        out_name = "cloud" if name == "bg_bird_clouds" else name
        out.save(os.path.join(OUT, out_name + ".png"))
        print("%-22s -> %-22s %s %s" % (name, out_name + ".png", out.size, info))
    # Stills from the sheets for HUD chips / hub icons (replace the old SVGs).
    for sheet, frames, still, idx in [("coin_sheet", 8, "coin", 0), ("bomb_sheet", 6, "bomb", 0), ("bird_sheet", 4, "bird_mid", 1)]:
        s = Image.open(os.path.join(OUT, sheet + ".png"))
        fw = s.width // frames
        s.crop((idx * fw, 0, (idx + 1) * fw, s.height)).save(os.path.join(OUT, still + ".png"))
        print("still", still + ".png")
