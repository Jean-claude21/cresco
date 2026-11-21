import 'dart:math' as math;

import 'package:cresco_ui/src/palette.dart';
import 'package:cresco_ui/src/theme.dart';
import 'package:flutter/material.dart';

/// Rounded surface card with a hairline border.
class CrescoCarte extends StatelessWidget {
  const new({required this.child, super.key, this.padding = const EdgeInsets.all(22), this.onTap});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final carte = DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: CrescoShape.borderRadius,
        border: Border.all(color: p.line, width: CrescoShape.border),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Padding(padding: padding, child: child),
      ),
    );
    if (onTap == null) return carte;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: CrescoShape.borderRadius, onTap: onTap, child: carte),
    );
  }
}

/// Dark hero card for the engine's decisions, with faint growth lines. Text on it is white.
class CrescoCarteSombre extends StatelessWidget {
  const new({required this.child, super.key, this.padding = const EdgeInsets.all(24)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ClipRRect(
      borderRadius: CrescoShape.borderRadius,
      child: ColoredBox(
        color: p.hero,
        child: CustomPaint(
          painter: _LignesCroissance(p.effort),
          child: Padding(
            padding: padding,
            child: DefaultTextStyle.merge(
              style: const TextStyle(color: Colors.white),
              child: IconTheme.merge(data: const IconThemeData(color: Colors.white), child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _LignesCroissance extends CustomPainter {
  new(this.lime);
  final Color lime;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = lime.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (var i = 0; i < 16; i++) {
      final x = size.width * 0.62 + i * 9;
      final path = Path()
        ..moveTo(x, size.height + 4)
        ..cubicTo(x - 10, size.height * 0.6, x + 40, size.height * 0.35, x + 30, -4);
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant _LignesCroissance old) => old.lime != lime;
}

class Surtitre extends StatelessWidget {
  const new(this.texte, {super.key, this.couleur, this.majuscules = true});
  final String texte;
  final Color? couleur;

  /// False keeps an imposed case (e.g. "e1RM").
  final bool majuscules;

  @override
  Widget build(BuildContext context) =>
      Text(majuscules ? texte.toUpperCase() : texte, style: context.overlineStyle.copyWith(color: couleur));
}

/// Big number followed by its unit, on the same baseline.
class ChiffreUnite extends StatelessWidget {
  const new(this.chiffre, this.unite, {super.key, this.taille = 46, this.couleur});
  final String chiffre;
  final String unite;
  final double taille;
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    // The unit never wraps: "kcal/j" stays in one piece next to the number.
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          chiffre,
          style: CrescoTextes.chiffre.copyWith(fontSize: taille, color: couleur),
        ),
        const SizedBox(width: 10),
        Text(unite, softWrap: false, style: context.unitStyle.copyWith(color: couleur?.withValues(alpha: 0.8))),
      ],
    );
  }
}

class BarreProgres extends StatelessWidget {
  const new({required this.valeur, super.key, this.couleur});
  final double valeur;

  /// Ink of the current theme when null.
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: valeur.clamp(0, 1),
        minHeight: 9,
        color: couleur ?? context.palette.ink,
        backgroundColor: context.palette.line,
      ),
    );
  }
}

class Pastille extends StatelessWidget {
  const new(this.texte, {super.key, this.fond, this.texteCouleur});
  final String texte;

  /// Lime and its ink when null.
  final Color? fond;
  final Color? texteCouleur;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(color: fond ?? p.effort, borderRadius: CrescoShape.borderRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          texte,
          style: TextStyle(color: texteCouleur ?? p.onEffort, fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
    );
  }
}

/// Score ring (form of the day) with tick marks.
class Anneau extends StatelessWidget {
  const new({required this.fraction, required this.child, super.key, this.taille = 150, this.epaisseur = 12});
  final double fraction;
  final Widget child;
  final double taille;
  final double epaisseur;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: taille,
      child: CustomPaint(
        painter: _AnneauPeintre(fraction.clamp(0, 1), epaisseur, context.palette),
        child: Center(child: child),
      ),
    );
  }
}

