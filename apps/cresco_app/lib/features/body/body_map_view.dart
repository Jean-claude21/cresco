import 'package:cresco_app/app/app.locator.dart';
import 'package:cresco_app/app/app.router.dart';
import 'package:cresco_app/ui/commun.dart';
import 'package:cresco_data/cresco_data.dart' hide Json;
import 'package:cresco_ui/cresco_ui.dart';
import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

/// French names of the exercise catalog's muscle slugs, in body order.
const muscleNames = {
  'pectoraux': 'Pectoraux',
  'epaules': 'Épaules',
  'biceps': 'Biceps',
  'triceps': 'Triceps',
  'avant_bras': 'Avant-bras',
  'dos': 'Dos',
  'abdominaux': 'Abdominaux',
  'lombaires': 'Lombaires',
  'fessiers': 'Fessiers',
  'quadriceps': 'Quadriceps',
  'ischios': 'Ischio-jambiers',
  'mollets': 'Mollets',
};

/// Volume color scale of the body map, amber to braise: share of the weekly guideline reached.
/// Level 0 is replaced by [nothingColor], which depends on the theme.
const volumeScale = [
  (Color(0xFFD5D5D5), 'Rien cette semaine'),
  (Color(0xFFFFE0B3), 'Moins de la moitié'),
  (Color(0xFFFFB020), 'Plus de la moitié'),
  (Color(0xFFFF7A2A), 'Presque atteint'),
  (Color(0xFFE8341C), 'Repère atteint'),
];

/// "Nothing this week": neutral grey, dimmer in dark mode, so untrained muscles never stand out.
Color nothingColor(CrescoPalette p) =>
    p.background.computeLuminance() < 0.2 ? const Color(0xFF3A3A3A) : volumeScale[0].$1;

/// Fill of [level] in the current theme.
Color volumeColor(int level, CrescoPalette p) => level == 0 ? nothingColor(p) : volumeScale[level].$1;

/// Bucket of [effectiveSets] against [guideline] in [volumeScale] (display only: the sets
/// themselves come from the engine, rule C-PERF-5).
int volumeLevel(double effectiveSets, num guideline) {
  if (effectiveSets <= 0) return 0;
  final ratio = guideline > 0 ? effectiveSets / guideline : 1;
  if (ratio < 0.5) return 1;
  if (ratio < 0.8) return 2;
  if (ratio < 1) return 3;
  return 4;
}

class BodyMapViewModel extends FutureViewModel<Json> {
  final CrescoApi _api = locator<CrescoApi>();

  final NavigationService _nav = locator<NavigationService>();
  BodySide side = BodySide.front;
  String selected = 'pectoraux';

  /// Exercise catalog limited to the user's gym, to list what works each muscle.
  List<Json> catalog = [];

  @override
  Future<Json> futureToRun() async {
    final volume = await _api.muscleVolume();
    try {
      catalog = await _api.exercises(gymOnly: true);
    } on Exception {
      // The muscle card simply lists no exercise.
    }
    return volume;
  }

  /// Exercises whose primary muscles include [muscle], then those where it is secondary.
  List<Json> exercisesFor(String muscle) {
    bool has(Json e, String key) => ((e[key] as List<Object?>?) ?? const []).contains(muscle);
    return [
      ...catalog.where((e) => has(e, 'muscles_primaires')),
      ...catalog.where((e) => has(e, 'muscles_secondaires')),
    ];
  }

  /// Opens the session editor with [exercises] already added.
  Future<void> addSets(List<Json> exercises) =>
      _nav.navigateTo<void>(
        Routes.templateEditorView,
        arguments: TemplateEditorViewArguments(initialExercises: exercises),
      ) ??
      Future.value();

  num get guideline => (data?['guideline'] as num?) ?? 10;

  Map<String, double> get sets => {
    for (final m in (data?['muscles'] as List<Object?>? ?? const []).cast<Json>())
      m['muscle']! as String: nombre(m['effectiveSets']),
  };

  void showSide(BodySide s) {
    side = s;
    if (!BodyMuscles.of(s).contains(selected)) selected = BodyMuscles.of(s).first;
    notifyListeners();
  }

  /// Selects [muscle] and turns the body around when it is only visible on the other side.
  void select(String muscle) {
    selected = muscle;
    if (!BodyMuscles.of(side).contains(muscle)) {
      side = side == BodySide.front ? BodySide.back : BodySide.front;
    }
    notifyListeners();
  }
}

