import 'package:cresco_ui/src/palette.dart';
import 'package:flutter/material.dart';

/// Which side of the body is drawn.
enum BodySide { front, back }

/// A tappable muscle area. [muscle] is the exercise catalog slug (`pectoraux`, `dos`…):
/// several areas can share one muscle (left and right, traps and lats).
class BodyArea {
  const new(this.muscle, this.path);
  final String muscle;

  /// SVG path data in the 200 × 392 view box, absolute M, L, C and Z commands only.
  final String path;
}

/// Parses absolute `M`, `L`, `C` and `Z` path commands (the subset the body map uses).
Path parseBodyPath(String data) {
  final tokens = RegExp(r'[MLCZ]|-?\d*\.?\d+').allMatches(data).map((m) => m.group(0)!).toList();
  final path = Path();
  var i = 0;
  var command = 'M';
  double next() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    if (RegExp('[MLCZ]').hasMatch(tokens[i])) command = tokens[i++];
    switch (command) {
      case 'M':
        path.moveTo(next(), next());
        command = 'L';
      case 'L':
        path.lineTo(next(), next());
      case 'C':
        path.cubicTo(next(), next(), next(), next(), next(), next());
      case 'Z':
        path.close();
      default:
        throw FormatException('Unsupported path command $command');
    }
  }
  return path;
}

/// Rounded rectangle as path data, so every area goes through [parseBodyPath].
String roundedRectPath(double x, double y, double w, double h, double r) {
  const k = 0.5523; // Cubic approximation of a quarter circle.
  final c = r * k;
  return 'M${x + r} $y L${x + w - r} $y C${x + w - r + c} $y ${x + w} ${y + r - c} ${x + w} ${y + r} '
      'L${x + w} ${y + h - r} C${x + w} ${y + h - r + c} ${x + w - r + c} ${y + h} ${x + w - r} ${y + h} '
      'L${x + r} ${y + h} C${x + r - c} ${y + h} $x ${y + h - r + c} $x ${y + h - r} '
      'L$x ${y + r} C$x ${y + r - c} ${x + r - c} $y ${x + r} $y Z';
}

abstract final class BodyShapes {
  static const viewBox = Size(200, 392);

  static const outline =
      'M93 44 L93 56 C80 58 66 60 58 66 C48 72 46 82 45 92 L41 128 C39 146 37 162 34 192 C33 200 36 206 41 204 '
      'C44 202 45 196 46 188 L52 150 C54 136 57 124 60 114 L62 112 C64 130 67 150 69 168 C66 186 65 204 67 222 '
      'L71 280 C72 300 75 316 76 332 L77 372 C76 380 80 384 88 383 C93 382 94 378 93 370 L94 334 C96 314 96 296 96 280 '
      'L98 226 L100 220 L102 226 L104 280 C104 296 104 314 106 334 L107 370 C106 378 107 382 112 383 '
      'C120 384 124 380 123 372 L124 332 C125 316 128 300 129 280 L133 222 C135 204 134 186 131 168 '
      'C133 150 136 130 138 112 L140 114 C143 124 146 136 148 150 L154 188 C155 196 156 202 159 204 '
      'C164 206 167 200 166 192 C163 162 161 146 159 128 L155 92 C154 82 152 72 142 66 C134 60 120 58 107 56 L107 44 Z';

  static const _shoulders = [
    BodyArea('epaules', 'M60 66 C50 70 46 82 47 96 C52 92 58 86 66 80 C68 74 66 68 60 66 Z'),
    BodyArea('epaules', 'M140 66 C150 70 154 82 153 96 C148 92 142 86 134 80 C132 74 134 68 140 66 Z'),
  ];
  static const _upperArmLeft = 'M48 100 C44 110 43 122 46 132 C50 130 54 122 58 112 C57 104 53 99 48 100 Z';
  static const _upperArmRight = 'M152 100 C156 110 157 122 154 132 C150 130 146 122 142 112 C143 104 147 99 152 100 Z';
  static const _forearms = [
    BodyArea('avant_bras', 'M44 138 C40 154 38 170 37 186 L44 186 C46 172 50 156 53 140 C50 136 46 135 44 138 Z'),
    BodyArea('avant_bras', 'M156 138 C160 154 162 170 163 186 L156 186 C154 172 150 156 147 140 C150 136 154 135 156 138 Z'),
  ];

  static final List<BodyArea> front = [
    const BodyArea('dos', 'M82 60 L93 53 L93 62 Z'),
    const BodyArea('dos', 'M118 60 L107 53 L107 62 Z'),
    ..._shoulders,
    const BodyArea('pectoraux', 'M98 66 L72 68 C66 74 64 86 68 96 C78 104 92 104 98 98 Z'),
    const BodyArea('pectoraux', 'M102 66 L128 68 C134 74 136 86 132 96 C122 104 108 104 102 98 Z'),
    const BodyArea('biceps', _upperArmLeft),
    const BodyArea('biceps', _upperArmRight),
    ..._forearms,
    BodyArea('abdominaux', roundedRectPath(88, 104, 24, 66, 8)),
    const BodyArea('abdominaux', 'M85 106 L72 108 C70 124 70 146 74 166 L85 172 Z'),
    const BodyArea('abdominaux', 'M115 106 L128 108 C130 124 130 146 126 166 L115 172 Z'),
    const BodyArea('quadriceps', 'M97 222 C86 214 74 214 70 226 C70 250 74 270 80 284 L94 284 C97 264 98 244 97 222 Z'),
    const BodyArea('quadriceps', 'M103 222 C114 214 126 214 130 226 C130 250 126 270 120 284 L106 284 C103 264 102 244 103 222 Z'),
    const BodyArea('mollets', 'M78 300 C76 316 77 340 80 356 L90 356 C93 340 94 316 92 300 C88 296 82 296 78 300 Z'),
    const BodyArea('mollets', 'M122 300 C124 316 123 340 120 356 L110 356 C107 340 106 316 108 300 C112 296 118 296 122 300 Z'),
  ];

