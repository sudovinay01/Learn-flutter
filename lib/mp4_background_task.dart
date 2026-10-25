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
  int _maxConcurrentFiles = 1;
  List<Mp4Target> _operationTargets = const [];
  List<Map<String, dynamic>> _results = [];
  Future<void> _stateUpdateTail = Future<void>.value();

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
      _operationTargets = targets;
      _maxConcurrentFiles =
          (await FlutterForegroundTask.getData<int>(
                    key: 'mp4_max_concurrent_files',
                  ) ??
                  1)
              .clamp(1, 2)
              .toInt();
      final resultsJson = await FlutterForegroundTask.getData<String>(
        key: 'mp4_job_results',
      );
      if (resultsJson != null) {
        _results = (jsonDecode(resultsJson) as List<dynamic>)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }

      var nextIndex = 0;
      Future<void> processNext() async {
        while (!_cancelRequested) {
          if (nextIndex >= targets.length) return;
          final index = nextIndex++;
          final target = targets[index];
          final previousResult = _resultFor(target);
          if (previousResult?['status'] == 'updated' ||
              previousResult?['status'] == 'skipped') {
            continue;
          }

          _updateResult(target, 'processing');
          await _publishState({
            'type': 'fileStarted',
            'target': target.toJson(),
            'index': index,
            'total': targets.length,
          });

          final result = await _processor.process(
            target,
            isCancellationRequested: () => _cancelRequested,
          );
          _updateResult(
            target,
            result.status,
            message: result.message,
            log: result.log,
          );
          await _publishState({
            'type': 'fileFinished',
            'target': target.toJson(),
            ...result.toJson(),
            'index': index,
            'total': targets.length,
          });
        }
      }

      final workerCount = targets.isEmpty
          ? 0
          : _maxConcurrentFiles.clamp(1, targets.length).toInt();
      await Future.wait(List.generate(workerCount, (_) => processNext()));

      if (_cancelRequested) {
        for (final target in targets) {
          final status = _resultFor(target)?['status'];
          if (status == 'pending' || status == 'processing') {
            _updateResult(
              target,
              'cancelled',
              message: 'Not processed because the batch was stopped.',
            );
          }
        }
      }
      await _publishState({
        'type': 'jobFinished',
        'cancelled': _cancelRequested,
        'total': targets.length,
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
      await _publishState({'type': 'jobFailed', 'message': error.toString()});
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
    final previous = _stateUpdateTail;
    final completed = Completer<void>();
    _stateUpdateTail = completed.future;
    await previous;

    try {
      final results = _results
          .map((result) => Map<String, dynamic>.from(result))
          .toList();
      final operationResults = _operationTargets
          .map(_resultFor)
          .whereType<Map<String, dynamic>>();
      final completedCount = operationResults
          .where(
            (result) =>
                result['status'] != 'pending' &&
                result['status'] != 'processing',
          )
          .length;
      final activeCount = operationResults
          .where((result) => result['status'] == 'processing')
          .length;
      final publishedState = {
        ...state,
        'results': results,
        'completed': completedCount,
        'active': activeCount,
      };

      await FlutterForegroundTask.saveData(
        key: 'mp4_job_results',
        value: jsonEncode(results),
      );
      await FlutterForegroundTask.saveData(
        key: 'mp4_job_state',
        value: jsonEncode(publishedState),
      );
      FlutterForegroundTask.sendDataToMain(publishedState);

      if (state['type'] == 'fileStarted' || state['type'] == 'fileFinished') {
        await FlutterForegroundTask.updateService(
          notificationTitle: 'Removing MP4 titles',
          notificationText:
              '$completedCount of ${state['total']} complete · '
              '$activeCount active',
          notificationButtons: const [
            NotificationButton(id: _cancelCommand, text: 'Stop'),
          ],
        );
      }
    } finally {
      completed.complete();
    }
  }

  void _updateResult(
    Mp4Target target,
    String status, {
    String? message,
    String? log,
  }) {
    final index = _results.indexWhere(
      (result) => result['fileUri'] == target.fileUri,
    );
    if (index == -1) return;
    _results[index] = {
      ..._results[index],
      'status': status,
      'message': message,
      'log': log,
    };
  }

  Map<String, dynamic>? _resultFor(Mp4Target target) {
    for (final result in _results) {
      if (result['fileUri'] == target.fileUri) return result;
    }
    return null;
  }
}
