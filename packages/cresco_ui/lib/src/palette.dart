import 'package:flutter/material.dart';

/// Color roles of docs/design/DESIGN.md, in a light and a dark variant.
///
/// Read it with `context.palette`. Lime is never text on a light background
/// (1.3:1): it is a fill under ink, or text on [hero].
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
    required this.lime,
    required this.onLime,
    required this.fast,
    required this.onFast,
    required this.danger,
    required this.dangerSoft,
    required this.onDangerSoft,
    required this.warningSoft,
    required this.onWarningSoft,
  });

  final Color background;
  final Color surface;
  final Color ink;
  final Color muted;
  final Color line;

  /// Main buttons and the active tab.
  final Color action;
  final Color onAction;

  /// Dark highlight cards (form score, verdict): white text, lime accents.
  final Color hero;
  final Color onHeroMuted;
  final Color lime;
  final Color onLime;

  /// Fasting and sleep cards.
  final Color fast;
  final Color onFast;
  final Color danger;
  final Color dangerSoft;
  final Color onDangerSoft;
  final Color warningSoft;
  final Color onWarningSoft;

  static const light = CrescoPalette(
    background: Color(0xFFF2F3EE),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF111311),
    muted: Color(0xFF5B6158),
    line: Color(0xFFECEDE6),
    action: Color(0xFF111311),
    onAction: Color(0xFFCDEB5A),
    hero: Color(0xFF111311),
    onHeroMuted: Color(0xFFC9CEC3),
    lime: Color(0xFFCDEB5A),
    onLime: Color(0xFF111311),
    fast: Color(0xFFDAD5FF),
    onFast: Color(0xFF2B2269),
    danger: Color(0xFFC2264A),
    dangerSoft: Color(0xFFFFD9DF),
    onDangerSoft: Color(0xFF5E1426),
    warningSoft: Color(0xFFFFE7C2),
    onWarningSoft: Color(0xFF6B4300),
  );

  static const dark = CrescoPalette(
    background: Color(0xFF0B0D0B),
    surface: Color(0xFF1A1D19),
    ink: Color(0xFFF2F3EE),
    muted: Color(0xFFA8AEA2),
    line: Color(0xFF2A2D27),
    action: Color(0xFFCDEB5A),
    onAction: Color(0xFF111311),
    hero: Color(0xFF1A1D19),
    onHeroMuted: Color(0xFFC9CEC3),
    lime: Color(0xFFCDEB5A),
    onLime: Color(0xFF111311),
    fast: Color(0xFF26214F),
    onFast: Color(0xFFDAD5FF),
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
    lime: lime,
    onLime: onLime,
    fast: fast,
    onFast: onFast,
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
      lime: mix(lime, other.lime),
      onLime: mix(onLime, other.onLime),
      fast: mix(fast, other.fast),
      onFast: mix(onFast, other.onFast),
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
