import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Keeps a workout running with the screen off.
///
/// Android: a foreground service of type `mediaPlayback` (the voice cues) with a wake lock and an
/// ongoing notification that shows the current step; the timer itself stays in the app and reads
/// the wall clock, so nothing drifts while the CPU sleeps. iOS: the `audio` background mode keeps
/// the voice cues playing (Info.plist). Any failure falls back to the screen staying on.
abstract final class WorkoutKeepAlive {
  static bool _running = false;

  static bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static Future<void> start({required String title, required String text}) async {
    if (!_supported || _running) return;
    try {
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'seance',
          channelName: 'Séance en cours',
          channelDescription: 'Minuteur et annonces de la séance, écran éteint',
          onlyAlertOnce: true,
        ),
        iosNotificationOptions: const IOSNotificationOptions(showNotification: false),
        foregroundTaskOptions: ForegroundTaskOptions(eventAction: ForegroundTaskEventAction.nothing()),
      );
      // No permission prompt: on Android 13+ the service runs even when its notification may not
      // be shown, and a system dialog in the middle of a session would be worse than no notice.
      final result = await FlutterForegroundTask.startService(
        serviceId: 1307,
        serviceTypes: Platform.isAndroid ? [ForegroundServiceTypes.mediaPlayback] : null,
        notificationTitle: title,
        notificationText: text,
        callback: _startCallback,
      );
      _running = result is ServiceRequestSuccess;
    } on Object catch (e) {
      debugPrint('WorkoutKeepAlive: $e');
    }
  }

  /// Text of the ongoing notification (current step and time left).
  static Future<void> update({required String title, required String text}) async {
    if (!_running) return;
    try {
      await FlutterForegroundTask.updateService(notificationTitle: title, notificationText: text);
    } on Object catch (e) {
      debugPrint('WorkoutKeepAlive: $e');
    }
  }

  static Future<void> stop() async {
    if (!_running) return;
    _running = false;
    try {
      await FlutterForegroundTask.stopService();
    } on Object catch (e) {
      debugPrint('WorkoutKeepAlive: $e');
    }
  }
}

@pragma('vm:entry-point')
void _startCallback() => FlutterForegroundTask.setTaskHandler(_IdleHandler());

/// The service only keeps the process alive: the workout logic runs in the app.
class _IdleHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}
