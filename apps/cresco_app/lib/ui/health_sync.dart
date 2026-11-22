import 'dart:io';

import 'package:cresco_data/cresco_data.dart';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reads sleep, heart-rate variability, resting heart rate, steps and weight from Health Connect
/// (Android) or Apple Santé (iOS), and sends them to Cresco. The server skips what it already has,
/// so a sync can run at every launch.
class HealthSync {
  new(this._api, {Health? health}) : _health = health ?? Health();
  final CrescoApi _api;
  final Health _health;

  static const _key = 'sante_connectee';

  static bool get supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// HRV is RMSSD on Health Connect and SDNN on Apple Santé: both go to the `vfc` measure,
  /// which the form score reads as a deviation from the user's own baseline (C-FORME).
  static List<HealthDataType> get types => [
    if (Platform.isAndroid) HealthDataType.SLEEP_SESSION else HealthDataType.SLEEP_ASLEEP,
    if (Platform.isAndroid) HealthDataType.HEART_RATE_VARIABILITY_RMSSD else HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.STEPS,
    HealthDataType.WEIGHT,
  ];

  String get _source => Platform.isAndroid ? 'health_connect' : 'apple_sante';

  /// Name shown to the user.
  static String get appName => !kIsWeb && Platform.isIOS ? 'Apple Santé' : 'Health Connect';

  Future<bool> get connected async => (await SharedPreferences.getInstance()).getBool(_key) ?? false;

  /// Asks the read permissions, then imports the last [days] days. False when nothing was granted
  /// or Health Connect is missing.
  Future<bool> connect({int days = 30}) async {
    if (!supported) return false;
    await _health.configure();
    if (Platform.isAndroid && !await _health.isHealthConnectAvailable()) {
      await _health.installHealthConnect();
      return false;
    }
    final granted = await _health.requestAuthorization(
      types,
      permissions: [for (final _ in types) HealthDataAccess.READ],
    );
    if (!granted) return false;
    await (await SharedPreferences.getInstance()).setBool(_key, true);
    await sync(days: days);
    return true;
  }

  Future<void> disconnect() async {
    await (await SharedPreferences.getInstance()).setBool(_key, false);
  }

  /// Imports the last [days] days when connected. Returns what the server added.
  Future<({int nights, int measures})> sync({int days = 3}) async {
    if (!supported || !await connected) return (nights: 0, measures: 0);
    await _health.configure();
    final end = DateTime.now();
    final start = DateTime(end.year, end.month, end.day).subtract(Duration(days: days));
    final points = _health.removeDuplicates(
      await _health.getHealthDataFromTypes(types: types, startTime: start, endTime: end),
    );
    final nights = nightsFrom(
      points.where((p) => p.type == HealthDataType.SLEEP_SESSION || p.type == HealthDataType.SLEEP_ASLEEP),
    );
    final measures = <Map<String, Object?>>[
      for (final p in points)
        if (_measureType(p.type) case final type? when p.value is NumericHealthValue)
          {
            'type': type,
            'valeur': (p.value as NumericHealthValue).numericValue,
            'le': p.dateTo.toUtc().toIso8601String(),
          },
    ];
    // Steps: one total per local day, dated at its midnight.
    for (var d = 0; d <= days; d++) {
      final dayStart = DateTime(start.year, start.month, start.day + d);
      if (dayStart.isAfter(end)) break;
      final dayEnd = dayStart.add(const Duration(days: 1));
      final steps = await _health.getTotalStepsInInterval(dayStart, dayEnd.isAfter(end) ? end : dayEnd);
      if (steps > 0) measures.add({'type': 'pas', 'valeur': steps, 'le': dayStart.toUtc().toIso8601String()});
    }
    final r = await _api.importSante({'source': _source, 'nuits': nights, 'mesures': measures});
    return (nights: (r['nuits'] as num? ?? 0).toInt(), measures: (r['mesures'] as num? ?? 0).toInt());
  }

  static String? _measureType(HealthDataType t) => switch (t) {
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD || HealthDataType.HEART_RATE_VARIABILITY_SDNN => 'vfc',
    HealthDataType.RESTING_HEART_RATE => 'fc_repos',
    HealthDataType.WEIGHT => 'poids',
    _ => null,
  };
}

/// Nights from sleep points: a Health Connect session is one night; Apple Santé gives asleep
/// segments, joined into one night when less than 2 h apart. Naps under 3 h are left out.
@visibleForTesting
List<Map<String, Object?>> nightsFrom(Iterable<HealthDataPoint> points) {
  final segments = [for (final p in points) (p.dateFrom, p.dateTo)]..sort((a, b) => a.$1.compareTo(b.$1));
  final nights = <(DateTime, DateTime, int)>[];
  for (final (from, to) in segments) {
    final minutes = to.difference(from).inMinutes;
    if (nights.isNotEmpty && from.difference(nights.last.$2) < const Duration(hours: 2)) {
      final (start, end, asleep) = nights.removeLast();
      nights.add((start, to.isAfter(end) ? to : end, asleep + minutes));
    } else {
      nights.add((from, to, minutes));
    }
  }
  return [
    for (final (start, end, asleep) in nights)
      if (asleep >= 180)
        {
          'coucher': start.toUtc().toIso8601String(),
          'lever': end.toUtc().toIso8601String(),
          'dormiMin': asleep.clamp(0, 1440),
        },
  ];
}
