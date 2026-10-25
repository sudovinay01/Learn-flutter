# MP4 Title Cleaner

A Flutter Android app that removes title metadata from MP4 files in a folder.

## Use

1. Choose a folder with the Android folder picker. The app scans that folder
   and its subfolders for `.mp4` files.
2. Review the number and total size of the files, then confirm the operation.
3. The app processes one file at a time, skips files without title metadata,
   and shows an updated, skipped, failed, or cancelled result for each file.
   Failed files can be retried. When processing starts, Android displays an
   ongoing notification; the batch can continue when the app is minimized or
   its task is dismissed from Recents. Use **Clear results** near the selected
   folder summary to clear a completed batch's results and forget the selected
   folder and its file list.

The app stream-copies media rather than re-encoding it. It writes a temporary
result beside the original, checks that the result can be read and that its
media streams and title tags are correct, and then replaces the original.
The original filename and folder location are kept. If processing or
verification fails, the original is left in place. Stopping a batch takes
effect after the current file is safely handled.

Rewriting a video requires temporary free space in the app cache and selected
folder. The app copies the current video to its cache, creates and verifies a
stream-copied result, then writes a temporary result beside the original.
During remuxing, app-cache free space of about twice the current file size may
be needed; the selected folder also needs room for a temporary copy.
Android folder providers do not all expose reliable free-space information,
so the app processes files individually and reports a failure if the storage
provider or device cannot complete the rewrite.

The foreground service is allowed to restart if Android kills it, and saved
results prevent already completed files from being processed again. Force
stopping the app, shutting down the device, or an Android service timeout can
still interrupt a batch. Android 15 and later limit data-sync foreground
services to six hours per 24-hour period. Grant notification permission when
prompted so the ongoing progress notification is visible.

## Appearance

The app follows the system light or dark setting. On Android 12 and later, its
accent color is based on the system dynamic color palette; older versions use
indigo as a fallback. The dark theme uses a pure-black background.

## Platform and dependencies

- Android 7.0 (API 24) or later.
- Android Storage Access Framework access through `saf`.
- FFmpeg stream-copy remuxing through `ffmpeg_kit_flutter_new_min` (LGPL).
- System accent colors through `dynamic_color`.
