import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/media_information.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saf/saf.dart';

import 'mp4_metadata_verifier.dart';

class Mp4Target {
  const Mp4Target({
    required this.fileUri,
    required this.name,
    required this.length,
    required this.parentUri,
    required this.relativePath,
  });

  final String fileUri;
  final String name;
  final int length;
  final String parentUri;
  final String relativePath;

  Map<String, Object> toJson() => {
    'fileUri': fileUri,
    'name': name,
    'length': length,
    'parentUri': parentUri,
    'relativePath': relativePath,
  };

  factory Mp4Target.fromJson(Map<String, dynamic> json) => Mp4Target(
    fileUri: json['fileUri'] as String,
    name: json['name'] as String,
    length: json['length'] as int,
    parentUri: json['parentUri'] as String,
    relativePath: json['relativePath'] as String,
  );
}

class Mp4ProcessResult {
  const Mp4ProcessResult({required this.status, this.message, this.log});

  final String status;
  final String? message;
  final String? log;

  Map<String, Object?> toJson() => {
    'status': status,
    'message': message,
    'log': log,
  };
}

class _StreamPacketProbe {
  const _StreamPacketProbe({required this.packetCounts, this.problem});

  final Map<int, String> packetCounts;
  final String? problem;

  String describe() {
    if (problem != null) return problem!;
    if (packetCounts.isEmpty) return 'No stream packet counts were returned.';
    return packetCounts.entries
        .map((entry) => 'stream ${entry.key}: ${entry.value} packets')
        .join('\n');
  }
}

class Mp4TitleProcessor {
  Mp4TitleProcessor({Saf? saf}) : _saf = saf ?? Saf();

  static int _temporaryFileSequence = 0;
  final Saf _saf;

