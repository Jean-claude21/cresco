import 'package:cresco_app/app/app.locator.dart';
import 'package:cresco_app/features/exercises/exercise_picker.dart';
import 'package:cresco_app/ui/commun.dart';
import 'package:cresco_app/ui/messages.dart';
import 'package:cresco_data/cresco_data.dart' hide Json;
import 'package:cresco_ui/cresco_ui.dart';
import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

/// One strength exercise of a template, as edited on screen.
class TemplateItem {
  new({
    required this.exerciseId,
    required this.name,
    this.sets = 3,
    this.reps = 10,
    this.loadKg,
    this.rir = 2,
    this.restS = 90,
  });

  final String exerciseId;
  final String name;
  int sets;
  int reps;

  /// Null: the engine computes the load from history (`charge_kg: "auto"`).
  double? loadKg;
  int rir;
  int restS;

  Json toBlock() => {
    'repeter': sets,
    'etapes': [
      {
        'exercice_id': exerciseId,
        'duree': {'reps': reps},
        'cible': {'rir': rir, 'charge_kg': loadKg ?? 'auto'},
        'repos_s': restS,
      },
    ],
  };
}

class TemplateEditorViewModel extends BaseViewModel {
  new({this.template});

  /// Template being edited; null creates a new one.
  final Json? template;
  final CrescoApi _api = locator<CrescoApi>();
  final NavigationService _nav = locator<NavigationService>();
  final Messages _messages = locator<Messages>();

  final name = TextEditingController();
  final items = <TemplateItem>[];

  /// Blocks the editor does not handle (cardio, supersets): kept as they are.
  final _untouched = <Json>[];
  bool get hasUntouched => _untouched.isNotEmpty;

  String? get templateId => template?['id'] as String?;

  Future<void> load() async {
    final t = template;
    if (t == null) return;
    name.text = t['nom'] as String? ?? '';
    final blocks = ((t['contenu'] as Json?)?['blocs'] as List<Object?>? ?? const []).cast<Json>();
    setBusy(true);
    var names = <String, String>{};
    try {
      names = {for (final e in await _api.exercises()) e['id']! as String: e['nom']! as String};
    } on Exception {
      // Offline: ids are shown instead of names.
    }
    for (final b in blocks) {
      final steps = (b['etapes']! as List<Object?>).cast<Json>();
      final s = steps.length == 1 ? steps.first : null;
      final reps = (s?['duree'] as Json?)?['reps'];
      final id = s?['exercice_id'] as String?;
      if (s == null || id == null || reps is! num) {
        _untouched.add(b);
        continue;
      }
      final target = s['cible'] as Json? ?? const {};
      items.add(
        TemplateItem(
          exerciseId: id,
          name: names[id] ?? id,
          sets: (b['repeter']! as num).toInt(),
          reps: reps.toInt(),
          loadKg: target['charge_kg'] is num ? (target['charge_kg']! as num).toDouble() : null,
          rir: nombre(target['rir'], 2).toInt(),
          restS: nombre(s['repos_s'], 90).toInt(),
        ),
      );
    }
    setBusy(false);
  }

  void add(Json exercise) {
    items.add(TemplateItem(exerciseId: exercise['id']! as String, name: exercise['nom']! as String));
    notifyListeners();
  }

  void remove(TemplateItem item) {
    items.remove(item);
    notifyListeners();
  }

  void reorder(int from, int to) {
    final item = items.removeAt(from);
    items.insert(to, item);
    notifyListeners();
  }

  void update() => notifyListeners();

  bool get canSave => name.text.trim().isNotEmpty && (items.isNotEmpty || hasUntouched) && !isBusy;

  Future<void> save() async {
    if (!canSave) return;
    setBusy(true);
    try {
      final saved = await _api.saveTemplate({
        'nom': name.text.trim(),
        'type': 'muscu',
        'blocs': [for (final i in items) i.toBlock(), ..._untouched],
      }, id: templateId);
      final missing = (saved['unavailableAtGym'] as List<Object?>? ?? const []).length;
      _nav.back<bool>(result: true);
      _messages.afficher(
        message: missing == 0
            ? 'Séance enregistrée.'
            : 'Séance enregistrée. $missing exercice${missing > 1 ? 's ne sont' : ' n’est'} pas dans ta salle.',
      );
    } on ErreurApi catch (e) {
      _messages.afficher(message: e.message);
    } finally {
      setBusy(false);
    }
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }
}

