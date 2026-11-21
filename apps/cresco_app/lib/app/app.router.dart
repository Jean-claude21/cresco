// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// StackedNavigatorGenerator
// **************************************************************************

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:cresco_app/features/accueil/accueil_view.dart' as _i3;
import 'package:cresco_app/features/connexion/connexion_view.dart' as _i2;
import 'package:cresco_app/features/intervalles/intervalles_view.dart' as _i5;
import 'package:cresco_app/features/jeune/jeune_view.dart' as _i6;
import 'package:cresco_app/features/profil/profil_view.dart' as _i8;
import 'package:cresco_app/features/scan/scan_view.dart' as _i7;
import 'package:cresco_app/features/seance/seance_view.dart' as _i4;
import 'package:flutter/material.dart' as _i9;
import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart' as _i1;
import 'package:stacked_services/stacked_services.dart' as _i10;

class Routes {
  static const connexionView = '/';

  static const accueilView = '/accueil-view';

  static const seanceView = '/seance-view';

  static const intervallesView = '/intervalles-view';

  static const jeuneView = '/jeune-view';

  static const scanView = '/scan-view';

  static const profilView = '/profil-view';

  static const all = <String>{
    connexionView,
    accueilView,
    seanceView,
    intervallesView,
    jeuneView,
    scanView,
    profilView,
  };
}

class StackedRouter extends _i1.RouterBase {
  final _routes = <_i1.RouteDef>[
    _i1.RouteDef(Routes.connexionView, page: _i2.ConnexionView),
    _i1.RouteDef(Routes.accueilView, page: _i3.AccueilView),
    _i1.RouteDef(Routes.seanceView, page: _i4.SeanceView),
    _i1.RouteDef(Routes.intervallesView, page: _i5.IntervallesView),
    _i1.RouteDef(Routes.jeuneView, page: _i6.JeuneView),
    _i1.RouteDef(Routes.scanView, page: _i7.ScanView),
    _i1.RouteDef(Routes.profilView, page: _i8.ProfilView),
  ];

  final _pagesMap = <Type, _i1.StackedRouteFactory>{
    _i2.ConnexionView: (data) {
      final args = data.getArgs<ConnexionViewArguments>(
        orElse: () => const ConnexionViewArguments(),
      );
      return _i9.MaterialPageRoute<dynamic>(
        builder: (context) => _i2.ConnexionView(key: args.key),
        settings: data,
      );
    },
    _i3.AccueilView: (data) {
      final args = data.getArgs<AccueilViewArguments>(
        orElse: () => const AccueilViewArguments(),
      );
      return _i9.MaterialPageRoute<dynamic>(
        builder: (context) => _i3.AccueilView(key: args.key),
        settings: data,
      );
    },
    _i4.SeanceView: (data) {
      final args = data.getArgs<SeanceViewArguments>(
        orElse: () => const SeanceViewArguments(),
      );
      return _i9.MaterialPageRoute<dynamic>(
        builder: (context) => _i4.SeanceView(key: args.key),
        settings: data,
      );
    },
    _i5.IntervallesView: (data) {
      final args = data.getArgs<IntervallesViewArguments>(nullOk: false);
      return _i9.MaterialPageRoute<dynamic>(
        builder: (context) =>
            _i5.IntervallesView(modele: args.modele, key: args.key),
        settings: data,
      );
    },
    _i6.JeuneView: (data) {
      final args = data.getArgs<JeuneViewArguments>(
        orElse: () => const JeuneViewArguments(),
      );
      return _i9.MaterialPageRoute<dynamic>(
        builder: (context) => _i6.JeuneView(key: args.key),
        settings: data,
      );
    },
    _i7.ScanView: (data) {
      final args = data.getArgs<ScanViewArguments>(
        orElse: () => const ScanViewArguments(),
      );
      return _i9.MaterialPageRoute<dynamic>(
        builder: (context) => _i7.ScanView(key: args.key),
        settings: data,
      );
    },
    _i8.ProfilView: (data) {
      final args = data.getArgs<ProfilViewArguments>(
        orElse: () => const ProfilViewArguments(),
      );
      return _i9.MaterialPageRoute<dynamic>(
        builder: (context) => _i8.ProfilView(key: args.key),
        settings: data,
      );
    },
  };

  @override
  List<_i1.RouteDef> get routes => _routes;

  @override
  Map<Type, _i1.StackedRouteFactory> get pagesMap => _pagesMap;
}

class ConnexionViewArguments {
  const ConnexionViewArguments({this.key});

  final _i9.Key? key;

  @override
  String toString() {
    return '{"key": "$key"}';
  }

  @override
  bool operator ==(covariant ConnexionViewArguments other) {
    if (identical(this, other)) return true;
    return other.key == key;
  }

  @override
  int get hashCode {
    return key.hashCode;
  }
}

class AccueilViewArguments {
  const AccueilViewArguments({this.key});

  final _i9.Key? key;

