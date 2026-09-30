import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/page_result.dart';
import '../../products/providers/product_provider.dart';
import '../../home/providers/dashboard_provider.dart';
import '../../reports/providers/report_providers.dart';
import '../data/sale.dart';
import '../data/sale_repository.dart';

final saleRepositoryProvider = Provider<SaleRepository>(
  (_) => SaleRepository(),
);

final saleControllerProvider =
    StateNotifierProvider<
      SaleController,
      PaginatedState<SaleListItem, SaleCursor>
    >((ref) => SaleController(ref));

class SaleController
    extends StateNotifier<PaginatedState<SaleListItem, SaleCursor>> {
  SaleController(this.ref) : super(const PaginatedState()) {
    loadSales();
  }
  final Ref ref;

  SaleRepository get _repository => ref.read(saleRepositoryProvider);

  Future<void> loadSales() async {
    state = state.copyWith(
      items: const [],
      clearCursor: true,
      hasMore: true,
      initialLoading: true,
      clearError: true,
    );
    try {
      final page = await _repository.getSalesPage();
      state = state.copyWith(
        items: page.items,
        cursor: page.nextCursor,
        hasMore: page.hasMore,
        initialLoading: false,
      );
    } catch (error) {
      state = state.copyWith(initialLoading: false, error: error);
    }
  }

  Future<void> loadMore() async {
    if (state.initialLoading || state.loadingMore || !state.hasMore) return;
    state = state.copyWith(loadingMore: true, clearError: true);
    try {
      final page = await _repository.getSalesPage(cursor: state.cursor);
      state = state.copyWith(
        items: [...state.items, ...page.items],
        cursor: page.nextCursor,
        hasMore: page.hasMore,
        loadingMore: false,
      );
    } catch (error) {
      state = state.copyWith(loadingMore: false, error: error);
    }
  }

  Future<Sale> createSale(Sale sale) async {
    final result = await _repository.createSale(sale);
    _invalidateRelatedData();
    await loadSales();
    return result;
  }

  Future<Sale> updateSale(Sale sale) async {
    final result = await _repository.updateSale(sale);
    _invalidateRelatedData();
    await loadSales();
    return result;
  }

  Future<void> deleteSale(int id) async {
    await _repository.deleteSale(id);
    _invalidateRelatedData();
    await loadSales();
  }

  Future<void> deleteSales(Iterable<int> ids) async {
    await _repository.deleteSales(ids);
    _invalidateRelatedData();
    await loadSales();
  }

  void _invalidateRelatedData() {
    ref.invalidate(productControllerProvider);
    ref.invalidate(dashboardProvider);
    ref.invalidate(lowStockItemsProvider);
    ref.invalidate(productSalesProvider);
    ref.invalidate(salesReportProvider);
    ref.invalidate(purchasesReportProvider);
    ref.invalidate(inventoryReportProvider);
  }
}

final productSalesProvider = FutureProvider.family<List<Sale>, int>(
  (ref, productId) =>
      ref.read(saleRepositoryProvider).getSalesByProduct(productId, limit: 5),
);
