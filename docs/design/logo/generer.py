"""Cresco logo (direction A): a thick braise "C" whose lower end climbs in three steps.

Writes the SVG sources to docs/design/logo/ and, with --png, the app icons:
- logo-icone.svg        app icon: braise C on an ink rounded square (512 x 512)
- logo-symbole.svg      the C alone, transparent background (Android adaptive foreground, splash)
- logo-horizontal.svg   icon + "cresco" wordmark, ink on white
- logo-horizontal-blanc.svg  same on ink (dark backgrounds)
- logo-monochrome.svg   the C in ink only (stamps, documents)

The wordmark is Barlow Condensed ExtraBold (the app's figures font, SIL OFL), turned into outlines
so it renders the same everywhere. Usage: python -I generer.py [--png]
"""
import math
import sys
from pathlib import Path

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

HERE = Path(__file__).parent
ROOT = HERE.parents[2]
FONT = ROOT / 'packages' / 'cresco_ui' / 'fonts' / 'BarlowCondensed-ExtraBold.ttf'

INK = '#111111'
BRAISE = '#FF5A1F'
WHITE = '#FFFFFF'

# Geometry on a 512 grid, centered at (256, 256).
C = 256
R_OUT = 150          # outer radius of the C
T = 64               # thickness of the band (and size of a step)
R_IN = R_OUT - T
R_MID = (R_OUT + R_IN) / 2
TOP = -42            # angle (degrees, SVG: clockwise from +x) of the rounded upper end
STEP = 44            # each step climbs STEP up and STEP right


def point(r, deg):
    a = math.radians(deg)
    return C + r * math.cos(a), C + r * math.sin(a)


def f(x):
    return f'{x:.2f}'.rstrip('0').rstrip('.')


def symbol_path():
    """One closed path: the arc from the rounded top end, round the left, to the bottom, then
    three square steps climbing to the right."""
    x0o, y0o = point(R_OUT, TOP)
    x0i, y0i = point(R_IN, TOP)
    bottom_o = (C, C + R_OUT)          # bottom of the ring, outer edge (x = 256)
    bottom_i = (C, C + R_IN)           # inner edge
    # Steps: three T x T blocks, each STEP higher and STEP further right than the previous one.
    s = [(C + k * STEP, C + R_IN - k * STEP) for k in range(3)]  # top-left corner of each block
    d = [
        f'M{f(x0o)} {f(y0o)}',
        # Outer arc, counterclockwise through the top and the left down to the bottom.
        f'A{R_OUT} {R_OUT} 0 1 0 {f(bottom_o[0])} {f(bottom_o[1])}',
        # Lower edge of the steps, climbing right.
        f'L{f(s[0][0] + T)} {f(bottom_o[1])}',
        f'L{f(s[0][0] + T)} {f(s[1][1] + T)}',
        f'L{f(s[1][0] + T)} {f(s[1][1] + T)}',
        f'L{f(s[1][0] + T)} {f(s[2][1] + T)}',
        f'L{f(s[2][0] + T)} {f(s[2][1] + T)}',
        # Top of the last step, then back down the upper edge of the stairs.
        f'L{f(s[2][0] + T)} {f(s[2][1])}',
        f'L{f(s[2][0])} {f(s[2][1])}',
        f'L{f(s[2][0])} {f(s[1][1])}',
        f'L{f(s[1][0])} {f(s[1][1])}',
        f'L{f(s[1][0])} {f(s[0][1])}',
        f'L{f(bottom_i[0])} {f(bottom_i[1])}',
        # Inner arc back up to the top end.
        f'A{R_IN} {R_IN} 0 1 1 {f(x0i)} {f(y0i)}',
        # Rounded end.
        f'A{T / 2} {T / 2} 0 0 0 {f(x0o)} {f(y0o)}',
        'Z',
    ]
    return ' '.join(d)


def wordmark(text, height):
    """Outlines of [text] in Barlow Condensed ExtraBold; returns (svg path, width) for a cap
    height of [height] px with the baseline at y = 0."""
    font = TTFont(FONT)
    glyphs = font.getGlyphSet()
    cmap = font.getBestCmap()
    upm = font['head'].unitsPerEm
    x_height = font['OS/2'].sxHeight or upm * 0.5
    scale = height / x_height
    pen = SVGPathPen(glyphs)
    x = 0.0
    hmtx = font['hmtx']
    for ch in text:
        name = cmap[ord(ch)]
        glyphs[name].draw(TransformPen(pen, (scale, 0, 0, -scale, x, 0)))
        x += hmtx[name][0] * scale
    return pen.getCommands(), x


