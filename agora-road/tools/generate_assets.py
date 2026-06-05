#!/usr/bin/env python3
"""
Agora Road — pixel-art asset generator
--------------------------------------
Bakes every PNG used by the homepage background:
  - earth_tile.png      seamless ground (repeats in all directions)
  - road_tile.png       seamless horizontal cobblestone road (repeats left<->right)
  - cypress.png, olive_bush.png, amphora.png, broken_column.png,
    statue.png, brazier.png      decorative props
  - building_2.png, building_3.png   matching placeholder buildings (swap for yours)

Style is matched to the supplied agora icon: warm marble cream, terracotta,
stone-brown, soft olive greens — dithered, high pixel density.

Run:  python tools/generate_assets.py
"""
import os, math, random
from PIL import Image, ImageDraw
import numpy as np

random.seed(7)
np.random.seed(7)

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(HERE, "assets")
os.makedirs(OUT, exist_ok=True)

# ---- palette (sampled & extended from the reference icon) -------------------
P = {
    "marble_hi": (252, 240, 216), "marble": (240, 228, 200), "marble_lo": (214, 196, 158),
    "stone_hi": (200, 176, 132), "stone": (164, 138, 96), "stone_lo": (122, 96, 60),
    "stone_dk": (94, 70, 44), "grout": (74, 56, 36),
    "earth_hi": (150, 112, 74), "earth": (120, 86, 54), "earth_lo": (94, 64, 40),
    "grass_hi": (146, 156, 90), "grass": (110, 124, 62), "grass_lo": (82, 96, 46),
    "terra_hi": (218, 156, 122), "terra": (182, 110, 74), "terra_lo": (146, 84, 60),
    "gold": (204, 156, 84), "olive": (96, 110, 56),
    "cyp_hi": (96, 116, 74), "cyp": (66, 88, 56), "cyp_lo": (46, 64, 42),
    "trunk": (110, 78, 50), "shadow": (58, 42, 28),
}

def C(name): return P[name]

def newimg(w, h): return Image.new("RGBA", (w, h), (0, 0, 0, 0))

def save(img, name):
    img.save(os.path.join(OUT, name))
    print("  wrote", name, img.size)

# ---- tileable value noise ---------------------------------------------------
def tile_noise(w, h, cells_x, cells_y, octaves=1):
    """Periodic value noise in [0,1], seamless on both axes."""
    acc = np.zeros((h, w), dtype=np.float32)
    amp = 1.0
    total = 0.0
    for o in range(octaves):
        cx, cy = cells_x * (2 ** o), cells_y * (2 ** o)
        g = np.random.rand(cy, cx).astype(np.float32)
        # bilinear upscale with wrap
        ys = (np.arange(h) / h * cy)
        xs = (np.arange(w) / w * cx)
        y0 = np.floor(ys).astype(int); x0 = np.floor(xs).astype(int)
        fy = (ys - y0)[:, None]; fx = (xs - x0)[None, :]
        y1 = (y0 + 1) % cy; x1 = (x0 + 1) % cx
        y0 %= cy; x0 %= cx
        g00 = g[np.ix_(y0, x0)]; g01 = g[np.ix_(y0, x1)]
        g10 = g[np.ix_(y1, x0)]; g11 = g[np.ix_(y1, x1)]
        top = g00 * (1 - fx) + g01 * fx
        bot = g10 * (1 - fx) + g11 * fx
        acc += (top * (1 - fy) + bot * fy) * amp
        total += amp; amp *= 0.5
    acc /= total
    return acc

def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))

def bayer4():
    m = np.array([[0,8,2,10],[12,4,14,6],[3,11,1,9],[15,7,13,5]], dtype=np.float32)
    return (m + 0.5) / 16.0

BAYER = bayer4()
def dither_at(x, y):
    return BAYER[y % 4, x % 4]

