import 'dart:convert';
import 'dart:io';

import 'package:cresco_engine/cresco_engine.dart';
import 'package:test/test.dart';

void main() {
  final fichier = File('../../engine-spec/cases.json');
  final spec = jsonDecode(fichier.readAsStringSync()) as Map<String, Object?>;
  final tolerance = (spec['tolerance']! as num).toDouble();
  final cas = (spec['cas']! as List).cast<Map<String, Object?>>();

  void compare(Object? attendu, Object? obtenu, String chemin) {
    if (attendu is num) {
      expect(obtenu, isA<num>(), reason: chemin);
      expect(((obtenu! as num) - attendu).abs(), lessThanOrEqualTo(tolerance), reason: '$chemin : $obtenu ≠ $attendu');
    } else if (attendu is List) {
      expect(obtenu, isA<List<Object?>>(), reason: chemin);
      final liste = obtenu! as List;
      expect(liste.length, attendu.length, reason: chemin);
      for (var i = 0; i < attendu.length; i++) {
        compare(attendu[i], liste[i], '$chemin[$i]');
      }
    } else if (attendu is Map) {
      for (final entree in attendu.entries) {
        compare(entree.value, (obtenu! as Map)[entree.key], '$chemin.${entree.key}');
      }
    } else {
      expect(obtenu, attendu, reason: chemin);
    }
  }

  group('engine-spec', () {
    for (var i = 0; i < cas.length; i++) {
      final c = cas[i];
      test('$i ${c['regle']} ${c['fonction']}', () {
        final f = fonctions[c['fonction']];
        expect(f, isNotNull, reason: 'fonction inconnue ${c['fonction']}');
        compare(c['sortie'], f!(c['entree']! as Map<String, Object?>), c['fonction']! as String);
      });
    }
  });
}
