import 'package:cresco_ui/cresco_ui.dart';
import 'package:flutter/material.dart';

typedef Json = Map<String, Object?>;

double nombre(Object? v, [double defaut = 0]) => v is num ? v.toDouble() : defaut;
String entier(Object? v) => v is num ? v.round().toString() : '—';

/// « 6 h 05 » à partir de minutes.
String duree(Object? minutes) {
  if (minutes is! num) return '—';
  final m = minutes.round();
  // Espaces insécables : « 6 h 05 » ne se coupe jamais en fin de ligne.
  return '${m ~/ 60} h ${(m % 60).toString().padLeft(2, '0')}';
}

/// Entier signé avec le vrai signe moins (−260, +12).
String signe(int v) => v < 0 ? '−${-v}' : (v > 0 ? '+$v' : '0');

/// « 1 min 30 s », « 45 s ».
String dureeCourte(int secondes) {
  if (secondes < 60) return '$secondes s';
  final reste = secondes % 60;
  return '${secondes ~/ 60} min${reste > 0 ? ' $reste s' : ''}';
}

/// « 72,5 » : décimale française, sans zéro inutile.
String decimal(Object? v, {int chiffres = 1}) {
  if (v is! num) return '—';
  final t = v.toStringAsFixed(chiffres);
  final propre = t.contains('.') ? t.replaceFirst(RegExp(r'\.?0+$'), '') : t;
  return propre.replaceAll('.', ',');
}

const libellesDecision = {
  'NORMALE': 'Plan normal',
  'ADAPTEE': 'Séance adaptée',
  'LEGERE': 'Séance légère',
  'REPOS_ACTIF': 'Repos actif',
  'REPOS': 'Jour de repos',
  'ARRET': 'Pas de séance',
};

const libellesPhase = {
  'post_repas': 'Digestion',
  'glycogene': 'Glycogène',
  'bascule': 'Bascule métabolique',
  'cetose': 'Cétose',
  'prolonge': 'Jeûne prolongé',
};

const libellesTypeJeune = {
  'intermittent': 'Intermittent',
  'eau': 'À l’eau',
  'sec': 'Sec',
  'partiel': 'Daniel (partiel)',
};

/// Page standard : titre serif, contenu défilant avec marges de DESIGN.md.
class PageCresco extends StatelessWidget {
  const new({
    required this.titre,
    required this.enfants,
    super.key,
    this.entete,
    this.surTitre,
    this.basDePage,
    this.onRefresh,
  });
  final String titre;
  final List<Widget> enfants;
  final Widget? entete;
  final Widget? surTitre;
  final Widget? basDePage;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final liste = ListView(
      padding: const EdgeInsets.fromLTRB(CrescoMesures.marge, 8, CrescoMesures.marge, 130),
      children: [
        ?surTitre,
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: Text(titre, style: CrescoTextes.titrePage)),
            ?entete,
          ],
        ),
        const SizedBox(height: 18),
        for (final e in enfants) ...[e, const SizedBox(height: CrescoMesures.gouttiere)],
        ?basDePage,
      ],
    );
    return SafeArea(
      bottom: false,
      child: onRefresh == null
          ? liste
          : RefreshIndicator(color: CrescoCouleurs.pin, onRefresh: onRefresh!, child: liste),
    );
  }
}

class Chargement extends StatelessWidget {
  const new({super.key});
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(40),
      child: CircularProgressIndicator(color: CrescoCouleurs.pin),
    ),
  );
}

class MessageErreur extends StatelessWidget {
  const new(this.message, {super.key, this.reessayer});
  final String message;
  final VoidCallback? reessayer;

  @override
  Widget build(BuildContext context) {
    return CrescoCarte(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: CrescoTextes.corps),
          if (reessayer != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: reessayer, child: const Text('Réessayer')),
          ],
        ],
      ),
    );
  }
}

/// Appel de plugin toléré : un plugin absent (web, test, appareil sans support) ne doit jamais
/// interrompre une séance.
Future<void> sansEchec(Future<void> Function() appel) async {
  try {
    await appel();
  } on Exception {
    // Fonction de confort indisponible sur cet appareil : on continue sans.
  }
}
