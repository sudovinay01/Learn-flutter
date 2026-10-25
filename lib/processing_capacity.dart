import 'mp4_title_processor.dart';

class ProcessingResources {
  const ProcessingResources({
    required this.availableProcessors,
    required this.availableMemoryBytes,
    required this.cacheAvailableBytes,
    required this.folderAvailableBytes,
  });

  final int? availableProcessors;
  final int? availableMemoryBytes;
  final int? cacheAvailableBytes;
  final int? folderAvailableBytes;

  factory ProcessingResources.fromMap(Map<Object?, Object?> values) {
    return ProcessingResources(
      availableProcessors: values['availableProcessors'] as int?,
      availableMemoryBytes: values['availableMemoryBytes'] as int?,
      cacheAvailableBytes: values['cacheAvailableBytes'] as int?,
      folderAvailableBytes: values['folderAvailableBytes'] as int?,
    );
  }
}

class ProcessingCapacity {
  static const maxConcurrentFiles = 2;
  static const _bytesPerMiB = 1024 * 1024;
  static const _minimumAvailableMemoryBytes = 1536 * _bytesPerMiB;
  static const _minimumStorageReserveBytes = 64 * _bytesPerMiB;

  static int forBatch(List<Mp4Target> files, ProcessingResources resources) {
    if (files.length < 2 || files.any((file) => file.length <= 0)) return 1;

    final processors = resources.availableProcessors;
    final availableMemory = resources.availableMemoryBytes;
    final cacheAvailable = resources.cacheAvailableBytes;
    final folderAvailable = resources.folderAvailableBytes;
    if (processors == null ||
        processors < 4 ||
        availableMemory == null ||
        availableMemory < _minimumAvailableMemoryBytes ||
        cacheAvailable == null ||
        folderAvailable == null) {
      return 1;
    }

    final largestFiles = files.map((file) => file.length).toList()..sort();
    final largestPairBytes =
        largestFiles[largestFiles.length - 1] +
        largestFiles[largestFiles.length - 2];
    final requiredBytes =
        (largestPairBytes * 2.25).ceil() + _minimumStorageReserveBytes;

    return cacheAvailable >= requiredBytes && folderAvailable >= requiredBytes
        ? maxConcurrentFiles
        : 1;
  }
}
