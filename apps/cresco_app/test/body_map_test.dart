import 'package:cresco_app/features/body/body_map_view.dart';
import 'package:cresco_ui/cresco_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BodyLabels (generated masks)', () {
    testWidgets('finds the muscle under a point of the front and back maps', (t) async {
      final (front, back) = (await t.runAsync(
        () async => (await BodyLabels.load(BodySide.front), await BodyLabels.load(BodySide.back)),
      ))!;
      // Fractions of the 1024 × 2048 images: centre of the left pectoral, left quadriceps,
      // the middle of the back, the head (no muscle).
      expect(front.muscleAt(const Offset(0.40, 0.23)), 'pectoraux');
      expect(front.muscleAt(const Offset(0.40, 0.55)), 'quadriceps');
      expect(back.muscleAt(const Offset(0.50, 0.30)), 'dos');
      expect(front.muscleAt(const Offset(0.50, 0.04)), isNull);
      expect(front.muscleAt(const Offset(1.5, 0.5)), isNull);
    });

    test('every catalog muscle is drawn on one side or the other', () {
      expect({...BodyMuscles.front, ...BodyMuscles.back}, containsAll(muscleNames.keys));
      expect(BodyMuscles.all.toSet(), muscleNames.keys.toSet());
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
      await chargerImages(t);
      await t.pumpAndSettle();
    }

    testWidgets('shows the selected muscle against the weekly guideline', (t) async {
      await open(t);
      expect(find.textContaining('8,5', findRichText: true), findsWidgets);
      expect(find.textContaining('/ 10 séries efficaces', findRichText: true), findsOneWidget);
    });

    testWidgets('the Dos tab turns the body around and lists the back muscles', (t) async {
      await open(t);
      await t.tap(find.text('Dos').first);
      await t.pumpAndSettle();
      expect(t.widget<BodyMap>(find.byType(BodyMap)).side, BodySide.back);
      expect(find.byKey(const ValueKey('muscle-ischios')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('muscle-ischios')));
      await t.pumpAndSettle();
      expect(find.text('Aucune série efficace cette semaine pour ce muscle.'), findsOneWidget);
    });

    testWidgets('touching the body selects the muscle under the finger', (t) async {
      await open(t);
      await t.tap(find.byKey(const ValueKey('muscle-quadriceps')));
      await t.pumpAndSettle();
      expect(find.text('Repère hebdomadaire atteint.'), findsOneWidget);
      final box = t.getRect(find.byType(BodyMap));
      // Left pectoral, as a fraction of the body image.
      await t.tapAt(Offset(box.left + box.width * 0.40, box.top + box.height * 0.23));
      await t.pumpAndSettle();
      expect(find.text('Encore 1,5 série pour atteindre le repère.'), findsOneWidget);
    });
  });
}
