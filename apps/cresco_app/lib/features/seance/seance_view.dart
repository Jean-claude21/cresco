import 'dart:async';

import 'package:cresco_app/app/app.locator.dart';
import 'package:cresco_app/features/exercises/exercise_picker.dart';
import 'package:cresco_app/ui/commun.dart';
import 'package:cresco_app/ui/messages.dart';
import 'package:cresco_data/cresco_data.dart' hide Json;
import 'package:cresco_engine/cresco_engine.dart' as moteur;
import 'package:cresco_ui/cresco_ui.dart';
import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class SerieAFaire {
  new({
    required this.exerciceId,
    required this.nom,
    required this.numero,
    required this.total,
    required this.reps,
    required this.rirCible,
    required this.reposS,
    this.chargeKg,
  });
  final String exerciceId;
  final String nom;
  final int numero;
  final int total;
  final int reps;
  final double rirCible;
  final int reposS;
  double? chargeKg;
}

class SeanceViewModel extends BaseViewModel {
  new({this.templateId});

  /// Template picked in "Mes séances"; null runs today's latest one.
  final String? templateId;
  final CrescoApi _api = locator<CrescoApi>();
  final NavigationService _nav = locator<NavigationService>();
  final Messages _snack = locator<Messages>();

  Json? seance;
  List<SerieAFaire> series = [];
  final faites = <Json>[];
  Map<String, Json> exercices = {};
  int index = 0;
  int? rirChoisi;
  int repos = 0;
  Timer? _minuteur;
  final debut = DateTime.now();
  String? erreur;

  SerieAFaire? get courante => index < series.length ? series[index] : null;
  bool get termine => index >= series.length;

  /// Vrai une fois la séance chargée : avant, l'écran montre le chargement (jamais « terminée »).
  bool charge = false;

  Future<void> charger() async {
    unawaited(sansEchec(WakelockPlus.enable));
    await runBusyFuture(
      Future(() async {
        try {
          seance = await _api.seanceDuJour(templateId: templateId);
          try {
            exercices = {for (final e in await _api.exercices()) e['id']! as String: e};
          } on ErreurApi {
            // Hors ligne : on garde les noms de la séance.
          }
          final blocs = ((seance!['modele']! as Json)['blocs']! as List).cast<Json>();
          for (final b in blocs) {
            final total = (b['repeter']! as num).toInt();
            for (final e in (b['etapes']! as List).cast<Json>()) {
              final reps = (e['duree']! as Json)['reps'];
              if (reps is! num || e['exercice_id'] == null) continue;
              final cible = e['cible']! as Json;
              for (var n = 1; n <= total; n++) {
                series.add(
                  SerieAFaire(
                    exerciceId: e['exercice_id']! as String,
                    nom: e['nom'] as String? ?? e['exercice_id']! as String,
                    numero: n,
                    total: total,
                    reps: reps.toInt(),
                    rirCible: nombre(cible['rir'], 2),
                    reposS: nombre(e['repos_s'], 120).toInt(),
                    chargeKg: cible['charge_kg'] is num ? nombre(cible['charge_kg']) : null,
                  ),
                );
              }
            }
          }
        } on ErreurApi catch (e) {
          erreur = e.message;
        }
      }),
    );
    charge = true;
    notifyListeners();
  }

  /// Adds [sets] × [reps] of [exercise] at the end of the session (also after it was finished).
  void addExercise(Json exercise, {int sets = 3, int reps = 10, double? loadKg}) {
    final id = exercise['id']! as String;
    exercices[id] = exercise;
    for (var n = 1; n <= sets; n++) {
      series.add(
        SerieAFaire(
          exerciceId: id,
          nom: exercise['nom']! as String,
          numero: n,
          total: sets,
          reps: reps,
          rirCible: 2,
          reposS: 90,
          chargeKg: loadKg,
        ),
      );
    }
    _minuteur?.cancel();
    repos = 0;
    _snack.afficher(message: '${exercise['nom']} ajouté : $sets × $reps');
    notifyListeners();
  }

