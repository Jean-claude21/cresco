import 'package:cresco_app/app/app.locator.dart';
import 'package:cresco_app/ui/commun.dart';
import 'package:cresco_app/ui/messages.dart';
import 'package:cresco_data/cresco_data.dart' hide Json;
import 'package:cresco_ui/cresco_ui.dart';
import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

/// One piece of equipment the user can check.
typedef Equipment = ({String key, String label, String kind});

class GymViewModel extends BaseViewModel {
  final CrescoApi _api = locator<CrescoApi>();
  final Messages _messages = locator<Messages>();

  final name = TextEditingController();
  String? chain;
  Set<String> selected = {};
  List<Equipment> catalog = [];
  Map<String, List<String>> presets = {};
  String? loadError;

  /// True when the checked list comes from a chain preset and has not been saved yet.
  bool fromPreset = false;

  Future<void> load() async {
    setBusy(true);
    loadError = null;
    try {
      final g = await _api.gym();
      catalog = [
        for (final e in (g['catalog']! as List<Object?>).cast<Json>())
          (key: e['key']! as String, label: e['label']! as String, kind: e['kind']! as String),
      ];
      presets = {
        for (final MapEntry(:key, :value) in (g['presets']! as Json).entries) key: (value! as List<Object?>).cast<String>(),
      };
      final gym = g['gym'] as Json?;
      name.text = gym?['name'] as String? ?? '';
      chain = gym?['chain'] as String?;
      selected = {...(g['equipment']! as List<Object?>).cast<String>()};
    } on Exception {
      loadError = 'Ta salle n’a pas pu se charger.';
    }
    setBusy(false);
  }

  /// Picks a chain; on a first setup, its usual equipment is checked as a starting point.
  void pickChain(String? c) {
    chain = c;
    final preset = presets[c];
    if (preset != null && selected.isEmpty) {
      selected = {...preset};
      fromPreset = true;
    }
    if (name.text.trim().isEmpty && c != null) name.text = c;
    notifyListeners();
  }

  void toggle(String key) {
    selected.contains(key) ? selected.remove(key) : selected.add(key);
    notifyListeners();
  }

  List<Equipment> ofKind(String kind) => catalog.where((e) => e.kind == kind).toList();

  bool get canSave => name.text.trim().isNotEmpty && !isBusy;

  Future<bool> save() async {
    if (!canSave) return false;
    setBusy(true);
    try {
      await _api.saveGym(name: name.text.trim(), chain: chain, equipment: selected.toList()..sort());
      fromPreset = false;
      _messages.afficher(message: 'Ma salle est enregistrée. Tes séances n’utiliseront que ce matériel.');
      return true;
    } on Exception {
      _messages.afficher(message: 'Enregistrement impossible. Vérifie ta connexion et réessaie.');
      return false;
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

/// "Ma salle": the gym and the equipment really available there, remembered for the app and the AI.
class GymView extends StatelessWidget {
  const new({super.key});

  static const List<(String, String, IconData)> _kinds = [
    ('machine', 'Machines', Icons.precision_manufacturing_outlined),
    ('free', 'Poids libres', Icons.fitness_center),
    ('cardio', 'Cardio', Icons.directions_run),
  ];

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<GymViewModel>.reactive(
      viewModelBuilder: GymViewModel.new,
      onViewModelReady: (vm) => vm.load(),
      builder: (context, vm, _) {
        final p = context.palette;
        final loaded = vm.catalog.isNotEmpty;
        return Scaffold(
          appBar: AppBar(title: const Text('Ma salle', style: TextStyle(fontWeight: FontWeight.w900))),
          bottomNavigationBar: loaded
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: FilledButton(
                      onPressed: vm.canSave ? vm.save : null,
                      child: Text('Enregistrer · ${vm.selected.length} équipement${vm.selected.length > 1 ? 's' : ''}'),
                    ),
                  ),
                )
              : null,
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              if (vm.isBusy && !loaded) const LoadingState(heights: [120, 300]),
              if (vm.loadError != null && !loaded) ErrorState(message: vm.loadError!, onRetry: vm.load),
              if (loaded) ...[
                FadeSlideIn(
                  child: Text(
                    'Coche ce qu’il y a vraiment dans ta salle. Tes séances et ton IA n’utiliseront que ça.',
                    style: context.mutedStyle.copyWith(fontSize: 15),
                  ),
                ),
                const SizedBox(height: 16),
                FadeSlideIn(
                  index: 1,
                  child: TextField(
                    key: const ValueKey('gym-name'),
                    controller: vm.name,
                    onChanged: (_) => vm.notifyListeners(),
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Nom de ta salle', hintText: 'Basic-Fit Bastille'),
                  ),
                ),
                const SizedBox(height: 12),
                FadeSlideIn(
                  index: 2,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in [...vm.presets.keys, 'Autre'])
                        ChoiceChip(
                          showCheckmark: false,
                          label: Text(c),
                          selected: (vm.chain ?? 'Autre') == c && (vm.chain != null || c == 'Autre'),
                          onSelected: (_) => vm.pickChain(c == 'Autre' ? null : c),
                        ),
                    ],
                  ),
                ),
                if (vm.fromPreset) ...[
                  const SizedBox(height: 12),
                  DecoratedBox(
                    decoration: BoxDecoration(color: p.warningSoft, borderRadius: BorderRadius.circular(18)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        'Liste habituelle de ${vm.chain} : décoche ce qui manque dans ton club avant d’enregistrer.',
                        style: TextStyle(color: p.onWarningSoft, fontSize: 14, height: 1.4),
                      ),
                    ),
                  ),
                ],
                for (final (i, (kind, title, icon)) in _kinds.indexed)
                  if (vm.ofKind(kind).isNotEmpty)
                    FadeSlideIn(
                      index: 3 + i,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: _Group(
                          title: title,
                          icon: icon,
                          items: vm.ofKind(kind),
                          selected: vm.selected,
                          onToggle: vm.toggle,
                        ),
                      ),
                    ),
                const SizedBox(height: 12),
                Text('Le poids du corps (pompes, tractions, gainage) est toujours disponible.', style: context.mutedStyle),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Group extends StatelessWidget {
  const new({required this.title, required this.icon, required this.items, required this.selected, required this.onToggle});
  final String title;
  final IconData icon;
  final List<Equipment> items;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final count = items.where((e) => selected.contains(e.key)).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: p.ink),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
            Text('$count / ${items.length}', style: context.mutedStyle),
          ],
        ),
        const SizedBox(height: 8),
        Material(
          color: p.surface,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final e in items)
                CheckboxListTile(
                  key: ValueKey('gym-${e.key}'),
                  value: selected.contains(e.key),
                  onChanged: (_) => onToggle(e.key),
                  title: Text(e.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: p.action,
                  checkColor: p.onAction,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
