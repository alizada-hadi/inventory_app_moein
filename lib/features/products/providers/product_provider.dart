import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/page_result.dart';
import '../data/product.dart';
import '../data/product_repository.dart';
import '../../home/providers/dashboard_provider.dart';
import '../../reports/providers/report_providers.dart';

final productRepositoryProvider = Provider<ProductRepository>(
  (_) => ProductRepository(),
);

final productControllerProvider =
    StateNotifierProvider<
      ProductController,
      PaginatedState<Product, ProductCursor>
    >((ref) => ProductController(ref.read(productRepositoryProvider), ref));

class ProductController
    extends StateNotifier<PaginatedState<Product, ProductCursor>> {
  ProductController(this._repository, this._ref)
    : super(const PaginatedState()) {
    loadProducts();
  }
  final ProductRepository _repository;
  final Ref _ref;
  int _requestGeneration = 0;

  Future<void> loadProducts([String query = '']) async {
    final generation = ++_requestGeneration;
    state = state.copyWith(
      items: const [],
      clearCursor: true,
      hasMore: true,
      initialLoading: true,
      loadingMore: false,
      refreshing: false,
      clearError: true,
      query: query.trim(),
    );
    try {
      final page = await _repository.getProductsPage(query: query);
      if (generation != _requestGeneration) return;
      state = state.copyWith(
        items: page.items,
        cursor: page.nextCursor,
        hasMore: page.hasMore,
        initialLoading: false,
      );
    } catch (error) {
      if (generation != _requestGeneration) return;
      state = state.copyWith(initialLoading: false, error: error);
    }
  }

  Future<void> loadMore() async {
    if (state.initialLoading || state.loadingMore || !state.hasMore) return;
    final generation = _requestGeneration;
    state = state.copyWith(loadingMore: true, clearError: true);
    try {
      final page = await _repository.getProductsPage(
        cursor: state.cursor,
        query: state.query,
      );
      if (generation != _requestGeneration) return;
      state = state.copyWith(
        items: [...state.items, ...page.items],
        cursor: page.nextCursor,
        hasMore: page.hasMore,
        loadingMore: false,
      );
    } catch (error) {
      if (generation != _requestGeneration) return;
      state = state.copyWith(loadingMore: false, error: error);
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(refreshing: true, clearError: true);
    await loadProducts(state.query);
  }

  Future<void> createProduct(Product product) async {
    await _repository.createProduct(product);
    _invalidateRelatedData();
    await loadProducts(state.query);
  }

  Future<void> updateProduct(Product product) async {
    await _repository.updateProduct(product);
    _invalidateRelatedData();
    await loadProducts(state.query);
  }

  Future<void> deleteProduct(int id) async {
    await _repository.deleteProduct(id);
    _invalidateRelatedData();
    await loadProducts(state.query);
  }

  Future<void> deleteProducts(Iterable<int> ids) async {
    await _repository.deleteProducts(ids);
    _invalidateRelatedData();
    await loadProducts(state.query);
  }

  void _invalidateRelatedData() {
    _ref.invalidate(dashboardProvider);
    _ref.invalidate(lowStockItemsProvider);
    _ref.invalidate(salesReportProvider);
    _ref.invalidate(purchasesReportProvider);
    _ref.invalidate(inventoryReportProvider);
  }
}
