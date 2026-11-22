"""Builds CATALOGUE-MATRIX.md from matrix-catalogue-brut.txt (official Matrix catalog, 22/11/2026).

For each model: range, model code, official English name, French name, and the Cresco machine or
equipment it maps to (exercise id, `material:<id>`, or "à créer"). Storage racks and platforms are
listed apart: they are not exercise stations. Usage: python -I catalogue_matrix.py
"""
import re
from collections import OrderedDict
from pathlib import Path

HERE = Path(__file__).parent

STORAGE = re.compile(
    r'dumbbell rack|flat rack|saddle rack|kettlebell|ball rack|mat wall rack|plate and bar rack|barbell rack|'
    r'accessory rack|weight tree|weight rack|portable seat|platform|blank station|dumbbell flat',
    re.I,
)

# (pattern on the model name, French name, Cresco ids). The first match wins: specific first.
RULES = [
    (r'multi press', 'Presse multiple (pectoraux, incliné, épaules)', ['developpe-convergent', 'presse-inclinee-machine', 'developpe-epaules-convergent']),
    (r'converging chest press', 'Presse pectorale convergente', ['developpe-convergent']),
    (r'vertical decline bench press', 'Développé décliné vertical à disques', ['developpe-decline-disques']),
    (r'vertical bench press', 'Développé vertical à disques', ['developpe-disques']),
    (r'supine bench press', 'Développé couché à disques', ['developpe-disques']),
    (r'incline bench press', 'Développé incliné à disques', ['presse-inclinee-machine']),
    (r'chest press', 'Presse pectorale', ['developpe-convergent']),
    (r'decline pec fly', 'Écarté décliné à disques', ['ecarte-decline-disques']),
    (r'pec(toral)? fly / rear delt|rear delt / fly', 'Pec deck / oiseau inversé', ['material:pec-deck']),
    (r'pec(toral)? fly', 'Pec deck (écarté)', ['material:pec-deck']),
    (r'converging shoulder press', 'Presse épaules convergente', ['developpe-epaules-convergent']),
    (r'shoulder press', 'Presse épaules', ['developpe-epaules-convergent']),
    (r'lateral raise', 'Élévations latérales', ['elevations-laterales-machine']),
    (r'lat pulldown / seated row', 'Tirage vertical / rowing assis', ['tirage-vertical-divergent', 'rowing-divergent']),
    (r'diverging lat pulldown', 'Tirage vertical divergent', ['tirage-vertical-divergent']),
    (r'lat pulldown', 'Tirage vertical', ['tirage-vertical']),
    (r'diverging seated row', 'Rowing assis divergent', ['rowing-divergent']),
    (r't-bar row', 'Rowing T-bar', ['rowing-t-bar']),
    (r'incline lever row', 'Rowing incliné à levier', ['rowing-incline-levier']),
    (r'high row', 'Rowing haut', ['rowing-haut-disques']),
    (r'low row', 'Rowing bas', ['rowing-bas-disques']),
    (r'seated row', 'Rowing assis', ['rowing-divergent']),
    (r'elevated biceps curl', 'Curl biceps surélevé à disques', ['curl-biceps-surleve']),
    (r'bicep / tricep', 'Curl biceps / extension triceps', ['curl-biceps-machine', 'extension-triceps-machine']),
    (r'preacher curl', 'Pupitre à biceps', ['material:pupitre']),
    (r'standing arm curl', 'Pupitre à biceps debout', ['material:pupitre']),
    (r'biceps? curl|arm curl', 'Curl biceps', ['curl-biceps-machine']),
    (r'triceps pressdown', 'Extension triceps à la poulie haute', ['extension-triceps-poulie']),
    (r'triceps press', 'Dips assis (triceps press)', ['dips-assis-machine']),
    (r'triceps? extension', 'Extension triceps', ['extension-triceps-machine']),
    (r'ab crunch bench|adjustable ab bench', 'Banc à abdominaux', ['material:banc-abdos']),
    (r'ab / low back', 'Abdominaux / lombaires', ['abdominaux-machine', 'extension-lombaire-machine']),
    (r'abdominal', 'Machine abdominale (crunch)', ['abdominaux-machine']),
    (r'rotary torso', 'Rotation du buste', ['rotation-buste']),
    (r'reverse back extension', 'Extension lombaire inversée (reverse hyper)', ['extension-inversee']),
    (r'back extension bench', 'Banc à lombaires', ['material:banc-lombaires']),
    (r'mi back trainer', 'Machine lombaires (rééducation)', ['extension-lombaire-machine']),
    (r'back extension', 'Extension lombaire', ['extension-lombaire-machine']),
    (r'glute ham', 'GHD (glute ham)', ['material:ghd']),
    (r'chin / dip|dip / chin', 'Traction et dips assistés', ['material:traction-dips-assistes']),
    (r'vkr|power station', 'Chaise romaine', ['material:chaise-romaine']),
    (r'leg press / calf press', 'Presse à cuisses / mollets', ['presse-cuisses-assise', 'mollets-assis-guidee']),
    (r'45-degree leg press', 'Presse à cuisses 45°', ['presse-cuisses']),
    (r'leg press', 'Presse à cuisses assise', ['presse-cuisses-assise']),
    (r'leg extension / leg curl', 'Leg extension / leg curl', ['leg-extension', 'leg-curl-assis']),
    (r'reclining leg extension', 'Leg extension inclinée', ['leg-extension-inclinee']),
    (r'leg extension', 'Leg extension', ['leg-extension']),
    (r'kneeling leg curl', 'Leg curl à genoux', ['leg-curl-genoux']),
    (r'prone leg curl', 'Leg curl allongé', ['leg-curl']),
    (r'seated leg curl', 'Leg curl assis', ['leg-curl-assis']),
    (r'hip abductor / adductor', 'Adducteurs / abducteurs', ['material:adducteurs-abducteurs']),
    (r'standing hip abductor', 'Abducteurs debout à disques', ['material:adducteurs-abducteurs']),
    (r'hip adduct', 'Adducteurs', ['material:adducteurs-abducteurs']),
    (r'hip abduct', 'Abducteurs', ['material:adducteurs-abducteurs']),
    (r'rotary hip', 'Extension de hanche rotative', ['fessiers-machine']),
    (r'standing hip thrust|hip thrust', 'Hip thrust', ['hip-thrust-machine']),
    (r'glute', 'Machine fessiers', ['fessiers-machine']),
    (r'calf press|calf extension', 'Mollets (presse)', ['mollets-assis-guidee']),
    (r'standing calf', 'Mollets debout', ['mollets-debout']),
    (r'seated calf', 'Mollets assis à disques', ['mollets-assis-disques']),
    (r'hack squat', 'Hack squat', ['hack-squat']),
    (r'pendulum squat|perfect squat', 'Pendulum squat', ['pendulum-squat']),
    (r'belt squat', 'Belt squat', ['belt-squat']),
    (r'squat / lunge', 'Squat / fentes à disques', ['squat-fentes-disques']),
    (r'smith', 'Smith machine', ['material:smith']),
    (r'power rack|half rack|squat rack|configurable', 'Rack à squat', ['material:rack']),
    (r'cable crossover', 'Vis-à-vis à poulies', ['material:vis-a-vis']),
    (r'adjustable pulley|functional trainer', 'Poulie double réglable', ['material:poulie']),
    (r'multi-station|multi-gym', 'Station multiple (tirage, rowing, triceps à la poulie)', ['tirage-vertical', 'rowing-assis-poulie', 'extension-triceps-poulie']),
    (r'push sled', 'Traîneau de poussée', ['material:traineau']),
    (r'olympic (flat|incline|decline|shoulder) bench|3-way olympic', 'Banc olympique (avec supports de barre)', ['material:banc-olympique']),
    (r'bench', 'Banc de musculation (plat ou réglable)', ['material:banc']),
]

