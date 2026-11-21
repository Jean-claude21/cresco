import 'package:flutter/material.dart';

/// Couleurs de DESIGN.md (direction « vert pin »).
abstract final class CrescoCouleurs {
  static const calcaire = Color(0xFFF4F5EF);
  static const blanc = Color(0xFFFFFFFF);
  static const encre = Color(0xFF182C24);
  static const pin = Color(0xFF184D3B);
  static const pinSombre = Color(0xFF123E31);
  static const pousse = Color(0xFFD8EEA1);
  static const sauge = Color(0xFFE3EDDB);
  static const eucalyptus = Color(0xFF427F77);
  static const texteSecondaire = Color(0xFF56695E);
  static const filet = Color(0xFFDCE3D8);
  static const ombre = Color(0xFFE9EDE4);
  static const sable = Color(0xFFF3EDDE);
  static const terre = Color(0xFF694F2E);
  static const alerte = Color(0xFFB3412F);
}

/// Rayons et espacements (pt) de DESIGN.md.
abstract final class CrescoMesures {
  static const rayon = 22.0;
  static const rayonPetit = 18.0;
  static const marge = 18.0;
  static const gouttiere = 12.0;
}

/// Titres à empattements (Georgia, repli serif), données en sans-serif.
abstract final class CrescoTextes {
  static const _serif = 'Georgia';
  static const _serifRepli = ['Noto Serif', 'serif'];

  static const titrePage = TextStyle(
    fontFamily: _serif,
    fontFamilyFallback: _serifRepli,
    fontSize: 40,
    height: 1.05,
    color: CrescoCouleurs.encre,
    letterSpacing: -0.8,
  );
  static const titreCarte = TextStyle(
    fontFamily: _serif,
    fontFamilyFallback: _serifRepli,
    fontSize: 30,
    height: 1.1,
    color: CrescoCouleurs.encre,
    letterSpacing: -0.4,
  );
  static const surtitre = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 2,
    color: CrescoCouleurs.texteSecondaire,
  );
  static const chiffre = TextStyle(
    fontSize: 46,
    fontWeight: FontWeight.w800,
    height: 1,
    color: CrescoCouleurs.encre,
    letterSpacing: -1.5,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const unite = TextStyle(fontSize: 17, color: CrescoCouleurs.texteSecondaire);
  static const corps = TextStyle(fontSize: 16, height: 1.35, color: CrescoCouleurs.encre);
  static const secondaire = TextStyle(fontSize: 14, height: 1.35, color: CrescoCouleurs.texteSecondaire);
  static const intention = TextStyle(
    fontFamily: _serif,
    fontFamilyFallback: _serifRepli,
    fontSize: 24,
    color: CrescoCouleurs.encre,
  );
  static const verset = TextStyle(
    fontFamily: _serif,
    fontFamilyFallback: _serifRepli,
    fontSize: 16,
    fontStyle: FontStyle.italic,
    color: CrescoCouleurs.texteSecondaire,
  );
}

ThemeData crescoTheme({String? fontFamily}) {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: fontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: CrescoCouleurs.pin,
      primary: CrescoCouleurs.pin,
      onPrimary: CrescoCouleurs.blanc,
      secondary: CrescoCouleurs.pousse,
      surface: CrescoCouleurs.calcaire,
      error: CrescoCouleurs.alerte,
    ),
    scaffoldBackgroundColor: CrescoCouleurs.calcaire,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: CrescoCouleurs.encre, displayColor: CrescoCouleurs.encre),
    appBarTheme: const AppBarTheme(
      backgroundColor: CrescoCouleurs.calcaire,
      foregroundColor: CrescoCouleurs.encre,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: CrescoCouleurs.pin,
        foregroundColor: CrescoCouleurs.blanc,
        minimumSize: const Size.fromHeight(56),
        shape: const StadiumBorder(),
        textStyle: TextStyle(fontFamily: fontFamily, fontSize: 18, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: CrescoCouleurs.pin,
        minimumSize: const Size.fromHeight(56),
        side: const BorderSide(color: CrescoCouleurs.pin, width: 1.4),
        shape: const StadiumBorder(),
        textStyle: TextStyle(fontFamily: fontFamily, fontSize: 18, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: CrescoCouleurs.blanc,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CrescoMesures.rayonPetit),
        borderSide: const BorderSide(color: CrescoCouleurs.filet),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CrescoMesures.rayonPetit),
        borderSide: const BorderSide(color: CrescoCouleurs.filet),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: CrescoCouleurs.pinSombre,
    ),
  );
}
