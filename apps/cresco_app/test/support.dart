import 'dart:convert';
import 'dart:io';

import 'package:cresco_app/app/app.locator.dart';
import 'package:cresco_app/ui/commun.dart' show maintenant;
import 'package:cresco_app/ui/messages.dart';
import 'package:cresco_data/cresco_data.dart';
import 'package:cresco_ui/cresco_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Heure figée des captures : jeudi 15 janvier 2026, 13 h 30.
final heureDesCaptures = DateTime(2026, 1, 15, 13, 30);

/// Réponses de l'API, au format des services du serveur (apps/server/src/services.ts).
final reponses = <String, Object?>{
  '/v1/aujourdhui': {
    'forme': {
      'valeur': 68,
      'confiance': 'haute',
      'composantes': {
        'sommeil': 72,
        'dormiMin': 365,
        'vfc': 42,
        'fcRepos': 54,
        'energie': 3,
        'ratioAiguChronique': 1.1,
      },
    },
    'seance': {
      'decision': {'decision': 'ADAPTEE', 'volume': -0.2},
      'raison': 'Volume réduit après une nuit courte',
      'nom': 'Haut du corps',
      'type': 'muscu',
    },
    'energie': {
      'tdee': 2600,
      'ciblesSuspendues': false,
      'cibles': {'kcal': 2150, 'proteines': 150, 'lipides': 72, 'glucides': 240},
      'jour': {'kcal': 1510, 'proteines': 94},
    },
    'jeune': null,
  },
  '/v1/seances/du-jour': {
    'decision': {'decision': 'ADAPTEE', 'volume': -0.2},
    'raison': 'Volume réduit après une nuit courte',
    'modele': {
      'nom': 'Haut du corps',
      'type': 'muscu',
      'blocs': [
        {
          'repeter': 2,
          'etapes': [
            {
              'exercice_id': 'developpe-couche-barre',
              'nom': 'Développé couché',
              'duree': {'reps': 8},
              'cible': {'rir': 2, 'charge_kg': 72.5},
              'repos_s': 150,
            },
          ],
        },
        {
          'repeter': 2,
          'etapes': [
            {
              'exercice_id': 'rowing-barre',
              'nom': 'Rowing barre',
              'duree': {'reps': 10},
              'cible': {'rir': 2, 'charge_kg': 60},
              'repos_s': 120,
            },
          ],
        },
      ],
    },
  },
  '/v1/exercices': [
    {
      'id': 'developpe-couche-barre',
      'nom': 'Développé couché',
      'consignes': 'Omoplates serrées, barre au bas des pectoraux, pieds ancrés.',
      'liens': <Object?>[],
    },
  ],
  '/v1/energie': {
    'bmr': 1780,
    'tdee': 2410,
    'source': 'adaptatif',
    'sousSaisie': false,
    'cibles': {'kcal': 2150, 'proteines': 150, 'lipides': 72, 'glucides': 240},
    'ciblesSuspendues': false,
    'jour': {'kcal': 1510, 'proteines': 94},
    'bilan': {'moyen7j': -260, 'verdict': 'deficit', 'confiance': 'moyenne', 'pct': -0.108},
  },
  '/v1/plats': [
    {
      'id': '00000000-0000-0000-0000-000000000001',
      'nom': 'Riz sauce arachide',
      'nutriments': {'kcal100': 168},
      'cree_par': 'ia',
    },
  ],
  '/v1/progression': {
    'verdict': 'maintien_reussite',
    'explication': 'Ta force reste stable malgré des nuits de 6 h 12 en moyenne.',
    'exercices': [
      {
        'nom': 'Développé couché',
        'dernier': 96.7,
        'pctParSemaine': 0.18,
        'points': [
          {'e1rm': 96.1},
          {'e1rm': 96.6},
          {'e1rm': 96.1},
          {'e1rm': 96.9},
          {'e1rm': 96.3},
          {'e1rm': 96.5},
          {'e1rm': 96.8},
          {'e1rm': 96.7},
        ],
      },
    ],
    'energie': {'moyen7j': -260, 'verdict': 'deficit', 'confiance': 'moyenne'},
    'poidsLisse': 73.8,
    'sommeilMoyenMin': 372,
  },
  '/v1/jeunes/en-cours/decision': {
    'jeune': {
      'id': '00000000-0000-0000-0000-000000000002',
      'type': 'intermittent',
      'motif': 'spirituel',
      'intention': 'Faire de la place au silence.',
      'debut': heureDesCaptures.toUtc().subtract(const Duration(hours: 17, minutes: 30)).toIso8601String(),
      'fin_prevue': heureDesCaptures.toUtc().add(const Duration(minutes: 30)).toIso8601String(),
      'heures': 17.5,
      'phase': 'bascule',
    },
    'decision': {'decision': 'ADAPTEE', 'volume': -0.25, 'alerte': null},
    'reprise': {'mode': 'normale', 'proteinesRepas': 30},
  },
  '/v1/moi': {
    'id': 'u1',
    'email': 'demo@cresco.test',
    'nom': 'Démo',
    'sexe': 'homme',
    'niveau': 'intermediaire',
    'objectif': 'maintien',
    'taille_cm': 180,
    'preferences': {
      'moduleFoi': true,
      'prioriteSpirituelle': false,
      'joursReposVerrouilles': <int>[0],
    },
  },
};