SERIES = [
    ('Ultra', 'Ultra (haut de gamme, charge guidée)'),
    ('Aura', 'Aura (charge guidée et multi-stations)'),
    ('Versa', 'Versa (charge guidée)'),
    ('Go Series', 'Go (charge guidée, compacte)'),
    ('G1', 'G1 (multi-stations et bancs)'),
    ('Xult', 'Xult (Varsity : disques, Smith, multi-gym)'),
    ('Magnum', 'Magnum (charges libres, bancs, racks)'),
    ('Studio', 'Studio'),
    ('Kettlebell', 'Divers'),
    ('Blank', 'Divers'),
]

LABELS = {
    'single-station': 'Charge guidée',
    'multi-station': 'Multi-station',
    'plate-loaded': 'Disques',
    'free-weights': 'Charges libres',
    'racks-and-platforms': 'Racks et plateformes',
}


def code_of(slug):
    if slug.startswith('mac-'):
        return slug.split('-xult')[0].upper()
    m = re.match(r'([a-z]+\d*-[a-z]*\d+[a-z]?|mac-[a-z0-9]+|mg-[a-z0-9]+|vs-[a-z0-9]+|md-[a-z0-9]+|go-[a-z0-9]+|mr\d+|vy-[a-z0-9]+)', slug)
    return (m.group(1) if m else '').upper()