/// Creates or edits one of "Mes séances": exercises from the library, sets, reps, load, rest.
class TemplateEditorView extends StatelessWidget {
  const new({super.key, this.template});
  final Json? template;

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<TemplateEditorViewModel>.reactive(
      viewModelBuilder: () => TemplateEditorViewModel(template: template),
      onViewModelReady: (vm) => vm.load(),
      builder: (context, vm, _) {
        final p = context.palette;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              vm.templateId == null ? 'Nouvelle séance' : 'Modifier la séance',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: FilledButton(onPressed: vm.canSave ? vm.save : null, child: const Text('Enregistrer la séance')),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              TextField(
                key: const ValueKey('template-name'),
                controller: vm.name,
                onChanged: (_) => vm.update(),
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nom de la séance', hintText: 'Haut du corps, Jambes…'),
              ),
              const SizedBox(height: 16),
              if (vm.items.isEmpty && !vm.isBusy)
                const EmptyState(
                  icon: Icons.fitness_center,
                  title: 'Ajoute tes exercices',
                  message: 'Choisis-les dans la bibliothèque : par défaut, seulement ce qu’il y a dans ta salle.',
                ),
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorderItem: vm.reorder,
                children: [
                  for (final (i, item) in vm.items.indexed)
                    Padding(
                      key: ObjectKey(item),
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ItemCard(item: item, index: i, onChanged: vm.update, onRemove: () => vm.remove(item)),
                    ),
                ],
              ),
              if (vm.hasUntouched)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Les blocs cardio ou enchaînés de cette séance sont gardés tels quels.',
                    style: context.mutedStyle,
                  ),
                ),
              OutlinedButton.icon(
                key: const ValueKey('template-add'),
                onPressed: () async {
                  final e = await showExercisePicker(context);
                  if (e != null) vm.add(e);
                },
                icon: Icon(Icons.add, color: p.ink),
                label: const Text('Ajouter un exercice'),
              ),
              const SizedBox(height: 12),
              Text(
                'Charge « auto » : le moteur la calcule à partir de tes dernières séries (règle C-PERF-3). '
                'Les séances hors bornes de sécurité sont refusées.',
                style: context.mutedStyle.copyWith(fontSize: 13),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ItemCard extends StatelessWidget {
  const new({required this.item, required this.index, required this.onChanged, required this.onRemove});
  final TemplateItem item;
  final int index;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(Icons.drag_indicator, color: p.muted, semanticLabel: 'Déplacer'),
                  ),
                ),
                Expanded(child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                IconButton(tooltip: 'Retirer ${item.name}', onPressed: onRemove, icon: const Icon(Icons.close)),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Stepper(
                  label: 'Séries',
                  value: '${item.sets}',
                  onMinus: item.sets > 1 ? () => _set(() => item.sets--) : null,
                  onPlus: item.sets < 10 ? () => _set(() => item.sets++) : null,
                ),
                _Stepper(
                  label: 'Reps',
                  value: '${item.reps}',
                  onMinus: item.reps > 1 ? () => _set(() => item.reps--) : null,
                  onPlus: item.reps < 30 ? () => _set(() => item.reps++) : null,
                ),
                _Stepper(
                  label: 'Charge',
                  value: item.loadKg == null ? 'auto' : '${decimal(item.loadKg)} kg',
                  onMinus: item.loadKg == null
                      ? null
                      : () => _set(() => item.loadKg = item.loadKg! <= 2.5 ? null : item.loadKg! - 2.5),
                  onPlus: () => _set(() => item.loadKg = (item.loadKg ?? 0) + 2.5),
                ),
                _Stepper(
                  label: 'RIR',
                  value: '${item.rir}',
                  onMinus: item.rir > 0 ? () => _set(() => item.rir--) : null,
                  onPlus: item.rir < 5 ? () => _set(() => item.rir++) : null,
                ),
                _Stepper(
                  label: 'Repos',
                  value: dureeCourte(item.restS),
                  onMinus: item.restS > 30 ? () => _set(() => item.restS -= 15) : null,
                  onPlus: item.restS < 300 ? () => _set(() => item.restS += 15) : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _set(VoidCallback change) {
    change();
    onChanged();
  }
}

class _Stepper extends StatelessWidget {
  const new({required this.label, required this.value, required this.onMinus, required this.onPlus});
  final String label;
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(color: p.background, borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: '$label : moins',
              visualDensity: VisualDensity.compact,
              onPressed: onMinus,
              icon: const Icon(Icons.remove, size: 18),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: context.mutedStyle.copyWith(fontSize: 11)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ],
            ),
            IconButton(
              tooltip: '$label : plus',
              visualDensity: VisualDensity.compact,
              onPressed: onPlus,
              icon: const Icon(Icons.add, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
