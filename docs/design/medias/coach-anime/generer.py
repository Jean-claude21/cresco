"""Animated coach (Karim) doing machine exercises, as Lottie files (trial, 22/11/2026).

A flat vector rig seen from the side, in Karim's colours (docs/design/medias/coach-homme): head,
torso, upper arms, forearms, thighs, shins and feet are separate layers. For each frame the script
places the hands and feet where the exercise wants them, solves the elbows and knees by two-bone
inverse kinematics, and keyframes every layer's position and rotation (linear, one key every two
frames), so the body and the machine's moving parts always match. One loop: hold, concentric,
hold, eccentric, 2.4 s at 30 fps.

Writes json/<exercise id>.json (the app kept the ChatGPT poses instead, 22/11/2026). Usage: python -I generer.py
"""
import json
import math
from pathlib import Path

OUT = Path(__file__).parent / 'json'  # trial only, not shipped in the app
FPS, FRAMES, W, H = 30, 72, 512, 512

# Karim's palette and the machines' (design G).
SKIN, SKIN_FAR = '#C8763F', '#A55E31'
SHIRT, SHIRT_FAR = '#2F2A29', '#221E1D'
SHORTS, SHORTS_FAR = '#1E1A19', '#161312'
BRAISE, HAIR, SHOE = '#FF5A1F', '#2A1C16', '#F4EFEA'
FRAME, PAD, PLATE, CABLE = '#3B3B3B', '#141414', '#8C8C8C', '#6E6E6E'

TORSO, UPPER_ARM, FOREARM, THIGH, SHIN, FOOT = 125, 68, 62, 92, 90, 30


def rgb(hexa):
    h = hexa.lstrip('#')
    return [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)] + [1]


def direction(r):
    """Unit vector of a segment drawn down (0, 1) then rotated r degrees clockwise (Lottie)."""
    a = math.radians(r)
    return -math.sin(a), math.cos(a)


def angle_of(dx, dy):
    return math.degrees(math.atan2(-dx, dy))


def add(p, r, length):
    d = direction(r)
    return p[0] + d[0] * length, p[1] + d[1] * length


def two_bone(root, target, a, b, bend):
    """Angles (r1, r2) of a two-bone chain from root to target; bend = +1 or -1 picks the side."""
    dx, dy = target[0] - root[0], target[1] - root[1]
    d = max(abs(a - b) + 1, min(math.hypot(dx, dy), a + b - 0.5))
    base = math.atan2(dy, dx)
    alpha = math.acos((a * a + d * d - b * b) / (2 * a * d))
    j = (root[0] + a * math.cos(base + bend * alpha), root[1] + a * math.sin(base + bend * alpha))
    end = (root[0] + dx / math.hypot(dx, dy) * d, root[1] + dy / math.hypot(dx, dy) * d) if (dx or dy) else target
    return angle_of(j[0] - root[0], j[1] - root[1]), angle_of(end[0] - j[0], end[1] - j[1])


def lerp(a, b, t):
    return a + (b - a) * t


def lerp2(a, b, t):
    return lerp(a[0], b[0], t), lerp(a[1], b[1], t)


def progress(frame):
    """0 → 1 → 0 over the loop with holds at both ends, eased."""
    ease = lambda x: 0.5 - 0.5 * math.cos(math.pi * max(0.0, min(1.0, x)))
    if frame < 6:
        return 0.0
    if frame < 36:
        return ease((frame - 6) / 30)
    if frame < 42:
        return 1.0
    return ease(1 - (frame - 42) / 30)


# ------------------------------------------------------------------ exercises
# Each returns the pose at progress p: pelvis, torso tilt (deg, + leans forward), hand and ankle
# targets, elbow / knee bend sides, and the machine's moving points.

def chest_press(p):
    pelvis = (215, 335)
    hand = lerp2((268, 222), (338, 222), p)
    return dict(pelvis=pelvis, tilt=-6, hand=hand, elbow=1, ankle=(300, 432), knee=-1, foot=-80,
                moving=dict(handle=hand, stack=p))


def lat_pulldown(p):
    pelvis = (225, 352)
    hand = lerp2((236, 108), (246, 214), p)
    return dict(pelvis=pelvis, tilt=-10, hand=hand, elbow=1, ankle=(308, 442), knee=-1, foot=-80,
                moving=dict(bar=hand, stack=p))


def leg_press(p):
    pelvis = (175, 385)
    ankle = lerp2((248, 322), (306, 262), p)
    return dict(pelvis=pelvis, tilt=-58, hand=(150, 392), elbow=1, ankle=ankle, knee=-1, foot=-135,
                moving=dict(sled=ankle))