def svg(width, height, body):
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {f(width)} {f(height)}" '
        f'width="{f(width)}" height="{f(height)}">\n{body}\n</svg>\n'
    )


def icon_body(background=INK, mark=BRAISE, radius=104):
    return (
        f'  <rect width="512" height="512" rx="{radius}" fill="{background}"/>\n'
        f'  <path d="{symbol_path()}" fill="{mark}"/>'
    )


def main(png=False):
    out = {}
    out['logo-icone.svg'] = svg(512, 512, icon_body())
    out['logo-symbole.svg'] = svg(512, 512, f'  <path d="{symbol_path()}" fill="{BRAISE}"/>')
    out['logo-monochrome.svg'] = svg(512, 512, f'  <path d="{symbol_path()}" fill="{INK}"/>')

    # Horizontal logo: 512 icon scaled to 160, then the lowercase word with its x-height at 72.
    word, word_w = wordmark('cresco', 76)
    icon = 160
    gap = 36
    height = 200
    width = icon + gap + word_w + 20
    for name, bg, ink in (('logo-horizontal.svg', WHITE, INK), ('logo-horizontal-blanc.svg', INK, WHITE)):
        out[name] = svg(
            width,
            height,
            f'  <rect width="{f(width)}" height="{height}" fill="{bg}"/>\n'
            f'  <g transform="translate(0 20) scale({icon / 512})">\n  {icon_body()}\n  </g>\n'
            f'  <path transform="translate({icon + gap} {height / 2 + 38})" d="{word}" fill="{ink}"/>',
        )
    for name, content in out.items():
        (HERE / name).write_text(content, encoding='utf-8', newline='\n')
        print(name)
    if png:
        export_png(out)


def export_png(out):
    import resvg_py

    def render(svg_text, size, path):
        data = bytes(resvg_py.svg_to_bytes(svg_string=svg_text))
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)

    def square(svg_text, size):
        # resvg draws at the viewBox scale: wrap the 512 drawing in an explicit scale instead.
        body = svg_text.split('>', 1)[1].rsplit('</svg>', 1)[0]
        return svg(size, size, f'<g transform="scale({size / 512})">{body}</g>')

    def resized(name, size):
        return square(out[name], size)

    app = ROOT / 'apps' / 'cresco_app'
    # Android legacy launcher icons (square with rounded corners) and round ones.
    for folder, size in (('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)):
        res = app / 'android' / 'app' / 'src' / 'main' / 'res'
        render(resized('logo-icone.svg', size), size, res / f'mipmap-{folder}' / 'ic_launcher.png')
        # Adaptive icon foreground: 108 dp canvas, the C kept inside the 66 dp safe zone.
        fg_size = size * 108 // 48
        fg = svg(512, 512, f'  <g transform="translate(256 256) scale(0.74) translate(-256 -256)">'
                           f'<path d="{symbol_path()}" fill="{BRAISE}"/></g>')
        render(square(fg, fg_size), fg_size,
               res / f'mipmap-{folder}' / 'ic_launcher_foreground.png')
        # Splash: the C alone, 96 dp.
        sp = size * 2
        render(resized('logo-symbole.svg', sp), sp, res / f'drawable-{folder}' / 'splash_logo.png')
    # iOS: one 1024 icon without transparency (Xcode generates the other sizes).
    ios = app / 'ios' / 'Runner' / 'Assets.xcassets' / 'AppIcon.appiconset'
    full = out['logo-icone.svg'].replace('rx="104"', 'rx="0"')
    render(square(full, 1024), 1024, ios / 'Icon-App-1024x1024@1x.png')
    # In-app logo (welcome screen) and previews.
    ui = ROOT / 'packages' / 'cresco_ui' / 'assets' / 'logo'
    render(resized('logo-icone.svg', 384), 384, ui / 'icone.png')
    for name in ('logo-icone.svg', 'logo-horizontal.svg', 'logo-horizontal-blanc.svg'):
        text = out[name]
        w = float(text.split('width="')[1].split('"')[0])
        h = float(text.split('height="')[1].split('"')[0])
        scale = 3
        big = text.replace(f'width="{f(w)}" height="{f(h)}"', f'width="{f(w * scale)}" height="{f(h * scale)}"', 1)
        data = bytes(resvg_py.svg_to_bytes(svg_string=big))
        (HERE / name.replace('.svg', '.png')).write_bytes(data)
    print('png ok')


if __name__ == '__main__':
    main(png='--png' in sys.argv)
