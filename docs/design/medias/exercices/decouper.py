"""Cuts the six exercise sheets (4 rows x 2 columns: start, end) into the app's demo frames.

Writes packages/cresco_ui/assets/exercises/<id>-depart.jpg and <id>-arrivee.jpg (512 x 384,
grayscale JPEG). Ids are the exercise catalog's. Usage: python -I decouper.py
"""
from pathlib import Path

from PIL import Image

HERE = Path(__file__).parent
OUT = HERE.parents[3] / 'packages' / 'cresco_ui' / 'assets' / 'exercises'
SHEETS = {
    'planche-1.png': ['developpe-couche-barre', 'developpe-incline-halteres', 'developpe-militaire', 'elevations-laterales'],
    'planche-2.png': ['tractions', 'tirage-vertical', 'rowing-barre', 'rowing-assis-poulie'],
    'planche-3.png': ['squat-barre', 'presse-cuisses', 'souleve-de-terre', 'souleve-terre-roumain'],
    'planche-4.png': ['fentes-halteres', 'leg-curl', 'leg-extension', 'hip-thrust'],
    'planche-5.png': ['mollets-debout', 'curl-halteres', 'extension-triceps-poulie', 'dips'],
    'planche-6.png': ['pompes', 'crunch-poulie'],
}
SIZE = (512, 384)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for sheet, ids in SHEETS.items():
        path = HERE / sheet
        if not path.exists():
            print('manque', sheet)
            continue
        img = Image.open(path).convert('L')
        cw, ch = img.width / 2, img.height / 4
        for row, eid in enumerate(ids):
            for col, name in enumerate(('depart', 'arrivee')):
                box = (round(col * cw + 3), round(row * ch + 3), round((col + 1) * cw - 3), round((row + 1) * ch - 3))
                img.crop(box).resize(SIZE, Image.LANCZOS).save(OUT / f'{eid}-{name}.jpg', quality=80, optimize=True, progressive=True)
            print(eid)


if __name__ == '__main__':
    main()
