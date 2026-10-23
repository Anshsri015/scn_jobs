/// Which kind of file is being uploaded — drives allowed extensions and
/// max size, checked client-side before ever hitting the network.
enum UploadFileKind { resume, photo }

extension UploadFileKindX on UploadFileKind {
  /// Resume: PDF only, per the UploadThing `resumeUploader` route config
  /// (doc explicitly says "PDF only" — doc/docx are rejected server-side
  /// even if picked here, so there's no point letting the picker offer
  /// them).
  List<String> get allowedExtensions => switch (this) {
    UploadFileKind.resume => const ['pdf'],
    UploadFileKind.photo => const ['jpg', 'jpeg', 'png'],
  };

  /// Resume max size is 4MB per doc (enforced both client and server
  /// side there) — was 5MB here, which would let a file through the
  /// client check only to get rejected by the server.
  int get maxSizeBytes => switch (this) {
    UploadFileKind.resume => 4 * 1024 * 1024, // 4 MB
    UploadFileKind.photo => 2 * 1024 * 1024, // 2 MB
  };

  String get label => switch (this) {
    UploadFileKind.resume => 'resume',
    UploadFileKind.photo => 'photo',
  };
}
