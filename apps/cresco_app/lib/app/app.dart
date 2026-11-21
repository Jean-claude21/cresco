import 'package:cresco_app/features/accueil/accueil_view.dart';
import 'package:cresco_app/features/body/body_map_view.dart';
import 'package:cresco_app/features/connexion/connexion_view.dart';
import 'package:cresco_app/features/intervalles/intervalles_view.dart';
import 'package:cresco_app/features/jeune/jeune_view.dart';
import 'package:cresco_app/features/profil/profil_view.dart';
import 'package:cresco_app/features/scan/scan_view.dart';
import 'package:cresco_app/features/seance/seance_view.dart';
import 'package:stacked/stacked_annotations.dart';
import 'package:stacked_services/stacked_services.dart';

@StackedApp(
  routes: [
    MaterialRoute(page: ConnexionView, initial: true),
    MaterialRoute(page: AccueilView),
    MaterialRoute(page: SeanceView),
    MaterialRoute(page: IntervallesView),
    MaterialRoute(page: JeuneView),
    MaterialRoute(page: ScanView),
    MaterialRoute(page: ProfilView),
    MaterialRoute(page: BodyMapView),
  ],
  dependencies: [LazySingleton<NavigationService>(classType: NavigationService)],
)
class App;