  Future<Mp4ProcessResult> process(
    Mp4Target target, {
    required bool Function() isCancellationRequested,
  }) async {
    String? temporaryUri;
    String? failureMessage;
    String? failureLog;
    String? ffmpegLog;
    final verificationDiagnostics = <String>[];
    var status = 'failed';
    String? completionMessage;
    final localFiles = <File>[];

    try {
      final cacheDirectory = await getTemporaryDirectory();
      final uniqueId =
          '${DateTime.now().microsecondsSinceEpoch}-${_temporaryFileSequence++}';
      final inputFile = File(
        '${cacheDirectory.path}${Platform.pathSeparator}title-cleaner-input-$uniqueId.mp4',
      );
      final outputFile = File(
        '${cacheDirectory.path}${Platform.pathSeparator}title-cleaner-output-$uniqueId.mp4',
      );
      final verifyFile = File(
        '${cacheDirectory.path}${Platform.pathSeparator}title-cleaner-verify-$uniqueId.mp4',
      );
      localFiles.addAll([inputFile, outputFile, verifyFile]);

      await _saf.copyToLocalFile(target.fileUri, inputFile.path);

      final sourceInformation = await _readMediaInformation(inputFile.path);
      verificationDiagnostics.add(
        'Source media information:\n'
        '${_mediaDiagnostics(sourceInformation)}',
      );
      if (!Mp4MetadataVerifier.hasTitleTag(sourceInformation)) {
        status = 'skipped';
        completionMessage = 'No title metadata was found.';
      } else {
        final timecodeStreamIndexes =
            Mp4MetadataVerifier.timecodeDataStreamIndexes(sourceInformation);
        final ignoredSourceStreamIndexes = timecodeStreamIndexes.toSet();
        if (timecodeStreamIndexes.isNotEmpty) {
          verificationDiagnostics.add(
            'Omitting timecode data stream(s) for viewing compatibility: '
            '${timecodeStreamIndexes.join(', ')}',
          );
        }
        final ffmpegArguments = <String>[
          '-hide_banner',
          '-nostdin',
          '-y',
          '-i',
          inputFile.path,
        ];
        final sourceStreams = sourceInformation.getStreams();
        for (var index = 0; index < sourceStreams.length; index++) {
          final streamIndex = sourceStreams[index].getIndex() ?? index;
          if (timecodeStreamIndexes.contains(index)) continue;
          ffmpegArguments.addAll(['-map', '0:$streamIndex']);
        }
        ffmpegArguments.addAll([
          '-map_metadata',
          '0',
          '-map_chapters',
          '0',
          '-c',
          'copy',
          '-metadata',
          'title=',
          '-metadata:s',
          'title=',
        ]);
        if (timecodeStreamIndexes.isNotEmpty) {
          ffmpegArguments.addAll(['-metadata:s:v', 'timecode=']);
        }
        if (sourceInformation.getChapters().isNotEmpty) {
          ffmpegArguments.addAll(['-metadata:c', 'title=']);
        }
        ffmpegArguments.addAll(['-f', 'mp4', outputFile.path]);
        final session = await FFmpegKit.executeWithArguments(ffmpegArguments);
        ffmpegLog = await session.getAllLogsAsString();

        final returnCode = await session.getReturnCode();
        if (!ReturnCode.isSuccess(returnCode)) {
          throw StateError(
            'FFmpeg could not rewrite the video. '
            '${_usefulOutput(ffmpegLog)}',
          );
        }

        final resultInformation = await _readMediaInformation(outputFile.path);
        verificationDiagnostics.add(
          'FFmpeg output media information:\n'
          '${_mediaDiagnostics(resultInformation)}',
        );
        if (Mp4MetadataVerifier.hasTitleTag(resultInformation)) {
          throw StateError(
            'The temporary video still contains title metadata in '
            '${Mp4MetadataVerifier.titleTagLocations(resultInformation)}.',
          );
        }
        final emptyDataStreamIndexes = <int>{};
        var streamIssue = _streamPreservationIssue(
          sourceInformation,
          resultInformation,
          ignoredOriginalStreamIndexes: ignoredSourceStreamIndexes,
        );
        if (streamIssue != null) {
          final sourcePacketCounts = await _streamPacketCounts(inputFile.path);
          final outputPacketCounts = await _streamPacketCounts(outputFile.path);
          verificationDiagnostics.add(
            'FFprobe counted packets by stream:\n'
            'Source:\n${sourcePacketCounts.describe()}\n'
            'Output:\n${outputPacketCounts.describe()}',
          );
          if (sourcePacketCounts.problem == null) {
            for (var index = 0; index < sourceStreams.length; index++) {
              final stream = sourceStreams[index];
              final streamIndex = stream.getIndex() ?? index;
              final packetCount = sourcePacketCounts.packetCounts[streamIndex];
              if (stream.getType() == 'data' &&
                  (packetCount == 'N/A' || packetCount == '0')) {
                emptyDataStreamIndexes.add(index);
              }
            }
            if (emptyDataStreamIndexes.isNotEmpty) {
              verificationDiagnostics.add(
                'Ignored confirmed empty data stream indexes: '
                '${emptyDataStreamIndexes.join(', ')}',
              );
              ignoredSourceStreamIndexes.addAll(emptyDataStreamIndexes);
              streamIssue = _streamPreservationIssue(
                sourceInformation,
                resultInformation,
                ignoredOriginalStreamIndexes: ignoredSourceStreamIndexes,
              );
            }
          }
        }
        if (streamIssue != null) {
          throw StateError(
            'The temporary video did not preserve the original media streams: '
            '$streamIssue',
          );
        }

        if (isCancellationRequested()) {
          status = 'cancelled';
          completionMessage = 'Cancelled before replacing the original.';
        } else {
          await inputFile.delete();
          final backupName = 'title-cleaner-backup-$uniqueId.mp4';
          final temporaryName = 'title-cleaner-$uniqueId.mp4';
          final temporaryFile = await _saf.pasteLocalFile(
            outputFile.path,
            target.parentUri,
            temporaryName,
            'video/mp4',
          );
          temporaryUri = temporaryFile.uri;
          await outputFile.delete();

          await _saf.copyToLocalFile(temporaryUri, verifyFile.path);
          final copiedInformation = await _readMediaInformation(
            verifyFile.path,
          );
          verificationDiagnostics.add(
            'SAF-copied temporary media information:\n'
            '${_mediaDiagnostics(copiedInformation)}',
          );
          if (Mp4MetadataVerifier.hasTitleTag(copiedInformation)) {
            throw StateError(
              'The copied temporary video still contains title metadata in '
              '${Mp4MetadataVerifier.titleTagLocations(copiedInformation)}.',
            );
          }
          final copiedStreamIssue = _streamPreservationIssue(
            sourceInformation,
            copiedInformation,
            ignoredOriginalStreamIndexes: ignoredSourceStreamIndexes,
          );
          if (copiedStreamIssue != null) {
            throw StateError(
              'The copied temporary video did not preserve the original media '
              'streams: $copiedStreamIssue',
            );
          }
          await verifyFile.delete();

          if (isCancellationRequested()) {
            status = 'cancelled';
            completionMessage = 'Cancelled before replacing the original; the original was not changed.';
          } else {
            final backupFile = await _saf.rename(target.fileUri, backupName);
            try {
              await _saf.rename(temporaryUri, target.name);
              temporaryUri = null;
            } catch (replaceError) {
              try {
                await _saf.rename(backupFile.uri, target.name);
              } catch (restoreError) {
                throw StateError(
                  'Could not install the verified video ($replaceError) or '
                  'restore the original name ($restoreError). The original is '
                  'still available as "$backupName".',
                );
              }
              throw StateError(
                'Could not replace the original. It was restored unchanged: '
                '$replaceError',
              );
            }

            status = 'updated';
            completionMessage = timecodeStreamIndexes.isEmpty
                ? 'Title metadata removed; filename unchanged.'
                : 'Title metadata removed; timecode metadata discarded for '
                      'viewing compatibility; filename unchanged.';
            try {
              await _saf.delete(backupFile.uri);
            } catch (cleanupError) {
              completionMessage =
                  '$completionMessage Backup cleanup failed: $cleanupError';
            }
          }
        }
      }
    } catch (error) {
      status = 'failed';
      failureMessage = error.toString();
      failureLog = [
        error.toString(),
        if (ffmpegLog != null && ffmpegLog.isNotEmpty) ffmpegLog,
        if (verificationDiagnostics.isNotEmpty)
          verificationDiagnostics.join('\n\n'),
      ].join('\n\n');
    } finally {
      if (temporaryUri != null) {
        try {
          await _saf.delete(temporaryUri);
        } catch (cleanupError) {
          final cleanupMessage =
              'Temporary file cleanup failed ($cleanupError).';
          failureMessage = failureMessage == null
              ? cleanupMessage
              : '$failureMessage $cleanupMessage';
          failureLog =
              '${failureLog == null ? '' : '$failureLog\n\n'}$cleanupMessage';
          status = 'failed';
        }
      }
      for (final file in localFiles) {
        try {
          if (await file.exists()) await file.delete();
        } catch (cleanupError) {
          final cleanupMessage =
              'Local temporary file cleanup failed (${file.path}): $cleanupError.';
          failureMessage = failureMessage == null
              ? cleanupMessage
              : '$failureMessage $cleanupMessage';
          failureLog =
              '${failureLog == null ? '' : '$failureLog\n\n'}$cleanupMessage';
          if (status == 'pending' || status == 'processing') {
            status = 'failed';
          }
        }
      }
    }

    return Mp4ProcessResult(
      status: status,
      message: failureMessage ?? completionMessage,
      log: failureLog == null ? null : _limitDiagnosticLog(failureLog),
    );
  }

