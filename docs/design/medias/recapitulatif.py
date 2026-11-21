"""Recap sheet of the final media, with "Mon corps" rebuilt from the extracted masks as the app will."""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).parent
BODY = HERE.parents[2] / 'packages' / 'cresco_ui' / 'assets' / 'body'
BG = '#EFEFEA'
font = ImageFont.truetype('arialbd.ttf', 40)
small = ImageFont.truetype('arial.ttf', 26)

# Volume colors of the example week (amber → braise red; grey = nothing).
VOLUME = {'quadriceps': '#E8341C', 'pectoraux': '#FF5A1F', 'dos': '#FF8A2A', 'epaules': '#FFB020',
          'triceps': '#FFB020', 'biceps': '#FFC96B', 'abdominaux': '#FFC96B', 'avant_bras': '#FFC96B'}
NOTHING = '#C9CBC4'


def body(side):
    base = Image.open(BODY / f'{side}-base.png').convert('RGBA')
    canvas = Image.new('RGBA', base.size, (255, 255, 255, 0))
    for mask in sorted(BODY.glob(f'{side}-*.png')):
        slug = mask.stem[len(side) + 1:]
        if slug in ('base', 'labels'):
            continue
        alpha = Image.open(mask).getchannel('A')
        tint = Image.new('RGBA', base.size, VOLUME.get(slug, NOTHING))
        tint.putalpha(alpha)
        canvas.alpha_composite(tint)
    canvas.alpha_composite(base)
    return canvas


def fit(img, w, h):
    img = img.copy()
    img.thumbnail((w, h))
    return img


sheet = Image.new('RGB', (2400, 2050), BG)
d = ImageDraw.Draw(sheet)
d.text((40, 30), 'Cresco · médias définitifs générés avec ChatGPT', fill='#0A0A0A', font=font)

duo = fit(Image.open(HERE / 'accueil-duo' / 'accueil-duo.png').convert('RGBA'), 760, 760)
sheet.paste(duo, (40, 110), duo)
d.text((40, 880), 'Accueil : le duo', fill='#0A0A0A', font=small)

for row, who in enumerate(('coach-femme', 'coach-homme')):
    for i, pose in enumerate(('salue', 'explique', 'carnet', 'pouce', 'reflechit', 'celebre')):
        im = fit(Image.open(HERE / who / f'pose-{pose}.png').convert('RGBA'), 250, 250)
        sheet.paste(im, (840 + i * 255, 110 + row * 380), im)
    d.text((840, 370 + row * 380), f'{who.replace("-", " ").capitalize()} · 6 poses', fill='#0A0A0A', font=small)

for i, side in enumerate(('face', 'dos')):
    im = fit(body(side), 500, 1000)
    sheet.paste(im, (40 + i * 520, 940), im)
d.text((40, 1960), 'Mon corps reconstruit depuis les masques (exemple de semaine)', fill='#0A0A0A', font=small)

for i, icon in enumerate(('seance', 'repas', 'jeune', 'sommeil')):
    im = fit(Image.open(HERE / 'icones-photos' / f'icone-{icon}.png').convert('RGBA'), 280, 280)
    sheet.paste(im, (1120 + i * 300, 900), im)
d.text((1120, 1190), 'Icônes des raccourcis', fill='#0A0A0A', font=small)

for i, photo in enumerate(('seance-du-jour', 'chest-press', 'intervalles', 'jambes')):
    im = fit(Image.open(HERE / 'icones-photos' / f'photo-{photo}.png').convert('RGB'), 600, 340)
    sheet.paste(im, (1120 + (i % 2) * 620, 1250 + (i // 2) * 360))
d.text((1120, 1960), 'Photos (noir et blanc)', fill='#0A0A0A', font=small)

sheet.save(HERE / 'recapitulatif.png', optimize=True)
print('ok', sheet.size)
