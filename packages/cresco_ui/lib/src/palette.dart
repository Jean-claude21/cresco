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
    required this.limeSoft,
    required this.onLimeSoft,
    required this.accent,
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

  /// Soft green fills (illustrations, avatars) and the text drawn on them.
  final Color limeSoft;
  final Color onLimeSoft;

  /// Second data color (protein, history curves).
  final Color accent;

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
    limeSoft: Color(0xFFE4F2C0),
    onLimeSoft: Color(0xFF34470A),
    accent: Color(0xFF6B5CE7),
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
    limeSoft: Color(0xFF2C3A12),
    onLimeSoft: Color(0xFFE4F2C0),
    accent: Color(0xFF9C92F2),
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
    limeSoft: limeSoft,
    onLimeSoft: onLimeSoft,
    accent: accent,
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
      limeSoft: mix(limeSoft, other.limeSoft),
      onLimeSoft: mix(onLimeSoft, other.onLimeSoft),
      accent: mix(accent, other.accent),
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
  TextStyle get overlineStyle => TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: palette.muted);
  TextStyle get unitStyle => TextStyle(fontSize: 17, color: palette.muted);
  TextStyle get verseStyle => TextStyle(
    fontFamily: 'packages/cresco_ui/Gelasio',
    fontFamilyFallback: const ['Georgia', 'serif'],
    fontSize: 16,
    fontStyle: FontStyle.italic,
    color: palette.muted,
  );
}
