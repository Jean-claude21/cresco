"""Cuts the machine sheets (4 x 2 cells) into equipment photos for "Ma salle".

Writes packages/cresco_ui/assets/equipment/<id>.jpg (400 x 400, square crop slightly above the
cell center, grayscale JPEG), like ../equipements/decouper.py. The four machines redone in
../machines-2 replace the first versions. Ids are the exercise (or material) ids of the catalog.
Usage: python -I decouper.py
"""
from pathlib import Path

from PIL import Image

HERE = Path(__file__).parent
OUT = HERE.parents[3] / 'packages' / 'cresco_ui' / 'assets' / 'equipment'
SHEETS = {
    HERE / 'planche-1.png': [
        'developpe-convergent', 'pec-deck', 'developpe-epaules-convergent', 'tirage-vertical-divergent',
        'rowing-divergent', 'elevations-laterales-machine', 'traction-dips-assistes', 'pull-over-machine',
    ],
    HERE / 'planche-2.png': [
        'curl-biceps-machine', 'extension-triceps-machine', 'abdominaux-machine', 'rotation-buste',
        'extension-lombaire-machine', 'presse-cuisses-assise', 'leg-curl-assis', 'adducteurs-abducteurs',
    ],
    HERE / 'planche-3.png': [
        'fessiers-machine', 'mollets-assis-guidee', 'mollets-assis-disques', 'poulie',
        'vis-a-vis', 'presse-inclinee-machine', 'chaise-romaine', 'banc-lombaires',
    ],
    HERE / 'planche-4.png': [
        'hack-squat', 'pendulum-squat', 'belt-squat', 'leg-extension-inclinee',
        'leg-curl-genoux', 'hip-thrust-machine', 'smith', 'rack',
    ],
    HERE / 'planche-5.png': ['rowing-bas-disques', 'rowing-haut-disques', 'rowing-incline-levier', 'rowing-t-bar', 'curl-biceps-surleve'],
    # Stations of the full Matrix catalog (machines-3).
    HERE.parent / 'machines-3' / 'planche-1.png': [
        'developpe-disques', 'developpe-decline-disques', 'ecarte-decline-disques', 'dips-assis-machine',
        'pupitre', 'banc-abdos', 'extension-inversee', 'ghd',
    ],
    HERE.parent / 'machines-3' / 'planche-2.png': ['squat-fentes-disques', 'traineau', 'banc', 'banc-olympique'],
    # Redone with a sharper brief (machines-2): they overwrite the first versions.
    HERE.parent / 'machines-2' / 'planche.png': [
        'abdominaux-machine', 'extension-lombaire-machine', 'pull-over-machine', 'extension-triceps-machine',
    ],
}
SIZE = (400, 400)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for sheet, ids in SHEETS.items():
        if not sheet.exists():
            print('manque', sheet.name)
            continue
        img = Image.open(sheet).convert('L')
        cw, ch = img.width / 4, img.height / 2
        for i, eid in enumerate(ids):
            x0, y0 = (i % 4) * cw, (i // 4) * ch
            w = cw - 8
            cx, cy = x0 + cw / 2, y0 + ch * 0.47
            box = (round(cx - w / 2), round(cy - w / 2), round(cx + w / 2), round(cy + w / 2))
            img.crop(box).resize(SIZE, Image.LANCZOS).save(OUT / f'{eid}.jpg', quality=82, optimize=True, progressive=True)
        print(sheet.name, len(ids))


if __name__ == '__main__':
    main()
