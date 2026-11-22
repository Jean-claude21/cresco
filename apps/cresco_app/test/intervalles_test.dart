import 'package:cresco_app/features/intervalles/intervalles_view.dart';
import 'package:cresco_app/ui/heart_rate.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

/// 2 × (1 min fast, 1 min easy).
const Map<String, Object?> _modele = {
  'nom': 'Test',
  'annonces': {'voix': false, 'preavis_s': 10},
  'blocs': [
    {
      'repeter': 2,
      'etapes': [
        {
          'libelle': 'Rapide',
          'duree': {'temps_s': 60},
          'cible': {'vitesse_ms': 3.33},
        },
        {
          'libelle': 'Récup',
          'duree': {'temps_s': 60},
          'cible': {'vitesse_ms': 2.22},
        },
      ],
    },
  ],
};

void main() {
  setUp(preparer);

  test('the timer follows the wall clock: steps missed with the screen off are caught up', () {
    var now = DateTime(2026, 11, 22, 10);
    final vm = IntervallesViewModel(_modele, clock: () => now)..basculerPause();
    expect(vm.courante.libelle, 'Rapide');
    expect(vm.restant, 60);

    // The phone sleeps 2 min 30 s: two steps are over, the third is half done.
    now = now.add(const Duration(minutes: 2, seconds: 30));
    vm.tic();
    expect(vm.index, 2);
    expect(vm.courante.libelle, 'Rapide');
    expect(vm.restant, 30);

    // Far past the end: the session is finished, not negative.
    now = now.add(const Duration(minutes: 10));
    vm.tic();
    expect(vm.termine, isTrue);
    expect(vm.restant, 0);
    vm.dispose();
  });

  test('pause freezes the time left', () {
    var now = DateTime(2026, 11, 22, 10);
    final vm = IntervallesViewModel(_modele, clock: () => now)..basculerPause();
    now = now.add(const Duration(seconds: 20));
    vm
      ..tic()
      ..basculerPause();
    expect(vm.restant, 40);
    now = now.add(const Duration(minutes: 5));
    vm.tic();
    expect(vm.restant, 40, reason: 'En pause, le temps ne s’écoule pas');
    vm.basculerPause();
    now = now.add(const Duration(seconds: 10));
    vm.tic();
    expect(vm.restant, 30);
    vm.dispose();
  });

  test('heart-rate measurement: one byte or two bytes', () {
    expect(parseMeasurement([0x00, 72]), 72);
    expect(parseMeasurement([0x01, 0x2C, 0x01]), 300);
    expect(parseMeasurement([0x01, 0x2C]), isNull);
    expect(parseMeasurement([0x00]), isNull);
  });
}
