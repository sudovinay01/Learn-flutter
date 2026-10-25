import 'package:ffmpeg_kit_flutter_new_min/media_information.dart';

class Mp4MetadataVerifier {
  static bool hasTitleTag(MediaInformation information) {
    if (_hasNonEmptyTitle(information.getTags())) return true;
    for (final stream in information.getStreams()) {
      if (_hasNonEmptyTitle(stream.getTags())) return true;
    }

    final chapters = information.getChapters();
    for (var index = 0; index < chapters.length; index++) {
      final tags = chapters[index].getTags();
      final title = _titleValue(tags);
      if (title == null || title.trim().isEmpty) continue;
      // FFprobe synthesizes "Chapter N" labels for chapters with no title tag.
      if (_isGeneratedChapterTitle(title, index)) continue;
      return true;
    }
    return false;
  }

  static String titleTagLocations(MediaInformation information) {
    final locations = <String>[];

    if (_hasNonEmptyTitle(information.getTags())) {
      locations.add('file metadata');
    }
    final streams = information.getStreams();
    for (var index = 0; index < streams.length; index++) {
      if (_hasNonEmptyTitle(streams[index].getTags())) {
        locations.add('stream $index');
      }
    }
    final chapters = information.getChapters();
    for (var index = 0; index < chapters.length; index++) {
      final title = _titleValue(chapters[index].getTags());
      if (title != null &&
          title.trim().isNotEmpty &&
          !_isGeneratedChapterTitle(title, index)) {
        locations.add('chapter $index');
      }
    }
    return locations.join(', ');
  }

  static String titleTagDiagnostics(MediaInformation information) {
    List<String> titleTags(Map<dynamic, dynamic>? tags) {
      if (tags == null) return const ['<none>'];
      final entries = tags.entries
          .where((entry) => entry.key.toString().toLowerCase() == 'title')
          .map((entry) => '${entry.key}=${_quote(entry.value)}')
          .toList();
      return entries.isEmpty ? const ['<none>'] : entries;
    }

    final lines = <String>[
      'Format title tags: ${titleTags(information.getTags()).join(', ')}',
    ];
    final streams = information.getStreams();
    for (var index = 0; index < streams.length; index++) {
      final stream = streams[index];
      lines.add(
        'Stream $index (${stream.getType() ?? 'unknown'}) title tags: '
        '${titleTags(stream.getTags()).join(', ')}',
      );
    }
    final chapters = information.getChapters();
    for (var index = 0; index < chapters.length; index++) {
      final chapter = chapters[index];
      final tags = titleTags(chapter.getTags());
      final title = _titleValue(chapter.getTags());
      lines.add(
        'Chapter $index (id=${chapter.getId() ?? 'unknown'}) title tags: '
        '${tags.join(', ')}; generated-default-match='
        '${title != null && _isGeneratedChapterTitle(title, index)}',
      );
    }
    return lines.join('\n');
  }

  static String? _titleValue(Map<dynamic, dynamic>? tags) {
    if (tags == null) return null;
    for (final entry in tags.entries) {
      if (entry.key.toString().toLowerCase() == 'title') {
        return entry.value?.toString() ?? '';
      }
    }
    return null;
  }

  static bool _hasNonEmptyTitle(Map<dynamic, dynamic>? tags) {
    final title = _titleValue(tags);
    return title != null && title.trim().isNotEmpty;
  }

  static String _quote(Object? value) {
    final text = value?.toString() ?? '<null>';
    final escaped = text
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\r', r'\r')
        .replaceAll('\n', r'\n');
    const maximumCharacters = 500;
    return '"${escaped.length <= maximumCharacters ? escaped : '${escaped.substring(0, maximumCharacters)}…'}"';
  }

  static bool _isGeneratedChapterTitle(String title, int index) =>
      title.trim().toLowerCase() == 'chapter ${index + 1}';
}