# =============================================================================
# EARTH GROUND TILE  (seamless all directions)
# =============================================================================
def earth_tile(size=192):
    w = h = size
    n  = tile_noise(w, h, 6, 6, octaves=3)
    n2 = tile_noise(w, h, 16, 16, octaves=2)
    px = newimg(w, h).load()
    for y in range(h):
        for x in range(w):
            v = n[y, x] * 0.7 + n2[y, x] * 0.3
            v += (dither_at(x, y) - 0.5) * 0.12
            if v < 0.42:
                col = lerp(C("earth_lo"), C("earth"), v / 0.42)
            elif v < 0.72:
                col = lerp(C("earth"), C("earth_hi"), (v - 0.42) / 0.30)
            else:
                col = lerp(C("earth_hi"), C("stone_hi"), (v - 0.72) / 0.28)
            px[x, y] = col + (255,)
    img = Image.new("RGBA", (w, h)); img.putdata([])  # noop
    img = Image.frombytes if False else _from_px(px, w, h)
    # scatter seamless grass tufts & pebbles (wrap-aware)
    d = ImageDraw.Draw(img)
    rnd = random.Random(11)
    for _ in range(70):
        cx, cy = rnd.randint(0, w-1), rnd.randint(0, h-1)
        if rnd.random() < 0.55:
            _tuft(img, cx, cy, rnd)
        else:
            _pebble(img, cx, cy, rnd)
    return img

def _from_px(px, w, h):
    img = Image.new("RGBA", (w, h))
    img.putdata([px[x, y] for y in range(h) for x in range(w)])
    return img

