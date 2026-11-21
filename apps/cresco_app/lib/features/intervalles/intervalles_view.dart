import 'dart:async';

import 'package:cresco_app/app/app.locator.dart';
import 'package:cresco_app/ui/commun.dart';
import 'package:cresco_data/cresco_data.dart' hide Json;
import 'package:cresco_ui/cresco_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class Etape {
  new({
    required this.libelle,
    required this.secondes,
    required this.vitesseMs,
    required this.repetition,
    required this.repetitions,
    required this.bloc,
  });
  final String libelle;
  final int secondes;
  final double? vitesseMs;
  final int repetition;
  final int repetitions;
  final int bloc;

  /// Unités internes SI, affichage en km/h (AGENTS.md).
  String get vitesseKmh => vitesseMs == null ? '—' : decimal(vitesseMs! * 3.6);
}

/// Aplatit les blocs → étapes (MODELE_DONNEES.md) en une suite chronologique.
List<Etape> aplatir(Json modele) {
  final etapes = <Etape>[];
  final blocs = (modele['blocs']! as List).cast<Json>();
  for (var b = 0; b < blocs.length; b++) {
    final rep = (blocs[b]['repeter']! as num).toInt();
    for (var r = 1; r <= rep; r++) {
      for (final e in (blocs[b]['etapes']! as List).cast<Json>()) {
        final t = (e['duree']! as Json)['temps_s'];
        if (t is! num) continue;
        final v = (e['cible']! as Json)['vitesse_ms'];
        etapes.add(
          Etape(
            libelle: e['libelle'] as String? ?? 'Étape',
            secondes: t.toInt(),
            vitesseMs: v is num ? v.toDouble() : null,
            repetition: r,
            repetitions: rep,
            bloc: b,
          ),
        );
      }
    }
  }
  return etapes;
}

class IntervallesViewModel extends BaseViewModel {
  new(this.modele) : etapes = aplatir(modele);
  final Json modele;
  final List<Etape> etapes;
  final _tts = FlutterTts();
  final CrescoApi _api = locator<CrescoApi>();
  final NavigationService _nav = locator<NavigationService>();

  int index = 0;
  late int restant = etapes.first.secondes;
  bool enPause = true;

  /// Vrai dès le premier départ : distingue « Démarrer » de « Reprendre ».
  bool demarre = false;
  bool termine = false;
  Timer? _minuteur;
  final debut = DateTime.now();

  int get preavis => nombre((modele['annonces'] as Json?)?['preavis_s'], 15).toInt();
  bool get voix => (modele['annonces'] as Json?)?['voix'] != false;
  Etape get courante => etapes[index];
  Etape? get suivante => index + 1 < etapes.length ? etapes[index + 1] : null;

  Future<void> demarrer() async {
    await sansEchec(() => _tts.setLanguage('fr-FR'));
    await sansEchec(() => _tts.setSpeechRate(0.5));
    await sansEchec(WakelockPlus.enable);
    basculerPause();
  }

  void basculerPause() {
    enPause = !enPause;
    demarre = true;
    if (enPause) {
      _minuteur?.cancel();
    } else {
      if (restant == courante.secondes) _annoncer('${courante.libelle}, ${courante.vitesseKmh} kilomètres heure');
      _minuteur = Timer.periodic(const Duration(seconds: 1), (_) => _tic());
    }
    notifyListeners();
  }

  void _tic() {
    restant--;
    final s = suivante;
    if (restant == preavis && s != null && preavis > 0) {
      _annoncer('Dans $preavis secondes, passe à ${s.vitesseKmh} kilomètres heure');
      unawaited(HapticFeedback.mediumImpact());
    }
    if (restant <= 0) {
      if (s == null) {
        _minuteur?.cancel();
        termine = true;
        _annoncer('Séance terminée. Bravo.');
      } else {
        index++;
        restant = courante.secondes;
        _annoncer('${courante.libelle}, ${courante.vitesseKmh} kilomètres heure');
        unawaited(HapticFeedback.heavyImpact());
      }
    }
    notifyListeners();
  }

  void _annoncer(String texte) {
    if (voix) unawaited(sansEchec(() => _tts.speak(texte)));
  }

