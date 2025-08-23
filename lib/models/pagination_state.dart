// lib/models/pagination_state.dart
class PaginationState<T> {
  final List<T> items;
  final bool isLoading;
  final bool hasMore;
  final bool isFromCache;
  final bool isInitialized;
  final int currentPage;  
  final dynamic error;

  const PaginationState({
    this.items = const [],
    this.isLoading = false,
    this.hasMore = false,
    this.isFromCache = false,
    this.isInitialized = false, 
    this.currentPage = 0,
    this.error,
  });

  PaginationState<T> copyWith({
    List<T>? items,
    bool? isLoading,
    bool? hasMore,
    bool? isFromCache,
    bool? isInitialized, 
    int? currentPage,
    dynamic error,
  }) {
    return PaginationState<T>(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      isFromCache: isFromCache ?? this.isFromCache,
      isInitialized: isInitialized ?? this.isInitialized,
      currentPage: currentPage ?? this.currentPage,
      error: error ?? this.error,
    );
  }
}
