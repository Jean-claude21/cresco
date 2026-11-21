import 'package:cresco_app/app/app.locator.dart';
import 'package:cresco_app/ui/commun.dart';
import 'package:cresco_data/cresco_data.dart' hide Json;
import 'package:cresco_ui/cresco_ui.dart';
import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

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

/// Volume color scale of the body map: share of the weekly guideline reached.
/// Level 0 is replaced by [nothingColor], which depends on the theme.
const volumeScale = [
  (Color(0xFFD3D6CC), 'Rien cette semaine'),
  (Color(0xFFEEF7C9), 'Moins de la moitié'),
  (Color(0xFFDCEF95), 'Plus de la moitié'),
  (Color(0xFFCDEB5A), 'Presque atteint'),
  (Color(0xFF8DB52C), 'Repère atteint'),
];

/// "Nothing this week": darker than the body in light mode, dimmer than it in dark mode,
/// so untrained muscles never stand out more than trained ones.
Color nothingColor(CrescoPalette p) =>
    p.background.computeLuminance() < 0.2 ? const Color(0xFF3F443C) : volumeScale[0].$1;

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

  BodySide side = BodySide.front;
  String selected = 'pectoraux';

  @override
  Future<Json> futureToRun() => _api.muscleVolume();

  num get guideline => (data?['guideline'] as num?) ?? 10;

  Map<String, double> get sets => {
    for (final m in (data?['muscles'] as List<Object?>? ?? const []).cast<Json>())
      m['muscle']! as String: nombre(m['effectiveSets']),
  };

  void showSide(BodySide s) {
    side = s;
    notifyListeners();
  }

  /// Selects [muscle] and turns the body around when it is only visible on the other side.
  void select(String muscle) {
    selected = muscle;
    if (!BodyShapes.musclesOf(side).contains(muscle)) {
      side = side == BodySide.front ? BodySide.back : BodySide.front;
    }
    notifyListeners();
  }
}

/// "Mon corps": every muscle colored by this week's effective sets; touch one for details.
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
          appBar: AppBar(
            title: const Text('Mon corps', style: TextStyle(fontWeight: FontWeight.w900)),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SegmentedButton<BodySide>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  segments: const [
                    ButtonSegment(value: BodySide.front, label: Text('Face')),
                    ButtonSegment(value: BodySide.back, label: Text('Dos')),
                  ],
                  selected: {vm.side},
                  onSelectionChanged: (s) => vm.showSide(s.first),
                ),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                if (vm.isBusy && vm.data == null) const LoadingState(heights: [360, 120]),
                if (vm.hasError && vm.data == null)
                  ErrorState(message: 'Tes muscles n’ont pas pu se charger.', onRetry: vm.initialise),
                if (vm.data != null) ...[
                  FadeSlideIn(
                    child: Row(
                      children: [
                        Expanded(
                          flex: 11,
                          child: AnimatedSwitcher(
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 350),
                            transitionBuilder: (child, a) => FadeTransition(
                              opacity: a,
                              child: ScaleTransition(
                                scale: Tween<double>(begin: 0.94, end: 1).animate(a),
                                child: child,
                              ),
                            ),
                            child: BodyMap(
                              key: ValueKey(vm.side),
                              side: vm.side,
                              colors: colors,
                              selected: vm.selected,
                              onSelect: vm.select,
                              semanticLabel:
                                  'Silhouette ${vm.side == BodySide.front ? 'de face' : 'de dos'}. '
                                  'Choisis un muscle dans la liste en dessous.',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(flex: 9, child: _Legend(palette: p)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeSlideIn(
                    index: 1,
                    child: _Detail(muscle: vm.selected, sets: sets[vm.selected] ?? 0, guideline: vm.guideline),
                  ),
                  const SizedBox(height: 14),
                  FadeSlideIn(
                    index: 2,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final m in muscleNames.keys)
                          ChoiceChip(
                            key: ValueKey('muscle-$m'),
                            showCheckmark: false,
                            selected: m == vm.selected,
                            onSelected: (_) => vm.select(m),
                            avatar: CircleAvatar(radius: 6, backgroundColor: colors[m]),
                            label: Text(muscleNames[m]!),
                          ),
                      ],
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

class _Legend extends StatelessWidget {
  const new({required this.palette});
  final CrescoPalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Séries efficaces sur 7 jours',
          style: TextStyle(color: palette.muted, fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        for (final (level, (_, label)) in volumeScale.indexed.toList().reversed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(color: volumeColor(level, palette), borderRadius: BorderRadius.circular(5)),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(color: palette.ink, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Text(
          'Touche un muscle sur le corps ou dans la liste.',
          style: TextStyle(color: palette.muted, fontSize: 12, height: 1.4),
        ),
      ],
    );
  }
}

class _Detail extends StatelessWidget {
  const new({required this.muscle, required this.sets, required this.guideline});
  final String muscle;
  final double sets;
  final num guideline;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final reached = sets >= guideline;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: p.hero, borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(muscleNames[muscle] ?? muscle, style: CrescoTextes.titreCarte.copyWith(color: Colors.white)),
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: decimal(sets)),
                    TextSpan(
                      text: ' / ${decimal(guideline)} séries efficaces',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: p.onHeroMuted,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
                style: CrescoTextes.chiffre.copyWith(color: Colors.white, fontSize: 30),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(muscle),
                  tween: Tween(begin: 0, end: guideline > 0 ? (sets / guideline).clamp(0, 1).toDouble() : 0),
                  duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => LinearProgressIndicator(
                    value: v,
                    minHeight: 8,
                    color: p.lime,
                    backgroundColor: const Color(0xFF2A2D27),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                sets == 0
                    ? 'Aucune série efficace cette semaine pour ce muscle.'
                    : reached
                    ? 'Repère hebdomadaire atteint.'
                    : 'Encore ${decimal(guideline - sets)} série${guideline - sets > 1 ? 's' : ''} pour atteindre le repère.',
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Séries à 3 répétitions en réserve ou moins, sur 7 jours. Muscle principal de l’exercice : 1 série ; '
                'secondaire : 0,5. Repère : ${decimal(guideline)} séries par semaine (règle C-PERF-5).',
                style: TextStyle(color: p.onHeroMuted, fontSize: 12, height: 1.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