def main():
    rows = []
    for line in (HERE / 'matrix-catalogue-brut.txt').read_text(encoding='utf-8').splitlines():
        if not line.strip() or line.startswith('#'):
            continue
        path, name = [x.strip() for x in line.split('||')]
        cat, slug = path.split('/')
        series = next((label for key, label in SERIES if name.startswith(key)), 'Divers')
        if 'MD ' in name:
            series = 'Versa MD (rééducation)'
        model = re.sub(r'^(Ultra|Aura|Versa MD|Versa|Go Series|G1|Xult|Magnum PRO|Magnum)\s+', '', name)
        if STORAGE.search(name):
            fr, cresco = 'Rangement ou plateforme', ['—']
        else:
            fr, cresco = next(((f, c) for p, f, c in RULES if re.search(p, model, re.I)), ('?', ['à classer']))
        rows.append(dict(series=series, cat=LABELS.get(cat, cat), code=code_of(slug), name=name, fr=fr, cresco=cresco))

    groups = OrderedDict()
    for label in [s for _, s in SERIES] + ['Versa MD (rééducation)', 'Divers']:
        groups.setdefault(label, [])
    for r in rows:
        groups[r['series']].append(r)

    def cell(ids):
        out = []
        for i in ids:
            if i.startswith('nouveau:'):
                out.append(f'à créer (`{i[8:]}`)')
            elif i == '—':
                out.append('—')
            else:
                out.append(f'`{i}`')
        return ', '.join(out)

    stations = [r for r in rows if r['cresco'] != ['—']]
    to_create = sorted({i[8:] for r in rows for i in r['cresco'] if i.startswith('nouveau:')})
    md = [
        '# Catalogue Matrix Fitness (force)',
        '',
        f'Lu le 22/11/2026 sur le catalogue officiel ([fr.matrixfitness.com, Force](https://fr.matrixfitness.com/fra/strength/catalog)) : '
        f'**{len(rows)} produits**, dont **{len(stations)} postes d’exercice** et {len(rows) - len(stations)} rangements ou plateformes. '
        'Source brute : [matrix-catalogue-brut.txt](matrix-catalogue-brut.txt) ; ce tableau est généré par [catalogue_matrix.py](catalogue_matrix.py).',
        '',
        'Chaque modèle est rattaché à une machine de Cresco (identifiant d’exercice, ou `material:` pour un équipement partagé). '
        'Une même machine existe dans plusieurs gammes : dans l’app, on coche le poste (par exemple « Presse pectorale convergente »), '
        'quelle que soit la gamme. Noms anglais officiels, noms français de Cresco. Les photos de l’app sont génériques, sans marque.',
        '',
        (f'**Postes encore à créer dans Cresco** ({len(to_create)}) : ' + ', '.join(f'`{t}`' for t in to_create) + '.')
        if to_create
        else '**Chaque poste d’exercice de Matrix a son équivalent dans Cresco**, avec sa photo dans « Ma salle ».',
        '',
    ]
    for label, items in groups.items():
        if not items:
            continue
        md += [f'## {label} ({len(items)})', '', '| Code | Modèle (anglais) | Type | Nom français | Dans Cresco |', '|---|---|---|---|---|']
        for r in items:
            md.append(f"| {r['code']} | {r['name']} | {r['cat']} | {r['fr']} | {cell(r['cresco'])} |")
        md.append('')
    (HERE / 'CATALOGUE-MATRIX.md').write_text('\n'.join(md), encoding='utf-8', newline='\n')
    unknown = [r['name'] for r in rows if r['cresco'] == ['à classer']]
    print(len(rows), 'produits,', len(stations), 'postes ; à créer :', to_create, '; non classés :', unknown)


if __name__ == '__main__':
    main()