  static final List<BodyArea> back = [
    const BodyArea('dos', 'M100 48 L76 64 L100 112 L124 64 Z'),
    ..._shoulders,
    const BodyArea('dos', 'M74 82 C66 100 66 124 78 150 L96 128 L94 100 Z'),
    const BodyArea('dos', 'M126 82 C134 100 134 124 122 150 L104 128 L106 100 Z'),
    const BodyArea('triceps', _upperArmLeft),
    const BodyArea('triceps', _upperArmRight),
    ..._forearms,
    BodyArea('lombaires', roundedRectPath(89, 130, 22, 42, 7)),
    const BodyArea('fessiers', 'M99 178 C86 176 70 184 68 204 C70 220 84 226 99 220 Z'),
    const BodyArea('fessiers', 'M101 178 C114 176 130 184 132 204 C130 220 116 226 101 220 Z'),
    const BodyArea('ischios', 'M97 228 C86 226 74 228 72 238 C72 258 76 272 80 284 L94 284 C97 266 98 248 97 228 Z'),
    const BodyArea('ischios', 'M103 228 C114 226 126 228 128 238 C128 258 124 272 120 284 L106 284 C103 266 102 248 103 228 Z'),
    const BodyArea('mollets', 'M77 296 C72 312 74 332 80 346 C86 348 90 346 92 340 C94 322 94 306 91 296 C86 292 80 292 77 296 Z'),
    const BodyArea('mollets', 'M123 296 C128 312 126 332 120 346 C114 348 110 346 108 340 C106 322 106 306 109 296 C114 292 120 292 123 296 Z'),
  ];

  static List<BodyArea> of(BodySide side) => side == BodySide.front ? front : back;

  /// Muscles drawn on each side, in display order.
  static List<String> musclesOf(BodySide side) => {for (final a in of(side)) a.muscle}.toList();
}

/// Front or back silhouette whose muscles are colored by [colors] and selected by touch.
class BodyMap extends StatelessWidget {
  const new({
    required this.side,
    required this.colors,
    required this.onSelect,
    super.key,
    this.selected,
    this.semanticLabel,
  });

  final BodySide side;

  /// Fill per muscle slug; muscles without a color use the body tone.
  final Map<String, Color> colors;
  final String? selected;
  final ValueChanged<String> onSelect;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AspectRatio(
      aspectRatio: BodyShapes.viewBox.width / BodyShapes.viewBox.height,
      child: LayoutBuilder(
        builder: (context, box) {
          final scale = box.maxWidth / BodyShapes.viewBox.width;
          return Semantics(
            label: semanticLabel,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) {
                final hit = _hit(d.localPosition / scale);
                if (hit != null) onSelect(hit);
              },
              child: CustomPaint(
                size: Size(box.maxWidth, box.maxWidth / BodyShapes.viewBox.width * BodyShapes.viewBox.height),
                painter: _BodyPainter(side: side, colors: colors, selected: selected, palette: p),
              ),
            ),
          );
        },
      ),
    );
  }

  String? _hit(Offset point) {
    for (final area in BodyShapes.of(side).reversed) {
      if (_paths[area.path]!.contains(point)) return area.muscle;
    }
    return null;
  }
}

final Map<String, Path> _paths = {
  for (final a in [...BodyShapes.front, ...BodyShapes.back]) a.path: parseBodyPath(a.path),
  BodyShapes.outline: parseBodyPath(BodyShapes.outline),
};

class _BodyPainter extends CustomPainter {
  new({required this.side, required this.colors, required this.selected, required this.palette});
  final BodySide side;
  final Map<String, Color> colors;
  final String? selected;
  final CrescoPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / BodyShapes.viewBox.width;
    canvas.scale(scale);
    final dark = palette.background.computeLuminance() < 0.2;
    final skin = dark ? const Color(0xFF2A2D27) : const Color(0xFFE9EBE4);
    canvas
      ..drawCircle(const Offset(100, 28), 16, Paint()..color = dark ? const Color(0xFF353932) : const Color(0xFFDCDFD6))
      ..drawPath(_paths[BodyShapes.outline]!, Paint()..color = skin);
    final rest = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = palette.ink.withValues(alpha: 0.12);
    final focus = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeJoin = StrokeJoin.round
      ..color = palette.ink;
    final areas = BodyShapes.of(side);
    // Selected areas last, so their outline is never covered by a neighbour.
    for (final a in [...areas.where((a) => a.muscle != selected), ...areas.where((a) => a.muscle == selected)]) {
      final path = _paths[a.path]!;
      canvas
        ..drawPath(path, Paint()..color = colors[a.muscle] ?? skin)
        ..drawPath(path, a.muscle == selected ? focus : rest);
    }
    if (side == BodySide.front) {
      final lines = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black.withValues(alpha: 0.16);
      canvas
        ..drawLine(const Offset(88, 126), const Offset(112, 126), lines)
        ..drawLine(const Offset(88, 148), const Offset(112, 148), lines)
        ..drawLine(const Offset(100, 106), const Offset(100, 168), lines);
    }
  }

  @override
  bool shouldRepaint(_BodyPainter old) =>
      old.side != side || old.selected != selected || old.colors != colors || old.palette != palette;
}
