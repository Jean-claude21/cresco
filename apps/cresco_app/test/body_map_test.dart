import 'package:cresco_app/features/body/body_map_view.dart';
import 'package:cresco_ui/cresco_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  group('parseBodyPath', () {
    test('reads move, line, curve and close commands', () {
      final path = parseBodyPath('M0 0 L10 0 C10 5 10 5 10 10 L0 10 Z');
      expect(path.getBounds(), const Rect.fromLTRB(0, 0, 10, 10));
      expect(path.contains(const Offset(5, 5)), isTrue);
      expect(path.contains(const Offset(15, 5)), isFalse);
    });

    test('parses every area of both sides', () {
      for (final area in [...BodyShapes.front, ...BodyShapes.back]) {
        expect(parseBodyPath(area.path).getBounds().isEmpty, isFalse, reason: area.muscle);
      }
    });

    test('every catalog muscle can be reached on the silhouette', () {
      final drawn = {...BodyShapes.musclesOf(BodySide.front), ...BodyShapes.musclesOf(BodySide.back)};
      expect(drawn, containsAll(muscleNames.keys));
    });
  });

  test('volumeLevel buckets effective sets against the guideline', () {
    expect(volumeLevel(0, 10), 0);
    expect(volumeLevel(4, 10), 1);
    expect(volumeLevel(6, 10), 2);
    expect(volumeLevel(9.5, 10), 3);
    expect(volumeLevel(10, 10), 4);
  });

  group('BodyMapView', () {
    setUp(preparer);

    Future<void> open(WidgetTester t) async {
      await taillerTelephone(t);
      await t.pumpWidget(enveloppe(const BodyMapView()));
      await t.pumpAndSettle();
    }

    Future<void> chip(WidgetTester t, String muscle) async {
      final f = find.byKey(ValueKey('muscle-$muscle'));
      await t.drag(find.byType(ListView), const Offset(0, -400));
      await t.pumpAndSettle();
      await t.tap(f);
      await t.pumpAndSettle();
    }

    testWidgets('shows the selected muscle against the weekly guideline', (t) async {
      await open(t);
      expect(find.textContaining('8,5', findRichText: true), findsOneWidget);
      expect(find.textContaining('/ 10 séries efficaces', findRichText: true), findsOneWidget);
    });

    testWidgets('a back muscle chip turns the body around', (t) async {
      await open(t);
      await chip(t, 'ischios');
      expect(find.text('Aucune série efficace cette semaine pour ce muscle.'), findsOneWidget);
      final map = t.widget<BodyMap>(find.byType(BodyMap));
      expect(map.side, BodySide.back);
    });

    testWidgets('touching the silhouette selects the muscle under the finger', (t) async {
      await open(t);
      await chip(t, 'quadriceps');
      expect(find.text('Repère hebdomadaire atteint.'), findsOneWidget);
      await t.drag(find.byType(ListView), const Offset(0, 400));
      await t.pumpAndSettle();
      final box = t.getRect(find.byType(BodyMap));
      final scale = box.width / BodyShapes.viewBox.width;
      // Left pectoral, inside its path in the 200 × 392 view box.
      await t.tapAt(box.topLeft + const Offset(84, 86) * scale);
      await t.pumpAndSettle();
      expect(find.textContaining('8,5', findRichText: true), findsOneWidget);
    });
  });
}
