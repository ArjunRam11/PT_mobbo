"""UI kit + logo: art_src/*.png -> sprites/ui, sprites/game_ui, sprites/cards, sprites/logo
and a generated scripts/ui/ui_art_meta.gd (nine-slice margins, logo geometry).

    python tools/prepare_ui_art.py

Each sheet is cut into cells; every cell is keyed against ITS OWN border colour
(some sheets mix two greens), the generator's corner mark is dropped, and
buttons/cards/fields are measured so they can be used as nine-slice (stretchable)
styles: the soft glow around a shape becomes an "expand margin" so the shape
itself lines up with the control's edges.
"""
import json
import os
import shutil

import numpy as np
from PIL import Image
from scipy import ndimage

import prepare_art as P

ROOT = P.ROOT
SRC = P.SRC
SPR = P.OUT
META = os.path.join(ROOT, "scripts", "ui", "ui_art_meta.gd")


def src(name):
    """Original file: adopt it from sprites/ into art_src/ on first run."""
    path = os.path.join(SRC, name)
    if not os.path.exists(path):
        path = P.adopt(name)
    return path if os.path.exists(path) else None


def out_path(sub, name):
    d = os.path.join(SPR, sub)
    os.makedirs(d, exist_ok=True)
    return os.path.join(d, name + ".png")


def cells(img, cols, rows):
    cw, ch = img.width / cols, img.height / rows
    for j in range(rows):
        for i in range(cols):
            box = (int(round(i * cw)), int(round(j * ch)), int(round((i + 1) * cw)), int(round((j + 1) * ch)))
            yield j, i, box


def key_cell(img, box, lo=45.0, hi=115.0, sheet_size=None, drop_mark=True):
    """Key one cell against its own backdrop; drop the small generator mark if
    this cell holds the sheet's bottom-right corner."""
    cell = img.crop(box)
    out = P.key_screen(cell, lo, hi)
    if drop_mark and sheet_size is not None:
        W, H = sheet_size
        a = np.asarray(out).copy()
        al = a[..., 3] > 100
        lab, n = ndimage.label(al)
        area_cell = al.size
        for k in range(1, n + 1):
            ys, xs = np.where(lab == k)
            cx, cy = box[0] + xs.mean(), box[1] + ys.mean()
            if cx > W * 0.88 and cy > H * 0.82 and len(xs) < area_cell * 0.025:
                grow = ndimage.binary_dilation(lab == k, iterations=6)
                a[grow] = 0
        out = Image.fromarray(a, "RGBA")
    return out


def despill(img, keep=10.0):
    """Pull leftover green out of glows/edges on art that isn't meant to be green:
    green may not exceed the larger of red/blue (+keep)."""
    a = np.asarray(img).astype(np.float32).copy()
    a[..., 1] = np.minimum(a[..., 1], np.maximum(a[..., 0], a[..., 2]) + keep)
    return Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGBA")


def keep_largest(img):
    a = np.asarray(img).copy()
    al = a[..., 3] > 100
    lab, n = ndimage.label(al)
    if n > 1:
        sizes = ndimage.sum(al, lab, range(1, n + 1))
        keep = 1 + int(np.argmax(sizes))
        mask = ndimage.binary_dilation(lab == keep, iterations=12)
        a[~mask] = 0
    return Image.fromarray(a, "RGBA")


def nine_slice(img, shape_h, radius_frac, name, sub, meta, solid=200):
    """Crop to content, measure the glow pad around the solid shape, scale so
    the shape is `shape_h` px tall, and record nine-slice margins."""
    img = P._trim(img, pad=0, min_alpha=8)
    a = np.asarray(img)[..., 3]
    ys, xs = np.where(a > solid)
    sx0, sy0, sx1, sy1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
    k = shape_h / float(sy1 - sy0)
    img = img.resize((max(1, int(round(img.width * k))), max(1, int(round(img.height * k)))), Image.LANCZOS)
    pad = [sx0 * k, sy0 * k, (a.shape[1] - sx1) * k, (a.shape[0] - sy1) * k]   # l t r b
    r = shape_h * radius_frac
    img.save(out_path(sub, name))
    meta[sub + "/" + name] = {
        "expand": [round(v, 1) for v in pad],
        "margin": [round(pad[0] + r), round(pad[1] + r), round(pad[2] + r), round(pad[3] + r)],
    }


