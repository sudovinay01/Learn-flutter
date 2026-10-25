import 'dart:convert';
import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:saf/saf.dart';

import 'mp4_background_task.dart';
import 'mp4_title_processor.dart';

void main() {
  FlutterForegroundTask.initCommunicationPort();
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'mp4_title_processing',
      channelName: 'MP4 title processing',
      channelDescription: 'Progress for MP4 title metadata processing.',
      onlyAlertOnce: true,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: false,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.nothing(),
      allowWakeLock: true,
      allowAutoRestart: true,
      stopWithTask: false,
    ),
  );
  runApp(const Mp4TitleCleanerApp());
}

class Mp4TitleCleanerApp extends StatefulWidget {
  const Mp4TitleCleanerApp({super.key});

  @override
  State<Mp4TitleCleanerApp> createState() => _Mp4TitleCleanerAppState();
}

class _Mp4TitleCleanerAppState extends State<Mp4TitleCleanerApp> {
  Color? _systemAccent;

  @override
  void initState() {
    super.initState();
    _loadSystemAccent();
  }

  Future<void> _loadSystemAccent() async {
    try {
      final palette = await DynamicColorPlugin.getCorePalette();
      if (palette != null && mounted) {
        setState(() => _systemAccent = Color(palette.primary.get(40)));
      }
    } on PlatformException catch (error) {
      debugPrint('Could not read the system accent color: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final seedColor = _systemAccent ?? Colors.indigo;
    final darkColorScheme =
        ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ).copyWith(
          surface: Colors.black,
          surfaceDim: Colors.black,
          surfaceBright: Colors.black,
          surfaceContainerLowest: Colors.black,
          surfaceContainerLow: Colors.black,
          surfaceContainer: Colors.black,
          surfaceContainerHigh: Colors.black,
          surfaceContainerHighest: Colors.black,
          surfaceTint: Colors.black,
        );

    return MaterialApp(
      title: 'MP4 Title Cleaner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: darkColorScheme,
        cardTheme: const CardThemeData(
          color: Colors.black,
          surfaceTintColor: Colors.black,
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Colors.black,
          surfaceTintColor: Colors.black,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.black,
          surfaceTintColor: Colors.black,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const Mp4TitleCleanerPage(),
    );
  }
}

enum _ResultStatus { pending, processing, updated, skipped, failed, cancelled }

class _FileResult {
  const _FileResult({required this.target, required this.status, this.message});

  final Mp4Target target;
  final _ResultStatus status;
  final String? message;
}

class Mp4TitleCleanerPage extends StatefulWidget {
  const Mp4TitleCleanerPage({super.key});

  @override
  State<Mp4TitleCleanerPage> createState() => _Mp4TitleCleanerPageState();
}

class _Mp4TitleCleanerPageState extends State<Mp4TitleCleanerPage> {
  final Saf _saf = Saf();
  SafDocumentFile? _selectedFolder;
  List<Mp4Target> _files = const [];
  List<_FileResult> _results = const [];
  List<Mp4Target> _operationTargets = const [];
  bool _isScanning = false;
  bool _isProcessing = false;
  bool _cancelRequested = false;
  int _processedCount = 0;
  int _operationTotal = 0;
  String? _currentFile;

  @override
  void initState() {
    super.initState();
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
    _restoreBackgroundJob();
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    super.dispose();
  }

  Future<void> _restoreBackgroundJob() async {
    try {
      final allFilesJson = await FlutterForegroundTask.getData<String>(
        key: 'mp4_all_files',
      );
      final resultsJson = await FlutterForegroundTask.getData<String>(
        key: 'mp4_job_results',
      );
      final stateJson = await FlutterForegroundTask.getData<String>(
        key: 'mp4_job_state',
      );
      final folderName = await FlutterForegroundTask.getData<String>(
        key: 'mp4_folder_name',
      );
      final operationTargetsJson = await FlutterForegroundTask.getData<String>(
        key: 'mp4_job_targets',
      );
      if (allFilesJson == null) return;

      final files = _decodeTargets(allFilesJson);
      final operationTargets = operationTargetsJson == null
          ? files
          : _decodeTargets(operationTargetsJson);
      final results = files
          .map(
            (file) => _FileResult(target: file, status: _ResultStatus.pending),
          )
          .toList();
      final isServiceRunning = await FlutterForegroundTask.isRunningService;

      if (!mounted) return;
      setState(() {
        _files = files;
        _results = results;
        _operationTargets = operationTargets;
        _selectedFolder = SafDocumentFile(
          uri: '',
          name: folderName ?? 'Selected folder',
          isDir: true,
          length: 0,
          lastModified: 0,
        );
        if (resultsJson != null) _applyPersistedResults(resultsJson);
        if (stateJson != null) {
          final state = Map<String, dynamic>.from(jsonDecode(stateJson) as Map);
          _applyTaskState(state, notify: false);
          _isProcessing =
              isServiceRunning &&
              state['type'] != 'jobFinished' &&
              state['type'] != 'jobFailed' &&
              state['type'] != 'jobInterrupted';
          if (!isServiceRunning && state['type'] == 'fileStarted') {
            _setResult(
              _FileResult(
                target: Mp4Target.fromJson(
                  Map<String, dynamic>.from(state['target'] as Map),
                ),
                status: _ResultStatus.failed,
                message:
                    'The background task stopped before reporting a result. '
                    'Check the original file before retrying.',
              ),
            );
          }
        }
      });
    } on PlatformException catch (error) {
      _showError('Could not restore the background job: ${error.message}');
    } catch (error) {
      _showError('Could not restore the background job: $error');
    }
  }

  List<Mp4Target> _decodeTargets(String json) {
    return (jsonDecode(json) as List<dynamic>)
        .map(
          (item) => Mp4Target.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<void> _chooseFolder() async {
    if (_isProcessing || _isScanning) return;

    try {
      final folder = await _saf.pickDirectory();
      if (folder == null || !mounted) return;

      setState(() {
        _selectedFolder = folder;
        _files = const [];
        _results = const [];
        _isScanning = true;
      });

      final files = <Mp4Target>[];
      await _scanFolder(folder, '', files);
      files.sort(
        (a, b) => a.relativePath.toLowerCase().compareTo(
          b.relativePath.toLowerCase(),
        ),
      );

      if (!mounted) return;
      setState(() {
        _files = files;
        _results = files
            .map(
              (file) =>
                  _FileResult(target: file, status: _ResultStatus.pending),
            )
            .toList();
        _isScanning = false;
      });
    } on PlatformException catch (error) {
      _showError('Could not access the selected folder: ${error.message}');
      _stopScanning();
    } on SafException catch (error) {
      _showError('Could not scan the selected folder: $error');
      _stopScanning();
    } catch (error) {
      _showError('Could not scan the selected folder: $error');
      _stopScanning();
    }
  }

  Future<void> _scanFolder(
    SafDocumentFile folder,
    String relativeDirectory,
    List<Mp4Target> files,
  ) async {
    final children = await _saf.list(folder.uri);
    for (final child in children) {
      final relativePath = relativeDirectory.isEmpty
          ? child.name
          : '$relativeDirectory/${child.name}';
      if (child.isDir) {
        await _scanFolder(child, relativePath, files);
      } else if (child.name.toLowerCase().endsWith('.mp4')) {
        files.add(
          Mp4Target(
            fileUri: child.uri,
            name: child.name,
            length: child.length,
            parentUri: folder.uri,
            relativePath: relativePath,
          ),
        );
      }
    }
  }

  void _stopScanning() {
    if (!mounted) return;
    setState(() => _isScanning = false);
  }

  Future<void> _confirmAndProcess() async {
    if (_files.isEmpty || _isProcessing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove MP4 titles?'),
        content: Text(
          'The app found ${_files.length} MP4 file(s) '
          '(${_formatBytes(_files.fold<int>(0, (sum, file) => sum + file.length))}).\n\n'
          'It will remove title metadata only. Files keep their names and '
          'folder locations. Originals are replaced only after the temporary '
          'result is verified.\n\n'
          'Processing continues in the background with an ongoing '
          'notification. Each file is processed separately and temporary '
          'storage is required.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirmed == true) await _processFiles(_files);
  }

  Future<void> _retryFailures() async {
    if (_isProcessing) return;
    final failed = _results
        .where((result) => result.status == _ResultStatus.failed)
        .map((result) => result.target)
        .toList();
    if (failed.isNotEmpty) await _processFiles(failed);
  }

  Future<void> _clearResults() async {
    if (_isProcessing) return;

    try {
      if (await FlutterForegroundTask.isRunningService) {
        _showError(
          'Wait for background processing to finish before clearing results.',
        );
        return;
      }

      for (final key in [
        'mp4_all_files',
        'mp4_folder_name',
        'mp4_job_results',
        'mp4_job_state',
        'mp4_job_targets',
        'mp4_job_cancel_requested',
      ]) {
        final removed = await FlutterForegroundTask.removeData(key: key);
        if (!removed) {
          throw StateError('Could not clear saved processing data.');
        }
      }

      if (!mounted) return;
      setState(() {
        _selectedFolder = null;
        _files = const [];
        _results = const [];
        _operationTargets = const [];
        _processedCount = 0;
        _operationTotal = 0;
        _currentFile = null;
        _cancelRequested = false;
      });
      _showMessage('Results and selected folder cleared.');
    } catch (error) {
      _showError('Could not clear results: $error');
    }
  }

  Future<void> _processFiles(List<Mp4Target> files) async {
    if (!Platform.isAndroid) {
      _showError('Background processing is available on Android only.');
      return;
    }
    if (await FlutterForegroundTask.isRunningService) {
      _showError('A background processing task is already running.');
      return;
    }

    try {
      var permission =
          await FlutterForegroundTask.checkNotificationPermission();
      if (permission != NotificationPermission.granted) {
        permission =
            await FlutterForegroundTask.requestNotificationPermission();
      }
      if (permission != NotificationPermission.granted) {
        _showError(
          'Allow notifications so Android can show background progress.',
        );
        return;
      }

      _operationTargets = files;
      _operationTotal = files.length;
      _processedCount = 0;
      _cancelRequested = false;
      await FlutterForegroundTask.saveData(
        key: 'mp4_all_files',
        value: jsonEncode(_files.map((file) => file.toJson()).toList()),
      );
      await FlutterForegroundTask.saveData(
        key: 'mp4_job_targets',
        value: jsonEncode(files.map((file) => file.toJson()).toList()),
      );
      await FlutterForegroundTask.saveData(
        key: 'mp4_job_cancel_requested',
        value: false,
      );
      await FlutterForegroundTask.saveData(
        key: 'mp4_job_results',
        value: jsonEncode(
          _results
              .map(
                (result) => {
                  ...result.target.toJson(),
                  'status': result.status.name,
                  'message': result.message,
                },
              )
              .toList(),
        ),
      );
      await FlutterForegroundTask.saveData(
        key: 'mp4_folder_name',
        value: _selectedFolder?.name ?? 'Selected folder',
      );

      if (mounted) {
        setState(() {
          _isProcessing = true;
          _currentFile = null;
        });
      }

      final result = await FlutterForegroundTask.startService(
        serviceId: 271,
        serviceTypes: const [ForegroundServiceTypes.dataSync],
        notificationTitle: 'Removing MP4 titles',
        notificationText: 'Preparing ${files.length} file(s)…',
        notificationButtons: const [
          NotificationButton(id: 'cancel', text: 'Stop'),
        ],
        callback: startMp4BackgroundTask,
      );

      switch (result) {
        case ServiceRequestSuccess():
          break;
        case ServiceRequestFailure(:final error):
          if (mounted) {
            setState(() => _isProcessing = false);
            _showError('Could not start background processing: $error');
          }
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showError('Could not start background processing: $error');
      }
    }
  }

  void _onTaskData(Object data) {
    if (data is! Map) return;
    final state = Map<String, dynamic>.from(data);
    if (!mounted) return;
    setState(() => _applyTaskState(state));
  }

  void _applyTaskState(Map<String, dynamic> state, {bool notify = true}) {
    final results = state['results'];
    if (results is List) _applyPersistedResults(jsonEncode(results));

    switch (state['type']) {
      case 'fileStarted':
        final target = Mp4Target.fromJson(
          Map<String, dynamic>.from(state['target'] as Map),
        );
        _isProcessing = true;
        _currentFile = target.relativePath;
        _processedCount = state['index'] as int;
        _operationTotal = state['total'] as int;
        _operationTargets = _operationTargets.isEmpty
            ? [target]
            : _operationTargets;
        break;
      case 'fileFinished':
        final target = Mp4Target.fromJson(
          Map<String, dynamic>.from(state['target'] as Map),
        );
        _setResult(
          _FileResult(
            target: target,
            status: _statusFromString(state['status'] as String),
            message: state['message'] as String?,
          ),
        );
        _processedCount = (state['index'] as int) + 1;
        _operationTotal = state['total'] as int;
        break;
      case 'jobFinished':
        _isProcessing = false;
        _currentFile = null;
        _cancelRequested = state['cancelled'] as bool? ?? false;
        if (notify) {
          _showMessage(
            _cancelRequested
                ? 'Processing stopped safely.'
                : 'Background processing finished.',
          );
        }
        break;
      case 'jobFailed':
      case 'jobInterrupted':
        _isProcessing = false;
        _currentFile = null;
        _showError(
          state['message'] as String? ?? 'Background processing stopped.',
        );
        break;
      case 'cancelRequested':
        _cancelRequested = true;
        break;
    }
  }

  void _applyPersistedResults(String json) {
    final results = jsonDecode(json) as List<dynamic>;
    for (final item in results) {
      final map = Map<String, dynamic>.from(item as Map);
      final target = Mp4Target.fromJson(map);
      _setResult(
        _FileResult(
          target: target,
          status: _statusFromString(map['status'] as String),
          message: map['message'] as String?,
        ),
      );
    }
  }

  _ResultStatus _statusFromString(String value) {
    return _ResultStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => _ResultStatus.failed,
    );
  }

  void _setResult(_FileResult updated) {
    final index = _results.indexWhere(
      (result) => result.target.fileUri == updated.target.fileUri,
    );
    if (index == -1) {
      _results = [..._results, updated];
    } else {
      final next = [..._results];
      next[index] = updated;
      _results = next;
    }
  }

  void _requestCancel() {
    if (_cancelRequested) return;
    FlutterForegroundTask.sendDataToTask('cancel');
    setState(() => _cancelRequested = true);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 6)),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalBytes = _files.fold<int>(0, (sum, file) => sum + file.length);
    final failedCount = _results
        .where((result) => result.status == _ResultStatus.failed)
        .length;
    final hasResults = _results.any(
      (result) => result.status != _ResultStatus.pending,
    );

    return WithForegroundTask(
      child: Scaffold(
        appBar: AppBar(title: const Text('MP4 Title Cleaner')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Icon(Icons.video_file_outlined, size: 56),
              const SizedBox(height: 12),
              Text(
                'Remove title metadata from MP4 files',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose a folder to scan it and its subfolders. Video and audio '
                'streams are copied without re-encoding.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _isProcessing || _isScanning ? null : _chooseFolder,
                icon: const Icon(Icons.folder_open),
                label: Text(
                  _selectedFolder == null
                      ? 'Choose folder'
                      : 'Choose another folder',
                ),
              ),
              if (_selectedFolder != null) ...[
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.folder),
                    title: Text(_selectedFolder!.name),
                    subtitle: Text(
                      _isScanning
                          ? 'Scanning folder and subfolders…'
                          : '${_files.length} MP4 file(s) · ${_formatBytes(totalBytes)}',
                    ),
                  ),
                ),
                if (hasResults && !_isProcessing)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _clearResults,
                      icon: const Icon(Icons.clear_all),
                      label: const Text('Clear results'),
                    ),
                  ),
              ],
              if (_isScanning) ...[
                const SizedBox(height: 20),
                const Center(child: CircularProgressIndicator()),
              ],
              if (_files.isNotEmpty && !_isProcessing) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _confirmAndProcess,
                  icon: const Icon(Icons.cleaning_services_outlined),
                  label: Text(
                    failedCount > 0
                        ? 'Process all files'
                        : 'Review and process',
                  ),
                ),
              ],
              if (_isProcessing) ...[
                const SizedBox(height: 20),
                LinearProgressIndicator(
                  value: _operationTotal == 0
                      ? null
                      : _processedCount / _operationTotal,
                ),
                const SizedBox(height: 8),
                Text(
                  'File ${_processedCount + 1} of $_operationTotal'
                  '${_currentFile == null ? '' : '\n$_currentFile'}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _cancelRequested ? null : _requestCancel,
                  child: Text(
                    _cancelRequested
                        ? 'Stopping after the current file…'
                        : 'Stop after the current file',
                  ),
                ),
              ],
              if (_files.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  'Background processing uses an ongoing notification. '
                  'Android may stop the task if the app is force-stopped or '
                  'the device shuts down. Temporary storage is required.',
                ),
                const SizedBox(height: 16),
                Text('Files', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final result in _results) _buildResultTile(result),
                if (failedCount > 0 && !_isProcessing)
                  FilledButton.tonalIcon(
                    onPressed: _retryFailures,
                    icon: const Icon(Icons.refresh),
                    label: Text('Retry $failedCount failed file(s)'),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultTile(_FileResult result) {
    final (icon, color, label) = switch (result.status) {
      _ResultStatus.pending => (Icons.schedule, null, 'Ready'),
      _ResultStatus.processing => (Icons.sync, null, 'Processing'),
      _ResultStatus.updated => (Icons.check_circle, Colors.green, 'Updated'),
      _ResultStatus.skipped => (Icons.remove_circle_outline, null, 'Skipped'),
      _ResultStatus.failed => (Icons.error_outline, Colors.red, 'Failed'),
      _ResultStatus.cancelled => (Icons.cancel_outlined, null, 'Cancelled'),
    };

    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(result.target.relativePath),
        subtitle: result.message == null
            ? Text('${_formatBytes(result.target.length)} · $label')
            : Text('$label · ${result.message}'),
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var size = bytes / 1024;
  var unitIndex = 0;
  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex++;
  }
  return '${size.toStringAsFixed(1)} ${units[unitIndex]}';
}
