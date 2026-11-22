import 'package:flutter/material.dart';

/// Color roles of the validated design (docs/design/DESIGN.md, direction G "Net et braise"),
/// in a light and a dark variant. Read it with `context.palette`.
///
/// - Daily screens are black on white; [action] is black (white in dark mode).
/// - [effort] (braise orange) marks effort only: start, validate, load, muscle heat.
///   Its text is [onEffort], dark: white on braise would be 3:1, below WCAG AA.
/// - [rest] (glacier blue) marks rest, sleep and fasting.
@immutable
class CrescoPalette extends ThemeExtension<CrescoPalette> {
  const new({
    required this.background,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.line,
    required this.action,
    required this.onAction,
    required this.hero,
    required this.onHeroMuted,
    required this.effort,
    required this.onEffort,
    required this.effortSoft,
    required this.onEffortSoft,
    required this.rest,
    required this.onRest,
    required this.restSoft,
    required this.onRestSoft,
    required this.danger,
    required this.dangerSoft,
    required this.onDangerSoft,
    required this.warningSoft,
    required this.onWarningSoft,
  });

  final Color background;

  /// Cards, fields and tiles; always drawn with a [line] outline (Picnic shape).
  final Color surface;
  final Color ink;
  final Color muted;
  final Color line;

  /// Main buttons and the active tab.
  final Color action;
  final Color onAction;

  /// Solid black highlight cards (today's session). Text on it is white.
  final Color hero;
  final Color onHeroMuted;

  final Color effort;
  final Color onEffort;
  final Color effortSoft;
  final Color onEffortSoft;

  final Color rest;
  final Color onRest;
  final Color restSoft;
  final Color onRestSoft;

  final Color danger;
  final Color dangerSoft;
  final Color onDangerSoft;
  final Color warningSoft;
  final Color onWarningSoft;

  static const light = CrescoPalette(
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFF6F6F6),
    ink: Color(0xFF0A0A0A),
    muted: Color(0xFF616161),
    line: Color(0xFFE2E2E2),
    action: Color(0xFF0A0A0A),
    onAction: Color(0xFFFFFFFF),
    hero: Color(0xFF0A0A0A),
    onHeroMuted: Color(0xFFBDBDBD),
    effort: Color(0xFFFF5A1F),
    onEffort: Color(0xFF0A0A0A),
    effortSoft: Color(0xFFFFE6DB),
    onEffortSoft: Color(0xFF8A2A05),
    rest: Color(0xFF38BDF8),
    onRest: Color(0xFF0A0A0A),
    restSoft: Color(0xFFE3F5FD),
    onRestSoft: Color(0xFF075985),
    danger: Color(0xFFC2264A),
    dangerSoft: Color(0xFFFFE4E8),
    onDangerSoft: Color(0xFF5E1426),
    warningSoft: Color(0xFFFFF1D6),
    onWarningSoft: Color(0xFF6B4300),
  );

  static const dark = CrescoPalette(
    background: Color(0xFF0A0A0A),
    surface: Color(0xFF161616),
    ink: Color(0xFFF5F5F5),
    muted: Color(0xFFA3A3A3),
    line: Color(0xFF2A2A2A),
    action: Color(0xFFF5F5F5),
    onAction: Color(0xFF0A0A0A),
    hero: Color(0xFF161616),
    onHeroMuted: Color(0xFFBDBDBD),
    effort: Color(0xFFFF5A1F),
    onEffort: Color(0xFF0A0A0A),
    effortSoft: Color(0xFF3A1A0E),
    onEffortSoft: Color(0xFFFFD2BF),
    rest: Color(0xFF38BDF8),
    onRest: Color(0xFF0A0A0A),
    restSoft: Color(0xFF0C2A3A),
    onRestSoft: Color(0xFFBAE6FD),
    danger: Color(0xFFFF8FA3),
    dangerSoft: Color(0xFF3A1820),
    onDangerSoft: Color(0xFFFFD9DF),
    warningSoft: Color(0xFF3A2A10),
    onWarningSoft: Color(0xFFFFE7C2),
  );

  @override
  CrescoPalette copyWith({Color? background, Color? surface, Color? ink, Color? muted}) => CrescoPalette(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    ink: ink ?? this.ink,
    muted: muted ?? this.muted,
    line: line,
    action: action,
    onAction: onAction,
    hero: hero,
    onHeroMuted: onHeroMuted,
    effort: effort,
    onEffort: onEffort,
    effortSoft: effortSoft,
    onEffortSoft: onEffortSoft,
    rest: rest,
    onRest: onRest,
    restSoft: restSoft,
    onRestSoft: onRestSoft,
    danger: danger,
    dangerSoft: dangerSoft,
    onDangerSoft: onDangerSoft,
    warningSoft: warningSoft,
    onWarningSoft: onWarningSoft,
  );

  @override
  CrescoPalette lerp(CrescoPalette? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return CrescoPalette(
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      ink: mix(ink, other.ink),
      muted: mix(muted, other.muted),
      line: mix(line, other.line),
      action: mix(action, other.action),
      onAction: mix(onAction, other.onAction),
      hero: mix(hero, other.hero),
      onHeroMuted: mix(onHeroMuted, other.onHeroMuted),
      effort: mix(effort, other.effort),
      onEffort: mix(onEffort, other.onEffort),
      effortSoft: mix(effortSoft, other.effortSoft),
      onEffortSoft: mix(onEffortSoft, other.onEffortSoft),
      rest: mix(rest, other.rest),
      onRest: mix(onRest, other.onRest),
      restSoft: mix(restSoft, other.restSoft),
      onRestSoft: mix(onRestSoft, other.onRestSoft),
      danger: mix(danger, other.danger),
      dangerSoft: mix(dangerSoft, other.dangerSoft),
      onDangerSoft: mix(onDangerSoft, other.onDangerSoft),
      warningSoft: mix(warningSoft, other.warningSoft),
      onWarningSoft: mix(onWarningSoft, other.onWarningSoft),
    );
  }
}

/// `context.palette`: the current [CrescoPalette], light when the theme has none.
extension CrescoPaletteContext on BuildContext {
  CrescoPalette get palette => Theme.of(this).extension<CrescoPalette>() ?? CrescoPalette.light;
}

/// Secondary text styles in the current theme's muted color (they follow dark mode).
extension CrescoMutedStyles on BuildContext {
  TextStyle get mutedStyle => TextStyle(fontSize: 14, height: 1.35, color: palette.muted);
  TextStyle get overlineStyle =>
      TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: palette.muted);
  TextStyle get unitStyle => TextStyle(fontSize: 17, color: palette.muted);
  TextStyle get verseStyle => TextStyle(
    fontFamily: 'packages/cresco_ui/Gelasio',
    fontFamilyFallback: const ['Georgia', 'serif'],
    fontSize: 16,
    fontStyle: FontStyle.italic,
    color: palette.muted,
  );
}
