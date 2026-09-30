import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/page_result.dart';
import '../data/report_filters.dart';
import '../data/report_repository.dart';

final reportRepositoryProvider = Provider((_) => ReportRepository());

class SalesReportState {
  const SalesReportState({
    required this.filter,
    this.items = const [],
    this.summary,
    this.cursor,
    this.hasMore = true,
    this.loading = false,
    this.loadingMore = false,
    this.error,
    this.generation = 0,
  });
  final TransactionFilter filter;
  final List<SaleReportRow> items;
  final TransactionSummary? summary;
  final TransactionCursor? cursor;
  final bool hasMore, loading, loadingMore;
  final Object? error;
  final int generation;
}

class PurchasesReportState {
  const PurchasesReportState({
    required this.filter,
    this.items = const [],
    this.summary,
    this.cursor,
    this.hasMore = true,
    this.loading = false,
    this.loadingMore = false,
    this.error,
    this.generation = 0,
  });
  final TransactionFilter filter;
  final List<PurchaseReportRow> items;
  final TransactionSummary? summary;
  final TransactionCursor? cursor;
  final bool hasMore, loading, loadingMore;
  final Object? error;
  final int generation;
}

class InventoryReportState {
  const InventoryReportState({
    this.filter = const InventoryFilter(),
    this.items = const [],
    this.cursor,
    this.hasMore = true,
    this.loading = false,
    this.loadingMore = false,
    this.error,
    this.generation = 0,
  });
  final InventoryFilter filter;
  final List<InventoryReportRow> items;
  final ProductInventoryCursor? cursor;
  final bool hasMore, loading, loadingMore;
  final Object? error;
  final int generation;
}

final salesReportProvider =
    StateNotifierProvider<SalesReportController, SalesReportState>(
      (ref) => SalesReportController(ref),
    );
final purchasesReportProvider =
    StateNotifierProvider<PurchasesReportController, PurchasesReportState>(
      (ref) => PurchasesReportController(ref),
    );
final inventoryReportProvider =
    StateNotifierProvider<InventoryReportController, InventoryReportState>(
      (ref) => InventoryReportController(ref),
    );

class SalesReportController extends StateNotifier<SalesReportState> {
  SalesReportController(this.ref)
    : super(
        SalesReportState(
          filter: TransactionFilter(dateRange: DateRangeFilter.thisMonth()),
        ),
      ) {
    load();
  }
  final Ref ref;
  Future<void> load([TransactionFilter? filter]) async {
    if (!mounted) return;
    final generation = state.generation + 1;
    final active = filter ?? state.filter;
    state = SalesReportState(
      filter: active,
      loading: true,
      generation: generation,
    );
    try {
      final repo = ref.read(reportRepositoryProvider);
      final result = await Future.wait([
        repo.getSalesPage(active),
        repo.getSalesSummary(active),
      ]);
      if (!mounted || generation != state.generation) return;
      final page = result[0] as PageResult<SaleReportRow, TransactionCursor>;
      state = SalesReportState(
        filter: active,
        items: page.items,
        summary: result[1] as TransactionSummary,
        cursor: page.nextCursor,
        hasMore: page.hasMore,
        generation: generation,
      );
    } catch (error) {
      if (mounted && generation == state.generation)
        state = SalesReportState(
          filter: active,
          loading: false,
          error: error,
          generation: generation,
        );
    }
  }

  Future<void> loadMore() async {
    if (!mounted) return;
    if (state.loading || state.loadingMore || !state.hasMore) return;
    final generation = state.generation;
    state = SalesReportState(
      filter: state.filter,
      items: state.items,
      summary: state.summary,
      cursor: state.cursor,
      hasMore: state.hasMore,
      loadingMore: true,
      generation: generation,
    );
    try {
      final page = await ref
          .read(reportRepositoryProvider)
          .getSalesPage(state.filter, cursor: state.cursor);
      if (!mounted || generation != state.generation) return;
      if (!mounted) return;
      state = SalesReportState(
        filter: state.filter,
        items: [...state.items, ...page.items],
        summary: state.summary,
        cursor: page.nextCursor,
        hasMore: page.hasMore,
        generation: generation,
      );
    } catch (error) {
      state = SalesReportState(
        filter: state.filter,
        items: state.items,
        summary: state.summary,
        cursor: state.cursor,
        hasMore: state.hasMore,
        error: error,
        generation: generation,
      );
    }
  }
}

