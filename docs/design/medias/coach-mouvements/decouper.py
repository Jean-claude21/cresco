"""Cuts Karim's movement sheets (3 columns x 4 rows of 341 x 384 px) into keyframes.

Writes packages/cresco_ui/assets/coach_moves/<exercise id>-<1|2|3>.jpg (start, middle, end) and
packages/cresco_ui/lib/src/coach_moves_list.dart, the set of exercises that have their three poses.
Sheets not generated yet are skipped. Usage: python -I decouper.py
"""
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).parent
ROOT = HERE.parents[3]
OUT = ROOT / 'packages' / 'cresco_ui' / 'assets' / 'coach_moves'
LIST = ROOT / 'packages' / 'cresco_ui' / 'lib' / 'src' / 'coach_moves_list.dart'

# One row per exercise, in the order of each BRIEF.md.
SHEETS = {
    'planche-1.png': ['developpe-convergent', 'tirage-vertical', 'presse-cuisses', 'leg-curl-assis'],
    'planche-2.png': ['hack-squat'],
    'lot-a/planche-1.png': ['adducteurs-machine', 'belt-squat', 'crunch-poulie', 'abdominaux-machine'],
    'lot-a/planche-2.png': ['curl-biceps-surleve', 'curl-biceps-machine', 'dips-assis-machine', 'developpe-disques'],
    'lot-a/planche-3.png': ['developpe-decline-disques', 'extension-inversee', 'extension-lombaire-machine', 'extension-triceps-poulie'],
    'lot-a/planche-4.png': ['extension-triceps-machine', 'hip-thrust-machine', 'leg-curl', 'leg-curl-genoux'],
    'lot-b/planche-1.png': ['leg-extension', 'leg-extension-inclinee', 'fessiers-machine', 'mollets-assis-disques'],
    'lot-b/planche-2.png': ['mollets-debout', 'mollets-assis-guidee', 'pec-deck', 'pendulum-squat'],
    'lot-b/planche-3.png': ['presse-inclinee-machine', 'presse-cuisses-assise', 'developpe-epaules-convergent', 'pull-over-machine'],
    'lot-c/planche-1.png': ['rotation-buste', 'rowing-divergent', 'rowing-assis-poulie', 'rowing-bas-disques'],
    'lot-c/planche-2.png': ['rowing-haut-disques', 'rowing-incline-levier', 'rowing-t-bar', 'squat-fentes-disques'],
    'lot-c/planche-3.png': ['tirage-vertical-divergent', 'traction-assistee', 'ecarte-decline-disques', 'elevations-laterales-machine'],
    'lot-d/planche-1.png': ['oiseau-machine', 'dips-assistes', 'abducteurs-machine', 'ecarte-vis-a-vis'],
    'lot-d/planche-2.png': ['tirage-visage-poulie', 'squat-smith', 'developpe-couche-smith', 'releve-jambes-chaise'],
    'lot-d/planche-3.png': ['extension-lombaire-45', 'curl-pupitre', 'crunch-banc', 'glute-ham-raise'],
    'lot-e/planche-1.png': ['poussee-traineau', 'curl-poulie', 'elevations-laterales-poulie', 'tirage-bras-tendus-poulie'],
    'lot-e/planche-2.png': ['extension-triceps-nuque-poulie', 'kickback-fessier-poulie', 'bucheron-poulie', 'oiseau-poulie'],
    'lot-e/planche-3.png': ['ecarte-poulie-basse', 'developpe-militaire-smith', 'fentes-smith', 'hip-thrust-smith'],
    'lot-e/planche-4.png': ['mollets-smith', 'rowing-smith'],
}
def shift_to(ref, img, limit=40):
    """Translation that best lays img over ref (phase correlation on the dark machine frame)."""
    a = 255 - np.asarray(ref.convert('L'), dtype=float)
    b = 255 - np.asarray(img.convert('L'), dtype=float)
    a, b = (a > 150) * 1.0, (b > 150) * 1.0  # the anthracite frame, not the skin or the shirt shading
    r = np.fft.ifft2(np.fft.fft2(a) * np.conj(np.fft.fft2(b)))
    dy, dx = np.unravel_index(np.argmax(np.abs(r)), r.shape)
    dy = dy - a.shape[0] if dy > a.shape[0] // 2 else dy
    dx = dx - a.shape[1] if dx > a.shape[1] // 2 else dx
    return (int(dx), int(dy)) if abs(dx) <= limit and abs(dy) <= limit else (0, 0)


def align(ref, img):
    dx, dy = shift_to(ref, img)
    if (dx, dy) == (0, 0):
        return img
    out = Image.new('RGB', img.size, 'white')
    out.paste(img, (dx, dy))
    return out


# Rows to leave out after review (a pose that is wrong is worse than none).
REJECTED: set[str] = set()
# Redone in lot-f: the first version had no back pad.
REDONE = {'lot-f/planche-1.png': ['extension-lombaire-machine']}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    done = []
    redone = {e for ids in REDONE.values() for e in ids}
    sheets = {k: [None if e in redone else e for e in v] for k, v in SHEETS.items()} | REDONE
    for sheet, ids in sheets.items():
        path = HERE / sheet
        if not path.exists():
            print('manque', sheet)
            continue
        img = Image.open(path).convert('RGB')
        rw, rh = img.width / 3, img.height / 4
        for r, eid in enumerate(ids):
            if eid is None or eid in REJECTED:
                continue
            cells = [img.crop((round(c * rw), round(r * rh), round(c * rw) + int(rw), round(r * rh) + int(rh))) for c in range(3)]
            # Poses 2 and 3 are laid over pose 1 so the machine stays still in the loop.
            cells = [cells[0]] + [align(cells[0], cell) for cell in cells[1:]]
            for c, cell in enumerate(cells):
                cell.resize((342, 384), Image.LANCZOS).save(OUT / f'{eid}-{c + 1}.jpg', quality=86, optimize=True, progressive=True)
            done.append(eid)
        print(sheet, len(ids))
    for stale in OUT.glob('*.jpg'):
        if stale.stem.rsplit('-', 1)[0] not in done:
            stale.unlink()
    body = ''.join(f"  '{e}',\n" for e in sorted(done))
    LIST.write_text(
        '// Generated by docs/design/medias/coach-mouvements/decouper.py: do not edit.\n\n'
        '/// Exercises with their three poses in `assets/coach_moves/`.\n'
        f'const coachMovesAvailable = <String>{{\n{body}}};\n',
        encoding='utf-8',
    )
    print(len(done), 'exercices')


if __name__ == '__main__':
    main()