class _AnneauPeintre extends CustomPainter {
  new(this.fraction, this.epaisseur, this.p);
  final double fraction;
  final double epaisseur;
  final CrescoPalette p;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final rayon = size.width / 2 - epaisseur / 2;
    final rect = Rect.fromCircle(center: centre, radius: rayon);
    final fond = Paint()
      ..color = p.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = epaisseur;
    final arc = Paint()
      ..color = p.ink
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = epaisseur;
    canvas
      ..drawArc(rect, 0, 2 * math.pi, false, fond)
      ..drawArc(rect, -math.pi / 2, 2 * math.pi * fraction, false, arc);
    final graduation = Paint()
      ..color = p.muted.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    for (var i = 0; i < 48; i++) {
      final a = i / 48 * 2 * math.pi;
      final r1 = rayon - epaisseur - 4;
      final r2 = r1 - (i % 4 == 0 ? 7 : 3);
      canvas.drawLine(
        centre + Offset(math.cos(a) * r1, math.sin(a) * r1),
        centre + Offset(math.cos(a) * r2, math.sin(a) * r2),
        graduation,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AnneauPeintre old) => old.fraction != fraction || old.p != p;
}

/// 24-hour fasting dial: arc from the start to now, tick for the planned end.
class CadranJeune extends StatelessWidget {
  const new({required this.heuresEcoulees, required this.child, super.key, this.heuresPrevues, this.taille = 250});
  final double heuresEcoulees;
  final double? heuresPrevues;
  final Widget child;
  final double taille;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: taille,
      child: CustomPaint(
        painter: _CadranPeintre(heuresEcoulees, heuresPrevues, context.palette),
        child: Center(child: child),
      ),
    );
  }
}

class _CadranPeintre extends CustomPainter {
  new(this.h, this.prevues, this.p);
  final double h;
  final double? prevues;
  final CrescoPalette p;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 10;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = p.restSoft
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14,
    );
    final tour = (h % 24) / 24;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * (h >= 24 ? 1 : tour),
      false,
      Paint()
        ..color = p.rest
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 14,
    );
    final graduation = Paint()
      ..color = p.muted.withValues(alpha: 0.5)
      ..strokeWidth = 1.2;
    for (var i = 0; i < 96; i++) {
      final a = i / 96 * 2 * math.pi - math.pi / 2;
      final r1 = r - 18;
      final r2 = r1 - (i % 4 == 0 ? 9 : 4);
      canvas.drawLine(
        c + Offset(math.cos(a) * r1, math.sin(a) * r1),
        c + Offset(math.cos(a) * r2, math.sin(a) * r2),
        graduation,
      );
    }
    final ring = Paint()
      ..color = p.ink
      ..style = PaintingStyle.stroke;
    final debut = c + Offset(0, -r);
    canvas
      ..drawCircle(debut, 9, Paint()..color = p.background)
      ..drawCircle(debut, 9, ring..strokeWidth = 2);
    final a = 2 * math.pi * (h >= 24 ? 0.999 : tour) - math.pi / 2;
    final bout = c + Offset(math.cos(a) * r, math.sin(a) * r);
    canvas
      ..drawCircle(bout, 11, Paint()..color = p.rest)
      ..drawCircle(bout, 11, ring..strokeWidth = 3);
    if (prevues != null && prevues! < 24) {
      final af = 2 * math.pi * prevues! / 24 - math.pi / 2;
      canvas.drawLine(
        c + Offset(math.cos(af) * (r - 12), math.sin(af) * (r - 12)),
        c + Offset(math.cos(af) * (r + 12), math.sin(af) * (r + 12)),
        Paint()
          ..color = p.ink
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CadranPeintre old) => old.h != h || old.prevues != prevues || old.p != p;
}

