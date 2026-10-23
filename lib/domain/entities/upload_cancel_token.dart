/// Domain-layer cancellation handle — deliberately NOT `dio.CancelToken`
/// (domain never imports Dio). The data layer adapts this to a real
/// `CancelToken` internally (see `upload_remote_datasource.dart`).
class UploadCancelToken {
  bool _cancelled = false;
  final List<void Function()> _listeners = [];

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final listener in _listeners) {
      listener();
    }
  }

  /// Registered by the data layer to bridge into Dio's own cancel
  /// mechanism when this token is cancelled.
  void addListener(void Function() listener) => _listeners.add(listener);
}
