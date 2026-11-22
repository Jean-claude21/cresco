import 'dart:async';

import 'package:cresco_app/app/app.locator.dart';
import 'package:cresco_app/features/exercises/exercise_picker.dart';
import 'package:cresco_app/ui/commun.dart';
import 'package:cresco_app/ui/messages.dart';
import 'package:cresco_app/ui/workout_keep_alive.dart';
import 'package:cresco_data/cresco_data.dart' hide Json;
import 'package:cresco_engine/cresco_engine.dart' as moteur;
import 'package:cresco_ui/cresco_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
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

  /// End of the rest on the wall clock: the rest keeps counting with the screen off.
  DateTime? _finRepos;
  final _tts = FlutterTts();
  String? erreur;

  SerieAFaire? get courante => index < series.length ? series[index] : null;
  bool get termine => index >= series.length;

  /// Vrai une fois la séance chargée : avant, l'écran montre le chargement (jamais « terminée »).
  bool charge = false;

  Future<void> charger() async {
    unawaited(sansEchec(WakelockPlus.enable));
    unawaited(sansEchec(() => _tts.setLanguage('fr-FR')));
    unawaited(
      sansEchec(
        () => _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          IosTextToSpeechAudioCategoryOptions.duckOthers,
        ]),
      ),
    );
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
    if (repos == 0) {
      unawaited(WorkoutKeepAlive.stop());
      return;
    }
    // First rest of the session: keep the app alive so the rest ends on time, screen off.
    unawaited(WorkoutKeepAlive.start(title: 'Repos', text: _texteRepos));
    _finRepos = DateTime.now().add(Duration(seconds: repos));
    _minuteur = Timer.periodic(const Duration(milliseconds: 500), (_) => _ticRepos());
  }

  String get _texteRepos {
    final s = courante;
    final suite = s == null ? '' : ' · ensuite ${s.nom}';
    return '${repos ~/ 60}:${(repos % 60).toString().padLeft(2, '0')}$suite';
  }

  void _ticRepos() {
    final fin = _finRepos;
    if (fin == null) return;
    final avant = repos;
    repos = (fin.difference(DateTime.now()).inMilliseconds / 1000).ceil().clamp(0, 3600);
    if (repos == 0) {
      _minuteur?.cancel();
      _finRepos = null;
      final s = courante;
      unawaited(HapticFeedback.heavyImpact());
      unawaited(
        sansEchec(
          () => _tts.speak(
            s == null
                ? 'Repos terminé.'
                : 'Repos terminé. ${s.nom}, ${s.chargeKg == null ? '' : '${decimal(s.chargeKg)} kilos, '}${s.reps} répétitions.',
          ),
        ),
      );
      unawaited(
        WorkoutKeepAlive.update(title: 'À toi', text: s == null ? 'Repos terminé' : '${s.nom} · série ${s.numero}'),
      );
    } else if (repos != avant) {
      unawaited(WorkoutKeepAlive.update(title: 'Repos', text: _texteRepos));
    }
    if (repos != avant) notifyListeners();
  }

  void passerRepos() {
    _minuteur?.cancel();
    _finRepos = null;
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
    unawaited(WorkoutKeepAlive.stop());
    unawaited(sansEchec(_tts.stop));
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
    final p = context.palette;
    final s = vm.courante;
    final exercise = s == null ? null : vm.exercices[s.exerciceId];
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        title: const Text('Séance en cours', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
      ),
      bottomNavigationBar: s == null || vm.erreur != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(CrescoSpacing.margin, 8, CrescoSpacing.margin, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton(
                      onPressed: () async {
                        final e = await showExercisePicker(context);
                        if (e != null) vm.addExercise(e);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: p.effort,
                        side: BorderSide(color: p.effort, width: CrescoShape.border),
                      ),
                      child: const Text('Ajouter un exercice'),
                    ),
                    const SizedBox(height: 10),
                    FilledButton(
                      style: effortButtonStyle(context),
                      onPressed: vm.rirChoisi == null ? null : vm.validerSerie,
                      child: Text(vm.index + 1 >= vm.series.length ? 'Valider la dernière série' : 'Valider la série'),
                    ),
                  ],
                ),
              ),
            ),
      body: vm.isBusy || !vm.charge
          ? const Chargement()
          : vm.erreur != null
          ? Padding(padding: const EdgeInsets.all(18), child: MessageErreur(vm.erreur!))
          : ListView(
              padding: const EdgeInsets.fromLTRB(CrescoSpacing.margin, 0, CrescoSpacing.margin, 20),
              children: [
                if (s != null) ...[
                  Text(s.nom, style: CrescoTextes.titrePage.copyWith(fontSize: 36)),
                  if (materialLabel(exercise?['materiel'] as String?) case final m?)
                    Text(m, style: TextStyle(color: p.onHeroMuted, fontSize: 18)),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: CrescoShape.borderRadius,
                    child: ExerciseDemo(s.exerciceId, height: 180, semanticLabel: 'Démonstration : ${s.nom}'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _EffortOutline(
                          label: 'Consignes',
                          onTap: () => _instructions(context, s.nom, (exercise?['consignes'] as String?) ?? ''),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _EffortOutline(label: 'Ma vidéo', onTap: () => vm.ouvrirVideo(context)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _SetBlock(vm: vm, s: s),
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
              ],
            ),
    );
  }

  Future<void> _instructions(BuildContext context, String name, String text) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: CrescoTextes.titreCarte),
            const SizedBox(height: 10),
            Text(text.isEmpty ? 'Pas encore de consignes pour cet exercice.' : text, style: CrescoTextes.corps),
          ],
        ),
      ),
    ),
  );
}