/// Prépare le localisateur avec une fausse API et les polices réelles (pour des captures lisibles).
Future<void> preparer() async {
  maintenant = () => heureDesCaptures;
  TestWidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');
  SharedPreferences.setMockInitialValues({'jeton': 'cr_test'});
  await locator.reset();
  await setupLocator();
  final session = await Session.charger();
  final client = MockClient((requete) async {
    // Les écritures sont acceptées comme par le vrai serveur.
    if (requete.method != 'GET') return http.Response(jsonEncode({'id': 'cree'}), 201);
    final corps = reponses[requete.url.path];
    if (corps == null) return http.Response(jsonEncode({'erreur': 'Introuvable'}), 404);
    return http.Response.bytes(utf8.encode(jsonEncode(corps)), 200, headers: {'content-type': 'application/json'});
  });
  locator
    ..registerSingleton<Session>(session)
    ..registerSingleton<CrescoApi>(CrescoApi(session, client: client))
    ..registerSingleton<Messages>(Messages());
  await _chargerPolices();
}

Future<void> _chargerPolices() async {
  final dossier =
      '${Platform.environment['FLUTTER_ROOT'] ?? '../../.fvm/flutter_sdk'}/bin/cache/artifacts/material_fonts';
  Future<ByteData> lire(String f) async => ByteData.sublistView(await File('$dossier/$f').readAsBytes());
  // La police de titre embarquée par cresco_ui, sous le nom qu'utilise le thème.
  Future<ByteData> lirePaquet(String f) async =>
      ByteData.sublistView(await File('../../packages/cresco_ui/fonts/$f').readAsBytes());
  final serif = FontLoader(CrescoTextes.serif)
    ..addFont(lirePaquet('Gelasio[wght].ttf'))
    ..addFont(lirePaquet('Gelasio-Italic[wght].ttf'));
  await serif.load();
  for (final famille in ['Roboto']) {
    final loader = FontLoader(famille)
      ..addFont(lire('roboto-regular.ttf'))
      ..addFont(lire('roboto-bold.ttf'))
      ..addFont(lire('roboto-black.ttf'))
      ..addFont(lire('roboto-italic.ttf'));
    await loader.load();
  }
  final icones = FontLoader('MaterialIcons')..addFont(lire('materialicons-regular.otf'));
  await icones.load();
}

/// Enveloppe un écran dans le thème Cresco, au format d'un iPhone (402 × 874 pt).
Widget enveloppe(Widget ecran) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: crescoTheme(fontFamily: 'Roboto'),
  home: ecran,
);

Future<void> taillerTelephone(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(402 * 2, 874 * 2)
    ..devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}