/// "Mon corps" (mockup G): the full body, each muscle lit by this week's effective sets;
/// touch a muscle on the body or in the list for its details.
class BodyMapView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<BodyMapViewModel>.reactive(
      viewModelBuilder: BodyMapViewModel.new,
      builder: (context, vm, _) {
        final p = context.palette;
        final sets = vm.sets;
        final colors = {for (final m in muscleNames.keys) m: volumeColor(volumeLevel(sets[m] ?? 0, vm.guideline), p)};
        return Scaffold(
          appBar: AppBar(),
          body: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(CrescoSpacing.margin, 4, CrescoSpacing.margin, 32),
              children: [
                const Text('Mon corps', style: CrescoTextes.titrePage),
                const Text('Séries efficaces de la semaine', style: TextStyle(fontSize: 17)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<BodySide>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: BodySide.front, label: Text('Face')),
                      ButtonSegment(value: BodySide.back, label: Text('Dos')),
                    ],
                    selected: {vm.side},
                    onSelectionChanged: (s) => vm.showSide(s.first),
                  ),
                ),
                const SizedBox(height: 16),
                if (vm.isBusy && vm.data == null) const LoadingState(heights: [360, 120]),
                if (vm.hasError && vm.data == null)
                  ErrorState(message: 'Tes muscles n’ont pas pu se charger.', onRetry: vm.initialise),
                if (vm.data != null) ...[
                  FadeSlideIn(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 9,
                          child: AnimatedSwitcher(
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 350),
                            transitionBuilder: (child, a) => FadeTransition(opacity: a, child: child),
                            child: BodyMap(
                              key: ValueKey(vm.side),
                              side: vm.side,
                              colors: colors,
                              selected: vm.selected,
                              onSelect: vm.select,
                              semanticLabel:
                                  'Corps ${vm.side == BodySide.front ? 'de face' : 'de dos'}. '
                                  'Choisis un muscle dans la liste à côté.',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 11,
                          child: Column(
                            children: [
                              for (final m in BodyMuscles.of(vm.side))
                                _MuscleRow(
                                  key: ValueKey('muscle-$m'),
                                  name: muscleNames[m]!,
                                  sets: sets[m] ?? 0,
                                  color: colors[m]!,
                                  selected: m == vm.selected,
                                  onTap: () => vm.select(m),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Legend(palette: p),
                  const SizedBox(height: 16),
                  FadeSlideIn(
                    index: 1,
                    child: _Detail(
                      muscle: vm.selected,
                      sets: sets[vm.selected] ?? 0,
                      guideline: vm.guideline,
                      exercises: vm.exercisesFor(vm.selected).take(3).toList(),
                      onAdd: vm.addSets,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MuscleRow extends StatelessWidget {
  const new({
    required this.name,
    required this.sets,
    required this.color,
    required this.selected,
    required this.onTap,
    super.key,
  });
  final String name;
  final double sets;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Semantics(
        selected: selected,
        button: true,
        label: '$name, ${decimal(sets)} séries efficaces',
        excludeSemantics: true,
        child: Material(
          color: selected ? p.effortSoft : p.surface,
          shape: CrescoShape.rectangle(selected ? p.ink : p.line),
          child: InkWell(
            customBorder: CrescoShape.rectangle(),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(color: color, borderRadius: CrescoShape.borderRadius),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                    Text(decimal(sets), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const new({required this.palette});
  final CrescoPalette palette;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final (level, (_, label)) in volumeScale.indexed)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: volumeColor(level, palette), borderRadius: CrescoShape.borderRadius),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(color: palette.muted, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
      ],
    );
  }
}

class _Detail extends StatelessWidget {
  const new({
    required this.muscle,
    required this.sets,
    required this.guideline,
    required this.exercises,
    required this.onAdd,
  });
  final String muscle;
  final double sets;
  final num guideline;
  final List<Json> exercises;
  final Future<void> Function(List<Json> exercises) onAdd;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final left = guideline - sets;
    final status = sets == 0
        ? 'aucune série efficace cette semaine'
        : left <= 0
        ? 'repère hebdomadaire atteint'
        : 'encore ${decimal(left)} série${left >= 2 ? 's' : ''} pour le repère';
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: CrescoShape.outlined(p),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(muscleNames[muscle] ?? muscle, style: CrescoTextes.titreCarte.copyWith(fontSize: 26)),
              const SizedBox(height: 2),
              Text(
                '${decimal(sets)} / ${decimal(guideline)} séries efficaces · $status',
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 12),
              if (exercises.isNotEmpty) ...[
                const Text('Exercices', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                const SizedBox(height: 6),
                for (final e in exercises)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Material(
                      color: p.background,
                      shape: CrescoShape.rectangle(p.line),
                      child: InkWell(
                        customBorder: CrescoShape.rectangle(),
                        onTap: () => onAdd([e]),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              Icon(Icons.fitness_center, size: 20, color: p.ink),
                              const SizedBox(width: 12),
                              Expanded(child: Text(e['nom']! as String, style: const TextStyle(fontSize: 16))),
                              Icon(Icons.chevron_right, color: p.ink),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
              FilledButton(
                onPressed: exercises.isEmpty ? null : () => onAdd([exercises.first]),
                child: const Text('Ajouter des séries'),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => _explain(context, guideline),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  child: const Text('Comment c’est calculé', style: TextStyle(decoration: TextDecoration.underline)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _explain(BuildContext context, num guideline) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Text(
          'Séries à 3 répétitions en réserve ou moins, sur 7 jours. Muscle principal de l’exercice : 1 série ; '
          'secondaire : 0,5. Repère : ${decimal(guideline)} séries par semaine (règle C-PERF-5).',
          style: CrescoTextes.corps,
        ),
      ),
    ),
  );
}
