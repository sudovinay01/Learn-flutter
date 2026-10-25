# MP4 Title Cleaner

A Flutter Android app that removes title metadata from MP4 files in a folder.

## Use

1. Choose a folder with the Android folder picker. The app scans that folder
   and its subfolders for `.mp4` files.
2. Review the number and total size of the files, then confirm the operation.
3. The app processes up to two files at a time when the device has sufficient
   CPU, memory, and reliably measurable free space. If a resource check is
   unavailable or uncertain, it processes one file at a time. Files without
   title metadata are skipped, and each file gets an updated, skipped, failed,
   or cancelled result. Failed files can be retried, and **Show log** on a
   failed result opens copyable diagnostic information, including the parsed
   title tags and stream type, codec, and codec-tag values at each verification
   stage, plus packet counts when stream verification fails. When processing
   starts, Android displays an ongoing notification; the batch can continue
   when the app is minimized or its task is dismissed from Recents. Use
   **Clear results** near the selected folder summary to clear a completed
   batch's results and forget the selected folder and its file list.

The app stream-copies media rather than re-encoding it. It writes a temporary
result beside the original, checks that the result can be read and that its
media streams and title tags are correct, and then replaces the original.
Chapter timing is preserved while chapter title tags are removed.
Empty or whitespace-only title values left by the media tools are treated as
cleared; non-empty title values still fail verification. A data stream is
ignored only if FFprobe confirms it contains no packets; non-empty streams must
still be preserved. MP4 timecode (`tmcd`) data tracks are omitted for viewing
compatibility; they contain production timecode metadata, not video or audio.
The original filename and folder location are kept. If processing or
verification fails, the original is left in place. Stopping a batch takes
effect after the current file is safely handled.

Rewriting a video requires temporary free space in the app cache and selected
folder. The app copies the current video to its cache, creates and verifies a
stream-copied result, then writes a temporary result beside the original.
During remuxing, app-cache free space of about twice the current file size may
be needed; the selected folder also needs room for a temporary copy.
Android folder providers do not all expose reliable free-space information.
The app only enables two-file processing when it can estimate both app-cache
and selected-volume free space and there is enough headroom for the two largest
files in the batch. It also requires at least four CPU cores and 1.5 GiB of
available memory. Otherwise it processes sequentially. These are conservative
estimates, not guarantees: free space can change during a run, and a storage
provider or device may still fail a rewrite. Such failures are reported per
file, and an original is not replaced unless its temporary result passes
verification.

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
