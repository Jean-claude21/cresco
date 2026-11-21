import 'dart:async';
import 'dart:ui' as ui;

import 'package:cresco_ui/src/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Which side of the body is drawn.
enum BodySide { front, back }

/// Muscles of the body map, by exercise catalog slug.
///
/// The order is the one of docs/design/medias/corps/extraire.py: the label maps store
/// `index + 1` for each muscle (0 = no muscle).
abstract final class BodyMuscles {
  static const all = [
    'pectoraux',
    'epaules',
    'biceps',
    'avant_bras',
    'abdominaux',
    'quadriceps',
    'mollets',
    'dos',
    'triceps',
    'lombaires',
    'fessiers',
    'ischios',
  ];

  static const front = ['dos', 'epaules', 'pectoraux', 'biceps', 'avant_bras', 'abdominaux', 'quadriceps', 'mollets'];
  static const back = ['dos', 'epaules', 'triceps', 'avant_bras', 'lombaires', 'fessiers', 'ischios', 'mollets'];

  static List<String> of(BodySide side) => side == BodySide.front ? front : back;

  /// Width / height of the body images (1024 × 2048).
  static const aspectRatio = 0.5;
}

String _file(BodySide side) => side == BodySide.front ? 'face' : 'dos';

/// Quarter-resolution map of which muscle is where, decoded once per side from
/// `assets/body/<side>-labels.png` (pixel value = muscle index + 1).
class BodyLabels {
  new(this.width, this.height, this._rgba);

  final int width;
  final int height;
  final Uint8List _rgba;

  static final _cache = <BodySide, Future<BodyLabels>>{};

  static Future<BodyLabels> load(BodySide side, {AssetBundle? bundle}) =>
      _cache[side] ??= _decode((bundle ?? rootBundle).load('packages/cresco_ui/assets/body/${_file(side)}-labels.png'));

  static Future<BodyLabels> _decode(Future<ByteData> data) async {
    final codec = await ui.instantiateImageCodec((await data).buffer.asUint8List());
    final image = (await codec.getNextFrame()).image;
    final bytes = (await image.toByteData())!.buffer.asUint8List();
    return BodyLabels(image.width, image.height, bytes);
  }

  /// Muscle at [fraction] of the image (0–1 on both axes), or null outside any muscle.
  String? muscleAt(Offset fraction) {
    final x = (fraction.dx * width).floor();
    final y = (fraction.dy * height).floor();
    if (x < 0 || y < 0 || x >= width || y >= height) return null;
    final value = _rgba[(y * width + x) * 4];
    return value == 0 || value > BodyMuscles.all.length ? null : BodyMuscles.all[value - 1];
  }
}

/// Full anatomical body (front or back) whose muscles are tinted by [colors] and picked by touch.
/// Drawn from the masks generated with ChatGPT (docs/design/medias/corps).
class BodyMap extends StatefulWidget {
  const new({
    required this.side,
    required this.colors,
    required this.onSelect,
    super.key,
    this.selected,
    this.semanticLabel,
  });

  final BodySide side;

  /// Fill per muscle slug; muscles without a color are drawn in the neutral body tone.
  final Map<String, Color> colors;
  final String? selected;
  final ValueChanged<String> onSelect;
  final String? semanticLabel;

  @override
  State<BodyMap> createState() => _BodyMapState();
}

class _BodyMapState extends State<BodyMap> {
  BodyLabels? _labels;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(BodyMap old) {
    super.didUpdateWidget(old);
    if (old.side != widget.side) unawaited(_load());
  }

  Future<void> _load() async {
    final side = widget.side;
    final labels = await BodyLabels.load(side, bundle: DefaultAssetBundle.of(context));
    if (mounted && side == widget.side) setState(() => _labels = labels);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final neutral = p.background.computeLuminance() < 0.2 ? const Color(0xFF3A3A3A) : const Color(0xFFD5D5D5);
    final file = _file(widget.side);
    Widget mask(String muscle, Color color) => Image.asset(
      'assets/body/$file-$muscle.png',
      package: 'cresco_ui',
      color: color,
      colorBlendMode: BlendMode.srcIn,
      fit: BoxFit.contain,
      gaplessPlayback: true,
    );
    final selected = widget.selected;
    return AspectRatio(
      aspectRatio: BodyMuscles.aspectRatio,
      child: LayoutBuilder(
        builder: (context, box) => Semantics(
          label: widget.semanticLabel,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) {
              final hit = _labels?.muscleAt(Offset(d.localPosition.dx / box.maxWidth, d.localPosition.dy / box.maxHeight));
              if (hit != null) widget.onSelect(hit);
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Outline of the selected muscle: its mask, dilated and drawn in ink underneath.
                if (selected != null && BodyMuscles.of(widget.side).contains(selected))
                  ImageFiltered(imageFilter: ui.ImageFilter.dilate(radiusX: 4, radiusY: 4), child: mask(selected, p.ink)),
                for (final m in BodyMuscles.of(widget.side)) mask(m, widget.colors[m] ?? neutral),
                Image.asset(
                  'assets/body/$file-base.png',
                  package: 'cresco_ui',
                  fit: BoxFit.contain,
                  color: p.background.computeLuminance() < 0.2 ? const Color(0xFF8A8A8A) : null,
                  colorBlendMode: BlendMode.modulate,
                  gaplessPlayback: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
