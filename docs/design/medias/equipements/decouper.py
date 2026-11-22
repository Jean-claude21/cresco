"""Cuts the two equipment sheets (4 x 2 cells) into the app's equipment photos.

Writes packages/cresco_ui/assets/equipment/<id>.jpg: each cell cropped square, slightly above
its center so tall machines keep their pulley, 400 x 400, grayscale JPEG. Ids are the catalog's (exercise id or material).
"""
from pathlib import Path

from PIL import Image

HERE = Path(__file__).parent
OUT = HERE.parents[3] / 'packages' / 'cresco_ui' / 'assets' / 'equipment'
SHEETS = {
    'machines.png': [
        'tirage-vertical', 'rowing-assis-poulie', 'presse-cuisses', 'leg-curl',
        'leg-extension', 'mollets-debout', 'extension-triceps-poulie', 'crunch-poulie',
    ],
    'libres-cardio.png': ['barre', 'halteres', 'tapis', 'velo', 'rameur'],
}
SIZE = (400, 400)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for sheet, ids in SHEETS.items():
        img = Image.open(HERE / sheet).convert('L')
        cw, ch = img.width / 4, img.height / 2
        for i, eid in enumerate(ids):
            x0, y0 = (i % 4) * cw, (i // 4) * ch
            # Square crop a few pixels inside the cell (no seam), centered at 45 % of its height.
            w = cw - 8
            h = w
            cx, cy = x0 + cw / 2, y0 + ch * 0.45
            box = (round(cx - w / 2), round(cy - h / 2), round(cx + w / 2), round(cy + h / 2))
            cell = img.crop(box).resize(SIZE, Image.LANCZOS)
            cell.save(OUT / f'{eid}.jpg', quality=82, optimize=True, progressive=True)
            print(eid, box)


if __name__ == '__main__':
    main()