/// French label of the catalog's equipment, shown under the exercise name.
String? materialLabel(String? material) => switch (material) {
  'machine' => 'Machine',
  'barre' => 'Barre',
  'halteres' => 'Haltères',
  'poids_du_corps' => 'Poids du corps',
  'tapis' => 'Tapis de course',
  'velo' => 'Vélo',
  'rameur' => 'Rameur',
  _ => null,
};

/// Braise outlined button of the session screen.
class _EffortOutline extends StatelessWidget {
  const new({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: p.effort,
        side: BorderSide(color: p.effort, width: CrescoShape.border),
      ),
      child: Text(label),
    );
  }
}

/// The set to do, flat as in the mockup: progress, load × reps in braise, target RIR, real RIR,
/// rest timer and the next set.
class _SetBlock extends StatelessWidget {
  const new({required this.vm, required this.s});
  final SeanceViewModel vm;
  final SerieAFaire s;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final next = vm.index + 1 < vm.series.length ? vm.series[vm.index + 1] : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Série ${s.numero} sur ${s.total}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
            for (var i = 1; i <= s.total; i++)
              Container(
                margin: const EdgeInsets.only(left: 6),
                width: 24,
                height: 5,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(2)),
                  color: i <= s.numero ? p.effort : p.line,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        // One composed text: wraps with large text, figures on the same baseline.
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: s.chargeKg == null ? '—' : '${decimal(s.chargeKg)} kg'),
              const TextSpan(text: ' × '),
              TextSpan(text: '${s.reps}'),
            ],
          ),
          style: CrescoTextes.chiffre.copyWith(fontSize: 64, color: p.effort),
        ),
        Row(
          children: [
            Text('RIR visé ${decimal(s.rirCible)}', style: const TextStyle(fontSize: 17)),
            const Spacer(),
            if (vm.e1rmCourant != null) Text('e1RM ${decimal(vm.e1rmCourant)} kg  ', style: context.mutedStyle),
            IconButton(
              tooltip: 'Moins 2,5 kg',
              onPressed: () => vm.changerCharge(-2.5),
              icon: const Icon(Icons.remove),
            ),
            IconButton(tooltip: 'Plus 2,5 kg', onPressed: () => vm.changerCharge(2.5), icon: const Icon(Icons.add)),
          ],
        ),
        const SizedBox(height: 4),
        const Text('RIR réel', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        Text('Combien de répétitions restaient possibles ?', style: context.mutedStyle),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final r in [0, 1, 2, 3, 4]) ...[
              if (r > 0) const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  showCheckmark: false,
                  label: SizedBox(
                    width: double.infinity,
                    child: Text(r == 4 ? '4+' : '$r', textAlign: TextAlign.center),
                  ),
                  labelStyle: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: vm.rirChoisi == r ? p.onEffort : p.ink,
                  ),
                  side: BorderSide(color: vm.rirChoisi == r ? p.effort : p.ink, width: CrescoShape.border),
                  selectedColor: p.effort,
                  backgroundColor: p.background,
                  selected: vm.rirChoisi == r,
                  onSelected: (_) => vm.choisirRir(r),
                ),
              ),
            ],
          ],
        ),
        if (vm.repos > 0) ...[
          const SizedBox(height: 14),
          CrescoCarte(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.timer_outlined, color: p.ink),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Repos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ),
                Text(
                  '${vm.repos ~/ 60}:${(vm.repos % 60).toString().padLeft(2, '0')}',
                  style: CrescoTextes.chiffre.copyWith(color: p.rest, fontSize: 48),
                ),
                IconButton(tooltip: 'Passer le repos', onPressed: vm.passerRepos, icon: const Icon(Icons.skip_next)),
              ],
            ),
          ),
        ],
        if (next != null) ...[
          const SizedBox(height: 14),
          Text(
            next.exerciceId == s.exerciceId && next.chargeKg != null
                ? 'Série suivante : ${decimal(next.chargeKg)} kg'
                : 'Ensuite : ${next.nom}${next.chargeKg == null ? '' : ' · ${decimal(next.chargeKg)} kg'} × ${next.reps}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}
