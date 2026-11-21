"""Prepares the app assets from the media generated with ChatGPT, and archives the mockups lightly.

Run from anywhere: python docs/design/medias/preparer_assets.py
- packages/cresco_ui/assets/coach/<femme|homme>-<pose>.png: poses resized to 640 px, 256-color palette;
- packages/cresco_ui/assets/coach/duo.png: welcome illustration, 1024 px;
- packages/cresco_ui/assets/icons/<name>.png: shortcut icons, 384 px;
- packages/cresco_ui/assets/photos/<name>.jpg: black-and-white photos, 1200 px wide, JPEG q80;
- docs/design: reference sheets and mockups converted to JPEG, raw PNGs and Codex logs removed.
The muscle masks are produced separately by corps/extraire.py.
"""
from pathlib import Path

from PIL import Image

MEDIA = Path(__file__).parent
DESIGN = MEDIA.parent
ASSETS = DESIGN.parents[1] / 'packages' / 'cresco_ui' / 'assets'
POSES = ['salue', 'explique', 'carnet', 'pouce', 'reflechit', 'celebre']


def save_palette_png(img: Image.Image, out: Path, size: int) -> None:
    """Resizes an RGBA illustration and stores it with a 256-color palette (flat art stays crisp)."""
    img = img.convert('RGBA')
    img.thumbnail((size, size), Image.LANCZOS)
    img.quantize(colors=256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).save(out, optimize=True)


def to_jpeg(src: Path, width: int, quality: int = 82) -> Path:
    img = Image.open(src).convert('RGB')
    if img.width > width:
        img = img.resize((width, round(img.height * width / img.width)), Image.LANCZOS)
    out = src.with_suffix('.jpg')
    img.save(out, quality=quality, optimize=True, progressive=True)
    return out


def main() -> None:
    for d in ('coach', 'icons', 'photos'):
        (ASSETS / d).mkdir(parents=True, exist_ok=True)

    for who in ('femme', 'homme'):
        src = MEDIA / f'coach-{who}'
        for pose in POSES:
            save_palette_png(Image.open(src / f'pose-{pose}.png'), ASSETS / 'coach' / f'{who}-{pose}.png', 640)
    save_palette_png(Image.open(MEDIA / 'accueil-duo' / 'accueil-duo.png'), ASSETS / 'coach' / 'duo.png', 1024)

    for icon in ('seance', 'repas', 'jeune', 'sommeil'):
        save_palette_png(Image.open(MEDIA / 'icones-photos' / f'icone-{icon}.png'), ASSETS / 'icons' / f'{icon}.png', 384)
    for photo in ('seance-du-jour', 'chest-press', 'intervalles', 'jambes'):
        img = Image.open(MEDIA / 'icones-photos' / f'photo-{photo}.png').convert('RGB')
        img.thumbnail((1200, 1200), Image.LANCZOS)
        img.save(ASSETS / 'photos' / f'{photo}.jpg', quality=80, optimize=True, progressive=True)

    # Archive: keep the sources the docs show as light JPEGs; the app assets above are the reference.
    for who in ('coach-femme', 'coach-homme'):
        to_jpeg(MEDIA / who / 'reference.png', 1536, 85)
    to_jpeg(MEDIA / 'recapitulatif.png', 2400, 85)
    for png in list(MEDIA.glob('*/*.png')) + [MEDIA / 'recapitulatif.png']:
        if png.parent.name == 'corps' and png.stem in ('face', 'dos'):
            continue  # Exact key colors: needed to re-extract the muscle masks.
        png.unlink()
    for png in DESIGN.glob('propositions-v2/**/*.png'):
        to_jpeg(png, 2000 if png.stem.startswith('planche') else 900)
        png.unlink()
    for log in DESIGN.glob('**/codex.log'):
        log.unlink()

    total = sum(f.stat().st_size for f in ASSETS.rglob('*') if f.is_file())
    print(f'assets: {total / 1e6:.1f} MB')


if __name__ == '__main__':
    main()
