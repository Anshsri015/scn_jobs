import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:scn_jobs/domain/entities/upload_cancel_token.dart';

/// Runs UploadThing's real JS client (`genUploader` from
/// `uploadthing@7/client`) inside a hidden `WebView` to upload a file,
/// instead of hand-rolling UploadThing's presigned-URL wire protocol in
/// Dart/Dio.
///
/// ✅ This is a deliberate reversal from the previous approach
/// (`UploadRemoteDataSource`'s old Dio-based presigned-PUT flow) — that
/// was already the THIRD guess at UploadThing's undocumented wire
/// shape (field names for the presign response, whether it's PUT or a
/// signed POST, etc. were never confirmed), and kept breaking for the
/// same root reason each time: nothing published spells out the raw
/// REST protocol, only the JS client does. The teammate's
/// `resume-upload-tester.html` is CONFIRMED working — it calls
/// `genUploader(...).uploadFiles(...)` and succeeds. This class runs
/// that exact same client code, verbatim, so there is no protocol left
/// to reverse-engineer.
///
/// This needs a [BuildContext] — unlike a normal Dio-based datasource,
/// a `WebView` has to actually be mounted somewhere in the widget tree
/// to reliably execute JavaScript on both Android and iOS (a
/// controller with no attached `WebViewWidget` is not guaranteed to
/// run JS on iOS in particular). [uploadResume] pushes a transparent,
/// effectively invisible 1×1 `WebViewWidget` into the nearest
/// `Overlay`, waits for the upload to finish (or fail), then removes
/// it — the person never sees a browser, just their existing progress
/// UI in `ResumeUploadScreen`.
class UploadThingWebViewUploader {
  const UploadThingWebViewUploader();

  /// [baseUrl] should be `AppConfig.baseUrl` (already ends in `/api`,
  /// so this resolves to `.../api/uploadthing` — matching the doc).
  /// [routeSlug] is the UploadThing file-route name (`resumeUploader`,
  /// `profilePhotoUploader`, etc.) — never a REST path segment.
  Future<String> upload({
    required BuildContext context,
    required String baseUrl,
    required String routeSlug,
    required String filePath,
    required String fileName,
    required String contentType,
    required String token,
    UploadCancelToken? cancelToken,
    void Function(double progressPercent)? onProgress,
  }) async {
    final bytes = await File(filePath).readAsBytes();
    final base64Data = base64Encode(bytes);

    final overlay = Overlay.of(context, rootOverlay: true);
    final completer = Completer<String>();
    late final OverlayEntry entry;
    late final WebViewController controller;

    void cleanUp() {
      if (entry.mounted) {
        entry.remove();
      }
    }

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (message) {
          Map<String, dynamic> payload;
          try {
            payload = jsonDecode(message.message) as Map<String, dynamic>;
          } catch (_) {
            return; // Malformed message — ignore rather than crash.
          }

          switch (payload['type']) {
            case 'ready':
              // Page + module import finished loading — safe to kick
              // off the actual upload now.
              final escapedFileName = jsonEncode(fileName);
              final escapedMimeType = jsonEncode(contentType);
              controller.runJavaScript(
                'window.startUpload("$base64Data", $escapedFileName, '
                '$escapedMimeType);',
              );
              break;
            case 'progress':
              final progress = (payload['progress'] as num?)?.toDouble();
              if (progress != null) onProgress?.call(progress);
              break;
            case 'done':
              final url = payload['url'] as String?;
              if (url != null) {
                completer.complete(url);
              } else {
                completer.completeError(
                  StateError(
                    'Upload finished but no url in response: '
                    '${payload['raw']}',
                  ),
                );
              }
              cleanUp();
              break;
            case 'error':
              completer.completeError(
                StateError(payload['message']?.toString() ?? 'Upload failed'),
              );
              cleanUp();
              break;
          }
        },
      )
      ..loadHtmlString(
        _buildHtml(baseUrl: baseUrl, routeSlug: routeSlug, token: token),
        // ⚠️ Without this, Android WebView gives the loaded page an
        // origin of the literal string "null" (a known
        // loadHtmlString-without-baseUrl quirk) instead of a real
        // origin. UploadThing's client resolves URLs against
        // `window.location` internally — `new URL(...)` against the
        // string "null" throws "InvalidURL", which is exactly the
        // failure seen in testing (works fine in a real browser/
        // file:// tester where the origin is valid). Passing a real
        // https:// baseUrl here gives the page a valid origin so that
        // resolution succeeds, same as it does outside the WebView.
        baseUrl: baseUrl,
      );

