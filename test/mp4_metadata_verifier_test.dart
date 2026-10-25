import 'package:flutter_test/flutter_test.dart';
import 'package:ffmpeg_kit_flutter_new_min/media_information.dart';
import 'package:flutter_application_1/mp4_metadata_verifier.dart';

void main() {
  MediaInformation informationWithChapter(String title) => MediaInformation({
    'chapters': [
      {
        'id': 0,
        'tags': {'title': title},
      },
    ],
  });

  test('accepts an empty chapter title tag left by FFmpeg', () {
    expect(
      Mp4MetadataVerifier.hasTitleTag(informationWithChapter('')),
      isFalse,
    );
    expect(
      Mp4MetadataVerifier.titleTagLocations(informationWithChapter('')),
      isEmpty,
    );
  });

  test('accepts whitespace-only title values', () {
    final information = MediaInformation({
      'format': {
        'tags': {'title': '   '},
      },
      'streams': [
        {
          'tags': {'title': '\t'},
        },
      ],
      'chapters': [
        {
          'id': 0,
          'tags': {'title': '\n'},
        },
      ],
    });

    expect(Mp4MetadataVerifier.hasTitleTag(information), isFalse);
    expect(Mp4MetadataVerifier.titleTagLocations(information), isEmpty);
  });

  test('accepts FFprobe generated default chapter label', () {
    expect(
      Mp4MetadataVerifier.hasTitleTag(informationWithChapter('Chapter 1')),
      isFalse,
    );
  });

  test('diagnostics show chapter title value and generated-label decision', () {
    final diagnostics = Mp4MetadataVerifier.titleTagDiagnostics(
      informationWithChapter('Chapter 1'),
    );

    expect(diagnostics, contains('Chapter 0 (id=0)'));
    expect(diagnostics, contains('title="Chapter 1"'));
    expect(diagnostics, contains('generated-default-match=true'));
  });

  test('diagnostics identify non-default chapter title values', () {
    final diagnostics = Mp4MetadataVerifier.titleTagDiagnostics(
      informationWithChapter('Opening Scene'),
    );

    expect(diagnostics, contains('title="Opening Scene"'));
    expect(diagnostics, contains('generated-default-match=false'));
  });

  test('accepts case-insensitive generated labels with extra whitespace', () {
    expect(
      Mp4MetadataVerifier.hasTitleTag(informationWithChapter(' chapter 1 ')),
      isFalse,
    );
  });

  test('rejects a non-default chapter title', () {
    expect(
      Mp4MetadataVerifier.hasTitleTag(informationWithChapter('Opening Scene')),
      isTrue,
    );
  });

  test('checks the generated label against the chapter index', () {
    final secondChapter = MediaInformation({
      'chapters': [
        {
          'id': 0,
          'tags': {'title': 'Chapter 1'},
        },
        {
          'id': 1,
          'tags': {'title': 'Chapter 2'},
        },
      ],
    });

    expect(Mp4MetadataVerifier.hasTitleTag(secondChapter), isFalse);
  });

  test('rejects a title tag on a stream', () {
    final information = MediaInformation({
      'streams': [
        {
          'tags': {'title': 'Audio title'},
        },
      ],
    });

    expect(Mp4MetadataVerifier.hasTitleTag(information), isTrue);
  });

  test('rejects a title tag on the file', () {
    final information = MediaInformation({
      'format': {
        'tags': {'title': 'File title'},
      },
    });

    expect(Mp4MetadataVerifier.hasTitleTag(information), isTrue);
  });

  test('rejects title tags with non-default titles even if label-like', () {
    expect(
      Mp4MetadataVerifier.hasTitleTag(
        informationWithChapter('Chapter 2: Opening'),
      ),
      isTrue,
    );
  });
}
