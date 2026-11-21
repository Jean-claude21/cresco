import 'dart:async';

import 'package:cresco_app/app/app.locator.dart';
import 'package:cresco_app/features/body/body_map_view.dart';
import 'package:cresco_app/ui/commun.dart';
import 'package:cresco_data/cresco_data.dart' hide Json;
import 'package:cresco_ui/cresco_ui.dart';
import 'package:flutter/material.dart';

/// Opens the exercise library as a bottom sheet and returns the chosen exercise (or null).
/// By default it only lists what the user's gym allows ("Ma salle").
Future<Json?> showExercisePicker(BuildContext context, {String title = 'Ajouter un exercice'}) {
  return showModalBottomSheet<Json>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => FractionallySizedBox(heightFactor: 0.88, child: _Picker(title: title)),
  );
}

class _Picker extends StatefulWidget {
  const new({required this.title});
  final String title;

  @override
  State<_Picker> createState() => _PickerState();
}

class _PickerState extends State<_Picker> {
  final CrescoApi _api = locator<CrescoApi>();
  final _query = TextEditingController();
  bool _gymOnly = true;
  String? _muscle;
  List<Json>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _items = null;
      _error = null;
    });
    try {
      final items = await _api.exercises(gymOnly: _gymOnly);
      if (mounted) setState(() => _items = items);
    } on Exception {
      if (mounted) setState(() => _error = 'La bibliothèque n’a pas pu se charger.');
    }
  }

  List<String> _muscles(Json e) => [
    ...(e['muscles_primaires'] as List<Object?>? ?? const []).cast<String>(),
    ...(e['muscles_secondaires'] as List<Object?>? ?? const []).cast<String>(),
  ];

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final q = _query.text.trim().toLowerCase();
    final shown = (_items ?? const <Json>[])
        .where((e) => !(e['muscles_primaires'] as List<Object?>? ?? const []).contains('cardio'))
        .where((e) => q.isEmpty || (e['nom']! as String).toLowerCase().contains(q))
        .where((e) => _muscle == null || _muscles(e).contains(_muscle))
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(widget.title, style: CrescoTextes.titreCarte),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _query,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Chercher un exercice'),
            ),
          ),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            title: const Text('Seulement ma salle', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('Machines et matériel cochés dans « Ma salle »', style: context.mutedStyle.copyWith(fontSize: 13)),
            value: _gymOnly,
            onChanged: (v) {
              setState(() => _gymOnly = v);
              unawaited(_load());
            },
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                for (final m in [null, ...muscleNames.keys])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      showCheckmark: false,
                      label: Text(m == null ? 'Tous' : muscleNames[m]!),
                      selected: _muscle == m,
                      onSelected: (_) => setState(() => _muscle = m),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _error != null
                ? Padding(padding: const EdgeInsets.all(20), child: ErrorState(message: _error!, onRetry: _load))
                : _items == null
                ? const Padding(padding: EdgeInsets.all(20), child: LoadingState(heights: [64, 64, 64]))
                : shown.isEmpty
                ? EmptyState(
                    icon: Icons.search_off,
                    title: 'Aucun exercice',
                    message: _gymOnly
                        ? 'Rien ne correspond dans ta salle. Coche plus de matériel dans « Ma salle », ou cherche dans tout le catalogue.'
                        : 'Rien ne correspond à ta recherche.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: shown.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final e = shown[i];
                      final primary = (e['muscles_primaires'] as List<Object?>? ?? const []).cast<String>();
                      return Material(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(18),
                        child: ListTile(
                          key: ValueKey('exercise-${e['id']}'),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          title: Text(e['nom']! as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(primary.map((m) => muscleNames[m] ?? m).join(' · '), style: context.mutedStyle),
                          trailing: Icon(Icons.add_circle, color: p.ink),
                          onTap: () => Navigator.pop(context, e),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
