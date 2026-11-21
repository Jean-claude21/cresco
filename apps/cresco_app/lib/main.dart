import 'package:cresco_app/app/app.locator.dart';
import 'package:cresco_app/app/app.router.dart';
import 'package:cresco_data/cresco_data.dart';
import 'package:cresco_ui/cresco_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:stacked_services/stacked_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');
  await setupLocator();
  final session = await Session.charger();
  locator
    ..registerSingleton<Session>(session)
    ..registerSingleton<CrescoApi>(CrescoApi(session));
  runApp(CrescoApp(connecte: session.connecte));
}

class CrescoApp extends StatelessWidget {
  const new({required this.connecte, super.key});
  final bool connecte;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cresco',
      debugShowCheckedModeBanner: false,
      theme: crescoTheme(),
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      navigatorKey: StackedService.navigatorKey,
      onGenerateRoute: StackedRouter().onGenerateRoute,
      initialRoute: connecte ? Routes.accueilView : Routes.connexionView,
    );
  }
}
