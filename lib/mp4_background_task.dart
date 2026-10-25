import 'dart:async';
import 'dart:convert';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'mp4_title_processor.dart';

@pragma('vm:entry-point')
void startMp4BackgroundTask() {
  FlutterForegroundTask.setTaskHandler(Mp4BackgroundTaskHandler());
}

class Mp4BackgroundTaskHandler extends TaskHandler {
  static const _cancelCommand = 'cancel';
  final Mp4TitleProcessor _processor = Mp4TitleProcessor();
  bool _cancelRequested = false;
  List<Map<String, dynamic>> _results = [];

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    try {
      _cancelRequested =
          await FlutterForegroundTask.getData<bool>(
            key: 'mp4_job_cancel_requested',
          ) ??
          false;
      final targetsJson = await FlutterForegroundTask.getData<String>(
        key: 'mp4_job_targets',
      );
      if (targetsJson == null) {
        throw StateError('The saved MP4 processing list is missing.');
      }

      final targets = (jsonDecode(targetsJson) as List<dynamic>)
          .map(
            (target) =>
                Mp4Target.fromJson(Map<String, dynamic>.from(target as Map)),
          )
          .toList();
      final resultsJson = await FlutterForegroundTask.getData<String>(
        key: 'mp4_job_results',
      );
      if (resultsJson != null) {
        _results = (jsonDecode(resultsJson) as List<dynamic>)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }

      for (var index = 0; index < targets.length; index++) {
        if (_cancelRequested) break;
        final target = targets[index];
        final previousResult = _resultFor(target);
        if (previousResult?['status'] == 'updated' ||
            previousResult?['status'] == 'skipped' ||
            previousResult?['status'] == 'failed' ||
            previousResult?['status'] == 'cancelled') {
          continue;
        }
        _updateResult(target, 'processing');
        await _publishState({
          'type': 'fileStarted',
          'target': target.toJson(),
          'index': index,
          'total': targets.length,
          'results': _results,
        });
        await FlutterForegroundTask.updateService(
          notificationTitle: 'Removing MP4 titles',
          notificationText: 'File ${index + 1} of ${targets.length}',
          notificationButtons: const [
            NotificationButton(id: _cancelCommand, text: 'Stop'),
          ],
        );

        final result = await _processor.process(
          target,
          isCancellationRequested: () => _cancelRequested,
        );
        _updateResult(target, result.status, message: result.message);
        await _publishState({
          'type': 'fileFinished',
          'target': target.toJson(),
          ...result.toJson(),
          'index': index,
          'total': targets.length,
          'results': _results,
        });
      }

      if (_cancelRequested) {
        for (final target in targets) {
          _updateResult(
            target,
            'cancelled',
            message: 'Not processed because the batch was stopped.',
            onlyIfPending: true,
          );
        }
      }
      await _publishState({
        'type': 'jobFinished',
        'cancelled': _cancelRequested,
        'total': targets.length,
        'results': _results,
      });
      await FlutterForegroundTask.updateService(
        notificationTitle: 'MP4 title processing finished',
        notificationText: _cancelRequested
            ? 'Stopped safely. Open the app to review results.'
            : 'Finished. Open the app to review results.',
        notificationButtons: const [],
      );
      await FlutterForegroundTask.stopService();
    } catch (error) {
      await _publishState({
        'type': 'jobFailed',
        'message': error.toString(),
        'results': _results,
      });
      await FlutterForegroundTask.updateService(
        notificationTitle: 'MP4 processing stopped',
        notificationText: 'Open the app to see the error.',
        notificationButtons: const [],
      );
      await FlutterForegroundTask.stopService();
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    if (isTimeout) {
      await _publishState({
        'type': 'jobInterrupted',
        'message': 'Android stopped the foreground task because of a timeout.',
      });
    }
  }

  @override
  void onReceiveData(Object data) {
    if (data == _cancelCommand) {
      _cancelRequested = true;
      unawaited(
        FlutterForegroundTask.saveData(
          key: 'mp4_job_cancel_requested',
          value: true,
        ),
      );
      FlutterForegroundTask.sendDataToMain({'type': 'cancelRequested'});
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == _cancelCommand) {
      _cancelRequested = true;
      unawaited(
        FlutterForegroundTask.saveData(
          key: 'mp4_job_cancel_requested',
          value: true,
        ),
      );
      FlutterForegroundTask.sendDataToMain({'type': 'cancelRequested'});
    }
  }

  Future<void> _publishState(Map<String, Object?> state) async {
    await FlutterForegroundTask.saveData(
      key: 'mp4_job_results',
      value: jsonEncode(_results),
    );
    await FlutterForegroundTask.saveData(
      key: 'mp4_job_state',
      value: jsonEncode(state),
    );
    FlutterForegroundTask.sendDataToMain(state);
  }

  void _updateResult(
    Mp4Target target,
    String status, {
    String? message,
    bool onlyIfPending = false,
  }) {
    final index = _results.indexWhere(
      (result) => result['fileUri'] == target.fileUri,
    );
    if (index == -1) return;
    if (onlyIfPending && _results[index]['status'] != 'pending') return;
    _results[index] = {
      ..._results[index],
      'status': status,
      'message': message,
    };
  }

  Map<String, dynamic>? _resultFor(Mp4Target target) {
    for (final result in _results) {
      if (result['fileUri'] == target.fileUri) return result;
    }
    return null;
  }
}
