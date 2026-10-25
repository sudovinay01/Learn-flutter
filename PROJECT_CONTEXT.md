# Project context

This document gives future contributors and coding assistants a concise map of
the app, its safety requirements, and its build workflow. User-facing usage
information is in [README.md](./README.md).

## App purpose

MP4 Title Cleaner is an Android Flutter app that recursively scans a
user-selected folder for `.mp4` files and removes title metadata. It must keep
each file's original name and folder location. Video and audio are stream-copied
without re-encoding.

## Main flow

1. The Android Storage Access Framework (SAF) folder picker grants access to a
   folder. The app recursively scans it and lists MP4 targets.
2. The user reviews the scan and confirms processing.
3. Before starting the foreground service, Android resource information is
   checked. The batch uses at most two workers when CPU, available memory,
   app-cache space, and selected-volume space are sufficient and known;
   otherwise it uses one worker. Processing is cancellable and reports
   per-file outcomes.
4. For each target, the processor copies the source to app cache, uses FFmpeg to
   remux it, verifies the output with FFprobe, writes a temporary result beside
   the source, verifies that copy, and only then replaces the original.
5. The original name and folder are preserved. If the verified replacement
   cannot be installed, the code attempts to restore the original name from its
   backup.
6. **Clear results** clears the displayed results and the saved batch and folder
   state, returning the UI to its initial state. It must not interrupt a
   running service.

## Source map

- `lib/main.dart` — system-aware light/dark themes, dynamic accent color,
  folder selection and scanning, batch UI, persisted state restoration, and
  clear/retry/cancel actions.
- `lib/mp4_title_processor.dart` — per-file SAF/cache/FFmpeg/FFprobe processing,
  verification, replacement, rollback, cleanup, and bounded diagnostic logs
  returned for failed files.
- `lib/mp4_background_task.dart` — foreground-service entry point, queue
  processing, bounded concurrent workers, serialized progress persistence and
  notifications, and cancellation handling.
- `lib/processing_capacity.dart` — conservative CPU, memory, and storage rules
  for choosing one or two workers.
- `android/app/src/main/kotlin/com/example/flutter_application_1/MainActivity.kt`
  — Android resource probe for processor count, available memory, and free
  cache/selected-volume space; unknown folder-provider space forces sequential
  processing.
- `android/app/src/main/AndroidManifest.xml` — foreground-service permissions
  and service declaration.
- `android/app/build.gradle.kts` — Android app configuration; minimum SDK is
  API 24 for the FFmpeg dependency.
- `README.md` — end-user workflow, storage needs, appearance, and Android
  background-processing limitations.

## Important invariants

- Never rename a user's MP4 or move it to a different folder as the final
  result.
- Never replace the original until the temporary output has passed metadata
  and stream checks.
- Preserve all streams that contain packets. Some MP4s have an empty data
  stream used as a QT chapter-track placeholder; FFmpeg may omit it during
  remuxing. Ignore a missing data stream only when FFprobe packet counting
  confirms its packet count is zero or unavailable (`N/A`); never ignore
  missing video, audio, or non-empty data streams.
- Preserve chapter timing while removing chapter title metadata. FFprobe can
  report generated labels such as `Chapter 1` even when FFmpeg's output has no
  chapter title metadata; treat only the exact, index-matching `Chapter N`
  label as generated. Treat empty or whitespace-only title values as cleared,
  and continue rejecting all other non-empty chapter title values.
- Preserve a bounded diagnostic log for failed files so users can inspect and
  copy the reason for a failure, including stream count/type/codec comparisons
  and packet counts when media stream verification fails. Truncation must keep
  both the error and final verification diagnostics.
- Process no more than two videos at a time. Use one worker if device/storage
  information is unknown or estimates do not provide safe headroom. Temporary
  free space is needed in app cache and in the selected folder.
- Do not clear persisted job state while its foreground service is running.
  The foreground-task plugin stores both job data and its own service
  configuration; remove only the app's job-data keys rather than clearing all
  plugin data.
- Keep the dynamic accent and system light/dark selection. The dark theme uses
  black surfaces; older Android versions without dynamic colors use indigo.
- The app currently uses a placeholder Android application ID and debug
  signing configuration. Configure a unique application ID and secure release
  signing before public distribution.

## Dependencies and platform

The Flutter package dependencies are declared in `pubspec.yaml`, with resolved
versions in `pubspec.lock`. Important packages:

- `saf` for Android folder/document access.
- `ffmpeg_kit_flutter_new_min` for FFmpeg/FFprobe operations.
- `flutter_foreground_task` for Android background processing.
- `dynamic_color` for Android system accent colors.
- `path_provider` for app-cache paths.

The app targets Android API 24 and later. Android 15 and later impose a
six-hour-per-24-hour limit on data-sync foreground services. Force-stopping the
app, shutting down the device, revoking folder access, provider limitations,
or low storage can interrupt or prevent processing.

## Build and checks

Run these from the repository root with Flutter/Dart installed:

```powershell
flutter pub get
dart format lib
flutter analyze
flutter build apk --debug
flutter build apk --release
```

The generated APKs are under `build/app/outputs/flutter-apk/`. The universal
debug APK is large because it includes multiple Android ABIs; release
distribution should use an appropriately signed build and can use
`flutter build apk --release --split-per-abi` for smaller ABI-specific APKs.
