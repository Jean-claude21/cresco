import 'dart:math' as math;

import 'package:cresco_ui/src/theme.dart';
import 'package:flutter/material.dart';

/// Carte blanche arrondie avec filet et ombre courte.
class CrescoCarte extends StatelessWidget {
  const new({required this.child, super.key, this.padding = const EdgeInsets.all(22), this.onTap});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final carte = DecoratedBox(
      decoration: BoxDecoration(
        color: CrescoCouleurs.blanc,
        borderRadius: BorderRadius.circular(CrescoMesures.rayon),
        border: Border.all(color: CrescoCouleurs.filet, width: 0.7),
        boxShadow: const [BoxShadow(color: CrescoCouleurs.ombre, offset: Offset(0, 2))],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Padding(padding: padding, child: child),
      ),
    );
    if (onTap == null) return carte;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: BorderRadius.circular(CrescoMesures.rayon), onTap: onTap, child: carte),
    );
  }
}

/// Carte pin sombre réservée aux décisions du moteur, avec les lignes de croissance.
class CrescoCarteSombre extends StatelessWidget {
  const new({required this.child, super.key, this.padding = const EdgeInsets.all(24)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(CrescoMesures.rayon),
      child: ColoredBox(
        color: CrescoCouleurs.pinSombre,
        child: CustomPaint(
          painter: _LignesCroissance(),
          child: Padding(
            padding: padding,
            child: DefaultTextStyle.merge(
              style: const TextStyle(color: CrescoCouleurs.blanc),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _LignesCroissance extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = CrescoCouleurs.pousse.withValues(alpha: 0.18)
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class Surtitre extends StatelessWidget {
  const new(this.texte, {super.key, this.couleur, this.majuscules = true});
  final String texte;
  final Color? couleur;

  /// Faux pour garder une casse imposée (ex. « e1RM »).
  final bool majuscules;

  @override
  Widget build(BuildContext context) =>
      Text(majuscules ? texte.toUpperCase() : texte, style: CrescoTextes.surtitre.copyWith(color: couleur));
}

/// Grand nombre suivi de son unité, sur la même ligne de base.
class ChiffreUnite extends StatelessWidget {
  const new(this.chiffre, this.unite, {super.key, this.taille = 46, this.couleur});
  final String chiffre;
  final String unite;
  final double taille;
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    // L'unité ne se coupe jamais : « kcal/j » reste d'un seul tenant à côté du nombre.
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
        Text(unite, softWrap: false, style: CrescoTextes.unite.copyWith(color: couleur?.withValues(alpha: 0.8))),
      ],
    );
  }
}

class BarreProgres extends StatelessWidget {
  const new({required this.valeur, super.key, this.couleur = CrescoCouleurs.pin});
  final double valeur;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: valeur.clamp(0, 1),
        minHeight: 9,
        color: couleur,
        backgroundColor: CrescoCouleurs.filet,
      ),
    );
  }
}

class Pastille extends StatelessWidget {
  const new(this.texte, {super.key, this.fond = CrescoCouleurs.pousse, this.texteCouleur = CrescoCouleurs.pinSombre});
  final String texte;
  final Color fond;
  final Color texteCouleur;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: fond, borderRadius: BorderRadius.circular(40)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          texte,
          style: TextStyle(color: texteCouleur, fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
    );
  }
}

/// Anneau de score (forme du jour), avec graduations.
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
        painter: _AnneauPeintre(fraction.clamp(0, 1), epaisseur),
        child: Center(child: child),
      ),
    );
  }
}

class _AnneauPeintre extends CustomPainter {
  new(this.fraction, this.epaisseur);
  final double fraction;
  final double epaisseur;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final rayon = size.width / 2 - epaisseur / 2;
    final rect = Rect.fromCircle(center: centre, radius: rayon);
    final fond = Paint()
      ..color = CrescoCouleurs.sauge
      ..style = PaintingStyle.stroke
      ..strokeWidth = epaisseur;
    final arc = Paint()
      ..color = CrescoCouleurs.pin
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = epaisseur;
    canvas
      ..drawArc(rect, 0, 2 * math.pi, false, fond)
      ..drawArc(rect, -math.pi / 2, 2 * math.pi * fraction, false, arc);
    final graduation = Paint()
      ..color = CrescoCouleurs.texteSecondaire.withValues(alpha: 0.45)
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
  bool shouldRepaint(covariant _AnneauPeintre old) => old.fraction != fraction;
}

