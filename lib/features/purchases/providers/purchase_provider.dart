import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/page_result.dart';
import '../../products/providers/product_provider.dart';
import '../../home/providers/dashboard_provider.dart';
import '../../reports/providers/report_providers.dart';
import '../data/purchase.dart';
import '../data/purchase_repository.dart';

final purchaseRepositoryProvider = Provider<PurchaseRepository>(
  (_) => PurchaseRepository(),
);

final purchaseControllerProvider =
    StateNotifierProvider<
      PurchaseController,
      PaginatedState<PurchaseListItem, PurchaseCursor>
    >((ref) => PurchaseController(ref));

class PurchaseController
    extends StateNotifier<PaginatedState<PurchaseListItem, PurchaseCursor>> {
  PurchaseController(this.ref) : super(const PaginatedState()) {
    loadPurchases();
  }
  final Ref ref;

  PurchaseRepository get _repository => ref.read(purchaseRepositoryProvider);

  Future<void> loadPurchases() async {
    state = state.copyWith(
      items: const [],
      clearCursor: true,
      hasMore: true,
      initialLoading: true,
      clearError: true,
    );
    try {
      final page = await _repository.getPurchasesPage();
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
      final page = await _repository.getPurchasesPage(cursor: state.cursor);
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

  Future<Purchase> createPurchase(Purchase purchase) async {
    final result = await _repository.createPurchase(purchase);
    _invalidateRelatedData();
    await loadPurchases();
    return result;
  }

  Future<Purchase> updatePurchase(Purchase purchase) async {
    final result = await _repository.updatePurchase(purchase);
    _invalidateRelatedData();
    await loadPurchases();
    return result;
  }

  Future<void> deletePurchase(int id) async {
    await _repository.deletePurchase(id);
    _invalidateRelatedData();
    await loadPurchases();
  }

  Future<void> deletePurchases(Iterable<int> ids) async {
    await _repository.deletePurchases(ids);
    _invalidateRelatedData();
    await loadPurchases();
  }

  void _invalidateRelatedData() {
    ref.invalidate(productControllerProvider);
    ref.invalidate(dashboardProvider);
    ref.invalidate(lowStockItemsProvider);
    ref.invalidate(productPurchasesProvider);
    ref.invalidate(salesReportProvider);
    ref.invalidate(purchasesReportProvider);
    ref.invalidate(inventoryReportProvider);
  }
}

final productPurchasesProvider = FutureProvider.family<List<Purchase>, int>(
  (ref, productId) => ref
      .read(purchaseRepositoryProvider)
      .getPurchasesByProduct(productId, limit: 5),
);
