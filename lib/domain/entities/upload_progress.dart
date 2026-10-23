/// A snapshot of an in-flight upload — passed to the caller's
/// `onProgress` callback so a screen can drive a progress bar without
/// polling.
class UploadProgress {
  const UploadProgress({required this.bytesSent, required this.totalBytes});

  final int bytesSent;
  final int totalBytes;

  double get fraction => totalBytes <= 0 ? 0 : bytesSent / totalBytes;

  int get percentage => (fraction * 100).round();
}
