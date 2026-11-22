import 'package:cresco_app/ui/health_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

HealthDataPoint _asleep(DateTime from, DateTime to) => HealthDataPoint(
  uuid: '$from',
  value: NumericHealthValue(numericValue: to.difference(from).inMinutes),
  type: HealthDataType.SLEEP_ASLEEP,
  unit: HealthDataUnit.MINUTE,
  dateFrom: from,
  dateTo: to,
  sourcePlatform: HealthPlatformType.appleHealth,
  sourceDeviceId: 'test',
  sourceId: 'test',
  sourceName: 'test',
);

void main() {
  test('asleep segments less than 2 h apart make one night; naps are left out', () {
    final nights = nightsFrom([
      _asleep(DateTime.utc(2026, 11, 20, 22, 30), DateTime.utc(2026, 11, 21, 2)),
      // Woken 40 min, then asleep again.
      _asleep(DateTime.utc(2026, 11, 21, 2, 40), DateTime.utc(2026, 11, 21, 6, 10)),
      // Afternoon nap: 1 h.
      _asleep(DateTime.utc(2026, 11, 21, 14), DateTime.utc(2026, 11, 21, 15)),
    ]);
    expect(nights, hasLength(1));
    expect(nights.single['coucher'], '2026-11-20T22:30:00.000Z');
    expect(nights.single['lever'], '2026-11-21T06:10:00.000Z');
    expect(nights.single['dormiMin'], 210 + 210);
  });
}