def leg_curl(p):
    pelvis = (205, 330)
    knee = (300, 336)
    shin = lerp(-62, 32, p)
    ankle = add(knee, shin, SHIN)
    return dict(pelvis=pelvis, tilt=-14, hand=(238, 332), elbow=1, ankle=ankle, knee=1, foot=shin - 85,
                fixed_knee=knee, moving=dict(roller=ankle))


RAIL = (-0.488, -0.873)  # hack squat rails, pointing up and back


def hack_squat(p):
    top = (250, 282)
    pelvis = (top[0] - RAIL[0] * 80 * p, top[1] - RAIL[1] * 80 * p)
    return dict(pelvis=pelvis, tilt=-29, hand='shoulder', elbow=1, ankle=(332, 432), knee=-1, foot=-100,
                moving=dict(carriage=pelvis))


EXERCISES = {
    'developpe-convergent': chest_press,
    'tirage-vertical': lat_pulldown,
    'presse-cuisses': leg_press,
    'leg-curl-assis': leg_curl,
    'hack-squat': hack_squat,
}


def skeleton(pose):
    """World positions and angles of every segment."""
    torso_r = 180 + pose['tilt']
    pelvis = pose['pelvis']
    shoulder = add(pelvis, torso_r, TORSO)
    hand = (shoulder[0] + 26, shoulder[1] + 4) if pose['hand'] == 'shoulder' else pose['hand']
    upper, fore = two_bone(shoulder, hand, UPPER_ARM, FOREARM, pose['elbow'])
    if 'fixed_knee' in pose:
        knee = pose['fixed_knee']
        thigh = angle_of(knee[0] - pelvis[0], knee[1] - pelvis[1])
        shin = angle_of(pose['ankle'][0] - knee[0], pose['ankle'][1] - knee[1])
    else:
        thigh, shin = two_bone(pelvis, pose['ankle'], THIGH, SHIN, pose['knee'])
    elbow = add(shoulder, upper, UPPER_ARM)
    knee = add(pelvis, thigh, THIGH)
    ankle = add(knee, shin, SHIN)
    return dict(pelvis=pelvis, torso=torso_r, shoulder=shoulder, upper=upper, elbow=elbow, fore=fore,
                thigh=thigh, knee=knee, shin=shin, ankle=ankle, foot=pose['foot'])


# ------------------------------------------------------------------ Lottie helpers

def static(v):
    return {'a': 0, 'k': v}


def animated(values):
    keys = []
    for i, (t, v) in enumerate(values):
        k = {'t': t, 's': v if isinstance(v, list) else [v]}
        if i < len(values) - 1:
            k.update({'i': {'x': [1], 'y': [1]}, 'o': {'x': [0], 'y': [0]}})
        keys.append(k)
    return {'a': 1, 'k': keys}


def stroke(color, width):
    return {'ty': 'st', 'c': static(rgb(color)), 'o': static(100), 'w': static(width), 'lc': 2, 'lj': 2}


def fill(color):
    return {'ty': 'fl', 'c': static(rgb(color)), 'o': static(100), 'r': 1}


def path(points, closed=False):
    return {'c': closed, 'v': [list(p) for p in points], 'i': [[0, 0]] * len(points), 'o': [[0, 0]] * len(points)}


def line(a, b, color, width):
    return group([{'ty': 'sh', 'ks': static(path([a, b]))}, stroke(color, width)])


def rect(x, y, w, h, color, radius=4):
    return group([{'ty': 'rc', 'p': static([x + w / 2, y + h / 2]), 's': static([w, h]), 'r': static(radius)}, fill(color)])


def circle(x, y, r, color):
    return group([{'ty': 'el', 'p': static([x, y]), 's': static([2 * r, 2 * r])}, fill(color)])


def group(items):
    return {'ty': 'gr', 'it': items + [{'ty': 'tr', 'p': static([0, 0]), 'a': static([0, 0]), 's': static([100, 100]), 'r': static(0), 'o': static(100)}]}


def layer(name, shapes, position=None, rotation=None):
    return {
        'ddd': 0, 'ty': 4, 'nm': name, 'sr': 1, 'ip': 0, 'op': FRAMES, 'st': 0, 'bm': 0,
        'ks': {
            'o': static(100),
            'r': rotation if rotation is not None else static(0),
            'p': position if position is not None else static([0, 0, 0]),
            'a': static([0, 0, 0]),
            's': static([100, 100, 100]),
        },
        'shapes': shapes,
    }


def segment(length, width, color, extra=()):
    return [line((0, 0), (0, length), color, width), *extra]


# ------------------------------------------------------------------ body parts (local, drawn down)

def upper_arm(far):
    skin = SKIN_FAR if far else SKIN
    shirt = SHIRT_FAR if far else SHIRT
    return [line((0, 0), (0, 26), shirt, 27), *segment(UPPER_ARM, 21, skin)][::-1]