  @override
  String toString() {
    return '{"key": "$key"}';
  }

  @override
  bool operator ==(covariant AccueilViewArguments other) {
    if (identical(this, other)) return true;
    return other.key == key;
  }

  @override
  int get hashCode {
    return key.hashCode;
  }
}

class SeanceViewArguments {
  const SeanceViewArguments({this.key});

  final _i9.Key? key;

  @override
  String toString() {
    return '{"key": "$key"}';
  }

  @override
  bool operator ==(covariant SeanceViewArguments other) {
    if (identical(this, other)) return true;
    return other.key == key;
  }

  @override
  int get hashCode {
    return key.hashCode;
  }
}

class IntervallesViewArguments {
  const IntervallesViewArguments({required this.modele, this.key});

  final Map<String, Object?> modele;

  final _i9.Key? key;

  @override
  String toString() {
    return '{"modele": "$modele", "key": "$key"}';
  }

  @override
  bool operator ==(covariant IntervallesViewArguments other) {
    if (identical(this, other)) return true;
    return other.modele == modele && other.key == key;
  }

  @override
  int get hashCode {
    return modele.hashCode ^ key.hashCode;
  }
}

class JeuneViewArguments {
  const JeuneViewArguments({this.key});

  final _i9.Key? key;

  @override
  String toString() {
    return '{"key": "$key"}';
  }

  @override
  bool operator ==(covariant JeuneViewArguments other) {
    if (identical(this, other)) return true;
    return other.key == key;
  }

  @override
  int get hashCode {
    return key.hashCode;
  }
}

class ScanViewArguments {
  const ScanViewArguments({this.key});

  final _i9.Key? key;

  @override
  String toString() {
    return '{"key": "$key"}';
  }

  @override
  bool operator ==(covariant ScanViewArguments other) {
    if (identical(this, other)) return true;
    return other.key == key;
  }

  @override
  int get hashCode {
    return key.hashCode;
  }
}

class ProfilViewArguments {
  const ProfilViewArguments({this.key});

  final _i9.Key? key;

  @override
  String toString() {
    return '{"key": "$key"}';
  }

  @override
  bool operator ==(covariant ProfilViewArguments other) {
    if (identical(this, other)) return true;
    return other.key == key;
  }

  @override
  int get hashCode {
    return key.hashCode;
  }
}

extension NavigatorStateExtension on _i10.NavigationService {
  Future<dynamic> navigateToConnexionView({
    _i9.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
    transition,
  }) async {
    return navigateTo<dynamic>(
      Routes.connexionView,
      arguments: ConnexionViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> navigateToAccueilView({
    _i9.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
    transition,
  }) async {
    return navigateTo<dynamic>(
      Routes.accueilView,
      arguments: AccueilViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> navigateToSeanceView({
    _i9.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
    transition,
  }) async {
    return navigateTo<dynamic>(
      Routes.seanceView,
      arguments: SeanceViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> navigateToIntervallesView({
    required Map<String, Object?> modele,
    _i9.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
    transition,
  }) async {
    return navigateTo<dynamic>(
      Routes.intervallesView,
      arguments: IntervallesViewArguments(modele: modele, key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> navigateToJeuneView({
    _i9.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
    transition,
  }) async {
    return navigateTo<dynamic>(
      Routes.jeuneView,
      arguments: JeuneViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> navigateToScanView({
    _i9.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
    transition,
  }) async {
    return navigateTo<dynamic>(
      Routes.scanView,
      arguments: ScanViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> navigateToProfilView({
    _i9.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
    transition,
  }) async {
    return navigateTo<dynamic>(
      Routes.profilView,
      arguments: ProfilViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> replaceWithConnexionView({
    _i9.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
    transition,
  }) async {
    return replaceWith<dynamic>(
      Routes.connexionView,
      arguments: ConnexionViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> replaceWithAccueilView({
    _i9.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
    transition,
  }) async {
    return replaceWith<dynamic>(
      Routes.accueilView,
      arguments: AccueilViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> replaceWithSeanceView({
    _i9.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
    transition,
  }) async {
    return replaceWith<dynamic>(
      Routes.seanceView,
      arguments: SeanceViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> replaceWithIntervallesView({
    required Map<String, Object?> modele,
    _i9.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
    transition,
  }) async {
    return replaceWith<dynamic>(
      Routes.intervallesView,
      arguments: IntervallesViewArguments(modele: modele, key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> replaceWithJeuneView({
    _i9.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
    transition,
  }) async {
    return replaceWith<dynamic>(
      Routes.jeuneView,
      arguments: JeuneViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> replaceWithScanView({
    _i9.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
    transition,
  }) async {
    return replaceWith<dynamic>(
      Routes.scanView,
      arguments: ScanViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> replaceWithProfilView({
    _i9.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
    transition,
  }) async {
    return replaceWith<dynamic>(
      Routes.profilView,
      arguments: ProfilViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }
}
