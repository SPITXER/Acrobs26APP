#!/usr/bin/env python3
"""Approximate the CSS layout in PIL so we can eyeball desktop & mobile."""
import os, re
from PIL import Image, ImageDraw, ImageFont
H = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
A = os.path.join(H, "assets")
def L(n): return Image.open(os.path.join(A, n)).convert("RGBA")

def clamp_px(expr, W, Hh):
    expr = expr.strip()
    if expr.endswith("px"): return float(expr[:-2])
    if expr.endswith("%"):  return float(expr[:-1]) / 100 * W
    m = re.match(r"clamp\((.+),(.+),(.+)\)", expr)
    if m:
        lo, mid, hi = [t.strip() for t in m.groups()]
        def val(t):
            if t.endswith("vw"): return float(t[:-2]) / 100 * W
            if t.endswith("vh"): return float(t[:-2]) / 100 * Hh
            if t.endswith("px"): return float(t[:-2])
            return float(t)
        return max(val(lo), min(val(mid), val(hi)))
    return float(expr)

def pct(p, total): return float(p.strip().rstrip("%")) / 100 * total

# config mirrored from main.js
BUILDINGS = [
    ("building_1.png", "19%", "58%", "clamp(92px,23vw,280px)"),
    ("building_2.png", "50%", "57%", "clamp(86px,20vw,250px)"),
    ("building_3.png", "81%", "59%", "clamp(92px,22vw,270px)"),
]
SCEN_BACK = [
    ("cypress.png","7%","50%","clamp(46px,7vw,92px)"),
    ("statue.png","33%","50%","clamp(40px,6vw,78px)"),
    ("broken_column.png","66%","51%","clamp(34px,5vw,66px)"),
    ("cypress.png","93%","49%","clamp(46px,7vw,96px)"),
    ("olive_bush.png","42%","52%","clamp(34px,5vw,66px)"),
]
SCEN_FRONT = [
    ("amphora.png","11%","78%","clamp(30px,4.5vw,58px)"),
    ("olive_bush.png","27%","82%","clamp(44px,7vw,86px)"),
    ("brazier.png","50%","74%","clamp(26px,4vw,52px)"),
    ("olive_bush.png","73%","83%","clamp(48px,7vw,90px)"),
    ("amphora.png","90%","79%","clamp(30px,4.5vw,56px)"),
]

def place(scene, item, W, Hh):
    img, x, top, w = item
    s = L(img)
    tw = int(clamp_px(w, W, Hh)); th = int(s.height * tw / s.width)
    s = s.resize((tw, th), Image.NEAREST)
    cx = int(pct(x, W)); by = int(pct(top, Hh))
    scene.alpha_composite(s, (cx - tw // 2, by - th))  # bottom-center anchor

def render(W, Hh, road_y, band_min, band_vh, band_max, name):
    earth = L("earth_tile.png").resize((240, 240), Image.NEAREST)
    scene = Image.new("RGBA", (W, Hh))
    for yy in range(0, Hh, 240):
        for xx in range(0, W, 240):
            scene.alpha_composite(earth, (xx, yy))
    # road band
    bandH = int(max(band_min, min(band_vh / 100 * Hh, band_max)))
    road = L("road_tile.png")
    rscale = bandH / road.height
    rw = int(road.width * rscale)
    road = road.resize((rw, bandH), Image.NEAREST)
    band = Image.new("RGBA", (W + rw, bandH))
    for xx in range(0, W + rw, rw):
        band.alpha_composite(road, (xx, 0))
    cy = int(road_y / 100 * Hh)
    scene.alpha_composite(band, (-rw // 2, cy - bandH // 2))
    # scenery back, buildings, scenery front
    for it in SCEN_BACK: place(scene, it, W, Hh)
    for it in BUILDINGS: place(scene, it, W, Hh)
    for it in SCEN_FRONT: place(scene, it, W, Hh)
    # crude title
    d = ImageDraw.Draw(scene)
    try: f = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf", int(W*0.06))
    except: f = ImageFont.load_default()
    t = "THE AGORA ROAD"
    tb = d.textbbox((0,0), t, font=f); tw = tb[2]-tb[0]
    d.text(((W-tw)//2, int(Hh*0.06)), t, font=f, fill=(252,240,216,255),
           stroke_width=2, stroke_fill=(122,90,58,255))
    out = scene.convert("RGB")
    out.save(f"/tmp/{name}")
    print("rendered", name, (W,Hh), "band", bandH)

# desktop
render(1280, 800, 56, 150, 27, 320, "preview_desktop.png")
# phone (portrait)
render(390, 844, 60, 120, 20, 200, "preview_mobile.png")