def forearm(far):
    skin = SKIN_FAR if far else SKIN
    items = segment(FOREARM, 17, skin) + [line((0, FOREARM - 12), (0, FOREARM - 5), BRAISE, 20)]
    items.append(circle(0, FOREARM + 4, 10, skin))
    return items[::-1]


def thigh(far):
    shorts = SHORTS_FAR if far else SHORTS
    skin = SKIN_FAR if far else SKIN
    return [line((0, 0), (0, 52), shorts, 38), line((5, 4), (5, 50), BRAISE, 4), *segment(THIGH, 29, skin)][::-1]


def shin(far):
    return segment(SHIN, 23, SKIN_FAR if far else SKIN)[::-1]


def foot(far):
    return [line((0, -4), (0, FOOT), SHOE if not far else '#D8D2CC', 17), line((-4, 6), (-4, FOOT - 4), BRAISE, 4)][::-1]


def torso_shapes():
    return [line((0, 0), (0, TORSO), SHIRT, 52), line((0, 0), (0, 10), SHORTS, 54)][::-1]


def head_shapes():
    # Local up is -y: neck at (0, 0).
    return [
        circle(-7, -44, 28, HAIR),
        circle(3, -36, 25, SKIN),
        line((-2, 0), (0, -14), SKIN, 18),
        group([{'ty': 'sh', 'ks': static(path([(10, -22), (24, -27), (27, -38)]))}, stroke(HAIR, 7)]),
        circle(19, -42, 2.5, HAIR),
    ][::-1]


# ------------------------------------------------------------------ machines

def stack(x, top, p):
    """Weight stack: column, then plates of which the top ones rise with p."""
    shapes = [rect(x - 22, top, 44, 250, FRAME, 6)]
    for i in range(8):
        y = top + 150 + i * 12
        shapes.append(rect(x - 18, y, 36, 10, PLATE, 2))
    return shapes


def machine_static(name):
    s = []
    if name == 'developpe-convergent':
        s += stack(110, 150, 0) + [rect(160, 335, 120, 18, PAD), rect(150, 200, 24, 150, PAD), line((175, 352), (175, 440), FRAME, 12),
                                  line((110, 150), (300, 104), FRAME, 12), line((300, 104), (300, 150), FRAME, 10), rect(80, 440, 300, 14, FRAME)]
    elif name == 'tirage-vertical':
        s += stack(110, 120, 0) + [rect(170, 352, 120, 18, PAD), line((230, 370), (230, 450), FRAME, 12), rect(80, 450, 300, 14, FRAME),
                                  line((110, 120), (250, 52), FRAME, 12), circle(250, 58, 9, FRAME), rect(276, 316, 46, 20, PAD, 10),
                                  line((300, 336), (300, 450), FRAME, 10)]
    elif name == 'presse-cuisses':
        s += [line((60, 470), (420, 470), FRAME, 14), line((150, 470), (165, 400), FRAME, 14), rect(110, 392, 110, 20, PAD), line((175, 400), (60, 300), PAD, 22),
              line((110, 400), (40, 300), PAD, 26), line((200, 470), (420, 210), FRAME, 12), line((240, 470), (430, 250), FRAME, 10)]
    elif name == 'leg-curl-assis':
        s += stack(90, 170, 0) + [rect(150, 340, 140, 18, PAD), line((152, 340), (120, 210), PAD, 26), rect(250, 304, 70, 18, PAD, 9),
                                  line((210, 358), (210, 450), FRAME, 12), rect(60, 450, 320, 14, FRAME), line((300, 336), (300, 300), FRAME, 8)]
    elif name == 'hack-squat':
        s += [line((60, 470), (420, 470), FRAME, 14), line((300, 446), (380, 424), FRAME, 12), line((350, 432), (370, 470), FRAME, 10),
              line((300, 470), (110, 130), FRAME, 12), line((280, 470), (90, 130), FRAME, 8)]
    return s


