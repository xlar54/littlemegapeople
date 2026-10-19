"""Shared helpers for the Little Mega People asset pipeline.

Source art is a set of Amiga Little Computer People screenshots (art/source/),
captured at 2x, 4x or 6x scale. Everything here works in native Amiga pixels:
320x200, indexed against the game's 17-entry Amiga palette (AMIGA_PAL).
"""
import os
from collections import Counter
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, 'art')
SRC = os.path.join(ART, 'source')

# The 17 colours the Amiga LCP house uses (12-bit Amiga values, 8-bit scaled).
AMIGA_PAL = [
    (153, 153, 153), (0, 0, 221), (136, 0, 0), (255, 255, 255), (255, 187, 85),
    (170, 68, 0), (85, 85, 85), (51, 170, 85), (204, 204, 204), (0, 0, 0),
    (34, 102, 255), (17, 102, 17), (0, 204, 204), (221, 34, 153), (255, 0, 0),
    (238, 119, 0), (255, 204, 153),
]
# One letter per AMIGA_PAL entry, used by the ASCII sprite sheets.
AMIGA_CH = 'gbrwonudlkBvcmROp'

# Frames used for the empty-house majority vote. 'cards' has the blackjack table
# drawn over the top 60 rows, so those rows are excluded for it.
HOUSE_FRAMES = ['armchair', 'piano', 'stairs', 'kitchen', 'eating', 'brushing',
                'attic_dog', 'house_a', 'armchair_b', 'computer', 'cards']

_qcache = {}


def _nearest(c):
    if c not in _qcache:
        _qcache[c] = min(range(len(AMIGA_PAL)),
                         key=lambda i: sum((a - b) ** 2 for a, b in zip(c, AMIGA_PAL[i])))
    return _qcache[c]


def _sample(im, s, ox, oy, pal_fn):
    px = im.load()
    w, h = im.size
    out = [[9] * 320 for _ in range(200)]
    for y in range(200):
        sy = int(oy + y * s + s / 2)
        if not 0 <= sy < h:
            continue
        row = out[y]
        for x in range(320):
            sx = int(ox + x * s + s / 2)
            if 0 <= sx < w:
                row[x] = pal_fn(px[sx, sy])
    return out


_frames = {}


def frame(name):
    """Native 320x200 frame as a list of rows of AMIGA_PAL indices."""
    if name in _frames:
        return _frames[name]
    im = Image.open(os.path.join(SRC, name + '.png')).convert('RGB')
    s = im.size[0] / 320
    if name == 'house_a':
        f = _sample(im, s, 0, 0, _nearest)
    else:
        ref = frame('house_a')
        best = None
        for dy in range(-3, 4):
            f = _sample(im, s, 0, dy * s, _nearest)
            d = sum(1 for y in range(70, 200, 2) for x in range(0, 320, 2) if f[y][x] != ref[y][x])
            if best is None or d < best[0]:
                best = (d, f)
        f = best[1]
    _frames[name] = f
    return f


def raw_frame(name):
    """Native 320x200 frame, unaligned, as RGB tuples (for non-house screens)."""
    im = Image.open(os.path.join(SRC, name + '.png')).convert('RGB')
    s = im.size[0] / 320
    return _sample(im, s, 0, 0, lambda c: c)


_bg = None


def empty_house():
    """Majority vote over every house frame: removes the person, dog and props."""
    global _bg
    if _bg is not None:
        return _bg
    fs = {n: frame(n) for n in HOUSE_FRAMES}
    bg = [[0] * 320 for _ in range(200)]
    for y in range(200):
        for x in range(320):
            c = Counter(fs[n][y][x] for n in HOUSE_FRAMES if not (n == 'cards' and y < 60))
            bg[y][x] = c.most_common(1)[0][0]
    _bg = bg
    return bg


def extract(name, x0, y0, w, h):
    """Cut a sprite out of a frame: pixels that differ from the empty house,
    plus interior pixels that happen to match the wall colour (found by flood
    filling 'same as background' from the crop border). Returns rows of
    AMIGA_PAL indices with None for transparent."""
    f = frame(name)
    bg = empty_house()
    same = [[f[y0 + y][x0 + x] == bg[y0 + y][x0 + x] for x in range(w)] for y in range(h)]
    outside = [[False] * w for _ in range(h)]
    stack = [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]
    while stack:
        x, y = stack.pop()
        if 0 <= x < w and 0 <= y < h and same[y][x] and not outside[y][x]:
            outside[y][x] = True
            stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return [[None if outside[y][x] else f[y0 + y][x0 + x] for x in range(w)] for y in range(h)]


def trim(rows):
    """Crop transparent margins. Returns (dx, dy, rows)."""
    h = len(rows)
    w = len(rows[0])
    ys = [y for y in range(h) if any(v is not None for v in rows[y])]
    xs = [x for x in range(w) if any(rows[y][x] is not None for y in range(h))]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    return x0, y0, [r[x0:x1 + 1] for r in rows[y0:y1 + 1]]


def to_ascii(rows):
    return [''.join('.' if v is None else AMIGA_CH[v] for v in r) for r in rows]


def from_ascii(lines):
    return [[None if c == '.' else AMIGA_CH.index(c) for c in ln] for ln in lines]
