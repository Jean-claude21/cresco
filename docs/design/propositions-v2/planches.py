"""Assembles each direction's 4 screens into one side-by-side sheet (planche-<direction>.png)."""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).parent
SCREENS = ['01-aujourdhui', '02-seance', '03-mon-corps', '04-jeune']
TITLES = {'A-doux': 'A · Doux et clair', 'B-braise': 'B · Nuit et braise', 'C-editorial': 'C · Carnet éditorial', 'D-net': 'D · Net et direct (Cal AI + Uber)'}
W, H, GAP, TOP = 585, 1266, 40, 120

for folder, title in TITLES.items():
    sheet = Image.new('RGB', (GAP + len(SCREENS) * (W + GAP), TOP + H + GAP), '#E9EAE5')
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype('arialbd.ttf', 56)
    except OSError:
        font = ImageFont.load_default()
    draw.text((GAP, 32), title, fill='#111311', font=font)
    for i, name in enumerate(SCREENS):
        img = Image.open(ROOT / folder / f'{name}.png').convert('RGB').resize((W, H), Image.LANCZOS)
        sheet.paste(img, (GAP + i * (W + GAP), TOP))
    out = ROOT / f'planche-{folder}.png'
    sheet.save(out, optimize=True)
    print(out.name, sheet.size)
