"""Build every binary asset for Little Mega People.

    python tools/build_assets.py

Inputs : art/source/*.png    Amiga Little Computer People screenshots
         C128 character ROM  (8x8 font; path below, optional fallback)
Outputs: assets/bg.prg       64000-byte FCM char image of the empty house
         assets/title.prg    64000-byte FCM char image of the guestbook title
         assets/gfx.prg      font + software sprites + cell patches (bank 5)
         src/gen/palette.asm 256-entry palette + nibble-swap table
         src/gen/assets.asm  sprite/patch addresses, pose anchors
         art/preview_*.png   visual checks of the generated data

Every image is FCM: 40x25 cells of 8x8 bytes, one byte = one palette index,
cells stored row-major (cell n = row n/40, column n%40), 64 bytes per cell.
"""
import os
import sys
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lmp_art as A  # noqa: E402

ROOT = A.ROOT
CHARGEN = r'C:\Users\scott\repos\c128-emu-m65\src\chargen-390059-01.bin'
CHARGEN_LOCAL = os.path.join(ROOT, 'art', 'chargen.bin')
LOGO_FONT = r'C:\Windows\Fonts\ROCKEB.TTF'
GFX_BASE = 0x50002          # gfx.prg body lands at $50000 + 2-byte PRG header
SND_RATE = 5000             # phone voice sample rate
SND_BASE = 0x18000          # where the voice lives in chip RAM (bank 1)

# ---------------------------------------------------------------------------
# Palette layout (see README / src/platform.asm for the same list)
# ---------------------------------------------------------------------------
HOUSE0 = 1                  # 1..17 = Amiga house colours (AMIGA_PAL + 1)
SKY, TVSCR, MONITOR, BOTTLE, FIRE_A, FIRE_B, FIRE_C = range(18, 25)
SKIN, HAIR, SHIRT, SHIRT2, PANTS, SHOES, PANTS2 = range(25, 32)
# Polka dots: sprinkled over his shirt and trousers in their own palette
# entries, the cloth's colour by day (invisible), pink on his pyjamas.
DOTS_SHIRT, DOTS_PANTS = 48, 49
# The attic stereo while a record plays: the tone-arm bar shimmers (two
# alternating entries), the front-panel lights flicker, a green power light.
SPIN_A, SPIN_B, VU_R1, VU_R2, VU_B, LED = range(50, 56)
# The water cooler's bottle in five bands, bottom up: each blue while the
# water reaches it, so the level drops as he drinks.
BOTTLE_BANDS = list(range(56, 61))
BOTTLE_ROWS = ((173, 175), (171, 172), (169, 170), (167, 168), (165, 166))
UI = 32                     # 32..47 UI colours
TITLE0 = 64                 # 64..71 guestbook colours
LOGO0 = 80                  # 80..143 logo gradient x antialias

PAL = [(0, 0, 0)] * 256
for i, c in enumerate(A.AMIGA_PAL):
    PAL[HOUSE0 + i] = c
PAL[SKY] = (0, 0, 221)
PAL[TVSCR] = (255, 255, 255)
PAL[MONITOR] = (0, 0, 0)
PAL[BOTTLE] = (0, 0, 221)
PAL[FIRE_A] = (255, 0, 0)
PAL[FIRE_B] = (238, 119, 0)
PAL[FIRE_C] = (255, 221, 0)
PAL[SKIN] = (255, 204, 153)
PAL[HAIR] = (238, 119, 0)
PAL[SHIRT] = (34, 102, 255)
PAL[SHIRT2] = (17, 51, 170)
PAL[PANTS] = (255, 255, 255)
PAL[SHOES] = (85, 34, 0)
PAL[PANTS2] = (170, 170, 170)
PAL[DOTS_SHIRT] = PAL[SHIRT]
PAL[DOTS_PANTS] = PAL[PANTS]
UI_COLS = [
    (153, 153, 153),  # 32 bar background
    (0, 0, 0),        # 33 text
    (136, 0, 0),      # 34 dark red text
    (255, 255, 255),  # 35 white
    (51, 204, 85),    # 36 green
    (255, 221, 0),    # 37 yellow
    (238, 34, 0),     # 38 red
    (255, 244, 214),  # 39 letter paper
    (17, 34, 119),    # 40 letter ink
    (204, 0, 0),      # 41 card red
    (17, 17, 17),     # 42 card black
    (34, 68, 204),    # 43 card back
    (17, 102, 51),    # 44 card table felt
    (85, 85, 85),     # 45 dark grey
    (255, 187, 85),   # 46 highlight / cursor
    (230, 214, 170),  # 47 paper shadow
]
for i, c in enumerate(UI_COLS):
    PAL[UI + i] = c
GUEST_COLS = [(0, 0, 0), (85, 0, 0), (85, 85, 85), (153, 153, 153), (170, 68, 0),
              (204, 204, 204), (238, 119, 0), (255, 255, 255)]
for i, c in enumerate(GUEST_COLS):
    PAL[TITLE0 + i] = c
# Logo: 16 vertical gradient steps (deep red -> orange -> gold), 4 coverage levels
# blended over the logo box grey.
BOX_GREY = (204, 204, 204)
GRAD = [(119, 0, 0), (170, 17, 0), (221, 51, 0), (255, 102, 0), (255, 153, 17), (255, 204, 51)]


def grad(t):
    t = max(0.0, min(1.0, t)) * (len(GRAD) - 1)
    i = min(int(t), len(GRAD) - 2)
    f = t - i
    return tuple(int(GRAD[i][k] + (GRAD[i + 1][k] - GRAD[i][k]) * f) for k in range(3))


for g in range(16):
    base = grad(g / 15)
    for a in range(4):
        al = (a + 1) / 4
        PAL[LOGO0 + g * 4 + a] = tuple(int(BOX_GREY[k] + (base[k] - BOX_GREY[k]) * al) for k in range(3))

# ---------------------------------------------------------------------------
# House image
# ---------------------------------------------------------------------------
# Cell rectangles (cx, cy, cw, ch) and the frame each patch's pixels come from.
PATCHES = {
    'door_open': (36, 18, 3, 6, None),        # the majority vote has the front door open
    'fridge_open': (3, 19, 3, 5, 'stairs'),
    # bedroom closet door open on his clothes (from the Amiga 'cards' frame)
    'closet_open': (9, 11, 3, 4, ('BEDCLOSET', 0)),
    # the attic closet open (Amiga 'piano' frame), with / without the vacuum
    'vac_closet': (22, 3, 3, 4, ('ATTICCLOSET', 1)),
    'vac_closet_empty': (22, 3, 3, 4, ('ATTICCLOSET', 0)),
    # a pot on the stove's right burner, a flame under it
    'pot_on': (0, 20, 3, 2, ('POT', 0)),
    'fire_lit': (32, 21, 3, 2, 'cards'),
    # living-room phone with the handset lifted off (empty cradle)
    'phone_off': (24, 21, 3, 1, ('PHONE', 0)),
    # bathroom WC door swung open (hinged on the left)
    'wc_open': (23, 11, 3, 4, ('WCDOOR', 0)),
    # kitchen food cupboard, doors open, with 0-4 jars on its two shelves
    'cupboard_0': (7, 17, 5, 4, ('CUPBOARD', 0)),
    'cupboard_1': (7, 17, 5, 4, ('CUPBOARD', 1)),
    'cupboard_2': (7, 17, 5, 4, ('CUPBOARD', 2)),
    'cupboard_3': (7, 17, 5, 4, ('CUPBOARD', 3)),
    'cupboard_4': (7, 17, 5, 4, ('CUPBOARD', 4)),
    # the dog-food cupboard beside it, likewise with 0-4 cans
    'dogcab_0': (5, 17, 4, 4, ('DOGCAB', 0)),
    'dogcab_1': (5, 17, 4, 4, ('DOGCAB', 1)),
    'dogcab_2': (5, 17, 4, 4, ('DOGCAB', 2)),
    'dogcab_3': (5, 17, 4, 4, ('DOGCAB', 3)),
    'dogcab_4': (5, 17, 4, 4, ('DOGCAB', 4)),
    # attic filing cabinet: top drawer pulled out towards you, two steps
    'drawer_1': (32, 5, 3, 3, ('DRAWER', 2)),
    'drawer_2': (32, 5, 3, 3, ('DRAWER', 4)),
    # shower curtain pulled across the tub from the right, in three steps
    'curtain_1': (25, 11, 5, 4, ('CURTAIN', 224)),
    'curtain_2': (25, 11, 5, 4, ('CURTAIN', 214)),
    'curtain_3': (25, 11, 5, 4, ('CURTAIN', 208)),
}


def draw_wcdoor(img, _):
    """The WC door (frame x 187-204, y 90-119, knob on the right) swung open
    on its left hinge: the door seen edge-on as a narrow white strip at the
    hinge, the dark little room behind."""
    k, w, l, u, d = 9, 3, 8, 6, 6
    for y in range(91, 120):
        for x in range(188, 204):
            img[y][x] = d                        # inside: dark
        img[y][188] = w                          # door edge at the hinge
        img[y][189] = w
        img[y][190] = l
        img[y][191] = k
    for x in range(192, 204):                    # threshold
        img[119][x] = k


JAR = ['.lll.',
       'kRRRk',
       'kwwwk',
       'kRRRk',
       'kRRRk',
       '.kkk.']


CAN = ['.lll.',
       'kOOOk',
       'kwnwk',
       'kOOOk',
       'kOOOk',
       '.kkk.']


