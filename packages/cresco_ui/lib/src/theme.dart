import 'package:cresco_ui/src/palette.dart';
import 'package:flutter/material.dart';

/// Picnic-style shape of the validated design: almost square corners and a thin outline,
/// on buttons, cards, fields, chips, selectors, list rows, sheets and thumbnails.
/// Only the tab bar "+", data rings, legend dots and avatars stay round.
abstract final class CrescoShape {
  static const radius = 4.0;
  static const border = 1.5;
  static const borderRadius = BorderRadius.all(Radius.circular(radius));

  /// Button and control height (pt).
  static const controlHeight = 48.0;

  /// Rounded rectangle with an optional outline of [color].
  static RoundedRectangleBorder rectangle([Color? color]) => RoundedRectangleBorder(
    borderRadius: borderRadius,
    side: color == null ? BorderSide.none : BorderSide(color: color, width: border),
  );

  /// Decoration of an outlined surface (cards, tiles, rows).
  static BoxDecoration outlined(CrescoPalette p, {Color? fill, Color? outline}) => BoxDecoration(
    color: fill ?? p.surface,
    borderRadius: borderRadius,
    border: Border.all(color: outline ?? p.line, width: border),
  );
}

/// Page margins and the gap between cards (pt).
abstract final class CrescoSpacing {
  static const margin = 20.0;
  static const gutter = 12.0;
}

/// Inter for titles, numbers and text; Gelasio (serif) only for the faith module's voice.
/// Colors come from the theme (DefaultTextStyle, `context.palette`), never from these styles.
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
    letterSpacing: -1.2,
  );
  static const titreCarte = TextStyle(
    fontFamily: sans,
    fontSize: 24,
    fontWeight: FontWeight.w900,
    height: 1.08,
    letterSpacing: -0.6,
  );

  /// Barlow Condensed (OFL, embedded in cresco_ui), for poster numbers.
  static const condensed = 'packages/cresco_ui/BarlowCondensed';

  /// Poster numbers (loads, timers, scores, times): condensed and extra bold, as in the mockups.
  static const chiffre = TextStyle(
    fontFamily: condensed,
    fontSize: 46,
    fontWeight: FontWeight.w800,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const corps = TextStyle(fontSize: 16, height: 1.35);
  static const intention = TextStyle(fontFamily: serif, fontFamilyFallback: _serifFallback, fontSize: 24);
}

/// Effort button (start a session, validate a set): braise fill, dark label.
ButtonStyle effortButtonStyle(BuildContext context) {
  final p = context.palette;
  return FilledButton.styleFrom(backgroundColor: p.effort, foregroundColor: p.onEffort);
}

/// Material theme built from [CrescoPalette] and [CrescoShape]. Pass [brightness] for the dark variant.
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
      secondary: p.effort,
      onSecondary: p.onEffort,
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
  OutlineInputBorder field(Color color) => OutlineInputBorder(
    borderSide: BorderSide(color: color, width: CrescoShape.border),
  );
  // Picnic-style labels: regular weight, sentence case.
  final label = TextStyle(fontFamily: family, fontSize: 17, fontWeight: FontWeight.w500);
  const controlSize = Size.fromHeight(CrescoShape.controlHeight);
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
        minimumSize: controlSize,
        shape: CrescoShape.rectangle(),
        textStyle: label,
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.ink,
        minimumSize: controlSize,
        side: BorderSide(color: p.ink, width: CrescoShape.border),
        shape: CrescoShape.rectangle(),
        textStyle: label,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: p.ink, shape: CrescoShape.rectangle(), textStyle: label),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(shape: CrescoShape.rectangle())),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      floatingLabelStyle: TextStyle(color: p.ink, fontWeight: FontWeight.w600),
      border: field(p.line),
      enabledBorder: field(p.line),
      focusedBorder: field(p.ink),
    ),
    // Surfaces we never draw ourselves: cursor, selection, handles.
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.ink,
      selectionColor: p.effort.withValues(alpha: 0.35),
      selectionHandleColor: p.ink,
    ),
    // Choices (sex, level, Face/Dos): solid action color once selected, no check mark.
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10)),
        shape: WidgetStatePropertyAll(CrescoShape.rectangle()),
        textStyle: WidgetStatePropertyAll(TextStyle(fontFamily: family, fontSize: 15, fontWeight: FontWeight.w600)),
        side: WidgetStatePropertyAll(BorderSide(color: p.ink, width: CrescoShape.border)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.action : p.background,
        ),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.onAction : p.ink),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.background,
      selectedColor: p.action,
      checkmarkColor: p.onAction,
      side: BorderSide(color: p.line, width: CrescoShape.border),
      shape: CrescoShape.rectangle(),
      // The chip resolves a state color in labelStyle: the on-action color once selected.
      labelStyle: TextStyle(
        fontFamily: family,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: WidgetStateColor.resolveWith((s) => s.contains(WidgetState.selected) ? p.onAction : p.ink),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(2))),
      side: BorderSide(color: p.ink, width: CrescoShape.border),
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.action : Colors.transparent,
      ),
      checkColor: WidgetStatePropertyAll(p.onAction),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.effort : p.line),
      thumbColor: WidgetStatePropertyAll(p.background),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    sliderTheme: SliderThemeData(activeTrackColor: p.ink, inactiveTrackColor: p.line, thumbColor: p.ink),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.ink, linearTrackColor: p.line),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(CrescoShape.radius)),
      ),
    ),
    dialogTheme: DialogThemeData(backgroundColor: p.background, shape: CrescoShape.rectangle()),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.ink,
      contentTextStyle: TextStyle(fontFamily: family, color: p.background, fontSize: 15),
      shape: CrescoShape.rectangle(),
    ),
  );
}