def _wrapblit(img, stamp, cx, cy):
    """Blit a small RGBA stamp centered at cx,cy, wrapping across edges (seamless)."""
    w, h = img.size; sw, sh = stamp.size
    for dy in (-h, 0, h):
        for dx in (-w, 0, w):
            img.alpha_composite(stamp, (cx - sw // 2 + dx, cy - sh // 2 + dy))

def _tuft(img, cx, cy, rnd):
    s = newimg(11, 9); d = ImageDraw.Draw(s)
    base = rnd.choice(["grass", "grass_hi", "olive"])
    for bx in range(-3, 4):
        bh = rnd.randint(2, 6)
        shade = "grass_lo" if bx % 2 else base
        d.line([(5+bx, 8), (5+bx-rnd.randint(-1,1), 8-bh)], fill=C(shade)+(255,))
    _wrapblit(img, s, cx, cy)

def _pebble(img, cx, cy, rnd):
    r = rnd.randint(1, 2); s = newimg(r*2+3, r*2+3); d = ImageDraw.Draw(s)
    col = rnd.choice(["stone", "stone_hi", "stone_lo"])
    d.ellipse([1, 1, r*2+1, r*2+1], fill=C(col)+(255,))
    d.point([(2, 2)], fill=C("marble_hi")+(220,))
    _wrapblit(img, s, cx, cy)

# =============================================================================
# ROAD TILE  (seamless horizontally — cobblestone band with grass verges)
# =============================================================================
def road_tile(w=256, h=176, road_h=104):
    img = newimg(w, h)
    top = (h - road_h) // 2
    # --- cobblestones: running-bond bricks, integer columns => seamless x ----
    rows = 9
    brick_h = road_h / rows
    base_cols = 8                     # bricks per row at width w -> wraps
    bw = w / base_cols
    rnd = random.Random(23)
    cells = []
    for r in range(rows):
        off = (bw / 2) if (r % 2) else 0.0
        yy0 = top + r * brick_h
        yy1 = yy0 + brick_h
        # bricks; wrap the offset row by drawing one extra and clipping via wrap blit later
        x = -off
        while x < w:
            cells.append((x, yy0, x + bw, yy1, r))
            x += bw
    # bake cobbles to a numpy buffer for speed + per-pixel dither
    arr = np.zeros((h, w, 4), dtype=np.uint8)
    cob = tile_noise(w, h, 10, 6, octaves=2)
    for (x0, y0, x1, y1, r) in cells:
        bright = rnd.uniform(-0.12, 0.14)
        for yy in range(int(y0), int(math.ceil(y1))):
            if yy < top or yy >= top + road_h: continue
            for xxr in range(int(math.floor(x0)), int(math.ceil(x1))):
                xx = xxr % w
                # grout gaps
                edge = (xxr - x0 < 1.1) or (x1 - xxr < 1.4) or (yy - y0 < 1.0) or (y1 - yy < 1.4)
                if edge:
                    col = C("grout")
                else:
                    v = 0.5 + bright + (cob[yy, xx]-0.5)*0.5 + (dither_at(xx, yy)-0.5)*0.18
                    v = max(0.0, min(1.0, v))
                    if v < 0.5:
                        col = lerp(C("stone_dk"), C("stone"), v/0.5)
                    else:
                        col = lerp(C("stone"), C("stone_hi"), (v-0.5)/0.5)
                    # rounded shading top-left light, bottom-right dark
                    fx = (xxr - x0)/(x1-x0); fy=(yy-y0)/(y1-y0)
                    if fx+fy < 0.5: col = lerp(col, C("marble_hi"), 0.18)
                    if fx+fy > 1.5: col = lerp(col, C("shadow"), 0.22)
                arr[yy, xx] = (*col, 255)
    img = Image.fromarray(arr, "RGBA")
    # --- soft worn center track (lighter) ---
    d = ImageDraw.Draw(img)
    midy = top + road_h//2
    # --- grass verge that fades into transparency at very top/bottom edges ---
    verge = 22
    for yy in range(h):
        if yy < top:                 # upper verge
            t = yy / max(1, top)
            a = int(255 * (t**1.4))
            base = lerp(C("grass_lo"), C("grass"), t)
        elif yy >= top + road_h:     # lower verge
            t = (h-1 - yy) / max(1, h - (top+road_h))
            a = int(255 * (t**1.4))
            base = lerp(C("grass_lo"), C("grass_hi"), t)
        else:
            continue
        for xx in range(w):
            v = (tile_noise.__self__ if False else 0)
        # fill row with dithered grass
        for xx in range(w):
            n = 0.5 + (dither_at(xx, yy)-0.5)*0.5 + math.sin((xx+yy)*0.7)*0.05
            col = lerp(base, C("grass_hi"), max(0, min(1, n)))
            img.putpixel((xx, yy), (*col, a))
    # blend the road/verge seam with little grass blades poking onto stone
    rnd2 = random.Random(99)
    for _ in range(60):
        gx = rnd2.randint(0, w-1)
        for (gy, gh) in [(top, -4), (top+road_h, 4)]:
            s = newimg(5, 6); ds = ImageDraw.Draw(s)
            for b in range(-1, 2):
                ds.line([(2+b,5),(2+b,5-rnd2.randint(2,5))], fill=C(rnd2.choice(["grass","grass_hi"]))+(255,))
            _wrapblit(img, s, gx, gy)
    return img

# =============================================================================
# PROPS
# =============================================================================
def cypress():
    w, h = 56, 132
    img = newimg(w, h); d = ImageDraw.Draw(img)
    cx = w//2
    # trunk
    d.rectangle([cx-2, h-18, cx+1, h-4], fill=C("trunk")+(255,))
    # flame-like body via stacked ellipses, dithered
    arr = np.array(img)
    for y in range(8, h-12):
        # width profile: narrow top, bulge mid, taper bottom
        t = (y-8)/(h-20)
        rw = int( (math.sin(t*math.pi)**0.6) * 17 * (1-0.15*t) + 4 )
        for x in range(cx-rw, cx+rw+1):
            if not (0<=x<w): continue
            edge = abs(x-cx)/max(1,rw)
            v = 0.55 - edge*0.5 + (dither_at(x,y)-0.5)*0.35 + (tile_noise_cache(x,y))*0.25
            if v < 0.28: col = C("cyp_lo")
            elif v < 0.6: col = C("cyp")
            else: col = C("cyp_hi")
            # left light, right shadow
            if x < cx-rw*0.4: col = lerp(col, C("cyp_hi"), 0.25)
            if x > cx+rw*0.4: col = lerp(col, C("cyp_lo"), 0.3)
            arr[y, x] = (*col, 255)
    img = Image.fromarray(arr, "RGBA")
    return _ground_shadow(img, ry=6)

_NCACHE = tile_noise(64, 160, 8, 16, octaves=2)
def tile_noise_cache(x, y): return _NCACHE[y % 160, x % 64] - 0.5

def olive_bush():
    w, h = 60, 46; img = newimg(w, h); arr = np.array(img)
    cx, cy = w//2, h-16
    for y in range(2, h-6):
        for x in range(w):
            dx = (x-cx)/26.0; dy = (y-cy)/15.0
            if dx*dx+dy*dy <= 1.0:
                v = 0.5 - (dx*dx+dy*dy)*0.4 + (dither_at(x,y)-0.5)*0.4 + tile_noise_cache(x,y)*0.4
                if v < 0.3: col = C("grass_lo")
                elif v < 0.62: col = C("grass")
                else: col = C("grass_hi")
                if y < cy-6: col = lerp(col, C("grass_hi"), 0.2)
                arr[y, x] = (*col, 255)
    img = Image.fromarray(arr, "RGBA"); d = ImageDraw.Draw(img)
    rnd = random.Random(5)
    for _ in range(10):  # olives
        ox, oy = rnd.randint(cx-20,cx+20), rnd.randint(6,h-12)
        d.ellipse([ox,oy,ox+1,oy+1], fill=C("olive")+(255,))
    return _ground_shadow(img, ry=7)

def amphora():
    w, h = 34, 56; img = newimg(w, h); d = ImageDraw.Draw(img)
    cx = w//2
    body = [(cx, 10),(cx+11,20),(cx+9,40),(cx,48),(cx-9,40),(cx-11,20)]
    d.polygon(body, fill=C("terra")+(255,))
    d.polygon([(cx,10),(cx+11,20),(cx,26),(cx-11,20)], fill=C("terra_hi")+(255,))
    d.line([(cx-3,4),(cx-3,11)], fill=C("terra_lo")+(255,), width=2)  # neck
    d.rectangle([cx-5,2,cx+4,5], fill=C("terra_hi")+(255,))           # lip
    # handles
    d.arc([cx-15,14,cx-6,30], 60, 300, fill=C("terra_lo")+(255,), width=2)
    d.arc([cx+6,14,cx+15,30], 240, 120, fill=C("terra_lo")+(255,), width=2)
    # decorative band
    d.line([(cx-9,30),(cx+9,30)], fill=C("gold")+(255,))
    d.line([(cx-8,34),(cx+8,34)], fill=C("stone_dk")+(255,))
    return _ground_shadow(img, ry=5)

def broken_column():
    w, h = 40, 70; img = newimg(w, h); d = ImageDraw.Draw(img)
    cx = w//2; top = 16
    # fluted shaft
    for x in range(cx-9, cx+10):
        f = (x-cx)/9.0
        shade = 0.5 - f*0.45 + 0.15*math.cos((x-cx)*1.6)
        col = lerp(C("marble_lo"), C("marble_hi"), max(0,min(1,shade)))
        d.line([(x, top),(x, h-6)], fill=col+(255,))
    # broken jagged top
    d.polygon([(cx-9,top),(cx-5,top-5),(cx-1,top-1),(cx+3,top-6),(cx+9,top)], fill=C("marble")+(255,))
    # base block
    d.rectangle([cx-12, h-8, cx+11, h-2], fill=C("marble_lo")+(255,))
    d.rectangle([cx-12, h-8, cx+11, h-7], fill=C("marble_hi")+(255,))
    # a fallen drum beside it
    d.ellipse([cx+8, h-6, cx+22, h-1], fill=C("marble")+(255,))
    d.ellipse([cx+10, h-6, cx+15, h-2], fill=C("marble_hi")+(255,))
    return _ground_shadow(img, ry=6)

def statue():
    w, h = 44, 96; img = newimg(w, h); d = ImageDraw.Draw(img)
    cx = w//2
    # pedestal
    d.rectangle([cx-13, h-16, cx+12, h-2], fill=C("marble_lo")+(255,))
    d.rectangle([cx-13, h-16, cx+12, h-15], fill=C("marble_hi")+(255,))
    d.rectangle([cx-11, h-26, cx+10, h-16], fill=C("marble")+(255,))
    # robed figure (simple)
    body = [(cx-7,30),(cx+7,30),(cx+9,h-26),(cx-9,h-26)]
    d.polygon(body, fill=C("marble")+(255,))
    d.polygon([(cx-7,30),(cx,32),(cx-9,h-26)], fill=C("marble_hi")+(255,))  # lit side
    d.polygon([(cx+2,32),(cx+7,30),(cx+9,h-26),(cx+4,h-26)], fill=C("marble_lo")+(255,))
    # drapery lines
    for i in range(4):
        yy = 40+i*12
        d.line([(cx-6,yy),(cx+6,yy+3)], fill=C("marble_lo")+(180,))
    # head
    d.ellipse([cx-5,18,cx+5,30], fill=C("marble_hi")+(255,))
    d.ellipse([cx-5,15,cx+5,23], fill=C("marble")+(255,))  # hair/helm
    # raised arm hint
    d.line([(cx+6,34),(cx+12,24)], fill=C("marble")+(255,), width=3)
    return _ground_shadow(img, ry=7)

def brazier():
    w, h = 30, 50; img = newimg(w, h); d = ImageDraw.Draw(img)
    cx = w//2
    d.rectangle([cx-2, 18, cx+1, h-8], fill=C("stone_lo")+(255,))   # stem
    d.polygon([(cx-9,h-2),(cx+8,h-2),(cx+4,h-10),(cx-5,h-10)], fill=C("stone")+(255,))  # foot
    d.ellipse([cx-10, 12, cx+10, 24], fill=C("stone_lo")+(255,))    # bowl
    d.ellipse([cx-10, 10, cx+10, 20], fill=C("stone")+(255,))
    # flame
    d.polygon([(cx-5,14),(cx,2),(cx+5,14)], fill=C("gold")+(255,))
    d.polygon([(cx-3,14),(cx,7),(cx+3,14)], fill=C("terra_hi")+(255,))
    d.polygon([(cx-1,13),(cx,9),(cx+1,13)], fill=C("marble_hi")+(255,))
    return _ground_shadow(img, ry=5)

def _ground_shadow(img, ry=6):
    """Add a soft elliptical contact shadow at the base, return new image."""
    w, h = img.size
    pad = ry + 4
    out = newimg(w, h + pad)
    sh = newimg(w, pad*2); ds = ImageDraw.Draw(sh)
    ds.ellipse([w*0.18, 0, w*0.82, ry*2], fill=(*C("shadow"), 90))
    out.alpha_composite(sh, (0, h - ry))
    out.alpha_composite(img, (0, 0))
    return out

# =============================================================================
# PLACEHOLDER BUILDINGS  (matching style; meant to be swapped for the user's)
# =============================================================================
def iso_box(d, cx, by, bw, bh, ht, top_c, left_c, right_c):
    """Draw a simple isometric box. by = bottom-center y. returns top points."""
    hw = bw // 2; hh = bh // 2
    t = (cx, by - ht - hh*2)          # top apex (back)
    top = [(cx, by-ht-bh), (cx+hw, by-ht-hh), (cx, by-ht), (cx-hw, by-ht-hh)]
    # faces
    d.polygon([(cx-hw, by-ht-hh),(cx,by-ht),(cx,by),(cx-hw,by-hh)], fill=left_c)
    d.polygon([(cx+hw, by-ht-hh),(cx,by-ht),(cx,by),(cx+hw,by-hh)], fill=right_c)
    d.polygon(top, fill=top_c)
    return top

def building_temple():
    """Classical temple: stylobate, colonnade, terracotta pediment roof."""
    W, H = 300, 230
    img = newimg(W, H); d = ImageDraw.Draw(img)
    cx, by = W//2, H-26
    M=lambda k:C(k)+(255,)
    # circular stone base
    d.ellipse([cx-118, by-20, cx+118, by+30], fill=M("stone_lo"))
    d.ellipse([cx-118, by-26, cx+118, by+24], fill=M("stone"))
    # stylobate (3 steps)
    for i,(c) in enumerate(["terra_lo","terra","terra_hi"]):
        o=14-i*4
        d.polygon([(cx-92+o*1.4, by-22-i*7),(cx+92-o*1.4,by-22-i*7),
                   (cx+78-o, by-8-i*7),(cx-78+o,by-8-i*7)], fill=M(c))
    plat_y = by-22-2*7
    # columns
    n=6; span=150
    for i in range(n):
        colx = cx-75 + i*(span/(n-1))
        ch=70
        d.rectangle([colx-5, plat_y-ch, colx+5, plat_y], fill=M("marble_lo"))
        d.rectangle([colx-5, plat_y-ch, colx-1, plat_y], fill=M("marble_hi"))
        for fy in range(0,ch,3):  # flutes/shading
            d.point([(colx+3, plat_y-fy)], fill=M("marble_lo"))
        d.rectangle([colx-7, plat_y-ch-4, colx+7, plat_y-ch], fill=M("marble"))     # capital
        d.rectangle([colx-7, plat_y-2, colx+7, plat_y+2], fill=M("marble_lo"))      # base
    ent_y = plat_y-74
    # entablature
    d.polygon([(cx-84, ent_y),(cx+84, ent_y),(cx+72, ent_y+10),(cx-72, ent_y+10)], fill=M("marble"))
    d.polygon([(cx-84, ent_y),(cx+84, ent_y),(cx+84, ent_y-4),(cx-84,ent_y-4)], fill=M("marble_hi"))
    # pediment (triangular) with terracotta roof
    apex=(cx, ent_y-46)
    d.polygon([(cx-88, ent_y),(cx+88, ent_y),apex], fill=M("marble"))
    d.polygon([(cx-76, ent_y-3),(cx+76, ent_y-3),(cx, ent_y-38)], fill=M("marble_lo"))  # tympanum
    # roof tiles
    d.polygon([(cx-96, ent_y),(apex[0],apex[1]-6),(cx-78,ent_y)], fill=M("terra"))
    d.polygon([(cx+96, ent_y),(apex[0],apex[1]-6),(cx+78,ent_y)], fill=M("terra_lo"))
    for i in range(-8,9):
        d.line([(cx+i*9, ent_y-2),(apex[0], apex[1]-4)], fill=M("terra_hi"), width=1)
    return img

def building_stoa():
    """Stoa / market hall: long porch with columns + flat terracotta roof + awnings."""
    W, H = 320, 220
    img = newimg(W, H); d = ImageDraw.Draw(img); M=lambda k:C(k)+(255,)
    cx, by = W//2, H-24
    d.ellipse([cx-128, by-18, cx+128, by+28], fill=M("stone_lo"))
    d.ellipse([cx-128, by-24, cx+128, by+22], fill=M("stone"))
    # back wall block (iso)
    iso_box(d, cx+6, by-10, 150, 60, 64, M("marble"), M("marble_lo"), M("marble"))
    # terracotta roof slab on top
    ry=by-10-64-30
    d.polygon([(cx-78, ry+22),(cx+6, ry-8),(cx+90, ry+22),(cx+6, ry+52)], fill=M("terra"))
    d.polygon([(cx-78, ry+22),(cx+6, ry-8),(cx+6, ry+2),(cx-78,ry+32)], fill=M("terra_hi"))
    # front colonnade
    n=7
    for i in range(n):
        colx = cx-92 + i*26; cy0=by-6
        ch=62
        d.rectangle([colx-4, cy0-ch, colx+4, cy0], fill=M("marble_lo"))
        d.rectangle([colx-4, cy0-ch, colx-1, cy0], fill=M("marble_hi"))
        d.rectangle([colx-6, cy0-ch-4, colx+6, cy0-ch], fill=M("marble"))
        # striped awning between columns (market feel)
        if i<n-1:
            ax0=colx; ax1=colx+26
            for s in range(5):
                col = "terra" if s%2 else "marble_hi"
                d.polygon([(ax0+ s*5, cy0-ch-2),(ax0+s*5+5, cy0-ch-2),
                           (ax0+s*5+8, cy0-ch+10),(ax0+s*5+3, cy0-ch+10)], fill=M(col))
    return img

# =============================================================================
def main():
    print("Generating assets ->", OUT)
    save(earth_tile(192), "earth_tile.png")
    save(road_tile(), "road_tile.png")
    save(cypress(), "cypress.png")
    save(olive_bush(), "olive_bush.png")
    save(amphora(), "amphora.png")
    save(broken_column(), "broken_column.png")
    save(statue(), "statue.png")
    save(brazier(), "brazier.png")
    save(building_temple(), "building_2.png")
    save(building_stoa(), "building_3.png")
    print("done.")

if __name__ == "__main__":
    main()
