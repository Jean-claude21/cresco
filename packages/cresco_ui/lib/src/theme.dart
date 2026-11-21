import 'package:cresco_ui/src/palette.dart';
import 'package:flutter/material.dart';

/// Legacy color names, mapped to the validated light palette (docs/design/DESIGN.md).
/// New code reads [CrescoPalette] from the theme instead, so it follows dark mode.
abstract final class CrescoCouleurs {
  static const calcaire = Color(0xFFF2F3EE);
  static const blanc = Color(0xFFFFFFFF);
  static const encre = Color(0xFF111311);
  static const pin = Color(0xFF111311);
  static const pinSombre = Color(0xFF111311);
  static const pousse = Color(0xFFCDEB5A);
  static const sauge = Color(0xFFE4F2C0);
  static const eucalyptus = Color(0xFF6B5CE7);
  static const texteSecondaire = Color(0xFF5B6158);
  static const filet = Color(0xFFECEDE6);
  static const ombre = Color(0xFFE6E8E1);
  static const sable = Color(0xFFFFE7C2);
  static const terre = Color(0xFF6B4300);
  static const alerte = Color(0xFFC2264A);
}

/// Radii and spacing (pt) from DESIGN.md.
abstract final class CrescoMesures {
  static const rayon = 24.0;
  static const rayonPetit = 18.0;
  static const marge = 20.0;
  static const gouttiere = 12.0;
}

/// Inter for titles, numbers and text; Gelasio (serif) only for the faith module's voice.
abstract final class CrescoTextes {
  /// Inter (OFL, embedded in cresco_ui), variable weight 100–900.
  static const sans = 'packages/cresco_ui/Inter';

  /// Gelasio (OFL, embedded in cresco_ui): Georgia metrics, for intentions and verses.
  static const serif = 'packages/cresco_ui/Gelasio';
  static const _serifFallback = ['Georgia', 'serif'];

  static const titrePage = TextStyle(
    fontFamily: sans,
    fontSize: 34,
    fontWeight: FontWeight.w900,
    height: 1.02,
    color: CrescoCouleurs.encre,
    letterSpacing: -1.2,
  );
  static const titreCarte = TextStyle(
    fontFamily: sans,
    fontSize: 24,
    fontWeight: FontWeight.w900,
    height: 1.08,
    color: CrescoCouleurs.encre,
    letterSpacing: -0.6,
  );
  static const surtitre = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    color: CrescoCouleurs.texteSecondaire,
  );
  static const chiffre = TextStyle(
    fontFamily: sans,
    fontSize: 46,
    fontWeight: FontWeight.w900,
    height: 1,
    color: CrescoCouleurs.encre,
    letterSpacing: -1.5,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const unite = TextStyle(fontSize: 17, color: CrescoCouleurs.texteSecondaire);
  static const corps = TextStyle(fontSize: 16, height: 1.35, color: CrescoCouleurs.encre);
  static const secondaire = TextStyle(fontSize: 14, height: 1.35, color: CrescoCouleurs.texteSecondaire);
  static const intention = TextStyle(
    fontFamily: serif,
    fontFamilyFallback: _serifFallback,
    fontSize: 24,
    color: CrescoCouleurs.encre,
  );
  static const verset = TextStyle(
    fontFamily: serif,
    fontFamilyFallback: _serifFallback,
    fontSize: 16,
    fontStyle: FontStyle.italic,
    color: CrescoCouleurs.texteSecondaire,
  );
}

/// Material theme built from [CrescoPalette]. Pass [brightness] for the dark variant.
/// [fontFamily] overrides Inter for body text (tests use the bundled Roboto).
ThemeData crescoTheme({String? fontFamily, Brightness brightness = Brightness.light}) {
  final p = brightness == Brightness.dark ? CrescoPalette.dark : CrescoPalette.light;
  final family = fontFamily ?? CrescoTextes.sans;
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: family,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: p.action,
      onPrimary: p.onAction,
      secondary: p.lime,
      onSecondary: p.onLime,
      surface: p.background,
      onSurface: p.ink,
      surfaceContainerLowest: p.surface,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.surface,
      surfaceContainerHigh: p.surface,
      outline: p.line,
      outlineVariant: p.line,
      error: p.danger,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: p.background,
    extensions: [p],
  );
  OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(CrescoMesures.rayonPetit),
    borderSide: BorderSide(color: color, width: width),
  );
  final label = TextStyle(fontFamily: family, fontSize: 16, fontWeight: FontWeight.w800);
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: p.ink, displayColor: p.ink),
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      foregroundColor: p.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.action,
        foregroundColor: p.onAction,
        minimumSize: const Size.fromHeight(56),
        shape: const StadiumBorder(),
        textStyle: label,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.ink,
        backgroundColor: p.surface,
        minimumSize: const Size.fromHeight(56),
        side: BorderSide(color: p.line, width: 1.2),
        shape: const StadiumBorder(),
        textStyle: label,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      floatingLabelStyle: TextStyle(color: p.ink, fontWeight: FontWeight.w600),
      border: border(p.line),
      enabledBorder: border(p.line),
      focusedBorder: border(p.ink, 1.6),
    ),
    // Surfaces we never draw ourselves: cursor, selection, handles.
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.ink,
      selectionColor: p.lime.withValues(alpha: 0.7),
      selectionHandleColor: p.ink,
    ),
    // Choices (sex, level, goal): solid action color, no check mark that breaks labels.
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8)),
        textStyle: WidgetStatePropertyAll(TextStyle(fontFamily: family, fontSize: 15, fontWeight: FontWeight.w700)),
        side: WidgetStatePropertyAll(BorderSide(color: p.line, width: 1.2)),
        backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.action : p.surface),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.onAction : p.ink),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.surface,
      selectedColor: p.action,
      checkmarkColor: p.onAction,
      side: BorderSide(color: p.line, width: 1.2),
      shape: const StadiumBorder(),
      // The chip resolves a state color in labelStyle: the on-action color once selected.
      labelStyle: TextStyle(
        fontFamily: family,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: WidgetStateColor.resolveWith((s) => s.contains(WidgetState.selected) ? p.onAction : p.ink),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.ink : p.line),
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.lime : p.surface),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    sliderTheme: SliderThemeData(activeTrackColor: p.ink, inactiveTrackColor: p.line, thumbColor: p.ink),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.ink),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.hero,
      contentTextStyle: TextStyle(fontFamily: family, color: Colors.white, fontSize: 15),
      shape: const StadiumBorder(),
    ),
  );
}
