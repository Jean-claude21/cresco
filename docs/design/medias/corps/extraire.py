"""Turns the key-color body maps (face.png, dos.png) into app assets.

For each side it writes to packages/cresco_ui/assets/body/:
- <side>-<muscle>.png: one white alpha mask per muscle, tinted by the app with its volume color;
- <side>-labels.png: a quarter-resolution 8-bit map, pixel value = muscle index + 1 (0 = no muscle),
  used to know which muscle is under the finger.
Muscle slugs are the exercise catalog's (see MUSCLES); the index order is the one of that list.
"""
from pathlib import Path

from PIL import Image

HERE = Path(__file__).parent
OUT = HERE.parents[3] / 'packages' / 'cresco_ui' / 'assets' / 'body'
MUSCLES = [
    ('pectoraux', (255, 0, 0)),
    ('epaules', (0, 255, 0)),
    ('biceps', (0, 0, 255)),
    ('avant_bras', (255, 255, 0)),
    ('abdominaux', (255, 0, 255)),
    ('quadriceps', (0, 255, 255)),
    ('mollets', (255, 128, 0)),
    ('dos', (128, 0, 255)),
    ('triceps', (0, 128, 255)),
    ('lombaires', (255, 0, 128)),
    ('fessiers', (128, 255, 0)),
    ('ischios', (0, 255, 128)),
]
WHITE, SKIN, LINE = (255, 255, 255), (217, 217, 217), (58, 58, 58)
TOLERANCE = 60  # Squared-distance budget per channel sum, for slightly off pixels.


def nearest(px):
    """Index in MUSCLES of the key color closest to px, or a negative code for white, skin and line."""
    candidates = [(-1, WHITE), (-2, SKIN), (-3, LINE)] + [(i, c) for i, (_, c) in enumerate(MUSCLES)]
    best, dist = None, None
    for code, c in candidates:
        d = sum((a - b) ** 2 for a, b in zip(px, c))
        if dist is None or d < dist:
            best, dist = code, d
    return best


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for side in ('face', 'dos'):
        src = Image.open(HERE / f'{side}.png').convert('RGB')
        w, h = src.size
        pixels = src.load()
        base = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        bp = base.load()
        masks = {i: Image.new('L', (w, h), 0) for i in range(len(MUSCLES))}
        mp = {i: m.load() for i, m in masks.items()}
        labels = Image.new('L', (w, h), 0)
        lp = labels.load()
        cache = {}
        for y in range(h):
            for x in range(w):
                px = pixels[x, y]
                code = cache.get(px)
                if code is None:
                    code = cache[px] = nearest(px)
                if code == -2:
                    bp[x, y] = (*SKIN, 255)
                elif code == -3:
                    bp[x, y] = (*LINE, 255)
                elif code >= 0:
                    mp[code][x, y] = 255
                    lp[x, y] = code + 1
        # The drawn base layer is now the realistic render (../corps-realiste/preparer.py).
        present = []
        for i, (slug, _) in enumerate(MUSCLES):
            if masks[i].getbbox() is None:
                continue
            present.append(slug)
            white = Image.new('RGBA', (w, h), (255, 255, 255, 0))
            white.putalpha(masks[i])
            white.save(OUT / f'{side}-{slug}.png', optimize=True)
        labels.resize((w // 4, h // 4), Image.NEAREST).save(OUT / f'{side}-labels.png', optimize=True)
        print(side, (w, h), 'muscles:', ', '.join(present))


if __name__ == '__main__':
    main()
