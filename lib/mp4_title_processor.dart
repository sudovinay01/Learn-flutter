import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/media_information.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saf/saf.dart';

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
  const Mp4ProcessResult({required this.status, this.message});

  final String status;
  final String? message;

  Map<String, Object?> toJson() => {'status': status, 'message': message};
}

class Mp4TitleProcessor {
  Mp4TitleProcessor({Saf? saf}) : _saf = saf ?? Saf();

  final Saf _saf;

  Future<Mp4ProcessResult> process(
    Mp4Target target, {
    required bool Function() isCancellationRequested,
  }) async {
    String? temporaryUri;
    String? failureMessage;
    var status = 'failed';
    String? completionMessage;
    final localFiles = <File>[];

    try {
      final cacheDirectory = await getTemporaryDirectory();
      final uniqueId = DateTime.now().microsecondsSinceEpoch;
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
      if (!_hasTitleTag(sourceInformation)) {
        status = 'skipped';
        completionMessage = 'No title metadata was found.';
      } else {
        final ffmpegArguments = <String>[
          '-hide_banner',
          '-nostdin',
          '-y',
          '-i',
          inputFile.path,
          '-map',
          '0',
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
        ];
        if (sourceInformation.getChapters().isNotEmpty) {
          ffmpegArguments.addAll(['-metadata:c', 'title=']);
        }
        ffmpegArguments.addAll(['-f', 'mp4', outputFile.path]);
        final session = await FFmpegKit.executeWithArguments(ffmpegArguments);

        final returnCode = await session.getReturnCode();
        if (!ReturnCode.isSuccess(returnCode)) {
          final output = await session.getOutput();
          throw StateError(
            'FFmpeg could not rewrite the video. '
            '${_usefulOutput(output)}',
          );
        }

        final resultInformation = await _readMediaInformation(outputFile.path);
        if (_hasTitleTag(resultInformation)) {
          throw StateError(
            'The temporary video still contains title metadata.',
          );
        }
        if (!_preservedStreams(sourceInformation, resultInformation)) {
          throw StateError(
            'The temporary video did not preserve the original media streams.',
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
          if (_hasTitleTag(copiedInformation)) {
            throw StateError(
              'The copied temporary video still contains title metadata.',
            );
          }
          if (!_preservedStreams(sourceInformation, copiedInformation)) {
            throw StateError(
              'The copied temporary video did not preserve the original media streams.',
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
            completionMessage = 'Title metadata removed; filename unchanged.';
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
          if (status == 'pending' || status == 'processing') {
            status = 'failed';
          }
        }
      }
    }

    return Mp4ProcessResult(
      status: status,
      message: failureMessage ?? completionMessage,
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

  bool _hasTitleTag(MediaInformation information) {
    bool hasTitle(Map<dynamic, dynamic>? tags) {
      if (tags == null) return false;
      return tags.keys.any((key) => key.toString().toLowerCase() == 'title');
    }

    if (hasTitle(information.getTags())) return true;
    for (final stream in information.getStreams()) {
      if (hasTitle(stream.getTags())) return true;
    }
    for (final chapter in information.getChapters()) {
      if (hasTitle(chapter.getTags())) return true;
    }
    return false;
  }

  bool _preservedStreams(
    MediaInformation original,
    MediaInformation processed,
  ) {
    final originalStreams = original.getStreams();
    final processedStreams = processed.getStreams();
    if (originalStreams.length != processedStreams.length) return false;
    for (var index = 0; index < originalStreams.length; index++) {
      if (originalStreams[index].getCodec() !=
              processedStreams[index].getCodec() ||
          originalStreams[index].getType() !=
              processedStreams[index].getType()) {
        return false;
      }
    }
    return true;
  }

  String _usefulOutput(String? output) {
    final trimmed = output?.trim();
    if (trimmed == null || trimmed.isEmpty) return '';
    return trimmed.length <= 600
        ? trimmed
        : trimmed.substring(trimmed.length - 600);
  }
}
