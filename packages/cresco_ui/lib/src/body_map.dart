import 'dart:async';
import 'dart:ui' as ui;

import 'package:cresco_ui/src/palette.dart';
import 'package:flutter/foundation.dart';
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

/// Decoded images of one side: the realistic render and one alpha mask per visible muscle.
class _BodyImages {
  new(this.render, this.masks);
  final ui.Image render;
  final Map<String, ui.Image> masks;

  /// Sides already decoded, usable at once.
  static final ready = <BodySide, _BodyImages>{};

  /// Bumped each time a side is decoded: maps waiting for it rebuild.
  static final decoded = ValueNotifier<int>(0);

  static final _pending = <BodySide, Future<void>>{};

  static Future<void> load(BodySide side, AssetBundle bundle) =>
      ready.containsKey(side) ? Future.value() : _pending[side] ??= _decode(side, bundle);

  static Future<void> _decode(BodySide side, AssetBundle bundle) async {
    Future<ui.Image> decode(String name) async {
      final data = await bundle.load('packages/cresco_ui/assets/body/${_file(side)}-$name.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      return (await codec.getNextFrame()).image;
    }

    final render = await decode('render');
    final masks = {for (final m in BodyMuscles.of(side)) m: await decode(m)};
    ready[side] = _BodyImages(render, masks);
    decoded.value++;
  }
}

/// Full anatomical body (front or back), realistic and in grays, whose muscles are tinted by
/// [colors] and picked by touch. Render and masks generated with ChatGPT
/// (docs/design/medias/corps-realiste and docs/design/medias/corps).
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

  /// Tint per muscle slug, multiplied onto the render; a muscle without a color keeps the
  /// render's grays.
  final Map<String, Color> colors;
  final String? selected;
  final ValueChanged<String> onSelect;
  final String? semanticLabel;

  /// Decodes both sides ahead of display (tests decode inside `runAsync`).
  static Future<void> precache({AssetBundle? bundle}) async {
    for (final side in BodySide.values) {
      if (!_BodyImages.ready.containsKey(side)) await _BodyImages._decode(side, bundle ?? rootBundle);
      await BodyLabels.load(side, bundle: bundle);
    }
  }

  @override
  State<BodyMap> createState() => _BodyMapState();
}

class _BodyMapState extends State<BodyMap> {
  BodyLabels? _labels;

  @override
  void initState() {
    super.initState();
    _BodyImages.decoded.addListener(_redraw);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(BodyMap old) {
    super.didUpdateWidget(old);
    if (old.side != widget.side) {
      _labels = null;
      _load();
    }
  }

  @override
  void dispose() {
    _BodyImages.decoded.removeListener(_redraw);
    super.dispose();
  }

  void _redraw() {
    if (mounted) setState(() {});
  }

  void _load() {
    final side = widget.side;
    final bundle = DefaultAssetBundle.of(context);
    unawaited(_BodyImages.load(side, bundle));
    unawaited(
      BodyLabels.load(side, bundle: bundle).then((labels) {
        if (mounted && side == widget.side) setState(() => _labels = labels);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final images = _BodyImages.ready[widget.side];
    return AspectRatio(
      aspectRatio: BodyMuscles.aspectRatio,
      child: LayoutBuilder(
        builder: (context, box) => Semantics(
          label: widget.semanticLabel,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) {
              final hit = _labels?.muscleAt(
                Offset(d.localPosition.dx / box.maxWidth, d.localPosition.dy / box.maxHeight),
              );
              if (hit != null) widget.onSelect(hit);
            },
            child: images == null
                ? const SizedBox.expand()
                : CustomPaint(
                    size: Size.infinite,
                    painter: _BodyPainter(
                      images: images,
                      colors: widget.colors,
                      selected: BodyMuscles.of(widget.side).contains(widget.selected) ? widget.selected : null,
                      outline: p.ink,
                      dim: p.background.computeLuminance() < 0.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _BodyPainter extends CustomPainter {
  new({required this.images, required this.colors, required this.selected, required this.outline, required this.dim});

  final _BodyImages images;
  final Map<String, Color> colors;
  final String? selected;
  final Color outline;

  /// Dark theme: the render is toned down so the body does not glare.
  final bool dim;

  @override
  void paint(Canvas canvas, Size size) {
    final dst = Offset.zero & size;
    Rect src(ui.Image i) => Rect.fromLTWH(0, 0, i.width.toDouble(), i.height.toDouble());
    final quality = Paint()..filterQuality = FilterQuality.medium;

    canvas.drawImageRect(
      images.render,
      src(images.render),
      dst,
      Paint.from(quality)..colorFilter = dim ? const ColorFilter.mode(Color(0xFFB4B4B4), BlendMode.modulate) : null,
    );
    // Each worked muscle takes the hue of its color on the render's own shading: first darkened to
    // a mid tone (so the color is vivid, not pastel), then colored with the "color" blend (hue and
    // saturation of the tint, luminosity of the body).
    Paint tint(Color c) => Paint.from(quality)..colorFilter = ColorFilter.mode(c, BlendMode.srcIn);
    for (final MapEntry(key: muscle, value: color) in colors.entries) {
      final mask = images.masks[muscle];
      if (mask == null) continue;
      canvas
        ..saveLayer(dst, Paint()..blendMode = BlendMode.multiply)
        ..drawImageRect(mask, src(mask), dst, tint(const Color(0xFF9E9E9E)))
        ..restore()
        ..saveLayer(dst, Paint()..blendMode = BlendMode.color)
        ..drawImageRect(mask, src(mask), dst, tint(color))
        ..restore();
    }
    // Selected muscle: an ink ring around its mask (dilated mask minus the mask).
    final mask = selected == null ? null : images.masks[selected];
    if (mask != null) {
      canvas
        ..saveLayer(dst, Paint())
        ..drawImageRect(
          mask,
          src(mask),
          dst,
          Paint.from(quality)
            ..colorFilter = ColorFilter.mode(outline, BlendMode.srcIn)
            ..imageFilter = ui.ImageFilter.dilate(radiusX: 3, radiusY: 3),
        )
        ..drawImageRect(mask, src(mask), dst, Paint.from(quality)..blendMode = BlendMode.dstOut)
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_BodyPainter old) =>
      old.images != images ||
      old.selected != selected ||
      old.outline != outline ||
      old.dim != dim ||
      !mapEquals(old.colors, colors);
}