    entry = OverlayEntry(
      builder: (_) => Positioned(
        // Off-screen rather than zero-sized — some WebView
        // implementations throttle/suspend rendering (and, with it,
        // JS timers) for a 0×0 view. 1×1 well outside the visible
        // bounds avoids that while still being invisible to the user.
        left: -10,
        top: -10,
        width: 1,
        height: 1,
        child: IgnorePointer(child: WebViewWidget(controller: controller)),
      ),
    );
    overlay.insert(entry);

    cancelToken?.addListener(() {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Upload cancelled by user'));
      }
      cleanUp();
    });

    // Safety timeout — a silently-hung WebView (e.g. the esm.sh CDN
    // import never resolves) would otherwise leave the caller awaiting
    // forever with the overlay entry never cleaned up.
    final timeout = Timer(const Duration(minutes: 2), () {
      if (!completer.isCompleted) {
        completer.completeError(
          TimeoutException('Upload timed out after 2 minutes'),
        );
        cleanUp();
      }
    });

    try {
      return await completer.future;
    } finally {
      timeout.cancel();
    }
  }

  String _buildHtml({
    required String baseUrl,
    required String routeSlug,
    required String token,
  }) {
    final escapedBaseUrl = jsonEncode('$baseUrl/uploadthing');
    final escapedRouteSlug = jsonEncode(routeSlug);
    final escapedToken = jsonEncode(token);

    return '''
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"></head>
<body>
<script type="module">
  import { genUploader } from "https://esm.sh/uploadthing@7/client";

  const { uploadFiles } = genUploader({ url: $escapedBaseUrl });

  function base64ToBytes(base64) {
    const binary = atob(base64);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) {
      bytes[i] = binary.charCodeAt(i);
    }
    return bytes;
  }

  window.startUpload = async (base64Data, fileName, mimeType) => {
    try {
      const bytes = base64ToBytes(base64Data);
      const file = new File([bytes], fileName, { type: mimeType });

      const result = await uploadFiles($escapedRouteSlug, {
        files: [file],
        headers: { Authorization: "Bearer " + $escapedToken },
        onUploadProgress: ({ progress }) => {
          FlutterBridge.postMessage(
            JSON.stringify({ type: "progress", progress })
          );
        },
      });

      const first = Array.isArray(result) ? result[0] : result;
      const url = first?.url ?? first?.data?.url ?? null;
      FlutterBridge.postMessage(
        JSON.stringify({ type: "done", url, raw: result })
      );
    } catch (err) {
      FlutterBridge.postMessage(
        JSON.stringify({
          type: "error",
          message: (err && err.message) ? err.message : String(err),
        })
      );
    }
  };

  FlutterBridge.postMessage(JSON.stringify({ type: "ready" }));
</script>
</body>
</html>
''';
  }
}

// WHY THIS FILE
// [cancelToken] cancels by tearing down the WebView entirely
// (`cleanUp()`) rather than aborting the in-flight `fetch` UploadThing's
// client makes internally — there's no direct hook into that from
// outside the WebView's JS context. Destroying the page as a side
// effect does stop it (no more `FlutterBridge` messages can arrive
// after `entry.remove()`), it's just a coarser cancel than Dio's
// `CancelToken.cancel()` elsewhere in the app.
// The HTML/JS itself is deliberately near-identical, line for line, to
// `resume-upload-tester.html` — the whole point is zero protocol
// drift from the confirmed-working reference. The two additions are
// the `FlutterBridge` postMessage calls (to get results back into
// Dart) and `window.startUpload` (so Dart can trigger the upload
// after confirming the module import finished, rather than the
// tester's own click-handler wiring, which has no Dart side to
// trigger it).
// File bytes cross the Dart→JS boundary as a base64 string baked into
// a `runJavaScript` call — `webview_flutter` has no binary-postMessage
// channel, only string-based ones, so this is the only path in. Fine
// up to the doc's 4MB resume cap (base64 inflates that to ~5.3MB,
// still a reasonable single JS statement); would need chunking if
// this uploader were ever reused for a much larger file type.
// Pitfall a junior would hit: calling `window.startUpload(...)`
// immediately after `loadHtmlString` instead of waiting for the
// `"ready"` bridge message — the `<script type="module">` import from
// esm.sh is asynchronous, so `startUpload` doesn't exist on `window`
// yet at the moment the page "loads" in the WebView-navigation sense.
