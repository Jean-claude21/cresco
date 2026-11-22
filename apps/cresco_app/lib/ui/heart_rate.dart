import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Bluetooth heart-rate sensor (chest strap, armband, watch in broadcast mode) through the
/// standard Heart Rate service (0x180D, measurement 0x2A37).
class HeartRateMonitor extends ChangeNotifier {
  new _();
  static final HeartRateMonitor instance = HeartRateMonitor._();

  static final _service = Guid('180D');
  static final _measurement = Guid('2A37');

  BluetoothDevice? _device;
  StreamSubscription<List<int>>? _values;
  StreamSubscription<BluetoothConnectionState>? _state;

  /// Last beats per minute, null when no sensor sends data.
  int? bpm;

  /// Name of the connected sensor.
  String? get deviceName => _device?.platformName;
  bool get connected => _device != null;

  /// Sensors around, found by their Heart Rate service (scans for [timeout]).
  Stream<List<ScanResult>> scan({Duration timeout = const Duration(seconds: 8)}) {
    unawaited(
      FlutterBluePlus.startScan(withServices: [_service], timeout: timeout).catchError((Object e) {
        debugPrint('HeartRateMonitor scan: $e');
      }),
    );
    return FlutterBluePlus.scanResults;
  }

  Future<void> stopScan() => FlutterBluePlus.stopScan();

  /// Whether Bluetooth can be used on this device right now.
  Future<bool> get available async {
    try {
      if (!await FlutterBluePlus.isSupported) return false;
      return FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on ||
          await FlutterBluePlus.adapterState.first.timeout(const Duration(seconds: 2)) == BluetoothAdapterState.on;
    } on Object {
      return false;
    }
  }

  Future<void> connect(BluetoothDevice device) async {
    await disconnect();
    await stopScan();
    await device.connect(timeout: const Duration(seconds: 12));
    _device = device;
    _state = device.connectionState.listen((s) {
      if (s == BluetoothConnectionState.disconnected) {
        bpm = null;
        notifyListeners();
      }
    });
    final services = await device.discoverServices();
    final hr = services.firstWhere((s) => s.uuid == _service);
    final characteristic = hr.characteristics.firstWhere((c) => c.uuid == _measurement);
    await characteristic.setNotifyValue(true);
    _values = characteristic.onValueReceived.listen((v) {
      bpm = parseMeasurement(v);
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> disconnect() async {
    await _values?.cancel();
    await _state?.cancel();
    _values = null;
    _state = null;
    final device = _device;
    _device = null;
    bpm = null;
    notifyListeners();
    if (device != null) {
      try {
        await device.disconnect();
      } on Object catch (e) {
        debugPrint('HeartRateMonitor: $e');
      }
    }
  }
}

/// Beats per minute from a Heart Rate Measurement value (Bluetooth GATT 0x2A37): bit 0 of the
/// flags says whether the rate is on one byte or on two (little endian). Null when malformed.
int? parseMeasurement(List<int> value) {
  if (value.length < 2) return null;
  final wide = value[0] & 0x01 == 1;
  if (wide) return value.length < 3 ? null : value[1] | (value[2] << 8);
  return value[1];
}
