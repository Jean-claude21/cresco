import 'package:cresco_app/features/training/template_editor_view.dart';
import 'package:cresco_app/features/training/training_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  test('a template item becomes one engine block, with "auto" load when none is set', () {
    final item = TemplateItem(exerciseId: 'leg-curl', name: 'Leg curl', sets: 4, reps: 12, rir: 1, restS: 75);
    expect(item.toBlock(), {
      'repeter': 4,
      'etapes': [
        {
          'exercice_id': 'leg-curl',
          'duree': {'reps': 12},
          'cible': {'rir': 1, 'charge_kg': 'auto'},
          'repos_s': 75,
        },
      ],
    });
    item.loadKg = 42.5;
    expect(((item.toBlock()['etapes']! as List).first as Map)['cible'], {'rir': 1, 'charge_kg': 42.5});
  });

  group('Mes séances', () {
    setUp(preparer);

    testWidgets('lists my gym and my saved sessions', (t) async {
      await taillerTelephone(t);
      await t.pumpWidget(enveloppe(const Scaffold(body: TrainingView())));
      await t.pumpAndSettle();
      expect(find.text('Ma salle'), findsOneWidget);
      expect(find.text('Basic-Fit Bastille · 4 équipements'), findsOneWidget);
      expect(find.textContaining('créée par ton IA'), findsOneWidget);
    });

    testWidgets('the editor reloads a saved session with its exercise names', (t) async {
      await taillerTelephone(t);
      final template = (reponses['/v1/modeles-seance']! as List).first as Map<String, Object?>;
      await t.pumpWidget(enveloppe(TemplateEditorView(template: template)));
      await t.pumpAndSettle();
      expect(find.text('Modifier la séance'), findsOneWidget);
      expect(find.text('Développé couché'), findsOneWidget);
      expect(find.text('auto'), findsOneWidget);
      await t.tap(find.byTooltip('Séries : plus'));
      await t.pump();
      expect(find.text('4'), findsOneWidget);
    });
  });
}
