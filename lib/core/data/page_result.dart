/// Result of one database-backed keyset page.
class PageResult<T, C> {
  const PageResult({required this.items, required this.nextCursor});
  final List<T> items;
  final C? nextCursor;
  bool get hasMore => nextCursor != null;
}

class PaginatedState<T, C> {
  const PaginatedState({
    this.items = const [],
    this.cursor,
    this.hasMore = true,
    this.initialLoading = false,
    this.loadingMore = false,
    this.refreshing = false,
    this.error,
    this.query = '',
  });
  final List<T> items;
  final C? cursor;
  final bool hasMore;
  final bool initialLoading;
  final bool loadingMore;
  final bool refreshing;
  final Object? error;
  final String query;

  PaginatedState<T, C> copyWith({
    List<T>? items,
    C? cursor,
    bool clearCursor = false,
    bool? hasMore,
    bool? initialLoading,
    bool? loadingMore,
    bool? refreshing,
    Object? error,
    bool clearError = false,
    String? query,
  }) => PaginatedState(
    items: items ?? this.items,
    cursor: clearCursor ? null : cursor ?? this.cursor,
    hasMore: hasMore ?? this.hasMore,
    initialLoading: initialLoading ?? this.initialLoading,
    loadingMore: loadingMore ?? this.loadingMore,
    refreshing: refreshing ?? this.refreshing,
    error: clearError ? null : error ?? this.error,
    query: query ?? this.query,
  );
}