/// Cadran 24 h du jeûne : arc du début à maintenant, repère de fin prévue.
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
        painter: _CadranPeintre(heuresEcoulees, heuresPrevues),
        child: Center(child: child),
      ),
    );
  }
}

class _CadranPeintre extends CustomPainter {
  new(this.h, this.prevues);
  final double h;
  final double? prevues;

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
        ..color = CrescoCouleurs.sauge
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
        ..color = CrescoCouleurs.pin
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 14,
    );
    final graduation = Paint()
      ..color = CrescoCouleurs.texteSecondaire.withValues(alpha: 0.5)
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
    final debut = c + Offset(0, -r);
    canvas
      ..drawCircle(debut, 9, Paint()..color = CrescoCouleurs.pousse)
      ..drawCircle(
        debut,
        9,
        Paint()
          ..color = CrescoCouleurs.pin
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    final a = 2 * math.pi * (h >= 24 ? 0.999 : tour) - math.pi / 2;
    final bout = c + Offset(math.cos(a) * r, math.sin(a) * r);
    canvas
      ..drawCircle(bout, 11, Paint()..color = CrescoCouleurs.pousse)
      ..drawCircle(
        bout,
        11,
        Paint()
          ..color = CrescoCouleurs.pin
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    if (prevues != null && prevues! < 24) {
      final af = 2 * math.pi * prevues! / 24 - math.pi / 2;
      canvas.drawLine(
        c + Offset(math.cos(af) * (r - 12), math.sin(af) * (r - 12)),
        c + Offset(math.cos(af) * (r + 12), math.sin(af) * (r + 12)),
        Paint()
          ..color = CrescoCouleurs.encre
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CadranPeintre old) => old.h != h || old.prevues != prevues;
}

/// Courbe des e1RM (points) avec la droite de tendance en pointillés.
class CourbeTendance extends StatelessWidget {
  const new({required this.valeurs, super.key, this.hauteur = 170});
  final List<double> valeurs;
  final double hauteur;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: hauteur,
      width: double.infinity,
      child: CustomPaint(painter: _CourbePeintre(valeurs)),
    );
  }
}

class _CourbePeintre extends CustomPainter {
  new(this.v);
  final List<double> v;

  @override
  void paint(Canvas canvas, Size size) {
    if (v.length < 2) return;
    final mn = v.reduce(math.min) - 1;
    final mx = v.reduce(math.max) + 1;
    Offset pt(int i, double y) =>
        Offset(i / (v.length - 1) * (size.width - 16) + 8, size.height - 8 - (y - mn) / (mx - mn) * (size.height - 16));
    final grille = Paint()
      ..color = CrescoCouleurs.filet
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
      ..drawPath(aire, Paint()..color = CrescoCouleurs.sauge.withValues(alpha: 0.6))
      ..drawPath(
        chemin,
        Paint()
          ..color = CrescoCouleurs.eucalyptus
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
    // Droite des moindres carrés.
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
      ..color = CrescoCouleurs.pinSombre
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
        ..drawCircle(p, 5, Paint()..color = CrescoCouleurs.blanc)
        ..drawCircle(
          p,
          5,
          Paint()
            ..color = CrescoCouleurs.pin
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _CourbePeintre old) => old.v != v;
}

/// Ligne « libellé … valeur » avec icône, utilisée dans les cartes.
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
          Icon(icone, size: 20, color: CrescoCouleurs.encre),
          const SizedBox(width: 10),
          Expanded(child: Text(libelle, style: CrescoTextes.secondaire.copyWith(fontSize: 16))),
          Text(valeur, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        ],
      ),
    );
  }
}