  Future<void> enregistrer() async {
    await _api.enregistrerSeance({
      'type': modele['type'] ?? 'course_tapis',
      'dureeMin': DateTime.now().difference(debut).inMinutes.clamp(1, 600),
      'rpe': 7,
      'series': [
        for (final e in etapes.take(index + 1)) {'vitesseMs': ?e.vitesseMs, 'dureeS': e.secondes},
      ],
    });
    _nav.back<void>();
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    unawaited(sansEchec(_tts.stop));
    unawaited(sansEchec(WakelockPlus.disable));
    super.dispose();
  }
}

/// Écran 3 (maquette 03-intervalles) : minuteur, vitesse cible, préavis vocal, frise.
class IntervallesView extends StatelessWidget {
  const new({required this.modele, super.key});
  final Map<String, Object?> modele;

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<IntervallesViewModel>.reactive(
      viewModelBuilder: () => IntervallesViewModel(modele),
      onViewModelReady: (vm) => vm.demarrer(),
      builder: (context, vm, _) {
        final e = vm.courante;
        final s = vm.suivante;
        final frise = vm.etapes.where((x) => x.bloc == e.bloc).toList();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Séance en cours', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 30),
            children: [
              Text(modele['nom'] as String? ?? 'Intervalles', style: CrescoTextes.titrePage.copyWith(fontSize: 36)),
              const SizedBox(height: 14),
              CrescoCarteSombre(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Surtitre('Temps restant', couleur: context.palette.effort)),
                        Pastille(e.repetitions > 1 ? '${e.libelle} ${e.repetition}/${e.repetitions}' : e.libelle),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      vm.termine
                          ? 'Fini'
                          : '${(vm.restant ~/ 60).toString().padLeft(2, '0')}:${(vm.restant % 60).toString().padLeft(2, '0')}',
                      style: CrescoTextes.chiffre.copyWith(color: Colors.white, fontSize: 96),
                    ),
                    const Divider(color: Color(0x55D8EEA1), height: 28),
                    Row(
                      children: [
                        Icon(Icons.speed, color: context.palette.effort),
                        const SizedBox(width: 10),
                        const Text('Vitesse cible', style: TextStyle(color: Colors.white, fontSize: 18)),
                      ],
                    ),
                    ChiffreUnite(e.vitesseKmh, 'km/h', taille: 52, couleur: Colors.white),
                  ],
                ),
              ),
              if (s != null) ...[
                const SizedBox(height: 12),
                Material(
                  color: context.palette.effortSoft,
                  shape: CrescoShape.rectangle(context.palette.line),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: context.palette.action,
                      child: Icon(Icons.volume_up, color: context.palette.onAction),
                    ),
                    title: Text(
                      vm.restant <= vm.preavis
                          ? 'Dans ${vm.restant} s, passe à ${s.vitesseKmh} km/h'
                          : 'Ensuite : ${s.vitesseKmh} km/h',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
                    ),
                    subtitle: Text('${s.libelle} · ${dureeCourte(s.secondes)}'),
                  ),
                ),
              ],
              if (frise.length > 1) ...[
                const SizedBox(height: 12),
                CrescoCarte(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Surtitre('Déroulé des intervalles'),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 60,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (final x in frise)
                              Expanded(
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  height: (x.vitesseMs ?? 1) >= (e.vitesseMs ?? 1) ? 56 : 26,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    color: identical(x, e)
                                        ? context.palette.ink
                                        : vm.etapes.indexOf(x) < vm.index
                                        ? context.palette.effort.withValues(alpha: 0.7)
                                        : context.palette.line,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              CrescoCarte(
                child: Row(
                  children: [
                    const Icon(Icons.favorite_border),
                    const SizedBox(width: 12),
                    Expanded(child: Text('FC indisponible : aucun capteur connecté', style: context.mutedStyle)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (vm.termine)
                FilledButton(onPressed: vm.enregistrer, child: const Text('Enregistrer la séance'))
              else
                FilledButton.icon(
                  onPressed: vm.basculerPause,
                  icon: Icon(vm.enPause ? Icons.play_arrow : Icons.pause),
                  label: Text(vm.enPause ? (vm.demarre ? 'Reprendre' : 'Démarrer') : 'Mettre en pause'),
                ),
            ],
          ),
        );
      },
    );
  }
}