  Future<MediaInformation> _readMediaInformation(String path) async {
    final session = await FFprobeKit.getMediaInformation(path);
    final returnCode = await session.getReturnCode();
    final information = session.getMediaInformation();
    if (!ReturnCode.isSuccess(returnCode) || information == null) {
      throw StateError(
        'Could not read video metadata. ${_usefulOutput(await session.getOutput())}',
      );
    }
    return information;
  }

  String _mediaDiagnostics(MediaInformation information) {
    final streamLines = <String>[];
    final streams = information.getStreams();
    for (var index = 0; index < streams.length; index++) {
      final stream = streams[index];
      final properties = stream.getAllProperties();
      streamLines.add(
        'Stream $index: index=${stream.getIndex() ?? 'unknown'}, '
        'type=${stream.getType() ?? 'unknown'}, '
        'codec=${stream.getCodec() ?? 'unknown'}, '
        'codec_tag_string=${properties?['codec_tag_string'] ?? 'unknown'}, '
        'codec_tag=${properties?['codec_tag'] ?? 'unknown'}',
      );
    }
    return [
      Mp4MetadataVerifier.titleTagDiagnostics(information),
      'Streams (${streams.length}):\n${streamLines.join('\n')}',
    ].join('\n');
  }

  String? _streamPreservationIssue(
    MediaInformation original,
    MediaInformation processed, {
    Set<int> ignoredOriginalStreamIndexes = const {},
  }) {
    final originalStreams = original
        .getStreams()
        .indexed
        .where((entry) => !ignoredOriginalStreamIndexes.contains(entry.$1))
        .map((entry) => entry.$2)
        .toList();
    final processedStreams = processed.getStreams();
    if (originalStreams.length != processedStreams.length) {
      return 'stream count changed from ${originalStreams.length} '
          '(after excluding confirmed empty data streams) to '
          '${processedStreams.length}.';
    }
    for (var index = 0; index < originalStreams.length; index++) {
      final source = originalStreams[index];
      final output = processedStreams[index];
      if (source.getCodec() != output.getCodec() ||
          source.getType() != output.getType()) {
        return 'stream $index changed from '
            '${source.getType() ?? 'unknown'}/${source.getCodec() ?? 'unknown'} '
            'to ${output.getType() ?? 'unknown'}/'
            '${output.getCodec() ?? 'unknown'}.';
      }
    }
    return null;
  }