def moving_layers(name, frames):
    """Layers for the parts that move with the body: handles, bar and cable, sled, roller, carriage, plates."""
    out = []
    if name in ('developpe-convergent', 'tirage-vertical', 'leg-curl-assis'):
        x, top = {'developpe-convergent': (110, 150), 'tirage-vertical': (110, 120), 'leg-curl-assis': (90, 170)}[name]
        rise = [(f, [0, -36 * m.get('stack', abs(progress(f))), 0]) for f, m in frames]
        out.append(layer('plaques', [rect(x - 18, top + 150 - 2, 36, 12 * 3 + 2, '#B5B5B5', 2)], position=animated(rise)))
    if name == 'developpe-convergent':
        out.append(layer('levier', [group([{'ty': 'sh', 'ks': animated([(f, [path([(300, 120), m['handle']])]) for f, m in frames])}, stroke(FRAME, 11)])]))
        out.append(layer('poignee', [line((0, -14), (0, 14), PAD, 12)], position=animated([(f, [*m['handle'], 0]) for f, m in frames])))
    if name == 'tirage-vertical':
        out.append(layer('cable', [group([{'ty': 'sh', 'ks': animated([(f, [path([(250, 58), (m['bar'][0], m['bar'][1] - 6)])]) for f, m in frames])}, stroke(CABLE, 3)])]))
        out.append(layer('barre', [line((-34, 0), (30, -6), FRAME, 9)], position=animated([(f, [m['bar'][0], m['bar'][1] - 4, 0]) for f, m in frames])))
    if name == 'presse-cuisses':
        out.append(layer('plateau', [line((-30, -30), (30, 30), FRAME, 14), line((10, -12), (40, -40), FRAME, 8)],
                         position=animated([(f, [m['sled'][0] + 10, m['sled'][1] - 8, 0]) for f, m in frames])))
    if name == 'leg-curl-assis':
        out.append(layer('boudin', [circle(0, 0, 13, PAD)], position=animated([(f, [m['roller'][0] - 4, m['roller'][1] + 12, 0]) for f, m in frames])))
    if name == 'hack-squat':
        out.append(layer('chariot', [line((-30, 17), (-98, -105), PAD, 22), line((-90, -112), (-50, -128), PAD, 16)],
                         position=animated([(f, [*m['carriage'], 0]) for f, m in frames])))
    return out


# ------------------------------------------------------------------ build

def build(name, fn):
    frames = []
    bones = []
    for f in list(range(0, FRAMES, 2)) + [FRAMES]:
        pose = fn(progress(f))
        frames.append((f, pose['moving']))
        bones.append((f, skeleton(pose)))

    def pos(key):
        return animated([(f, [*b[key], 0]) for f, b in bones])

    def rot(key, offset=0.0):
        return animated([(f, b[key] + offset) for f, b in bones])

    layers = []
    # Front to back: Lottie draws the first layer on top.
    layers += moving_layers(name, frames)[::-1][:0]  # placeholder kept empty: handles drawn after the near arm below
    near_arm = [
        layer('main', forearm(False), position=pos('elbow'), rotation=rot('fore')),
        layer('bras', upper_arm(False), position=pos('shoulder'), rotation=rot('upper')),
    ]
    near_leg = [
        layer('pied', foot(False), position=pos('ankle'), rotation=rot('foot')),
        layer('jambe', shin(False), position=pos('knee'), rotation=rot('shin')),
        layer('cuisse', thigh(False), position=pos('pelvis'), rotation=rot('thigh')),
    ]
    body = [
        layer('tete', head_shapes(), position=pos('shoulder'), rotation=animated([(f, b['torso'] - 180) for f, b in bones])),
        layer('buste', torso_shapes(), position=pos('pelvis'), rotation=rot('torso')),
    ]
    far = [
        layer('main loin', forearm(True), position=animated([(f, [b['elbow'][0] - 8, b['elbow'][1] - 3, 0]) for f, b in bones]), rotation=rot('fore')),
        layer('bras loin', upper_arm(True), position=animated([(f, [b['shoulder'][0] - 8, b['shoulder'][1] - 3, 0]) for f, b in bones]), rotation=rot('upper')),
        layer('pied loin', foot(True), position=animated([(f, [b['ankle'][0] - 9, b['ankle'][1] - 4, 0]) for f, b in bones]), rotation=rot('foot')),
        layer('jambe loin', shin(True), position=animated([(f, [b['knee'][0] - 9, b['knee'][1] - 4, 0]) for f, b in bones]), rotation=rot('shin')),
        layer('cuisse loin', thigh(True), position=animated([(f, [b['pelvis'][0] - 9, b['pelvis'][1] - 4, 0]) for f, b in bones]), rotation=rot('thigh')),
    ]
    moving = moving_layers(name, frames)
    handles = [l for l in moving if l['nm'] in ('poignee', 'barre', 'boudin')]
    behind = [l for l in moving if l not in handles]
    layers = handles + near_arm + near_leg + body + far + behind + [layer('machine', machine_static(name))]
    for i, l in enumerate(layers):
        l['ind'] = i + 1
    doc = {'v': '5.7.4', 'fr': FPS, 'ip': 0, 'op': FRAMES, 'w': W, 'h': H, 'nm': f'Karim · {name}', 'ddd': 0, 'assets': [], 'layers': layers}
    OUT.mkdir(parents=True, exist_ok=True)
    path_out = OUT / f'{name}.json'
    path_out.write_text(json.dumps(doc, separators=(',', ':')), encoding='utf-8')
    return path_out


if __name__ == '__main__':
    for name, fn in EXERCISES.items():
        p = build(name, fn)
        print(name, p.stat().st_size // 1024, 'Ko')
