import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/processing_capacity.dart';
import 'package:flutter_application_1/mp4_title_processor.dart';

void main() {
  const resources = ProcessingResources(
    availableProcessors: 8,
    availableMemoryBytes: 4 * 1024 * 1024 * 1024,
    cacheAvailableBytes: 4 * 1024 * 1024 * 1024,
    folderAvailableBytes: 4 * 1024 * 1024 * 1024,
  );
  const files = [
    Mp4Target(
      fileUri: 'file://first',
      name: 'first.mp4',
      length: 100 * 1024 * 1024,
      parentUri: 'folder://test',
      relativePath: 'first.mp4',
    ),
    Mp4Target(
      fileUri: 'file://second',
      name: 'second.mp4',
      length: 100 * 1024 * 1024,
      parentUri: 'folder://test',
      relativePath: 'second.mp4',
    ),
  ];

  test('allows two files when device and storage have safe headroom', () {
    expect(ProcessingCapacity.forBatch(files, resources), 2);
  });

  test('uses one worker when storage information is unavailable', () {
    const unknownStorage = ProcessingResources(
      availableProcessors: 8,
      availableMemoryBytes: 4 * 1024 * 1024 * 1024,
      cacheAvailableBytes: null,
      folderAvailableBytes: 4 * 1024 * 1024 * 1024,
    );

    expect(ProcessingCapacity.forBatch(files, unknownStorage), 1);
  });

  test('uses one worker when the device has too few CPU cores', () {
    const limitedCpu = ProcessingResources(
      availableProcessors: 2,
      availableMemoryBytes: 4 * 1024 * 1024 * 1024,
      cacheAvailableBytes: 4 * 1024 * 1024 * 1024,
      folderAvailableBytes: 4 * 1024 * 1024 * 1024,
    );

    expect(ProcessingCapacity.forBatch(files, limitedCpu), 1);
  });

  test('uses one worker when available memory is low', () {
    const limitedMemory = ProcessingResources(
      availableProcessors: 8,
      availableMemoryBytes: 1024 * 1024 * 1024,
      cacheAvailableBytes: 4 * 1024 * 1024 * 1024,
      folderAvailableBytes: 4 * 1024 * 1024 * 1024,
    );

    expect(ProcessingCapacity.forBatch(files, limitedMemory), 1);
  });

  test('uses one worker when free space cannot fit two large inputs', () {
    const limitedStorage = ProcessingResources(
      availableProcessors: 8,
      availableMemoryBytes: 4 * 1024 * 1024 * 1024,
      cacheAvailableBytes: 500 * 1024 * 1024,
      folderAvailableBytes: 4 * 1024 * 1024 * 1024,
    );

    expect(ProcessingCapacity.forBatch(files, limitedStorage), 1);
  });

  test('never schedules more workers than files in the batch', () {
    expect(ProcessingCapacity.forBatch([files.first], resources), 1);
  });

  test('uses one worker when a file size cannot be measured', () {
    final unknownSize = [
      files.first,
      Mp4Target(
        fileUri: 'file://second',
        name: 'second.mp4',
        length: 0,
        parentUri: 'folder://test',
        relativePath: 'second.mp4',
      ),
    ];

    expect(ProcessingCapacity.forBatch(unknownSize, resources), 1);
  });
}