/// e1RM curve (points) with the dashed trend line.
class CourbeTendance extends StatelessWidget {
  const new({required this.valeurs, super.key, this.hauteur = 170});
  final List<double> valeurs;
  final double hauteur;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: hauteur,
      width: double.infinity,
      child: CustomPaint(painter: _CourbePeintre(valeurs, context.palette)),
    );
  }
}

class _CourbePeintre extends CustomPainter {
  new(this.v, this.c);
  final List<double> v;
  final CrescoPalette c;

  @override
  void paint(Canvas canvas, Size size) {
    if (v.length < 2) return;
    final mn = v.reduce(math.min) - 1;
    final mx = v.reduce(math.max) + 1;
    Offset pt(int i, double y) =>
        Offset(i / (v.length - 1) * (size.width - 16) + 8, size.height - 8 - (y - mn) / (mx - mn) * (size.height - 16));
    final grille = Paint()
      ..color = c.line
      ..strokeWidth = 1;
    for (var k = 0; k <= 2; k++) {
      final y = 8 + k * (size.height - 16) / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grille);
    }
    final chemin = Path()..moveTo(pt(0, v[0]).dx, pt(0, v[0]).dy);
    for (var i = 1; i < v.length; i++) {
      chemin.lineTo(pt(i, v[i]).dx, pt(i, v[i]).dy);
    }
    final aire = Path.from(chemin)
      ..lineTo(pt(v.length - 1, mn).dx, size.height)
      ..lineTo(pt(0, mn).dx, size.height)
      ..close();
    canvas
      ..drawPath(aire, Paint()..color = c.effort.withValues(alpha: 0.12))
      ..drawPath(
        chemin,
        Paint()
          ..color = c.effort
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
    // Least-squares line.
    final n = v.length;
    final mxI = (n - 1) / 2;
    final my = v.reduce((a, b) => a + b) / n;
    var num = 0.0;
    var den = 0.0;
    for (var i = 0; i < n; i++) {
      num += (i - mxI) * (v[i] - my);
      den += (i - mxI) * (i - mxI);
    }
    final pente = den == 0 ? 0 : num / den;
    final a = pt(0, my - pente * mxI);
    final b = pt(n - 1, my + pente * mxI);
    final tendance = Paint()
      ..color = c.ink
      ..strokeWidth = 2.4;
    const tiret = 9.0;
    final d = b - a;
    final longueur = d.distance;
    for (var s = 0.0; s < longueur; s += tiret * 2) {
      canvas.drawLine(a + d * (s / longueur), a + d * (math.min(s + tiret, longueur) / longueur), tendance);
    }
    for (var i = 0; i < n; i++) {
      final p = pt(i, v[i]);
      canvas
        ..drawCircle(p, 5, Paint()..color = c.surface)
        ..drawCircle(
          p,
          5,
          Paint()
            ..color = c.effort
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _CourbePeintre old) => old.v != v || old.c != c;
}

/// "Icon + label" header of small cards: the label wraps instead of overflowing
/// on narrow screens (overflow seen on a Galaxy S25).
class IconeLibelle extends StatelessWidget {
  const new(
    this.icone,
    this.libelle, {
    super.key,
    this.style = const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
  });
  final IconData icone;
  final String libelle;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icone, size: 22),
        const SizedBox(width: 8),
        Flexible(child: Text(libelle, style: style)),
      ],
    );
  }
}

/// "Label … value" row with an icon, used inside cards.
class LigneMesure extends StatelessWidget {
  const new({required this.icone, required this.libelle, required this.valeur, super.key});
  final IconData icone;
  final String libelle;
  final String valeur;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icone, size: 20, color: context.palette.ink),
          const SizedBox(width: 10),
          Expanded(child: Text(libelle, style: context.mutedStyle.copyWith(fontSize: 16))),
          Text(valeur, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        ],
      ),
    );
  }
}
