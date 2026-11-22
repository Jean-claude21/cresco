import 'package:flutter/material.dart';

/// The two illustrated coaches (docs/design/medias). The user picks one at onboarding.
enum Coach {
  femme('Coach Maya'),
  homme('Coach Karim');

  new(this.label);

  /// Name shown in the app.
  final String label;

  /// Coach stored in the profile preferences (`coach`), or null when none was picked yet.
  static Coach? fromName(Object? name) => Coach.values.where((c) => c.name == name).firstOrNull;
}

/// Poses drawn for both coaches.
enum CoachPose { salue, explique, carnet, pouce, reflechit, celebre }

const _package = 'cresco_ui';

/// One coach in one pose, on a transparent background. Decorative: excluded from semantics.
class CoachIllustration extends StatelessWidget {
  const new({required this.coach, required this.pose, super.key, this.height = 220});
  final Coach coach;
  final CoachPose pose;
  final double height;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Image.asset(
      'assets/coach/${coach.name}-${pose.name}.png',
      package: _package,
      height: height,
      fit: BoxFit.contain,
    ),
  );
}

/// Both coaches together in a small gym set, for the welcome screen.
class CoachDuo extends StatelessWidget {
  const new({super.key, this.height = 320});
  final double height;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Image.asset('assets/coach/duo.png', package: _package, height: height, fit: BoxFit.contain),
  );
}

/// 3D icons of the Today shortcuts.
enum ShortcutIcon { seance, repas, jeune, sommeil }

class ShortcutIconImage extends StatelessWidget {
  const new(this.icon, {super.key, this.size = 56});
  final ShortcutIcon icon;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Image.asset('assets/icons/${icon.name}.png', package: _package, width: size, height: size),
  );
}

/// Dish families of "Mes plats", each with a photo generated with ChatGPT (docs/design/medias/plats).
/// A dish gets the photo of the first family whose keyword appears in its name.
enum DishFamily {
  rizPoulet('riz-poulet', ['jollof', 'yassa', 'mafé', 'mafe', 'riz', 'poulet', 'thiép', 'thieb']),
  poisson('poisson', ['saumon', 'poisson', 'thon', 'cabillaud', 'sardine', 'crevette']),
  oeufs('oeufs', ['omelette', 'oeuf', 'œuf', 'oeufs', 'œufs']),
  legumineuses('legumineuses', ['lentille', 'dal', 'haricot', 'pois chiche', 'niébé', 'niebe', 'houmous', 'arachide']),
  bowl('bowl', ['bowl', 'salade', 'quinoa', 'buddha']),
  yaourtFruits('yaourt-fruits', ['skyr', 'yaourt', 'fromage blanc', 'fruit', 'porridge', 'avoine', 'granola']),
  pates('pates', ['pâte', 'pate', 'spaghetti', 'penne', 'lasagne', 'nouille']),
  soupe('soupe', ['soupe', 'velouté', 'veloute', 'bouillon', 'potage']),
  assiette('assiette', []);

  new(this.file, this.keywords);
  final String file;
  final List<String> keywords;

  String get asset => 'assets/dishes/$file.jpg';

  static DishFamily of(String dishName) {
    final name = dishName.toLowerCase();
    return values.firstWhere((f) => f.keywords.any(name.contains), orElse: () => assiette);
  }
}

class DishPhoto extends StatelessWidget {
  const new(this.dishName, {super.key, this.height});
  final String dishName;
  final double? height;

  @override
  Widget build(BuildContext context) => Image.asset(
    DishFamily.of(dishName).asset,
    package: _package,
    height: height,
    width: double.infinity,
    fit: BoxFit.cover,
    excludeFromSemantics: true,
  );
}

/// Black-and-white gym photos.
enum CrescoPhoto {
  seanceDuJour('seance-du-jour'),
  chestPress('chest-press'),
  intervalles('intervalles'),
  jambes('jambes');

  new(this.file);
  final String file;

  String get asset => 'assets/photos/$file.jpg';

  /// Photo matching an exercise of the catalog: the leg press and leg machines show the press,
  /// cardio shows the treadmill, upper-body machines the chest press, anything else the gym.
  static CrescoPhoto forExercise(String? exerciseId) => switch (exerciseId) {
    'presse-cuisses' || 'leg-curl' || 'leg-extension' || 'mollets-debout' || 'squat-barre' => jambes,
    'course-tapis' || 'velo' || 'rameur' => intervalles,
    'tirage-vertical' || 'rowing-assis-poulie' || 'extension-triceps-poulie' || 'developpe-couche-barre' => chestPress,
    _ => seanceDuJour,
  };
}

class CrescoPhotoImage extends StatelessWidget {
  const new(this.photo, {super.key, this.height, this.width, this.semanticLabel});
  final CrescoPhoto photo;
  final double? height;
  final double? width;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Image.asset(
    photo.asset,
    package: _package,
    height: height,
    width: width,
    fit: BoxFit.cover,
    semanticLabel: semanticLabel,
    excludeFromSemantics: semanticLabel == null,
  );
}

/// Photo of a piece of equipment of "Ma salle", by catalog key (`exercise:<id>` or `material:<id>`).
abstract final class EquipmentPhoto {
  /// Equipment with its own photo in `assets/equipment/<id>.jpg` (docs/design/medias/equipements).
  static const own = <String>{};

  /// Asset of [key]: its own photo, or the closest gym photo until it has one.
  static String asset(String key) {
    final id = key.split(':').last;
    if (own.contains(id)) return 'assets/equipment/$id.jpg';
    return switch (id) {
      'tapis' || 'velo' || 'rameur' => CrescoPhoto.intervalles,
      'barre' || 'halteres' => CrescoPhoto.seanceDuJour,
      _ => CrescoPhoto.forExercise(id),
    }.asset;
  }
}

class EquipmentPhotoImage extends StatelessWidget {
  const new(this.equipmentKey, {super.key, this.height, this.width});
  final String equipmentKey;
  final double? height;
  final double? width;

  @override
  Widget build(BuildContext context) => Image.asset(
    EquipmentPhoto.asset(equipmentKey),
    package: _package,
    height: height,
    width: width,
    fit: BoxFit.cover,
    excludeFromSemantics: true,
  );
}
