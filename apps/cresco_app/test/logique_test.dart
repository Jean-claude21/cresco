import 'package:cresco_app/features/entrainement/entrainement_view.dart';
import 'package:cresco_app/features/intervalles/intervalles_view.dart';
import 'package:cresco_app/ui/commun.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('intervalles', () {
    test('aplatit les blocs en étapes chronologiques', () {
      final etapes = aplatir(intervallesParDefaut);
      expect(etapes, hasLength(1 + 6 * 2 + 1));
      expect(etapes[1].libelle, 'Rapide');
      expect(etapes[1].repetition, 1);
      expect(etapes[12].repetition, 6);
    });

    test('affiche la vitesse en km/h (unités internes en m/s)', () {
      final etapes = aplatir(intervallesParDefaut);
      expect(etapes[1].vitesseKmh, '12');
      expect(etapes[2].vitesseKmh, '9');
    });
  });

  group('formats', () {
    test('durées et décimales à la française', () {
      expect(duree(365), '6 h 05');
      expect(dureeCourte(90), '1 min 30 s');
      expect(dureeCourte(45), '45 s');
      expect(decimal(72.5), '72,5');
      expect(decimal(90), '90');
    });
  });
}
