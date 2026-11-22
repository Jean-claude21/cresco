import 'package:flutter/widgets.dart';

/// Line icons of design G, from Phosphor Icons (MIT, fonts bundled with this package).
///
/// Regular stroke by default, bold for an active state (tab bar). Code points come from
/// phosphor_flutter 2.1.0; add an icon here rather than mixing icon sets on a screen.
abstract final class CrescoIcons {
  static const _regular = 'PhosphorRegular';
  static const _bold = 'PhosphorBold';
  static const _package = 'cresco_ui';

  static const calendar = IconData(0xe10a, fontFamily: _regular, fontPackage: _package);
  static const calendarBold = IconData(0xe10a, fontFamily: _bold, fontPackage: _package);
  static const barbell = IconData(0xe0b6, fontFamily: _regular, fontPackage: _package);
  static const barbellBold = IconData(0xe0b6, fontFamily: _bold, fontPackage: _package);
  static const forkKnife = IconData(0xe262, fontFamily: _regular, fontPackage: _package);
  static const forkKnifeBold = IconData(0xe262, fontFamily: _bold, fontPackage: _package);
  static const chartBar = IconData(0xe150, fontFamily: _regular, fontPackage: _package);
  static const chartBarBold = IconData(0xe150, fontFamily: _bold, fontPackage: _package);
}