def fit_into(img, w, h):
    img = P._trim(img, pad=2)
    k = min(w / img.width, h / img.height)
    img = img.resize((max(1, int(img.width * k)), max(1, int(img.height * k))), Image.LANCZOS)
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    canvas.alpha_composite(img, ((w - img.width) // 2, (h - img.height) // 2))
    return canvas


# -- App UI ------------------------------------------------------------------------------

UI_ICONS = ["login", "signup", "power", "logout", "_signup2", "id_card",
            "home", "back", "usb", "plug", "refresh", "diagnostics",
            "sound_on", "sound_off", "music_on", "music_off", "play", "stop",
            "record", "save", "assessment", "chart", "report", "folder",
            "calendar", "timer", "level_up", "level_down", "settings", "warning",
            "success", "error", "scale", "target", "boards", "_shield"]
GAME_ICONS = ["trophy", "star_gold", "star_silver", "star_bronze", "clock", "level", "heart", "coin",
              "play", "pause", "restart", "home", "sound_on", "sound_off", "music", "medal"]
BTN_STATES = ["normal", "hover", "pressed", "disabled"]


def ui_kit(meta):
    p = src("ui_buttons_sheet.png")
    if p:
        img = Image.open(p).convert("RGB")
        variants = ["primary", "accent", "danger", "secondary"]
        for j, i, box in cells(img, 4, 4):
            if (j, i) == (3, 3):
                continue  # corner mark sits on it; disabled looks the same in every row
            c = key_cell(img, box, sheet_size=img.size)
            if variants[j] != "primary" or BTN_STATES[i] == "disabled":
                c = despill(c)
            nine_slice(c, 44, 0.3, "btn_%s_%s" % (variants[j], BTN_STATES[i]), "ui", meta)
        shutil.copy(out_path("ui", "btn_primary_disabled"), out_path("ui", "btn_secondary_disabled"))
        meta["ui/btn_secondary_disabled"] = meta["ui/btn_primary_disabled"]
    p = src("ui_cards_sheet.png")
    if p:
        img = Image.open(p).convert("RGB")
        names = ["card_plain", "card_section", "card_highlight", "chip"]
        for j, i, box in cells(img, 2, 2):
            c = keep_largest(key_cell(img, box, sheet_size=img.size))
            n = names[j * 2 + i]
            if n != "card_section":          # that one's glow is meant to be green
                c = despill(c)
            if n == "chip":
                nine_slice(c, 32, 0.5, n, "ui", meta)
            else:
                nine_slice(c, 150, 0.12, n, "ui", meta)
    p = src("ui_fields_sheet.png")
    if p:
        img = Image.open(p).convert("RGB")
        for j, i, box in cells(img, 3, 1):
            c = despill(keep_largest(key_cell(img, box, sheet_size=img.size)))
            nine_slice(c, 40, 0.28, "field_" + ["normal", "focus", "error"][i], "ui", meta)
    p = src("ui_toggle.png")
    if p:
        img = Image.open(p).convert("RGB")
        for j, i, box in cells(img, 2, 1):
            c = keep_largest(key_cell(img, box, sheet_size=img.size))
            if i == 0:
                c = despill(c)
            c = P._trim(c, pad=2)
            k = 64.0 / c.height
            c.resize((int(c.width * k), 64), Image.LANCZOS).save(out_path("ui", "toggle_" + ["off", "on"][i]))
    p = src("ui_icons_sheet.png")
    if p:
        img = Image.open(p).convert("RGB")
        for j, i, box in cells(img, 6, 6):
            n = UI_ICONS[j * 6 + i]
            if n.startswith("_"):
                continue
            c = key_cell(img, box, sheet_size=img.size)
            if n == "logout":
                c = c.transpose(Image.FLIP_LEFT_RIGHT)   # sheet repeated "login": mirror it
            fit_into(c, 96, 96).save(out_path("ui", "icon_" + n))
    print("ui kit done")


# -- Game UI ---------------------------------------------------------------------------------

def game_kit(meta):
    p = src("game_buttons_sheet.png")
    if p:
        img = Image.open(p).convert("RGB")
        colours = ["green", "orange", "blue", "red"]
        for j, i, box in cells(img, 4, 4):
            c = keep_largest(key_cell(img, box, sheet_size=img.size))
            if colours[j] != "green" or BTN_STATES[i] == "disabled":
                c = despill(c)
            nine_slice(c, 52, 0.48, "btn_%s_%s" % (colours[j], BTN_STATES[i]), "game_ui", meta)
    p = src("game_panels_sheet.png")
    if p:
        img = Image.open(p).convert("RGB")
        names = ["panel", "panel_ribbon", "chip_gold", "chip_red"]
        for j, i, box in cells(img, 2, 2):
            c = despill(keep_largest(key_cell(img, box, sheet_size=img.size)))
            n = names[j * 2 + i]
            if n.startswith("chip"):
                nine_slice(c, 56, 0.5, n, "game_ui", meta)
            else:
                nine_slice(c, 300, 0.16, n, "game_ui", meta)
        # the ribbon panel's banner sticks out above: keep a deeper top margin
        m = meta["game_ui/panel_ribbon"]["margin"]
        m[1] = int(m[1] * 1.9)
    p = src("game_icons_sheet.png")
    if p:
        img = Image.open(p).convert("RGB")
        for j, i, box in cells(img, 4, 4):
            c = key_cell(img, box, sheet_size=img.size)
            fit_into(c, 128, 128).save(out_path("game_ui", "icon_" + GAME_ICONS[j * 4 + i]))
    p = src("game_badges.png")
    if p:
        img = Image.open(p).convert("RGB")
        for j, i, box in cells(img, 3, 1):
            c = keep_largest(key_cell(img, box, sheet_size=img.size))
            c = P._trim(c, pad=2)
            k = 256.0 / c.height
            c.resize((int(c.width * k), 256), Image.LANCZOS).save(out_path("game_ui", "badge_" + ["bronze", "silver", "gold"][i]))
    for n in ["card_coin_collector", "card_floppy_bird", "card_ping_pong", "card_weight_shifting",
              "card_sit_assessment", "card_stepper", "card_locked"]:
        p = src(n + ".png")
        if not p:
            continue
        img = Image.open(p).convert("RGB")
        c = keep_largest(key_cell(img, (0, 0, img.width, img.height), sheet_size=img.size))
        c = P._trim(c, pad=2)
        k = 640.0 / c.width
        c.resize((640, int(c.height * k)), Image.LANCZOS).save(out_path("cards", n.replace("card_", "")))
    for n, dst in [("confetti_sheet.png", "game_ui/confetti_sheet"), ("logo_glow_sheet.png", "logo/glow_sheet")]:
        p = src(n)
        if not p:
            continue
        img = Image.open(p).convert("RGB")
        a = np.asarray(img).copy()
        H, W = a.shape[:2]
        a[int(H * 0.78):, int(W * 0.962):] = 0    # generator mark, in the (empty) last frame
        sheet = P.key_black(Image.fromarray(a))
        sheet = sheet.resize((W // 3, H // 3), Image.LANCZOS)
        sub, name = dst.split("/")
        sheet.save(out_path(sub, name))
    print("game kit done")


# -- Logo -------------------------------------------------------------------------------------

def logo(meta):
    p = src("logo_mark.png")
    if p:
        img = Image.open(p).convert("RGB")
        keyed = key_cell(img, (0, 0, img.width, img.height), lo=22.0, hi=55.0, sheet_size=img.size)
        a = np.asarray(keyed).astype(np.float32)
        r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
        solid = al > 120
        blue = solid & (b > g + 30) & (b > r + 60)
        green = solid & (g > r + 60) & (g > b + 30) & ~blue
        yellow = solid & (r > 170) & (g > 120) & (b < 120)
        white = solid & (r > 185) & (g > 185) & (b > 185)

        def comps(mask):
            lab, n = ndimage.label(mask)
            out = []
            for k in range(1, n + 1):
                ys, xs = np.where(lab == k)
                out.append({"mask": lab == k, "n": len(xs), "cx": xs.mean(), "cy": ys.mean(),
                            "x0": xs.min(), "x1": xs.max(), "y0": ys.min(), "y1": ys.max()})
            return out

        def biggest(mask):
            cs = comps(mask)
            return max(cs, key=lambda c: c["n"])["mask"] if cs else mask

        board_l, board_r = biggest(blue), biggest(green)
        # The sheet drew a faint duplicate arc+dot above the real one: keep the LOWER.
        ycs = [c for c in comps(yellow) if c["n"] > 300]
        dot = max(ycs, key=lambda c: c["cy"])
        wcs = [c for c in comps(white) if (c["x1"] - c["x0"]) > img.width * 0.18]
        arc = max(wcs, key=lambda c: c["cy"])
        # sensor dots: small white blobs inside the boards' boxes (kept in the board images)
        bl = ndimage.binary_fill_holes(board_l)
        br = ndimage.binary_fill_holes(board_r)
        sensors = [c for c in comps(white) if c["n"] < img.width * img.width * 0.002 and (bl[int(c["cy"]), int(c["cx"])] or br[int(c["cy"]), int(c["cx"])])]
        layers = {"board_l": bl, "board_r": br,
                  "arc": ndimage.binary_dilation(arc["mask"], iterations=3) & ~ndimage.binary_dilation(yellow, iterations=4),
                  "dot": ndimage.binary_dilation(dot["mask"], iterations=3)}
        union = np.zeros_like(bl)
        for m in layers.values():
            union |= m
        ys, xs = np.where(union)
        pad = 40
        x0, y0 = max(0, xs.min() - pad), max(0, ys.min() - pad)
        x1, y1 = min(img.width, xs.max() + pad), min(img.height, ys.max() + pad)
        S = 512.0 / (y1 - y0)
        size = (int((x1 - x0) * S), 512)
        rgba = np.asarray(keyed)
        for name, m in layers.items():
            mm = ndimage.binary_dilation(m, iterations=2)
            layer = rgba.copy()
            layer[~mm] = 0
            Image.fromarray(layer[y0:y1, x0:x1], "RGBA").resize(size, Image.LANCZOS).save(out_path("logo", name))
        # Arc geometry: top edge of the arc -> circle fit (canvas px).
        am = arc["mask"]
        cols = [x for x in range(arc["x0"] + 6, arc["x1"] - 6, 4)]
        pts = [(x, np.where(am[:, x])[0].min()) for x in cols if am[:, x].any()]
        X = np.array([((px - x0) * S, (py - y0) * S) for px, py in pts])
        A = np.c_[2 * X[:, 0], 2 * X[:, 1], np.ones(len(X))]
        bb = (X ** 2).sum(1)
        cx, cy, c = np.linalg.lstsq(A, bb, rcond=None)[0]
        rad = float(np.sqrt(c + cx * cx + cy * cy))
        dot_r = (dot["x1"] - dot["x0"]) * 0.5 * S
        meta["logo"] = {
            "size": list(size),
            "arc_center": [round(float(cx), 1), round(float(cy), 1)], "arc_radius": round(rad, 1),
            "arc_x": [round(float(X[:, 0].min()), 1), round(float(X[:, 0].max()), 1)],
            "dot": [round(float((dot["cx"] - x0) * S), 1), round(float((dot["cy"] - y0) * S), 1), round(float(dot_r), 1)],
            "sensors": [[round(float((s["cx"] - x0) * S), 1), round(float((s["cy"] - y0) * S), 1)] for s in sensors],
            "boards": [[round(float((c_["cx"] - x0) * S), 1), round(float((c_["cy"] - y0) * S), 1)]
                       for c_ in (max(comps(blue), key=lambda c: c["n"]), max(comps(green), key=lambda c: c["n"]))],
        }
    p = src("logo_full.png")
    if p:
        img = Image.open(p).convert("RGB")
        keyed = key_cell(img, (0, 0, img.width, img.height), lo=30.0, hi=90.0, sheet_size=img.size)
        a = np.asarray(keyed)
        occ = (a[..., 3] > 60).any(0)
        xs = np.where(occ)[0]
        # biggest empty gap between the mark (left) and the words (right)
        gaps = np.diff(xs)
        cut = xs[int(np.argmax(gaps))] + gaps.max() // 2
        words = Image.fromarray(a[:, cut:], "RGBA")
        words = P._trim(words, pad=4)
        k = 220.0 / words.height
        words.resize((int(words.width * k), 220), Image.LANCZOS).save(out_path("logo", "wordmark"))
    p = src("app_icon.png")
    if p:
        img = Image.open(p).convert("RGB")
        a = np.asarray(img).astype(np.float32)
        bg = np.median(a[:20, :20].reshape(-1, 3), 0)
        diff = np.abs(a - bg).sum(-1) > 18
        diff[int(a.shape[0] * 0.85):, int(a.shape[1] * 0.85):] = False   # mark corner
        ys, xs = np.where(ndimage.binary_opening(diff, iterations=3))
        sq = img.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
        side = max(sq.size)
        icon = sq.resize((256, 256), Image.LANCZOS)
        icon.save(out_path("logo", "app_icon"))
        icon.save(os.path.join(SPR, "logo", "app_icon.ico"), sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    for n in ["logo_mark_white.png", "mobboicon.png", "Concept Exploration.png", "logo_glow_sheet.png"]:
        src(n)   # keep originals in art_src only
    print("logo done")


def write_meta(meta):
    with open(META, "w", encoding="utf-8", newline="\n") as f:
        f.write("class_name UiArtMeta\nextends RefCounted\n")
        f.write("## GENERATED by tools/prepare_ui_art.py -- do not edit by hand.\n")
        f.write("## Nine-slice data per texture: expand = glow pad around the shape (l,t,r,b),\n")
        f.write("## margin = slice margins (l,t,r,b), all in texture px. \"logo\" = geometry of\n")
        f.write("## sprites/logo/* layers (canvas px): arc circle, dot (x,y,r), sensor dots.\n\n")
        f.write("const DATA := " + json.dumps(meta, indent=1).replace("\n", "\n") + "\n")
    print("wrote", META)


if __name__ == "__main__":
    meta = {}
    ui_kit(meta)
    game_kit(meta)
    logo(meta)
    write_meta(meta)
    print(json.dumps(meta.get("logo", {}), indent=1))
