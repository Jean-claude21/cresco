import 'dart:async';
import 'dart:convert';

import 'package:cresco_app/features/nutrition/nutrition_view.dart';
import 'package:cresco_app/ui/commun.dart';
import 'package:cresco_data/cresco_data.dart' hide Json;
import 'package:cresco_engine/cresco_engine.dart' as moteur;
import 'package:cresco_ui/cresco_ui.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// The two AI entries of Nutrition: describe the meal in words, or take a photo of the plate.
/// The AI proposes foods and grams; nothing is saved before the user confirms.
class IaRepasEntrees extends StatelessWidget {
  const new({required this.api, required this.onAdd, super.key});
  final CrescoApi api;

  /// Saves the confirmed foods as one meal: (food id, grams).
  final Future<void> Function(List<(String, double)> portions) onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            key: const ValueKey('ia-texte'),
            onPressed: () => _texte(context),
            icon: const Icon(Icons.edit_note),
            label: const FittedBox(child: Text('Décrire mon repas')),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            key: const ValueKey('ia-photo'),
            onPressed: () => _photo(context),
            icon: const Icon(Icons.photo_camera_outlined),
            label: const FittedBox(child: Text('Photo de l’assiette')),
          ),
        ),
      ],
    );
  }

  Future<void> _texte(BuildContext context) async {
    final c = TextEditingController();
    final texte = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Qu’as-tu mangé ?'),
        content: TextField(
          controller: c,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Un bol de riz, deux œufs au plat et une banane'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('Analyser')),
        ],
      ),
    );
    if (texte == null || texte.length < 2 || !context.mounted) return;
    await _propositions(context, api.repasDepuisTexte(texte));
  }

  Future<void> _photo(BuildContext context) async {
    final XFile? image;
    try {
      image = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1280, imageQuality: 80);
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Appareil photo indisponible.')));
      }
      return;
    }
    if (image == null || !context.mounted) return;
    final bytes = await image.readAsBytes();
    if (!context.mounted) return;
    final type = image.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
    await _propositions(context, api.repasDepuisPhoto(base64Encode(bytes), type));
  }

  Future<void> _propositions(BuildContext context, Future<Json> demande) async {
    final portions = await showModalBottomSheet<List<(String, double)>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _PropositionsSheet(demande: demande),
    );
    if (portions != null && portions.isNotEmpty) await onAdd(portions);
  }
}

class _PropositionsSheet extends StatefulWidget {
  const new({required this.demande});
  final Future<Json> demande;

  @override
  State<_PropositionsSheet> createState() => _PropositionsSheetState();
}

class _Ligne {
  new(this.libelle, this.aliment, this.grammes);
  final String libelle;
  final Json? aliment;
  double grammes;
  bool garde = true;
}

class _PropositionsSheetState extends State<_PropositionsSheet> {
  List<_Ligne>? lignes;
  String? remarque;
  String? erreur;

  @override
  void initState() {
    super.initState();
    unawaited(
      widget.demande.then(
        (r) {
          if (!mounted) return;
          setState(() {
            lignes = [
              for (final p in (r['propositions'] as List<Object?>? ?? const []).cast<Json>())
                _Ligne(p['libelle']! as String, p['aliment'] as Json?, nombre(p['grammes'])),
            ];
            remarque = r['remarque'] as String?;
          });
        },
        onError: (Object e) {
          if (mounted) setState(() => erreur = e is ErreurApi ? e.message : 'Analyse impossible.');
        },
      ),
    );
  }

  Json _mange(_Ligne l) => moteur.portion({
    'kcal100': l.aliment?['kcal100'] ?? 0,
    'proteines100': l.aliment?['proteines100'] ?? 0,
    'masse': l.grammes,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final ls = lignes;
    final gardees = [
      for (final l in ls ?? const <_Ligne>[])
        if (l.garde && l.aliment != null) l,
    ];
    final kcal = gardees.fold<double>(0, (s, l) => s + nombre(_mange(l)['kcal']));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(CrescoSpacing.margin, 0, CrescoSpacing.margin, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Ton repas', style: CrescoTextes.titreCarte),
            Text('Proposé par ton assistant : vérifie avant d’ajouter.', style: context.mutedStyle),
            const SizedBox(height: 12),
            if (erreur != null)
              Text(erreur!, style: TextStyle(color: p.danger))
            else if (ls == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: LoadingState(heights: [56, 56, 56]),
              )
            else if (ls.isEmpty)
              Text('Aucun aliment reconnu.', style: context.mutedStyle)
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final l in ls)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: l.garde && l.aliment != null,
                        onChanged: l.aliment == null ? null : (v) => setState(() => l.garde = v ?? false),
                        title: Text(l.libelle, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          l.aliment == null
                              ? 'Introuvable dans la base : ajoute-le à la main'
                              : '${l.aliment!['nom']} · ${entier(_mange(l)['kcal'])} kcal',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        secondary: l.aliment == null
                            ? null
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Moins 10 g',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: l.grammes > 10 ? () => setState(() => l.grammes -= 10) : null,
                                    icon: const Icon(Icons.remove, size: 18),
                                  ),
                                  Text('${entier(l.grammes)} g', style: const TextStyle(fontWeight: FontWeight.w800)),
                                  IconButton(
                                    tooltip: 'Plus 10 g',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => setState(() => l.grammes += 10),
                                    icon: const Icon(Icons.add, size: 18),
                                  ),
                                ],
                              ),
                      ),
                  ],
                ),
              ),
            if (remarque != null && remarque!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(remarque!, style: context.mutedStyle),
            ],
            const SizedBox(height: 14),
            FilledButton(
              onPressed: gardees.isEmpty
                  ? null
                  : () => Navigator.pop(context, [for (final l in gardees) (l.aliment!['id']! as String, l.grammes)]),
              child: Text(gardees.isEmpty ? 'Ajouter' : 'Ajouter au ${mealOf(maintenant()).$2} · ${entier(kcal)} kcal'),
            ),
          ],
        ),
      ),
    );
  }
}