  void choisirRir(int rir) {
    rirChoisi = rir;
    notifyListeners();
  }

  void changerCharge(double delta) {
    final s = courante;
    if (s == null) return;
    s.chargeKg = ((s.chargeKg ?? 0) + delta).clamp(0, 1000);
    notifyListeners();
  }

  /// Valide la série : enregistre, puis ajuste la charge des séries suivantes du même exercice (C-PERF-4).
  void validerSerie() {
    final s = courante;
    if (s == null || rirChoisi == null) return;
    // Clés absentes plutôt que null : l'API refuse null (zod), et une charge inconnue n'est pas 0.
    faites.add({'exerciceId': s.exerciceId, 'reps': s.reps, 'chargeKg': ?s.chargeKg, 'rir': rirChoisi});
    final facteur = nombre(moteur.ajustementSerie({'rirReel': rirChoisi, 'rirCible': s.rirCible})['facteur'], 1);
    if (facteur != 1 && s.chargeKg != null) {
      for (final suivante in series.skip(index + 1).where((x) => x.exerciceId == s.exerciceId)) {
        suivante.chargeKg = (suivante.chargeKg! * facteur / 2.5).round() * 2.5;
      }
    }
    index++;
    rirChoisi = null;
    _lancerRepos(s.reposS);
    notifyListeners();
  }

  void _lancerRepos(int secondes) {
    _minuteur?.cancel();
    repos = termine ? 0 : secondes;
    _minuteur = Timer.periodic(const Duration(seconds: 1), (t) {
      if (repos <= 0) {
        t.cancel();
      } else {
        repos--;
      }
      notifyListeners();
    });
  }

  void passerRepos() {
    _minuteur?.cancel();
    repos = 0;
    notifyListeners();
  }

  double? get e1rmCourant {
    final s = courante;
    if (s?.chargeKg == null || rirChoisi == null) return null;
    return nombre(moteur.e1rm({'charge': s!.chargeKg, 'reps': s.reps, 'rir': rirChoisi})['valeur']);
  }

  Future<void> terminer(int rpe) async {
    try {
      // Hors ligne, la séance part en file d'attente (envoyée au prochain lancement).
      await _api.enregistrerSeance({
        'type': 'muscu',
        'rpe': rpe,
        'dureeMin': DateTime.now().difference(debut).inMinutes.clamp(1, 600),
        'decision': ?seance?['decision'],
        'series': faites,
      });
    } on ErreurApi catch (e) {
      _snack.afficher(message: 'Séance non enregistrée : ${e.message}');
      return;
    }
    // Quitter l'écran d'abord : avec une barre de message ouverte, back() fermerait la barre
    // au lieu de l'écran (NavigationService s'appuie sur GetX).
    _nav.back<void>();
    _snack.afficher(message: 'Séance enregistrée (${faites.length} séries)', duration: const Duration(seconds: 2));
  }

  Future<void> ouvrirVideo(BuildContext context) async {
    final s = courante;
    if (s == null) return;
    final liens = (exercices[s.exerciceId]?['liens'] as List?)?.cast<Json>() ?? const [];
    if (liens.isNotEmpty) {
      await launchUrl(Uri.parse(liens.first['url']! as String), mode: LaunchMode.externalApplication);
      return;
    }
    final controleur = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter ma vidéo'),
        content: TextField(
          controller: controleur,
          decoration: const InputDecoration(hintText: 'https://…'),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, controleur.text.trim()), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (url == null || !url.startsWith('https://')) return;
    await _api.ajouterLienVideo(s.exerciceId, url);
    exercices[s.exerciceId] = {
      ...?exercices[s.exerciceId],
      'liens': [
        {'url': url},
      ],
    };
    notifyListeners();
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    unawaited(sansEchec(WakelockPlus.disable));
    super.dispose();
  }
}