def draw_cupboard(img, jars, x0=68, x1=90, item=JAR, cols=(71, 81)):
    """A kitchen cupboard (inside x x0..x1-1, y 141-165; the food one by
    default) with both doors swung open towards you: the doors seen almost
    edge-on outside the frame, a dark inside with two shelves, and `jars`
    items, two per shelf (top shelf first)."""
    C = {ch: i for i, ch in enumerate(A.AMIGA_CH)}
    k, r, u, g, n = C['k'], C['r'], C['u'], C['g'], C['n']
    for y in range(141, 166):                    # inside
        for x in range(x0, x1):
            img[y][x] = u
    for x in range(x0, x1):                      # shelves
        img[153][x] = g
        img[154][x] = n
        img[165][x] = g
    for y in range(139, 168):                    # the open doors, edge-on
        for d0 in (x0 - 6, x1 + 1):
            for x in range(d0, d0 + 4):
                img[y][x] = k if x in (d0, d0 + 3) or y in (139, 167) else r
    for j in range(jars):
        jx = cols[j % 2]
        jy = (147, 159)[j // 2]
        for dy, row in enumerate(item):
            for dx, ch in enumerate(row):
                if ch != '.':
                    img[jy + dy][jx + dx] = C[ch]


def draw_dogcab(img, cans):
    draw_cupboard(img, cans, 49, 64, CAN, (50, 57))


def close_glass_cabinet(img):
    """The glass-fronted cabinet between the kitchen cupboards (x 48-64,
    y 140-166) stands open in the Amiga art; shut it with two red doors like
    its neighbours."""
    C = {ch: i for i, ch in enumerate(A.AMIGA_CH)}
    k, r, g, w = C['k'], C['r'], C['g'], C['w']
    for y in range(140, 167):
        for x in range(48, 65):
            img[y][x] = k if y in (140, 166) or x in (48, 56, 64) else r
    for x in (54, 58):                           # handles
        for y, c in zip(range(160, 165), (k, g, w, g, k)):
            img[y][x] = c


def draw_bedcloset(img, _):
    """The bedroom closet (door x 74-91, y 90-119) standing open, as in the
    Amiga original: the door swung back on its left hinge, shirts and
    trousers hanging inside, shoes on the floor."""
    f = A.frame('cards')
    for y in range(90, 120):
        for x in range(74, 92):
            img[y][x] = f[y][x]


POT = ['...kk...',
       '.kllllk.',
       'kkkkkkkk',
       'kddddddk',
       'kddddddk',
       '.kkkkkk.']


def draw_pot(img, _):
    """The cooking pot on the stove's right burner (x 13-20, in reach from
    beside the stove), a little flame
    licking up under it. Flame pixels are marked -1..-3: the fireplace's
    flickering palette entries."""
    C = {ch: i for i, ch in enumerate(A.AMIGA_CH)}
    for dy, row in enumerate(POT):
        for dx, ch in enumerate(row):
            if ch != '.':
                img[166 + dy][13 + dx] = C[ch]
    for x in range(14, 20):
        img[172][x] = -1 - (x % 3)
        if x % 2:
            img[171][x] = -1 - ((x + 1) % 3) if img[171][x] == C['k'] else img[171][x]
    for x in range(15, 20):                     # the burner glows
        img[174][x] = -1 - ((x + 2) % 3)


VAC_IN = ['.kk...',
          'kgk...',
          '.kk...',
          '.kk...',
          'kRRk..',
          'kRRk..',
          'kRRk..',
          'kRRk..',
          'kRRk..',
          'kkkkk.',
          'kllllk',
          'kkkkkk']


def draw_atticcloset(img, vac):
    """The attic closet (door x 177-196, y 26-55) standing open as in the
    Amiga original, and the upright vacuum cleaner kept in it if `vac`."""
    f = A.frame('piano')
    for y in range(27, 56):
        for x in range(178, 196):
            img[y][x] = f[y][x]
    if vac:
        C = {ch: i for i, ch in enumerate(A.AMIGA_CH)}
        for dy, row in enumerate(VAC_IN):
            for dx, ch in enumerate(row):
                if ch != '.':
                    img[44 + dy][188 + dx] = C[ch]


def draw_phone_off(img, _):
    """The phone on the side table (handset on rows 172-173, x 196-207) with
    the handset lifted: wall shows through, the cradle hooks remain, and the
    coiled cord runs off towards the armchair."""
    g, w = 0, 3
    for x in range(195, 209):
        img[172][x] = g
        img[173][x] = g
    for x in (196, 197, 205, 206):
        img[173][x] = w
    for x in range(207, 216, 2):                # dotted coiled cord
        img[174 - (x - 207) * 3 // 9][x] = w


def draw_drawer(img, out):
    """The filing cabinet's bottom drawer (front at x 260-272, y 48-54) pulled
    `out` pixels towards you: the front grows and drops, and the folders
    inside show above it."""
    k, u, l, w, O, n = 9, 6, 8, 3, 15, 5     # Amiga indices
    x0, x1 = 260 - out // 2, 272 + out // 2
    top = 48 + out
    bot = top + 6 + out // 2
    for y in range(48, top):                 # inside of the drawer: folders
        for x in range(x0 + 1, x1):
            img[y][x] = (w, O, l, w)[(x + (y == 48)) % 4] if y > 48 else k
        img[y][x0] = k
        img[y][x1] = k
    for y in range(top, bot + 1):            # drawer front
        for x in range(x0, x1 + 1):
            edge = y in (top, bot) or x in (x0, x1)
            img[y][x] = k if edge else u
    cx = (x0 + x1) // 2
    for i, c in enumerate((l, k, k, l)):     # handle
        img[top + 2][cx - 1 + i] = c


def draw_curtain(img, left):
    """The shower curtain (normally bunched at the right end of the tub)
    pulled across to x = left: red and magenta folds from the rod at y = 92
    down over the tub to its base, with the rod extended to match."""
    # Accordion pleats: the same number of folds whatever the width, so they
    # bunch up tight while the curtain is only partly drawn.
    folds = [14, 14, 13, 13, 14, 2]          # R R m m R r (Amiga indices)
    width = 238 - left
    pleats = 6
    for x in range(left, 238):
        img[92][x] = 9 if x % 2 else 3       # rod
        u = (x - left) * pleats / width      # position in pleats
        c = folds[min(5, int((u - int(u)) * 6))]
        for y in range(93, 119):
            img[y][x] = c
        img[119][x] = 13 if x % 2 else 2     # hem
DOOR_CLOSED_FROM = 'house_a'


def house_index(x, y, v, sky, fire=False):
    """Map an Amiga colour at (x, y) to the game palette, giving the props
    that the runtime animates their own palette entries."""
    if v < 0:                                   # drawn flame: -1..-3
        return (FIRE_A, FIRE_B, FIRE_C)[-v - 1]
    if sky[y][x]:
        return SKY
    if 42 <= x <= 50 and 48 <= y <= 57 and v == 3:
        return TVSCR
    if 291 <= x <= 307 and 97 <= y <= 108 and v == 9:
        return MONITOR
    if 146 <= x <= 159 and 165 <= y <= 175 and v == 1:
        for band, (y0, y1) in enumerate(BOTTLE_ROWS):
            if y0 <= y <= y1:
                return BOTTLE_BANDS[band]
    if fire and 258 <= x <= 280 and 170 <= y <= 184 and v in (14, 3, 10, 15, 4):
        return (FIRE_A, FIRE_B, FIRE_C)[(x * 7 + y * 3) % 3]
    if y == 42 and 70 <= x <= 83 and v == 3:
        return (SPIN_A, SPIN_B)[x % 2]
    if y == 47 and 64 <= x <= 81 and v == 14:
        return (VU_R1, VU_R2)[(x // 2) % 2]
    if y == 47 and 64 <= x <= 81 and v == 1:
        return VU_B
    if (x, y) == (78, 43):
        return LED
    return HOUSE0 + v


def sky_mask(img):
    m = [[False] * 320 for _ in range(200)]
    stack = [(0, 0), (319, 0), (0, 20), (319, 20)]
    while stack:
        x, y = stack.pop()
        if 0 <= x < 320 and 0 <= y < 200 and not m[y][x] and img[y][x] == 1:
            m[y][x] = True
            stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return m


def build_house():
    bg = [r[:] for r in A.empty_house()]
    bg[0] = bg[1][:]                    # a source frame is one row short
    bg[199] = bg[198][:]
    close_glass_cabinet(bg)
    patches = {}
    # Front door: majority vote shows it open; default the house to closed.
    door_src = A.frame(DOOR_CLOSED_FROM)
    open_rows = [r[:] for r in bg]
    cx, cy, cw, ch, _ = PATCHES['door_open']
    for y in range(cy * 8, (cy + ch) * 8):
        for x in range(cx * 8, (cx + cw) * 8):
            bg[y][x] = door_src[y][x]
    sky = sky_mask(bg)
    for name, (cx, cy, cw, ch, src) in PATCHES.items():
        if isinstance(src, tuple):
            f = [r[:] for r in bg]
            {'CURTAIN': draw_curtain, 'DRAWER': draw_drawer, 'PHONE': draw_phone_off,
             'WCDOOR': draw_wcdoor, 'CUPBOARD': draw_cupboard,
             'DOGCAB': draw_dogcab, 'BEDCLOSET': draw_bedcloset,
             'POT': draw_pot, 'ATTICCLOSET': draw_atticcloset}[src[0]](f, src[1])
        else:
            f = open_rows if src is None else A.frame(src)
        pix = [[house_index(x, y, f[y][x], sky, name == 'fire_lit') for x in range(cx * 8, (cx + cw) * 8)]
               for y in range(cy * 8, (cy + ch) * 8)]
        patches[name] = (cx, cy, cw, ch, pix)
    img = [[house_index(x, y, bg[y][x], sky) for x in range(320)] for y in range(200)]
    for slot, v in ((SPIN_A, 3), (SPIN_B, 3), (VU_R1, 14), (VU_R2, 14), (VU_B, 1), (LED, 6)):
        PAL[slot] = PAL[HOUSE0 + v]
    for slot in BOTTLE_BANDS:
        PAL[slot] = PAL[BOTTLE]
    return img, patches


# Foreground furniture the person walks BEHIND: (x0, y0, x1, y1, colours).
# Pixels inside the box whose Amiga colour is in the set are drawn over him.
FOREGROUND = [
    (103, 180, 139, 192, 'nrk'),      # kitchen table top and legs
    (113, 173, 128, 190, 'vk'),       # kitchen chair (walking past only; not when seated)
    (203, 50, 253, 63, None),          # attic desk (None = every pixel)
]


def build_mask():
    """1 bit per pixel in FCM cell order: byte (cell*8 + row), bit 7 = x&7 == 0."""
    bg = A.empty_house()
    mask = bytearray(1000 * 8)
    for x0, y0, x1, y1, cols in FOREGROUND:
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if cols is None or A.AMIGA_CH[bg[y][x]] in cols:
                    i = ((y >> 3) * 40 + (x >> 3)) * 8 + (y & 7)
                    mask[i] |= 0x80 >> (x & 7)
    return mask


def to_cells(img):
    out = bytearray()
    for cy in range(25):
        for cx in range(40):
            for y in range(8):
                out += bytes(img[cy * 8 + y][cx * 8:cx * 8 + 8])
    return out


def polka(rows):
    """Mark a staggered dot pattern on the shirt and trouser pixels."""
    out = [list(r) for r in rows]
    for y, r in enumerate(out):
        for x, v in enumerate(r):
            if y % 3 == 1 and (x + (y // 3) * 2) % 4 == 1:
                if v == SHIRT:
                    r[x] = DOTS_SHIRT
                elif v == PANTS:
                    r[x] = DOTS_PANTS
    return out


def patch_cells(cw, ch, pix):
    out = bytearray()
    for cy in range(ch):
        for cx in range(cw):
            for y in range(8):
                out += bytes(pix[cy * 8 + y][cx * 8:cx * 8 + 8])
    return out


# ---------------------------------------------------------------------------
# Title (guestbook) image
# ---------------------------------------------------------------------------
def build_title():
    f = A.raw_frame('guestbook')
    idx = {c: TITLE0 + i for i, c in enumerate(GUEST_COLS)}
    img = [[idx[min(GUEST_COLS, key=lambda g: sum((a - b) ** 2 for a, b in zip(g, c)))] for c in r] for r in f]
    page = TITLE0 + 4
    # Clear the field values/labels and footer; the runtime draws them on the
    # 8x8 grid.
    for y in range(92, 178):
        for x in range(66, 281):
            img[y][x] = page
    # Replace HOUSE-ON-A-DISK with the logo.
    for y in range(41, 72):
        for x in range(81, 264):
            img[y][x] = TITLE0 + 5
    logo_rows = render_logo(181, 29)
    for y, row in enumerate(logo_rows):
        for x, v in enumerate(row):
            if v is not None:
                img[42 + y][82 + x] = v
    return img


def render_logo(w, h):
    lines = ['LITTLE MEGA', 'PEOPLE']
    scale = 4
    W, H = w * scale, h * scale
    size = 10
    font = None
    while True:
        cand = ImageFont.truetype(LOGO_FONT, size * scale)
        lh = cand.getbbox('LITTLE MEGA')[3]
        widths = [cand.getbbox(t)[2] for t in lines]
        if max(widths) > W - 4 * scale or lh * 2 > H:
            break
        font = cand
        size += 1
    im = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(im)
    tops = []
    asc = font.getbbox('L')
    lh = asc[3] - asc[1]
    gap = (H - 2 * lh) // 3
    for i, t in enumerate(lines):
        bx = font.getbbox(t)
        x = (W - (bx[2] - bx[0])) // 2 - bx[0]
        y = gap + i * (lh + gap) - asc[1]
        d.text((x, y), t, fill=255, font=font)
        tops.append(gap + i * (lh + gap))
    small = im.resize((w, h), Image.LANCZOS)
    rows = []
    for y in range(h):
        # gradient restarts on each line of text
        line_top = max(t for t in tops if t <= max(y * scale, tops[0])) // scale
        t = (y - line_top) / max(1, lh // scale)
        g = max(0, min(15, int(t * 15 + 0.5)))
        row = []
        for x in range(w):
            a = small.getpixel((x, y))
            if a < 40:
                row.append(None)
            else:
                row.append(LOGO0 + g * 4 + min(3, (a - 40) * 4 // 216))
        rows.append(row)
    # 1px drop shadow, bottom-right, in the box's dark grey.
    shadow = TITLE0 + 2
    out = [r[:] for r in rows]
    for y in range(h):
        for x in range(w):
            if rows[y][x] is None and x > 0 and y > 0 and rows[y - 1][x - 1] is not None \
                    and rows[y - 1][x - 1] >= LOGO0 + 2:
                out[y][x] = shadow
    return out


# ---------------------------------------------------------------------------
# Sprites
# ---------------------------------------------------------------------------
N = None


def remap(rows, fn):
    return [[None if v is None else fn(x, y, v) for x, v in enumerate(r)] for y, r in enumerate(rows)]


def amiga(v):
    return HOUSE0 + v


def person_colours(hair, shirt, shirt2=(), pants=(), shoes=(), hair_rows=99, extra=None):
    def fn(x, y, v):
        if extra:
            r = extra(x, y, v)
            if r is not None:
                return r
        if v == 16:
            return SKIN
        if v in hair and y < hair_rows:
            return HAIR
        if v in shirt:
            return SHIRT
        if v in shirt2:
            return SHIRT2
        if v in pants:
            return PANTS
        if v in shoes:
            return SHOES
        return amiga(v)
    return fn


C = {ch: i for i, ch in enumerate(A.AMIGA_CH)}


def pose(name, frame, x, y, w, h, fn, crop=None):
    dx, dy, rows = A.trim(A.extract(frame, x, y, w, h))
    ax, ay = x + dx, y + dy
    if crop:
        cx0, cy0, cx1, cy1 = crop
        rows = [r[cx0:len(r) - cx1] for r in rows[cy0:len(rows) - cy1]]
        ax += cx0
        ay += cy0
    return name, remap(rows, fn), ax, ay


def draw_arm(rows, hx):
    """Side-view arm: a darker sleeve from the shoulder (row 12, column 7) down
    to the hand at column hx, which hangs at hip level (rows 18-19) over the
    trousers so it reads clearly; outlined in black where it leaves the body."""
    k = HOUSE0 + 9
    w = len(rows[0])
    pts = []
    for y in range(12, 18):
        t = (y - 12) / 5
        pts.append((y, round(7 + (hx - 7) * t)))
    for y, x in pts:
        rows[y][x] = SHIRT2
        rows[y][x + 1] = SHIRT2
    for y in (18, 19):
        rows[y][hx] = SKIN
        rows[y][hx + 1] = SKIN
    for y, x in pts + [(18, hx), (19, hx)]:
        for px in (x - 1, x + 2):
            if 0 <= px < w and rows[y][px] is None:
                rows[y][px] = k
    for px in (hx, hx + 1):
        if rows[20][px] is None:
            rows[20][px] = k


def dog_walk_frames(dog):
    """Trotting dog (facing left): keep the Amiga dog's head and body (rows
    0..12) and redraw the four legs below so they move. Diagonal pairs swing
    forward/back together; the pair that is swinging through lifts its paws."""
    k, fur = HOUSE0 + 9, HOUSE0 + 5
    body = [[None] + r[:] + [None] for r in dog[:13]]     # 1px margin each side
    w = len(body[0])
    bases = [1, 6, 12, 18]           # left edge of each leg (front ... back)
    pair = [0, 1, 1, 0]              # diagonal pairs
    # (dx for pair 0, dx for pair 1, lifted pair or None); forward = left
    phases = [(-2, 2, None), (0, 0, 0), (2, -2, None), (0, 0, 1)]
    frames = []
    for d0, d1, lift in phases:
        rows = [r[:] for r in body] + [[None] * w for _ in range(3)]
        for i, bx in enumerate(bases):
            dx = (d0, d1)[pair[i]]
            up = 1 if lift == pair[i] else 0
            for r in range(13, 15 - up):
                x = bx + (dx // 2 if r == 13 else dx)    # slant from the hip
                for j, c in enumerate((k, fur, fur, k)):
                    if 0 <= x + j < w:
                        rows[r][x + j] = c
            x = bx + dx
            for j in range(4):           # paw
                if 0 <= x + j < w:
                    rows[15 - up][x + j] = k
        frames.append(rows)
    return frames


def step_frames(base, hip, lx, rx, foot, bent=0):
    """Stair-stepping legs seen from the back or front: two frames, each with
    one knee bent out to the side as that foot lifts onto the next step while
    the other leg stays straight. hip = first leg row, lx/rx = left column of
    each 2px leg, foot = shoe row of a planted foot."""
    k = HOUSE0 + 9
    w = len(base[0])
    frames = []
    for bent in ((0, 1) if bent == 0 else (None,)):
        rows = [r[:] for r in base[:hip]] + [[None] * w for _ in range(foot + 1 - hip)]
        for i, x0 in enumerate((lx, rx)):
            out = -1 if i == 0 else 1                  # knees bend outwards
            if i == bent:
                knee = hip + (foot - hip) // 2 - 1
                lift = foot - 3
                pts = [(hip, x0), (knee, x0 + 2 * out), (lift, x0 + out)]
            else:
                pts = [(hip, x0), (foot - 1, x0)]
            for (y0, a), (y1, b) in zip(pts, pts[1:]):
                for y in range(y0, y1 + 1):
                    t = (y - y0) / max(1, y1 - y0)
                    x = round(a + (b - a) * t)
                    rows[y][x] = PANTS
                    rows[y][x + 1] = PANTS
                    for px in (x - 1, x + 2):
                        if 0 <= px < w and rows[y][px] is None:
                            rows[y][px] = k
            fy, fx = pts[-1][0] + 1, pts[-1][1]
            for px in range(fx - 1, fx + 3):          # shoe
                if 0 <= px < w:
                    rows[fy][px] = SHOES
            for px in (fx - 2, fx + 3):
                if 0 <= px < w and rows[fy][px] is None:
                    rows[fy][px] = k
        frames.append(rows)
    return frames


def bend_frame(stand):
    """Side view bent forward at the waist (facing left), looking for
    something: head and shoulders lean forward and drop, legs stay put.
    Padded 5 columns on the left for the lean."""
    pad = 5
    w = len(stand[0]) + pad
    rows = [[None] * pad + r[:] for r in stand]
    out = [[None] * w for _ in range(len(rows))]
    for y in range(17, len(rows)):            # hips and legs unchanged
        out[y] = rows[y][:]
    for y in range(0, 17):                    # upper body: lean and drop 3
        dx = -round((17 - y) * 5 / 17)
        ny = y + 3
        if ny >= 17:
            continue
        for x in range(w):
            v = rows[y][x]
            if v is not None and 0 <= x + dx < w:
                out[ny][x + dx] = v
    return out


def bend_back_frame(climb):
    """Back view, bent down to look in a low drawer or shelf: head and
    shoulders drop 4 pixels (the head sinks between the shoulders), legs
    straight."""
    straight = step_frames(climb, 19, 7, 10, 28, bent=None)[0]
    out = [[None] * len(straight[0]) for _ in straight]
    for y in range(19, len(straight)):
        out[y] = straight[y][:]
    for y in range(0, 15):
        out[y + 4] = straight[y][:]
    return out


def phone_frames(reading):
    """On the phone in the armchair, as in the Amiga original: facing you,
    holding the handset to his ear on the side nearest the phone (screen
    left), the coiled cord running down to the phone. Frame 0 mouth shut,
    frame 1 mouth open."""
    k, w, l = HOUSE0 + 9, HOUSE0 + 3, HOUSE0 + 8
    head = art(FRONT_ART[:10])                  # 18 wide
    base = [r[:] for r in reading]
    hw = len(base[0])
    for y in range(10):
        base[y] = head[y] + [None] * (hw - len(head[y]))
    # sleeve from the left shoulder up to the hand by his ear
    for y in (8, 9, 10):
        base[y][1] = SHIRT
        base[y][2] = SHIRT
        base[y][0] = k
    # handset against his left ear, hand round it
    for y in range(2, 8):
        base[y][0] = k
        base[y][1] = w
        base[y][2] = l if y in (2, 7) else w
    base[1][1] = k
    base[1][2] = k
    for y in (5, 6, 7):
        base[y][2] = SKIN
        base[y][3] = SKIN
    base[8][0] = w                              # cord leaves the handset
    base[10][0] = w
    shut = [r[:] for r in base]
    talk = [r[:] for r in base]
    talk[7][8] = HOUSE0 + 14                     # open mouth
    talk[7][9] = HOUSE0 + 14
    talk[8][8] = k
    talk[8][9] = k
    return [shut, talk]


def load_sound(path, rate):
    """16-bit mono WAV -> unsigned 8-bit at `rate`, normalised."""
    import wave
    import struct
    wv = wave.open(path, 'rb')
    src_rate = wv.getframerate()
    n = wv.getnframes()
    data = struct.unpack('<%dh' % n, wv.readframes(n))
    peak = max(1, max(abs(v) for v in data))
    out = bytearray()
    step = src_rate / rate
    i = 0.0
    while int(i) < n:
        j = int(i)
        acc = sum(data[j:j + max(1, int(step))]) / max(1, len(data[j:j + max(1, int(step))]))
        out.append(max(0, min(255, 128 + int(acc * 120 / peak))))
        i += step
    return out


CHAIR_X0, CHAIR_Y0, CHAIR_X1, CHAIR_Y1 = 99, 44, 118, 59   # attic chair back, arm and seat


def sit_side(stand):
    """Sitting back in a reclining chair, side view facing left (the attic TV),
    as in the Amiga original: sunk low and leaning back, knees raised towards
    the TV, feet on the floor in front of the chair. 8 columns of padding on
    the left for the legs."""
    k = HOUSE0 + 9
    pad = 8
    sink = 5
    w = len(stand[0]) + pad + 2
    rows = [[None] * w for _ in range(28)]
    # upper body, sunk 4 px and leaning back (top rows shifted right)
    for y in range(19):
        dx = round((18 - y) * 2 / 18)
        for x, v in enumerate(stand[y]):
            if v is not None:
                rows[y + sink][x + pad + dx] = v
    hip_y = 18 + sink                            # row 22

    def thick(y0, x0, y1, x1, colour):
        n = max(abs(y1 - y0), abs(x1 - x0), 1)
        for i in range(n + 1):
            y = round(y0 + (y1 - y0) * i / n)
            x = round(x0 + (x1 - x0) * i / n)
            for dy in (0, 1):
                rows[y + dy][x] = colour
                rows[y + dy][x + 1] = colour

    # thigh: hip (row 22, col 14) up to the raised knee (row 18, col 2)
    thick(hip_y - 1, 14, 18, 2, PANTS)
    # shin: knee down to the ankle (row 26, col 2)
    thick(19, 1, 26, 2, PANTS2)
    for x in range(0, 5):                        # shoe, toe to the left
        rows[27][x] = SHOES
    # outline everything that touches empty space
    out = [r[:] for r in rows]
    for y in range(28):
        for x in range(w):
            if rows[y][x] is None:
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < 28 and rows[ny][nx] in (PANTS, PANTS2, SHOES):
                        out[y][x] = k
                        break
    return out


def walk_frames(stand):
    """Side-view walk cycle (facing left): keep the stand torso (rows 0..18) and
    redraw the legs as hip -> knee -> ankle polylines so the knees bend. The
    far leg is drawn first in a darker shade."""
    torso = [r[:] for r in stand[:19]]
    w = len(stand[0])
    k = HOUSE0 + 9
    # Each leg: [(row, x), ...] keypoints for the left column of a 2px leg.
    reach = [(19, 6), (24, 4), (29, 4)]          # front leg planted, knee soft
    trail = [(19, 7), (24, 8), (28, 10)]         # back leg, heel lifting
    support = [(19, 7), (24, 7), (29, 7)]        # straight under the body
    swing = [(19, 6), (23, 4), (27, 6)]          # knee forward, foot lifted
    support_n = [(19, 6), (24, 6), (29, 6)]
    swing_f = [(19, 7), (23, 5), (27, 7)]
    phases = [(trail, reach), (support, swing), (reach, trail), (swing_f, support_n)]
    arm_x = [10, 7, 4, 7]       # hand column: swings opposite the near leg
    frames = []
    for far, near in phases:
        rows = [r[:] for r in torso] + [[N] * w for _ in range(11)]

        def leg(pts, colour):
            for (y0, x0), (y1, x1) in zip(pts, pts[1:]):
                for yy in range(y0, y1 + 1):
                    t = (yy - y0) / max(1, y1 - y0)
                    xx = round(x0 + (x1 - x0) * t)
                    rows[yy][xx] = colour
                    rows[yy][xx + 1] = colour
                    for px in (xx - 1, xx + 2):
                        if 0 <= px < w and rows[yy][px] in (None, k):
                            rows[yy][px] = k
            fy, fx = pts[-1]
            for px in range(fx - 2, fx + 2):     # shoe, toe pointing left
                if 0 <= px < w:
                    rows[fy][px] = SHOES
            for px in (fx - 3, fx + 2):
                if 0 <= px < w and rows[fy][px] is None:
                    rows[fy][px] = k
        leg(far, PANTS2)
        leg(near, PANTS)
        draw_arm(rows, arm_x[len(frames)])
        for px in range(4, 12):                   # waistband
            if rows[19][px] is None or rows[19][px] == k:
                rows[19][px] = PANTS if 5 <= px <= 10 else k
        frames.append(rows)
    return frames


# Front-facing standing pose (for knocking on the screen and idling), drawn in
# the style of the Amiga sprites. Letters: S skin, H hair, T shirt, t shirt shade,
# P trousers, Z shoes, plus the Amiga palette letters.
FRONT_ART = [
    '.....kkkkkkkk.....',
    '....kHHHHHHHHk....',
    '...kHHHSSSSHHHk...',
    '...kSSSSSSSSSSk...',
    '...kSSkkSSkkSSk...',
    '...kSSSSSSSSSSk...',
    '..kSSSHHHHHHSSSk..',
    '..kSSSSkkkkSSSSk..',
    '...kSSSSSSSSSSk...',
    '....kkSSSSSSkk....',
    '......kSSSSk......',
    '....kkTwwwwTkk....',
    '...kTTTTwwTTTTk...',
    '..kTTktTTTTtkTTk..',
    '..kTTktTTTTtkTTk..',
    '..kTTktTTTTtkTTk..',
    '..kTTktTTTTtkTTk..',
    '..kSSkTTTTTTkSSk..',
    '...kk.kTTTTk.kk...',
    '......kPPPPk......',
    '......kPPkPPk.....',
    '......kPPkPPk.....',
    '......kPPkPPk.....',
    '......kPPkPPk.....',
    '......kPPkPPk.....',
    '......kPPkPPk.....',
    '......kPPkPPk.....',
    '......kPPkPPk.....',
    '.....kZZZkZZZk....',
    '.....kkkk.kkkk....',
]
# Same pose with his left arm (screen right) raised towards the glass: the sleeve
# points out from the shoulder; the fist sprite is drawn beyond it.
def jack_art(arms, spread):
    """Jumping jacks, facing you (26 wide, his front pose in the middle):
    arms 'down' / 'side' (straight out) / 'up' (raised in a V), legs `spread`
    pixels apart at the feet."""
    W = 26
    g = [list('....' + ln + '....') for ln in FRONT_ART]
    if arms == 'down' and spread == 0:
        return [''.join(r) for r in g]
    # torso without the arms at his sides
    g[12] = list('.......kTTTTwwTTTTk.......')
    for y in range(13, 18):
        g[y] = list('........kTtTTTTtTk........')
    g[18] = list('.........kTTTTTTk.........')
    # legs: two 3-wide legs fanning out from the hips
    for y in range(19, 30):
        g[y] = list('.' * W)
    for y in range(19, 28):
        d = (y - 19) * spread // 8                   # how far out at this row
        for x0 in (10 - d, 13 + d):
            g[y][x0] = 'k'
            g[y][x0 + 1] = 'P'
            g[y][x0 + 2] = 'P'
            g[y][x0 + 3] = 'k'
    for x0, x1 in ((9 - spread, 13 - spread), (13 + spread, 17 + spread)):
        for x in range(x0, x1 + 1):                  # shoes
            g[28][x] = 'Z' if x0 < x < x1 else 'k'
            g[29][x] = 'k'
    # arms (2 wide, outlined), hands of skin at the ends
    # (y, x) on his right (screen left); mirrored for the other arm
    if arms == 'side':
        sleeve = [(y, x) for y in (12, 13) for x in range(2, 7)]
        hand = [(12, 1), (13, 1), (12, 0), (13, 0)]
    else:                                            # up, in a V
        sleeve = [(12 - i, x) for i in range(10) for x in (7 - i * 5 // 9, 6 - i * 5 // 9)]
        hand = [(1, 1), (1, 2), (2, 1), (2, 2)]
    sleeve += [(y, W - 1 - x) for y, x in sleeve]
    hand += [(y, W - 1 - x) for y, x in hand]
    for y, x in sleeve + hand:                       # outline first
        for yy, xx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if 0 <= yy < 30 and 0 <= xx < W and g[yy][xx] == '.':
                g[yy][xx] = 'k'
    for y, x in sleeve:
        g[y][x] = 'T'
    for y, x in hand:
        g[y][x] = 'S'
    return [''.join(r) for r in g]


# Facing you, drinking: his left arm (screen right) raised, the hand (and the
# cup, drawn over it) at his mouth.
FRONT_DRINK_ART = [ln for ln in FRONT_ART]
FRONT_DRINK_ART[9] = '....kkSSSSSSkTk...'
FRONT_DRINK_ART[10] = '......kSSSSk.kTk..'
FRONT_DRINK_ART[11] = '....kkTwwwwTkkTk..'
FRONT_DRINK_ART[12] = '...kTTTTwwTTTTTk..'
for _y in (13, 14, 15, 16):
    FRONT_DRINK_ART[_y] = '..kTTktTTTTtk.....'
FRONT_DRINK_ART[17] = '..kSSkTTTTTTk.....'
FRONT_DRINK_ART[18] = '...kk.kTTTTk......'
FRONT_KNOCK_ART = [ln for ln in FRONT_ART]
FRONT_KNOCK_ART[11] = '....kkTwwwwTkkkk..'
FRONT_KNOCK_ART[12] = '...kTTTTwwTTTTTTk.'
FRONT_KNOCK_ART[13] = '..kTTktTTTTtTTTTk.'
FRONT_KNOCK_ART[14] = '..kTTktTTTTtkkkk..'
FRONT_KNOCK_ART[15] = '..kTTktTTTTtk.....'
FRONT_KNOCK_ART[16] = '..kTTktTTTTtk.....'
FRONT_KNOCK_ART[17] = '..kSSkTTTTTTk.....'
FRONT_KNOCK_ART[18] = '...kk.kTTTTk......'
# An open book held in both hands, and the same with a page turning over.
BOOK_OPEN = [
    '.................',
    '.................',
    '..kkkkkk.kkkkkk..',
    '.kwwwwwwkwwwwwwk.',
    '.kwlllwwkwllllwk.',
    '.kwwwwwwkwwwwwwk.',
    '.kwllllwkwlllwwk.',
    'SkwwwwwwkwwwwwwkS',
    'SSkkkkkkkkkkkkkSS',
]
BOOK_TURN = [
    '........kk.......',
    '.......kwwk......',
    '..kkkkkkwwk.kkk..',
    '.kwwwwwkwwkwwwwk.',
    '.kwlllwkwwkwlllk.',
    '.kwwwwwkwwkwwwwk.',
    '.kwllllkwkwwlllk.',
    'SkwwwwwwkwwwwwwkS',
    'SSkkkkkkkkkkkkkSS',
]
PERSON_LETTERS = {'S': SKIN, 'H': HAIR, 'T': SHIRT, 't': SHIRT2, 'P': PANTS, 'Z': SHOES}


def art(lines, extra=None):
    m = dict(PERSON_LETTERS)
    if extra:
        m.update(extra)
    out = []
    for ln in lines:
        row = []
        for c in ln:
            if c == '.':
                row.append(None)
            elif c in m:
                row.append(m[c])
            else:
                row.append(HOUSE0 + A.AMIGA_CH.index(c))
        out.append(row)
    w = max(len(r) for r in out)
    return [r + [None] * (w - len(r)) for r in out]


def fist(size):
    """A fist seen knuckles-first, `size` pixels across, for the screen knock:
    four finger bumps along the top, the thumb curled across the front."""
    import math
    k, edge = HOUSE0 + 9, HOUSE0 + 5
    W, H = size, round(size * 0.9)
    fw = W / 4
    top = round(H * 0.15)
    finger_bottom = round(H * 0.62)

    def inside(x, y):
        # body: rounded box; top edge scalloped into four fingers
        if y < top:
            f = min(3, int(x / fw))
            cx = (f + 0.5) * fw
            return math.hypot((x + 0.5 - cx) / (fw / 2), (y + 0.5 - top) / max(1, top)) <= 1.0
        rx, ry = W / 2, (H - top)
        dx = abs(x + 0.5 - W / 2) / rx
        dy = max(0.0, (y + 0.5 - top) / ry - 0.55) / 0.45
        return dx ** 3 + dy ** 3 <= 1.0
    rows = [[SKIN if inside(x, y) else None for x in range(W)] for y in range(H)]
    out = [r[:] for r in rows]
    for y in range(H):
        for x in range(W):
            if rows[y][x] is None:
                continue
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if not (0 <= nx < W and 0 <= ny < H) or rows[ny][nx] is None:
                    out[y][x] = k
    if size >= 9:
        for f in (1, 2, 3):                      # gaps between the fingers
            x = round(f * fw)
            for y in range(top, finger_bottom):
                if out[y][x] == SKIN:
                    out[y][x] = edge
        for x in range(1, round(W * 0.7)):       # thumb across the front
            y = finger_bottom + (1 if x > W * 0.45 else 0)
            if y < H and out[y][x] == SKIN:
                out[y][x] = edge
    return out


# Deliveries (Amiga palette letters): groceries, dog food, a book, a record.
PACKAGES = {
    'pkgfood': ['.vOOv..', 'vOOvOv.', 'nnnnnnn', 'nOnnnOn', 'nnnnnnn', 'nnnnnnn', 'nnnnnnn'],
    'pkgdog': ['kkkkkkkk', 'kOOOOOOk', 'kOwwwwOk', 'kOwnnwOk', 'kOwwwwOk', 'kOOOOOOk', 'kkkkkkkk'],
    'pkgbook': ['kkkkkkk', 'kBBBBBw', 'kBRRRBw', 'kBBBBBw', 'kBBBBBw', 'kkkkkkw'],
    'pkgrecord': ['kkkkkkkk', 'kRRRRRRk', 'kRkkkkRk', 'kRkwwkRk', 'kRkkkkRk', 'kRRRRRRk', 'kkkkkkkk'],
}

ASCII_SPRITES = {
    'zz': ['wwww.', '..w..', '.w...', 'wwww.'],
    'note': ['..kk', '..kw', '..k.', '..k.', 'kkk.', 'kkk.'],
    'heart': ['.RR.RR.', 'RRRRRRR', 'RRRRRRR', '.RRRRR.', '..RRR..', '...R...'],
    'dogfood': ['.nnnn.', 'nnnnnn'],
    'dogfood2': ['......', '.nnnn.'],       # half eaten
    'bubble': ['.www.', 'w...w', '.www.'],
    # solitaire laid out on the kitchen table, either side of his hands; the
    # second frame has turned a card over
    # things he carries while cooking: a jar of food, the pot, a full plate
    'heldjar': ['.lll.', 'kRRRk', 'kwwwk', 'kRRRk', 'kRRRk', '.kkk.'],
    'heldpot': ['.kkkkkkk.', 'kklllllkk', '.kdddddk.', '.kdddddk.', '..kkkkk..'],
    'heldplate': ['..OvRO...', '.OnOvRO..', 'kwwwwwwwk', '.kkkkkkk.'],
    'heldcan': ['.lll.', 'kOOOk', 'kwnwk', 'kOOOk', 'kOOOk', '.kkk.'],
    # his cup: empty, full of water, and tipped up at his lips (two angles)
    'heldcup': ['k..k', 'kwwk', 'kwwk', '.kk.'],
    # the vacuum cleaner he pushes along (head on the floor in front of him)
    'heldvac': ['......kk',
                '.....kgk',
                '.....kk.',
                '....kk..',
                '....kk..',
                '...kk...',
                '..kRRk..',
                '..kRRk..',
                '..kRRk..',
                '..kRRk..',
                '.kkkkkk.',
                'kllllllk',
                'kkkkkkkk'],
    'heldcupfull': ['kBBk', 'kwwk', 'kwwk', '.kk.'],
    'cuptilt0': ['...kk', '..kBk', '.kwwk', 'kwwk.', '.kk..'],
    'cuptilt1': ['.....', 'kkkkk', 'Bwwwk', 'kwwwk', '.kkk.'],
    # the dog sitting up begging, a puppy side-on: round head with a floppy
    # ear, big black nose, both front paws held up (bobbing), tail wagging
    'dogbeg0': [
        '......kkkk......',
        '....kknnnnkk....',
        '...knnnnnnnnk...',
        '..knnnnnnkknnk..',
        '.kknnknnnknnnk..',
        'kkknnnnnnknnnk..',
        'kkknnnnnnknnnk..',
        '.knkkknnnknnnk..',
        '..knnnnnnkkkk...',
        '...kkknnnnk.....',
        '..kkkknnnnnk....',
        '.knnnnknnnnk...k',
        '.knnkkknnnnk..kn',
        '.knnnnknnnnk.knk',
        '..kkkknnnnnnkknk',
        '....knnnnnnnknk.',
        '....knnnknnnkk..',
        '....knnnkknnnk..',
        '....kkkkkkkkkk..',
],
    'dogbeg1': [
        '......kkkk......',
        '....kknnnnkk....',
        '...knnnnnnnnk...',
        '..knnnnnnkknnk..',
        '.kknnknnnknnnk..',
        'kkknnnnnnknnnk..',
        'kkknnnnnnknnnk..',
        '.knkkknnnknnnk..',
        '..knnnnnnkkkk...',
        '...kkknnnnk.....',
        '.....knnnnnk....',
        '..kkkknnnnnk....',
        '.knnnnknnnnk....',
        '.knnkkknnnnk....',
        '.knnnnknnnnnk...',
        '..kkkknnnnnnk.k.',
        '....knnnknnnkknk',
        '....knnnkknnnkkn',
        '....kkkkkkkkkk.k',
],
    # the dog eating at its bowl, side-on, head down (and up a pixel: chewing)
    'dogeat0': [
        '.....................kk.',
        '....................knk.',
        '.........kkkkkkkkkkknk..',
        '......kkknnnnnnnnnnnnk..',
        '.....knnnnnnnnnnnnnnnk..',
        '....knnknnnnnnnnnnnnnk..',
        '...knnnknnnnnnnnnnnnnk..',
        '..knnnnknnnnnnnnnnnnk...',
        '.knnknnkknnnnnnnnnnnk...',
        'knnnnnkknnkkkkkknnnk....',
        'kkknnnk.knnk....knnk....',
        'kkkkkk..knnk....knnk....',
        '........knnk....knnk....',
        '.......kknnk...kknnk....',
        '.......kkkkk...kkkkk....',
],
    'dogeat1': [
        '.....................kk.',
        '....................knk.',
        '.........kkkkkkkkkkknk..',
        '......kkknnnnnnnnnnnnk..',
        '.....knnnnnnnnnnnnnnnk..',
        '...knnnknnnnnnnnnnnnnk..',
        '..knnnnknnnnnnnnnnnnnk..',
        '.knnknnknnnnnnnnnnnnk...',
        'knnnnnkkknnnnnnnnnnnk...',
        'kkknnnk.nnkkkkkknnnk....',
        'kkkkkk..knnk....knnk....',
        '........knnk....knnk....',
        '........knnk....knnk....',
        '.......kknnk...kknnk....',
        '.......kkkkk...kkkkk....',
],
    'tablecards0': ['wRw.wkw.www.wRw..........wkw.www',
                    'www.www.www.www..........www.www'],
    'tablecards1': ['wRw.wkw.wkw.wRw..........wkw.wRw',
                    'www.www.www.www..........www.www'],
}


# ---------------------------------------------------------------------------
# Video games on the computer screen (17x8 at x 292, y 99): a maze muncher
# and a space shooter, 16 frames each. Our own little pixel games.
# ---------------------------------------------------------------------------
VG_W, VG_H = 17, 8


def vg_maze(f):
    K, B, Y, R, W = HOUSE0 + 9, HOUSE0 + 10, 37, HOUSE0 + 14, HOUSE0 + 3
    g = [[K] * VG_W for _ in range(VG_H)]
    for x in range(VG_W):                       # maze walls
        g[0][x] = B
        g[7][x] = B
    for x in (4, 5, 11, 12):
        g[1][x] = B
        g[6][x] = B
    mx = f                                      # the muncher, eating along row 3-5
    for x in range(1, VG_W, 2):                 # dots still to eat
        if x > mx + 1:
            g[4][x] = W
    open_ = f % 2 == 0
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            x, y = mx + dx, 4 + dy
            if 0 <= x < VG_W:
                if open_ and dx == 1 and dy in (0, -1) and (dy == 0):
                    continue                    # mouth
                g[y][x] = Y
    gx = mx - 6                                 # the ghost behind
    for dy, row in zip((-1, 0, 1), ('.R.', 'RWR', 'R.R')):
        for dx, c in zip((-1, 0, 1), row):
            x, y = gx + dx, 4 + dy
            if c != '.' and 0 <= x < VG_W:
                g[y][x] = R if c == 'R' else W
    return g


def vg_shoot(f):
    K, G, W, Y, R = HOUSE0 + 9, 36, HOUSE0 + 3, 37, HOUSE0 + 14
    g = [[K] * VG_W for _ in range(VG_H)]
    shuffle = (0, 1, 2, 1)[(f // 2) % 4]
    hit = 11 <= f <= 12
    for i in range(4):                           # the formation
        x = 1 + i * 4 + shuffle
        if i == 2 and 4 <= f <= 12:
            continue                             # this one's diving
        g[1][x] = G
        g[1][x + 1] = G
        g[2][x] = G
        g[2][x + 1] = G
    if 4 <= f <= 12:                             # the diver swoops down
        dx = (0, 1, 2, 3, 3, 2, 1, 0, 0)[f - 4]
        dy = (1, 2, 3, 3, 4, 4, 4, 4, 4)[f - 4]
        x, y = 10 + dx, dy
        c = R if hit else G
        for yy, xx in ((y, x), (y, x + 1), (y + 1, x), (y + 1, x + 1)):
            if 0 <= yy < VG_H and 0 <= xx < VG_W:
                g[yy][xx] = c
    sx = (4, 5, 6, 7, 8, 9, 10, 10, 10, 10, 10, 10, 9, 8, 6, 5)[f]   # his ship
    g[7][sx - 1] = W
    g[7][sx] = W
    g[7][sx + 1] = W
    g[6][sx] = W
    if 6 <= f <= 10:                             # a shot going up
        by = 5 - (f - 6)
        if 0 <= by < VG_H:
            g[by][10] = Y
    return g


def build_sprites():
    stand_fn = person_colours(hair=(15,), shirt=(4,), pants=(3,), shoes=())
    name, stand, sx, sy = pose('stand', 'kitchen', 44, 155, 20, 34, stand_fn)
    # clean the kitchen junk that touches the right edge of the extraction
    for y in range(len(stand)):
        for x in range(14, len(stand[0])):
            stand[y][x] = None
    stand = [r[:14] for r in stand]
    for y in (2, 3, 4, 5):
        stand[y][13] = HOUSE0 + 9
    # feet: replace the source's odd feet with simple shoes
    stand[28] = [N, N, N, N, HOUSE0 + 9, SHOES, SHOES, HOUSE0 + 9, HOUSE0 + 9, SHOES, SHOES, HOUSE0 + 9, N, N]
    stand[29] = [N, N, HOUSE0 + 9, SHOES, SHOES, SHOES, SHOES, HOUSE0 + 9, SHOES, SHOES, SHOES, SHOES, HOUSE0 + 9, N]
    for y in range(19, 28):
        stand[y] = [N, N, N, N, HOUSE0 + 9, PANTS, PANTS, HOUSE0 + 9, HOUSE0 + 9, PANTS, PANTS, HOUSE0 + 9, N, N]
    # Side-view torso: the source rows 13..15 bulge front and back (his arms as
    # seen from the front). In profile the trunk is a straight block; the arm
    # is drawn separately by draw_arm.
    for y in range(10, 19):
        stand[y] = [N, N, N, N, HOUSE0 + 9] + [SHIRT] * 6 + [HOUSE0 + 9, N, N]
    walks = walk_frames(stand)
    armless = [r[:] for r in stand]     # seated in the attic chair: the chair's
    draw_arm(stand, 7)                  # own arms show instead of his
    sprites = [('stand', stand), ('sittv', sit_side(armless)),
               ('bendside', bend_frame(stand))]     # leaning over to the TV knob
    # The attic chair's back and arm, drawn over him while he sits in it.
    bgh = A.empty_house()
    chair = [[HOUSE0 + bgh[y][x] if A.AMIGA_CH[bgh[y][x]] in 'Bb' else None
              for x in range(CHAIR_X0, CHAIR_X1 + 1)] for y in range(CHAIR_Y0, CHAIR_Y1 + 1)]
    sprites.append(('chairfront', chair))
    for i, fr in enumerate(walks):
        sprites.append(('walk%d' % i, fr))
    anchors = {}

    def add(p):
        n, rows, ax, ay = p
        sprites.append((n, rows))
        anchors[n] = (ax, ay)

    climb_fn = person_colours(hair=(15,), shirt=(2, 0), pants=(3,),
                              extra=lambda x, y, v: SHOES if v == 2 and y >= 26 else None)
    add(pose('climb', 'stairs', 166, 138, 24, 33, climb_fn))
    add(pose('brush', 'brushing', 159, 93, 21, 33,
             person_colours(hair=(15,), shirt=(4, 8), pants=(3,), hair_rows=8)))
    add(pose('chair', 'armchair', 215, 160, 23, 30,
             person_colours(hair=(5,), shirt=(10,), shirt2=(1,), hair_rows=9)))
    add(pose('eat', 'eating', 111, 160, 22, 25,
             person_colours(hair=(15,), shirt=(4,), hair_rows=9,
                            extra=lambda x, y, v: HAIR if v == 15 and 5 <= y <= 7 else None)))
    add(pose('piano', 'piano', 144, 32, 20, 24,
             person_colours(hair=(5,), shirt=(4,), pants=(14,), hair_rows=7)))
    add(pose('computer', 'computer', 266, 91, 23, 28,
             person_colours(hair=(5,), shirt=(10,), pants=(3,), hair_rows=11),
             crop=(0, 4, 0, 0)))
    # Computer: drop the stray pixels of the shelf ornament above his head.
    comp = sprites[-1][1]
    for y in range(len(comp)):
        for x in range(len(comp[0])):
            if x >= 13 and y < 1:
                comp[y][x] = None
    # Sleeping head, lying on the pillow: the front-facing head (with chin)
    # with the eyes closed.
    sleep_art = [ln for ln in FRONT_ART[:10]]
    sleep_art[4] = '...kSSSSSSSSSSk...'
    sleep_art[5] = '...kSkkSSSSkkSk...'
    sprites.append(('sleephead', art(sleep_art)))
    for n, (f, x, y, w, h) in {'dog1': ('attic_dog', 153, 137, 26, 19),
                               'dog2': ('kitchen', 245, 179, 27, 19),
                               'dog3': ('brushing', 47, 46, 26, 17)}.items():
        _, rows, ax, ay = pose(n, f, x, y, w, h, lambda x, y, v: amiga(9 if v in (0, 6) else v))
        if n == 'dog2':
            rows = [r[::-1] for r in rows]   # this screenshot's dog faces right; all face left
        sprites.append((n, rows))
        if n == 'dog1':
            for i, fr in enumerate(dog_walk_frames(rows)):
                sprites.append(('dogw%d' % i, fr))
    for n, rows in ASCII_SPRITES.items():
        sprites.append((n, remap(A.from_ascii(rows), lambda x, y, v: amiga(v))))
    for n, rows in PACKAGES.items():
        sprites.append((n, remap(A.from_ascii(rows), lambda x, y, v: amiga(v))))
    sprites.append(('front', art(FRONT_ART)))
    for f in range(16):
        sprites.append(('vgm%d' % f, vg_maze(f)))
    for f in range(16):
        sprites.append(('vgs%d' % f, vg_shoot(f)))
    sprites.append(('frontdrink', art(FRONT_DRINK_ART)))
    # jumping jacks in front of the bedroom dresser
    sprites.append(('jack0', art(jack_art('down', 0))))
    sprites.append(('jack1', art(jack_art('side', 2))))
    sprites.append(('jack2', art(jack_art('up', 5))))
    # Eating: the Amiga frame has his mouth wide open; add a chewing (shut)
    # frame and one with his hand up at his mouth.
    eat = dict(sprites)['eat']
    shut = [r[:] for r in eat]
    shut[7] = art(['.kSSSSSSSSSSSSSSk.'])[0]
    shut[8] = art(['.kSSSSkkkkkkSSSSk.'])[0]
    shut[9] = art(['.kSSSSSSSSSSSSSSk.'])[0]
    sprites.append(('eatshut', shut))
    hand = [r[:] for r in eat]
    k = HOUSE0 + 9
    for y, x in ((17, 13), (18, 12), (18, 13), (17, 14), (18, 14), (18, 11)):
        hand[y][x] = None                    # hand leaves the table...
    hand[17][13] = SHIRT
    for y in (11, 12, 13):                   # ...sleeve up the chest...
        hand[y][12] = SHIRT
        hand[y][13] = SHIRT
        hand[y][14] = k
    for y in (9, 10):                        # ...hand at his mouth
        for x in (11, 12, 13):
            hand[y][x] = SKIN
        hand[y][14] = k
    sprites.append(('eathand', hand))
    # Brushing: second frame with the toothbrush (row 10) and hand moved up a
    # pixel; alternating the two scrubs the brush up and down.
    brush = dict(sprites)['brush']
    brush_up = [r[:] for r in brush]
    brush_up[9][0:8] = brush[10][0:8]
    brush_up[10][0:8] = brush[9][0:8]
    sprites.append(('brushup', brush_up))
    # Stairs: the elbows alternate with the steps. Back view: the Amiga pose has
    # one arm out and the other elbow bent (hand on hip); the second frame
    # mirrors the arms (rows 10-18 are symmetric about his body).
    for i, fr in enumerate(step_frames(dict(sprites)['climb'], 19, 7, 10, 28)):
        if i == 1:
            for y in range(10, 19):
                fr[y] = fr[y][::-1]
        sprites.append(('climbstep%d' % i, fr))
    sprites.append(('bend', bend_back_frame(dict(sprites)['climb'])))
    # Standing still with his back to you, arms forward (into the sink): the
    # back-view head on a plain torso, both feet planted.
    climb = dict(sprites)['climb']
    torso = art(['......kTTTTTTk......',
                 '.....kTTTTTTTTk.....',
                 '....kTTTTTTTTTTk....',
                 '....kTTTTTTTTTTk....',
                 '....kTTTTTTTTTTk....',
                 '....kTTTTTTTTTTk....',
                 '....kTTTTTTTTTTk....',
                 '.....kTTTTTTTTk.....',
                 '......kPPPPPPk......'])
    back = [r[:] for r in climb[:10]] + torso + [r[:] for r in climb[19:]]
    sprites.append(('backstand', step_frames(back, 19, 7, 10, 28, bent=None)[0]))
    # second bent frame with the arms mirrored: busy hands (laying the fire)
    bend2 = [r[:] for r in dict(sprites)['bend']]
    for y in range(14, 19):
        bend2[y] = bend2[y][::-1]
    sprites.append(('bend2', bend2))
    # Front view coming down: left elbow out with the hand on the hip, then the
    # right one.
    elbow = [ln for ln in FRONT_ART]
    elbow[13] = '.kTTTktTTTTtkTTk..'
    elbow[14] = 'kTTk.ktTTTTtkTTk..'
    elbow[15] = 'kTTk.ktTTTTtkTTk..'
    elbow[16] = '.kTTkktTTTTtkTTk..'
    elbow[17] = '..kSSkTTTTTTkSSk..'
    for i, fr in enumerate(step_frames(art(elbow), 20, 7, 10, 28)):
        if i == 1:
            for y in range(13, 19):
                fr[y] = fr[y][::-1]
        sprites.append(('downstep%d' % i, fr))
    # Reading in the armchair: the relaxing pose with his raised elbows taken
    # out; the book sprite (held in both hands) covers his chest.
    chair = dict(sprites)['chair']
    reading = [r[:] for r in chair]
    for y, ln in ((8, '....kkkkkSSSSSk....'),
                  (9, '..kkTkSSSSSSSkTkk..'),
                  (10, '.kTTTTkSSSSSkTTTTk.'),
                  (11, '.kTTTTTttSSttTTTTk.')):
        reading[y] = art([ln])[0]
    sprites.append(('reading', reading))
    sprites.append(('bookopen', art(BOOK_OPEN)))
    # His hands on the typewriter keys (left keys x 216-219, right x 226-229),
    # one up while the other is down.
    for i in range(2):
        rows = [[None] * 14 for _ in range(5)]
        for hx, up in ((0, i == 0), (10, i == 1)):
            y0 = 0 if up else 1
            shape = ['.SS.', 'SSSS', '.kk.']           # knuckles, hand, shadow
            for dy, ln in enumerate(shape):
                for dx, c in enumerate(ln):
                    if c != '.':
                        rows[y0 + dy][hx + dx] = SKIN if c == 'S' else HOUSE0 + 9
        sprites.append(('hands%d' % i, rows))
    # His hands on the piano keys either side of him (seen from behind): they
    # move along the keyboard and take turns striking.
    for i, (lx, rx, lup) in enumerate(((1, 1, True), (3, 2, False), (2, 4, True), (0, 3, False))):
        rows = [[None] * 30 for _ in range(5)]
        for hx, up in ((lx + 2, lup), (20 + rx, not lup)):   # close in by his sides
            y0 = 0 if up else 1
            for dy, ln in enumerate(['.SS.', 'SSSS', '.kk.']):
                for dx, c in enumerate(ln):
                    if c != '.':
                        rows[y0 + dy][hx + dx] = SKIN if c == 'S' else HOUSE0 + 9
        sprites.append(('pianohands%d' % i, rows))
    for i, frame in enumerate(phone_frames(reading)):
        sprites.append(('phone%d' % i, frame))
    sprites.append(('bookturn', art(BOOK_TURN)))
    sprites.append(('frontknock', art(FRONT_KNOCK_ART)))
    talk_art = [ln for ln in FRONT_ART]
    talk_art[7] = '..kSSSSkRRkSSSSk..'      # mouth open
    sprites.append(('fronttalk', art(talk_art)))
    # Seated behind the attic desk facing you: just head and shoulders, so the
    # desk and typewriter stay in front of him.
    sprites.append(('sitdesk', art(FRONT_ART[:12])))
    # Censor mosaic for when he walks to the closet after a shower: 3x3 blocks
    # of skin shades, two variants so it shimmers.
    shades = [HOUSE0 + 16, HOUSE0 + 4, SKIN, HOUSE0 + 16]
    for v in range(2):
        rows = []
        for y in range(9):
            rows.append([shades[((x // 3) * 3 + (y // 3) * 5 + v) % 4] for x in range(9)])
        sprites.append(('mosaic%d' % v, rows))
    for i, sz in enumerate((5, 8, 11, 15)):
        sprites.append(('fist%d' % i, fist(sz)))
    return sprites, anchors


# ---------------------------------------------------------------------------
# Font: 128 glyphs x 8 bytes, ASCII-indexed. Codes 1..9 are game symbols.
# ---------------------------------------------------------------------------
CUSTOM_GLYPHS = {
    5: [0x3C, 0x42, 0xA5, 0x81, 0xA5, 0x99, 0x42, 0x3C],   # happy face
    6: [0x3C, 0x42, 0xA5, 0x81, 0x99, 0xA5, 0x42, 0x3C],   # sad face
    7: [0x00, 0x66, 0xFF, 0xFF, 0x7E, 0x3C, 0x18, 0x00],   # heart
    8: [0x0F, 0x09, 0x09, 0x09, 0x39, 0x79, 0x70, 0x00],   # note
    9: [0xFF] * 8,                                          # block cursor
    92: [0x00, 0x40, 0x20, 0x10, 0x08, 0x04, 0x02, 0x00],  # backslash
    95: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF],  # underscore
    123: [0x0E, 0x18, 0x18, 0x70, 0x18, 0x18, 0x0E, 0x00],
    124: [0x18] * 8,
    125: [0x70, 0x18, 0x18, 0x0E, 0x18, 0x18, 0x70, 0x00],
    126: [0x00, 0x00, 0x76, 0xDC, 0x00, 0x00, 0x00, 0x00],
}


def build_font():
    path = CHARGEN if os.path.exists(CHARGEN) else CHARGEN_LOCAL
    rom = open(path, 'rb').read()
    upper = rom[0:0x800]
    lower = rom[0x800:0x1000]
    font = bytearray(128 * 8)

    def put(code, src, sc):
        font[code * 8:code * 8 + 8] = src[sc * 8:sc * 8 + 8]
    for a in range(32, 128):
        if 32 <= a <= 63:
            put(a, lower, a)
        elif a == 64:
            put(a, lower, 0)
        elif 65 <= a <= 90:
            put(a, lower, a)
        elif 97 <= a <= 122:
            put(a, lower, a - 96)
        elif a == 91:
            put(a, lower, 27)
        elif a == 93:
            put(a, lower, 29)
        elif a == 94:
            put(a, lower, 30)
        elif a == 96:
            put(a, lower, 39)
    # suits from the upper/graphics set: spade, heart, diamond, club
    for code, sc in ((1, 65), (2, 83), (3, 90), (4, 88)):
        put(code, upper, sc)
    for code, g in CUSTOM_GLYPHS.items():
        font[code * 8:code * 8 + 8] = bytes(g)
    return font


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
def prg(data):
    return bytes([0, 0]) + bytes(data)


def write(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'wb') as fh:
        fh.write(data)


def preview(img, path, scale=3):
    im = Image.new('RGB', (len(img[0]), len(img)))
    im.putdata([PAL[v] if v is not None else (255, 0, 255) for r in img for v in r])
    im.resize((im.size[0] * scale, im.size[1] * scale), Image.NEAREST).save(path)


def main():
    house, patches = build_house()
    title = build_title()
    sprites, anchors = build_sprites()
    font = build_font()

    write(os.path.join(ROOT, 'assets', 'bg.prg'), prg(to_cells(house)))
    write(os.path.join(ROOT, 'assets', 'title.prg'), prg(to_cells(title)))

    blob = bytearray(font)
    lines = ['; Generated by tools/build_assets.py -- do not edit.', '',
             'GFX_FONT                = $%05X' % GFX_BASE]
    lines.append('GFX_MASK                = $%05X   ; foreground mask, 1 bit/pixel, cell order' % (GFX_BASE + len(blob)))
    blob += build_mask()
    for n, rows in sprites:
        rows = polka(rows)
        addr = GFX_BASE + len(blob)
        h = len(rows)
        w = len(rows[0])
        blob += bytes([w, h])
        for r in rows:
            blob += bytes(0 if v is None else v for v in r)
        lines.append('SPR_%-20s= $%05X   ; %dx%d' % (n.upper(), addr, w, h))
    lines.append('')
    for n, (cx, cy, cw, ch, pix) in patches.items():
        addr = GFX_BASE + len(blob)
        blob += patch_cells(cw, ch, pix)
        lines.append('PATCH_%-18s= $%05X' % (n.upper(), addr))
        lines.append('PATCH_%-18s= %d' % (n.upper() + '_CX', cx))
        lines.append('PATCH_%-18s= %d' % (n.upper() + '_CY', cy))
        lines.append('PATCH_%-18s= %d' % (n.upper() + '_CW', cw))
        lines.append('PATCH_%-18s= %d' % (n.upper() + '_CH', ch))
    lines.append('')
    for n, (x, y) in anchors.items():
        lines.append('POSE_%-19s= %d' % (n.upper() + '_X', x))
        lines.append('POSE_%-19s= %d' % (n.upper() + '_Y', y))
    # Digital sounds: all in one file, LMP-SOUNDS, which boot copies to Attic.
    # To play one the game DMAs it into the chip-RAM play buffer SND_BUF
    # (audio DMA can only read chip RAM), then starts audio DMA on it.
    sounds = [('talk', 'phone_talk.wav'),          # his voice (the Amiga original)
              ('flush', 'flush.wav'),              # public domain, Wikimedia Commons
              ('bell', 'doorbell.wav'),            # CC0, Wikimedia Commons
              ('bark', 'bark.wav')]                # CC BY-SA 3.0, Amada44, Wikimedia Commons
    sblob = bytearray()
    lines.append('SND_BUF                 = $%05X   ; chip-RAM play buffer (bank 1)' % SND_BASE)
    lines.append('SND_FREQ                = $%06X   ; audio DMA step: rate * 2^24 / 40.5 MHz' % round(SND_RATE * 16777216 / 40500000))
    for i, (name, fn) in enumerate(sounds):
        snd = load_sound(os.path.join(ROOT, 'art', 'sound', fn), SND_RATE)
        assert SND_BASE + len(snd) < 0x1F800, name + ' sample is bigger than the play buffer'
        lines.append('SND_%-20s= %d' % (name.upper(), i))
        lines.append('SND_%-20s= $%05X   ; offset in Attic sound bank, %d bytes' % (name.upper() + '_OFS', len(sblob), len(snd)))
        lines.append('SND_%-20s= %d' % (name.upper() + '_LEN', len(snd)))
        sblob += snd
    lines.append('SOUNDS_SIZE             = %d' % len(sblob))
    assert len(sblob) < 0xFFFE, 'sound bank is bigger than the boot stage'
    write(os.path.join(ROOT, 'assets', 'sounds.prg'), prg(sblob))
    lines.append('')
    lines.append('GFX_SIZE                = %d' % len(blob))
    assert GFX_BASE + len(blob) < 0x60000, 'gfx blob overflows bank 5'
    write(os.path.join(ROOT, 'assets', 'gfx.prg'), prg(blob))
    write(os.path.join(ROOT, 'src', 'gen', 'assets.asm'), ('\n'.join(lines) + '\n').encode())

    swap = lambda v: ((v & 15) << 4) | (v >> 4)  # noqa: E731
    pl = ['; Generated by tools/build_assets.py -- do not edit.',
          '; Raw 8-bit RGB per index; write nib_swap[v] to $D100/$D200/$D300.', '']
    for ch, k in (('r', 0), ('g', 1), ('b', 2)):
        pl.append('pal_%s:' % ch)
        for i in range(0, 256, 16):
            pl.append('        .byte ' + ','.join('$%02X' % PAL[j][k] for j in range(i, i + 16)))
    pl.append('nib_swap:')
    for i in range(0, 256, 16):
        pl.append('        .byte ' + ','.join('$%02X' % swap(j) for j in range(i, i + 16)))
    write(os.path.join(ROOT, 'src', 'gen', 'palette.asm'), ('\n'.join(pl) + '\n').encode())

    # SID frequency table, MIDI notes 0..95 (PAL clock 985248 Hz). Index = note.
    nl = ['; Generated by tools/build_assets.py -- do not edit.',
          '; SID frequency words for MIDI note numbers 0..95 (PAL).', '']
    freqs = [min(0xFFFF, round(440 * 2 ** ((n - 69) / 12) * 16777216 / 985248)) for n in range(96)]
    nl.append('note_lo:')
    for i in range(0, 96, 16):
        nl.append('        .byte ' + ','.join('$%02X' % (f & 255) for f in freqs[i:i + 16]))
    nl.append('note_hi:')
    for i in range(0, 96, 16):
        nl.append('        .byte ' + ','.join('$%02X' % (f >> 8) for f in freqs[i:i + 16]))
    write(os.path.join(ROOT, 'src', 'gen', 'notes.asm'), ('\n'.join(nl) + '\n').encode())

    preview(house, os.path.join(ROOT, 'art', 'preview_house.png'))
    preview(title, os.path.join(ROOT, 'art', 'preview_title.png'))
    # sprite sheet
    W = sum(len(r[0]) + 4 for _, r in sprites)
    H = max(len(r) for _, r in sprites)
    sheet = [[None] * W for _ in range(H)]
    x = 0
    for _, rows in sprites:
        for yy, r in enumerate(rows):
            for xx, v in enumerate(r):
                sheet[yy][x + xx] = v
        x += len(rows[0]) + 4
    preview(sheet, os.path.join(ROOT, 'art', 'preview_sprites.png'), 4)
    print('bg %d, title %d, gfx %d bytes, %d sprites, %d patches' %
          (64000, 64000, len(blob), len(sprites), len(patches)))


if __name__ == '__main__':
    main()
