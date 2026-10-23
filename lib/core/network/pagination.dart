/// Cursor-based pagination wrapper for list endpoints.
/// Backend currently returns ALL jobs in one response (no pagination yet —
/// see D8 in backend checklist), so `cursor` stays null and `hasMore`
/// stays false until the backend team ships pagination. This model is
/// forward-compatible with that — no app-side change needed later.
class Page<T> {
  const Page({
    required this.items,
    required this.hasMore,
    this.cursor,
  });
  final List<T> items;
  final bool hasMore;
  final String? cursor;

  Page<T> appending(
    List<T> newItems, {
    required bool newHasMore,
    String? newCursor,
  }) {
    return Page<T>(
      items: [...items, ...newItems],
      hasMore: newHasMore,
      cursor: newCursor,
    );
  }
}