/// Écran 2 (maquette 02-seance) : série en cours, RIR en un tap, repos, charge suivante.
class SeanceView extends StatelessWidget {
  const new({super.key, this.templateId});

  /// Template picked in "Mes séances"; null runs today's latest one.
  final String? templateId;

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<SeanceViewModel>.reactive(
      viewModelBuilder: () => SeanceViewModel(templateId: templateId),
      onViewModelReady: (vm) => vm.charger(),
      // Mockup G: the session screen is always dark, readable from a meter away between sets.
      builder: (context, vm, _) => Theme(
        data: crescoTheme(brightness: Brightness.dark, fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily),
        child: Builder(builder: (context) => _build(context, vm)),
      ),
    );
  }

  Widget _build(BuildContext context, SeanceViewModel vm) {
    final s = vm.courante;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Séance en cours', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (vm.charge && vm.erreur == null)
            IconButton(
              tooltip: 'Ajouter un exercice',
              icon: const Icon(Icons.playlist_add),
              onPressed: () async {
                final e = await showExercisePicker(context);
                if (e != null) vm.addExercise(e);
              },
            ),
        ],
      ),
      body: vm.isBusy || !vm.charge
          ? const Chargement()
          : vm.erreur != null
          ? Padding(padding: const EdgeInsets.all(18), child: MessageErreur(vm.erreur!))
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 30),
              children: [
                if (s != null) ...[
                  Text(s.nom, style: CrescoTextes.titrePage.copyWith(fontSize: 36)),
                  const SizedBox(height: 4),
                  Text((vm.exercices[s.exerciceId]?['consignes'] as String?) ?? '', style: context.mutedStyle),
                  const SizedBox(height: 14),
                  _Demonstration(exerciseId: s.exerciceId, onVideo: () => vm.ouvrirVideo(context)),
                  const SizedBox(height: 12),
                  _CarteSerie(vm: vm, s: s),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final e = await showExercisePicker(context);
                      if (e != null) vm.addExercise(e);
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter un exercice'),
                  ),
                ] else if (vm.series.isEmpty)
                  const CrescoCarte(
                    child: Text('Aucune série de musculation prévue aujourd’hui.', style: CrescoTextes.corps),
                  )
                else
                  CrescoCarte(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Séance terminée', style: CrescoTextes.titreCarte),
                        const SizedBox(height: 6),
                        Text(
                          '${vm.faites.length} séries enregistrées. Note l’effort global (RPE) :',
                          style: context.mutedStyle,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (var r = 4; r <= 10; r++)
                              ActionChip(label: Text('$r'), onPressed: () => vm.terminer(r)),
                          ],
                        ),
                      ],
                    ),
                  ),
                if (vm.repos > 0) ...[
                  const SizedBox(height: 12),
                  CrescoCarte(
                    child: Row(
                      children: [
                        Icon(Icons.timer_outlined, color: context.palette.rest),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Repos',
                            style: TextStyle(color: context.palette.ink, fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          '${(vm.repos ~/ 60).toString().padLeft(2, '0')}:${(vm.repos % 60).toString().padLeft(2, '0')}',
                          style: CrescoTextes.chiffre.copyWith(color: context.palette.rest, fontSize: 44),
                        ),
                        const SizedBox(width: 8),
                        IconButton.outlined(
                          tooltip: 'Passer le repos',
                          onPressed: vm.passerRepos,
                          icon: const Icon(Icons.skip_next),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

/// Black-and-white gym photo matching the exercise, with the user's own video link.
class _Demonstration extends StatelessWidget {
  const new({required this.exerciseId, required this.onVideo});
  final String exerciseId;
  final VoidCallback onVideo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: CrescoShape.borderRadius,
          child: CrescoPhotoImage(CrescoPhoto.forExercise(exerciseId), height: 170),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onVideo,
          style: OutlinedButton.styleFrom(
            foregroundColor: context.palette.effort,
            side: BorderSide(color: context.palette.effort, width: CrescoShape.border),
          ),
          icon: const Icon(Icons.play_circle_outline),
          label: const Text('Ma vidéo'),
        ),
      ],
    );
  }
}

class _CarteSerie extends StatelessWidget {
  const new({required this.vm, required this.s});
  final SeanceViewModel vm;
  final SerieAFaire s;

  @override
  Widget build(BuildContext context) {
    final suivante = vm.index + 1 < vm.series.length ? vm.series[vm.index + 1] : null;
    return CrescoCarte(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Surtitre('Série ${s.numero} sur ${s.total}')),
              for (var i = 1; i <= s.total; i++)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  width: 26,
                  height: 7,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: i < s.numero
                        ? context.palette.effort
                        : (i == s.numero ? context.palette.ink : context.palette.line),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Un seul texte composé : passe à la ligne avec un texte agrandi, chiffres sur la même ligne de base.
          GestureDetector(
            onTap: () => vm.changerCharge(2.5),
            onLongPress: () => vm.changerCharge(-2.5),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: s.chargeKg == null ? '—' : decimal(s.chargeKg),
                    style: CrescoTextes.chiffre.copyWith(fontSize: 58, color: context.palette.effort),
                  ),
                  TextSpan(text: ' kg  ×  ', style: context.unitStyle),
                  TextSpan(
                    text: '${s.reps}',
                    style: CrescoTextes.chiffre.copyWith(fontSize: 58, color: context.palette.effort),
                  ),
                  TextSpan(text: ' répétitions', style: context.unitStyle),
                ],
              ),
            ),
          ),
          Row(
            children: [
              IconButton(
                tooltip: 'Moins 2,5 kg',
                onPressed: () => vm.changerCharge(-2.5),
                icon: const Icon(Icons.remove_circle_outline),
              ),
              IconButton(
                tooltip: 'Plus 2,5 kg',
                onPressed: () => vm.changerCharge(2.5),
                icon: const Icon(Icons.add_circle_outline),
              ),
              if (vm.e1rmCourant != null) Text('e1RM ${decimal(vm.e1rmCourant)} kg', style: context.mutedStyle),
            ],
          ),
          Divider(color: context.palette.line),
          Row(
            children: [
              const Expanded(
                child: Text('RIR réel', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              ),
              Text(
                'Cible ${decimal(s.rirCible)}',
                style: TextStyle(color: context.palette.ink, fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ],
          ),
          Text('Combien de répétitions restaient possibles ?', style: context.mutedStyle),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final r in [0, 1, 2, 3, 4])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ChoiceChip(
                      showCheckmark: false,
                      label: SizedBox(
                        width: double.infinity,
                        child: Text(r == 4 ? '4+' : '$r', textAlign: TextAlign.center),
                      ),
                      labelStyle: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: vm.rirChoisi == r ? context.palette.onEffort : context.palette.ink,
                      ),
                      side: BorderSide(
                        color: vm.rirChoisi == r ? context.palette.effort : context.palette.ink,
                        width: CrescoShape.border,
                      ),
                      selectedColor: context.palette.effort,
                      backgroundColor: context.palette.background,
                      selected: vm.rirChoisi == r,
                      onSelected: (_) => vm.choisirRir(r),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: effortButtonStyle(context),
            onPressed: vm.rirChoisi == null ? null : vm.validerSerie,
            child: Text(suivante == null ? 'Valider la dernière série' : 'Valider la série'),
          ),
          if (suivante != null) ...[
            const SizedBox(height: 10),
            Text(
              'Ensuite : ${suivante.nom} · ${suivante.chargeKg == null ? '' : '${decimal(suivante.chargeKg)} kg × '}${suivante.reps}',
              style: context.mutedStyle,
            ),
          ],
        ],
      ),
    );
  }
}