  Future<_StreamPacketProbe> _streamPacketCounts(String path) async {
    final session = await FFprobeKit.executeWithArguments([
      '-v',
      'quiet',
      '-count_packets',
      '-show_entries',
      'stream=index,codec_type,codec_name,nb_read_packets',
      '-of',
      'csv=p=0',
      path,
    ]);
    final returnCode = await session.getReturnCode();
    final output = await session.getOutput();
    if (!ReturnCode.isSuccess(returnCode) || output == null) {
      return _StreamPacketProbe(
        packetCounts: const {},
        problem: 'Packet count probe failed. ${_usefulOutput(output)}',
      );
    }
    final rows = output
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) => line.split(','))
        .where(
          (fields) =>
              fields.length == 4 &&
              int.tryParse(fields[0]) != null &&
              fields[1].isNotEmpty &&
              fields[2].isNotEmpty &&
              fields[3].isNotEmpty,
        )
        .toList();
    if (rows.isEmpty) {
      return _StreamPacketProbe(
        packetCounts: const {},
        problem: 'No packet-count rows were returned. ${_usefulOutput(output)}',
      );
    }
    return _StreamPacketProbe(
      packetCounts: {for (final row in rows) int.parse(row[0]): row[3]},
    );
  }

  String _usefulOutput(String? output) {
    final trimmed = output?.trim();
    if (trimmed == null || trimmed.isEmpty) return '';
    return trimmed.length <= 600
        ? trimmed
        : trimmed.substring(trimmed.length - 600);
  }

  String _limitDiagnosticLog(String log) {
    const maximumCharacters = 12000;
    if (log.length <= maximumCharacters) return log;
    const prefixCharacters = 2000;
    const suffixCharacters = maximumCharacters - prefixCharacters;
    return '${log.substring(0, prefixCharacters)}\n'
        '[Middle of log truncated]\n'
        '${log.substring(log.length - suffixCharacters)}';
  }
}
