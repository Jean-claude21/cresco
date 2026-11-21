import 'package:cresco_app/app/app.locator.dart';
import 'package:cresco_app/ui/commun.dart';
import 'package:cresco_data/cresco_data.dart' hide Json;
import 'package:cresco_ui/cresco_ui.dart';
import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

class ProgresViewModel extends FutureViewModel<Json> {
  final CrescoApi _api = locator<CrescoApi>();
  int exercice = 0;

  @override
  Future<Json> futureToRun() => _api.progression();

  void choisir(int i) {
    exercice = i;
    notifyListeners();
  }
}

const libellesVerdict = {
  'progression': 'Tu progresses',
  'maintien_reussite': 'Maintien = réussite',
  'stagnation': 'Stagnation',
  'patience': 'Patience',
  'donnees_insuffisantes': 'Encore un peu de données',
};

/// Progrès (mockup G 08-progres): week verdict, strength curve, record, energy, weight.
class ProgresView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<ProgresViewModel>.reactive(
      viewModelBuilder: ProgresViewModel.new,
      builder: (context, vm, _) {
        final d = vm.data;
        final exercices = (d?['exercices'] as List?)?.cast<Json>() ?? const [];
        final energie = d?['energie'] as Json?;
        final record = d?['record'] as Json?;
        return PageCresco(
          titre: 'Progrès',
          onRefresh: vm.initialise,
          enfants: [
            if (vm.isBusy && d == null) const Chargement(),
            if (vm.hasError) MessageErreur(vm.modelError.toString(), reessayer: vm.initialise),
            if (d != null) ...[
              _VerdictCard(
                verdict: d['verdict'] as String?,
                sessions: (d['seancesSemaine'] as num?)?.toInt(),
                sleepMin: d['sommeilMoyenMin'],
              ),
              if (exercices.isNotEmpty)
                _StrengthCard(
                  exercises: exercices,
                  index: vm.exercice.clamp(0, exercices.length - 1),
                  onPick: vm.choisir,
                )
              else
                CrescoCarte(
                  child: Text(
                    'Enregistre quelques séances de musculation pour voir ta courbe de force.',
                    style: context.mutedStyle,
                  ),
                ),
              if (record != null)
                _InfoRow(
                  icon: Icons.emoji_events_outlined,
                  title: 'Record',
                  detail: '${decimal(record['chargeKg'])} kg × ${record['reps']} au ${(record['nom']! as String).toLowerCase()}',
                ),
              if (energie != null)
                _InfoRow(
                  icon: Icons.bolt_outlined,
                  title: 'Bilan énergie',
                  detail:
                      '${switch (energie['verdict']) {
                        'surplus' => 'surplus',
                        'deficit' => 'déficit',
                        _ => 'équilibre',
                      }} estimé ${signe(nombre(energie['moyen7j']).round())} kcal/j, confiance ${energie['confiance']}',
                ),
              _InfoRow(icon: Icons.monitor_weight_outlined, title: 'Poids lissé', value: '${decimal(d['poidsLisse'])} kg'),
              OutlinedButton(
                onPressed: () => _explain(context, d['explication'] as String? ?? ''),
                child: const Text('Comment c’est calculé'),
              ),
            ],
          ],
        );
      },
    );
  }
}

Future<void> _explain(BuildContext context, String explanation) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Comment c’est calculé', style: CrescoTextes.titreCarte),
          const SizedBox(height: 12),
          if (explanation.isNotEmpty) ...[
            Text(explanation, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
          ],
          const Text(
            'Force estimée : e1RM de tes meilleures séries (règle C-PERF-2), tendance sur 28 jours (C-PROG-1). '
            'Verdict de la semaine : progression comparée au rythme attendu pour ton niveau, en tenant compte '
            'du sommeil, de l’énergie et des jeûnes (C-VERDICT). Record : ta meilleure série des 8 dernières semaines.',
            style: CrescoTextes.corps,
          ),
          const SizedBox(height: 10),
          Text('Toutes les formules sont dans le moteur ; ton IA peut les lire par le MCP.', style: context.mutedStyle),
        ],
      ),
    ),
  ),
);

/// Week verdict: big title (braise arrow when you progress), sessions this week, average sleep.
class _VerdictCard extends StatelessWidget {
  const new({required this.verdict, required this.sessions, required this.sleepMin});
  final String? verdict;
  final int? sessions;
  final Object? sleepMin;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget line(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 24, color: p.ink),
          const SizedBox(width: 14),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 17))),
        ],
      ),
    );
    final count = sessions;
    final sleep = sleepMin;
    return CrescoCarte(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Verdict de la semaine', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          Row(
            children: [
              Flexible(child: Text(libellesVerdict[verdict] ?? '', style: CrescoTextes.titrePage.copyWith(fontSize: 32))),
              if (verdict == 'progression') ...[
                const SizedBox(width: 10),
                Icon(Icons.north_east, color: p.effort, size: 34),
              ],
            ],
          ),
          if (count != null) line(Icons.calendar_today_outlined, '$count séance${count > 1 ? 's' : ''} cette semaine'),
          if (sleep is num) line(Icons.bed_outlined, 'Sommeil moyen ${duree(sleep)}'),
        ],
      ),
    );
  }
}

/// Strength of one exercise: weekly trend in braise and the e1RM curve over 8 weeks.
class _StrengthCard extends StatelessWidget {
  const new({required this.exercises, required this.index, required this.onPick});
  final List<Json> exercises;
  final int index;
  final ValueChanged<int> onPick;

  Future<void> _pick(BuildContext context) async {
    final pick = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, e) in exercises.indexed)
              ListTile(title: Text(e['nom']! as String), onTap: () => Navigator.pop(context, i)),
          ],
        ),
      ),
    );
    if (pick != null) onPick(pick);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final ex = exercises[index];
    final pct = nombre(ex['pctParSemaine']);
    final points = [for (final x in (ex['points']! as List).cast<Json>()) nombre(x['e1rm'])];
    return CrescoCarte(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: exercises.length < 2 ? null : () => _pick(context),
            child: Row(
              children: [
                Flexible(child: Text(ex['nom']! as String, style: CrescoTextes.titreCarte.copyWith(fontSize: 24))),
                if (exercises.length > 1) const Icon(Icons.expand_more),
              ],
            ),
          ),
          const Text('e1RM · 8 semaines', style: TextStyle(fontSize: 17)),
          Text(
            '${pct >= 0 ? '+' : ''}${decimal(pct, chiffres: pct.abs() >= 1 ? 1 : 2)} % / semaine',
            style: TextStyle(color: pct >= 0 ? p.effort : p.muted, fontWeight: FontWeight.w900, fontSize: 26),
          ),
          const SizedBox(height: 12),
          ProgressChart(values: points, unit: 'kg', color: p.effort),
        ],
      ),
    );
  }
}

/// "Icon | title and detail (or big value)" row of the week summary.
class _InfoRow extends StatelessWidget {
  const new({required this.icon, required this.title, this.detail, this.value});
  final IconData icon;
  final String title;
  final String? detail;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return CrescoCarte(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: IntrinsicHeight(
        child: Row(
          children: [
            SizedBox(width: 44, child: Icon(icon, size: 34, color: p.ink)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: VerticalDivider(width: CrescoShape.border, thickness: CrescoShape.border, color: p.line),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                  if (detail != null) Text(detail!, style: const TextStyle(fontSize: 16)),
                  if (value != null) Text(value!, style: CrescoTextes.chiffre.copyWith(fontSize: 40)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
