"""Turns the realistic body renders (face.png, dos.png) into the app's base layer.

Writes packages/cresco_ui/assets/body/<side>-render.png: the grayscale body with a transparent
background (the white connected to the image border becomes transparent, white highlights inside
the body stay), 640 x 1280, gray + alpha. The muscle masks and the touch map still come from
../corps/extraire.py: the renders were aligned on those key-color maps (same silhouette box).

Run it after extraire.py: it also clears the shorts from the muscle masks, so the quadriceps,
glutes and hamstrings are tinted on the skin only (as in mockup G1-04).
"""
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = Path(__file__).parent
OUT = HERE.parents[3] / 'packages' / 'cresco_ui' / 'assets' / 'body'
SIZE = (640, 1280)
WHITE_LEVEL = 246  # Pixels this light and connected to the border are background.
SHORTS_LEVEL = 110  # The shorts are the dark area flooded from the crotch.


def shorts(gray):
    """Mask (L, 255 = shorts) of the dark shorts, flood-filled from the middle of the hips."""
    w, h = gray.size
    dark = gray.point(lambda v: 255 if v < SHORTS_LEVEL else 0)
    dark = dark.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(3))
    seed = next((w // 2, y) for y in range(int(h * 0.44), int(h * 0.56), 4) if dark.getpixel((w // 2, y)) == 255)
    ImageDraw.floodfill(dark, seed, 128)
    return dark.point(lambda v: 255 if v == 128 else 0).filter(ImageFilter.MaxFilter(5))


def main():
    for side in ('face', 'dos'):
        gray = Image.open(HERE / f'{side}.png').convert('L')
        w, h = gray.size
        # Background: flood fill from every border pixel over near-white pixels.
        marker = gray.point(lambda v: 255 if v >= WHITE_LEVEL else 0)
        for x, y in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1), (w // 2, 0), (w // 2, h - 1)]:
            if marker.getpixel((x, y)) == 255:
                ImageDraw.floodfill(marker, (x, y), 128)
        alpha = marker.point(lambda v: 0 if v == 128 else 255)
        # Soft one-pixel edge instead of a jagged cut.
        alpha = alpha.filter(ImageFilter.GaussianBlur(0.8))
        render = Image.merge('LA', (gray, alpha)).resize(SIZE, Image.LANCZOS)
        render.save(OUT / f'{side}-render.png', optimize=True)
        cut = shorts(gray)
        for mask_file in OUT.glob(f'{side}-*.png'):
            if mask_file.stem.endswith(('-render', '-labels', '-base')):
                continue
            mask = Image.open(mask_file).convert('RGBA')
            r, g, b, a = mask.split()
            mask = Image.merge('RGBA', (r, g, b, ImageChops.subtract(a, cut.resize(mask.size))))
            mask.save(mask_file, optimize=True)
        print(side, render.size, (OUT / f'{side}-render.png').stat().st_size // 1024, 'Ko')


if __name__ == '__main__':
    main()