class PurchasesReportController extends StateNotifier<PurchasesReportState> {
  PurchasesReportController(this.ref)
    : super(
        PurchasesReportState(
          filter: TransactionFilter(dateRange: DateRangeFilter.thisMonth()),
        ),
      ) {
    load();
  }
  final Ref ref;
  Future<void> load([TransactionFilter? filter]) async {
    if (!mounted) return;
    final generation = state.generation + 1;
    final active = filter ?? state.filter;
    state = PurchasesReportState(
      filter: active,
      loading: true,
      generation: generation,
    );
    try {
      final repo = ref.read(reportRepositoryProvider);
      final result = await Future.wait([
        repo.getPurchasesPage(active),
        repo.getPurchasesSummary(active),
      ]);
      if (!mounted || generation != state.generation) return;
      final page =
          result[0] as PageResult<PurchaseReportRow, TransactionCursor>;
      state = PurchasesReportState(
        filter: active,
        items: page.items,
        summary: result[1] as TransactionSummary,
        cursor: page.nextCursor,
        hasMore: page.hasMore,
        generation: generation,
      );
    } catch (error) {
      if (mounted && generation == state.generation)
        state = PurchasesReportState(
          filter: active,
          loading: false,
          error: error,
          generation: generation,
        );
    }
  }

  Future<void> loadMore() async {
    if (!mounted) return;
    if (state.loading || state.loadingMore || !state.hasMore) return;
    final generation = state.generation;
    state = PurchasesReportState(
      filter: state.filter,
      items: state.items,
      summary: state.summary,
      cursor: state.cursor,
      hasMore: state.hasMore,
      loadingMore: true,
      generation: generation,
    );
    try {
      final page = await ref
          .read(reportRepositoryProvider)
          .getPurchasesPage(state.filter, cursor: state.cursor);
      if (!mounted || generation != state.generation) return;
      if (!mounted) return;
      state = PurchasesReportState(
        filter: state.filter,
        items: [...state.items, ...page.items],
        summary: state.summary,
        cursor: page.nextCursor,
        hasMore: page.hasMore,
        generation: generation,
      );
    } catch (error) {
      state = PurchasesReportState(
        filter: state.filter,
        items: state.items,
        summary: state.summary,
        cursor: state.cursor,
        hasMore: state.hasMore,
        error: error,
        generation: generation,
      );
    }
  }
}

class InventoryReportController extends StateNotifier<InventoryReportState> {
  InventoryReportController(this.ref) : super(const InventoryReportState()) {
    load();
  }
  final Ref ref;
  Future<void> load([InventoryFilter? filter]) async {
    if (!mounted) return;
    final generation = state.generation + 1;
    final active = filter ?? state.filter;
    state = InventoryReportState(
      filter: active,
      loading: true,
      generation: generation,
    );
    try {
      final page = await ref
          .read(reportRepositoryProvider)
          .getInventoryPage(active);
      if (!mounted || generation != state.generation) return;
      state = InventoryReportState(
        filter: active,
        items: page.items,
        cursor: page.nextCursor,
        hasMore: page.hasMore,
        generation: generation,
      );
    } catch (error) {
      if (mounted && generation == state.generation)
        state = InventoryReportState(
          filter: active,
          loading: false,
          error: error,
          generation: generation,
        );
    }
  }

  Future<void> loadMore() async {
    if (!mounted) return;
    if (state.loading || state.loadingMore || !state.hasMore) return;
    final generation = state.generation;
    state = InventoryReportState(
      filter: state.filter,
      items: state.items,
      cursor: state.cursor,
      hasMore: state.hasMore,
      loadingMore: true,
      generation: generation,
    );
    try {
      final page = await ref
          .read(reportRepositoryProvider)
          .getInventoryPage(state.filter, cursor: state.cursor);
      if (!mounted || generation != state.generation) return;
      if (!mounted) return;
      state = InventoryReportState(
        filter: state.filter,
        items: [...state.items, ...page.items],
        cursor: page.nextCursor,
        hasMore: page.hasMore,
        generation: generation,
      );
    } catch (error) {
      state = InventoryReportState(
        filter: state.filter,
        items: state.items,
        cursor: state.cursor,
        hasMore: state.hasMore,
        error: error,
        generation: generation,
      );
    }
  }
}
