import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/product_price_history.dart';
import '../data/product_price_repository.dart';
import 'product_provider.dart';

final productPriceRepositoryProvider = Provider<ProductPriceRepository>(
  (_) => ProductPriceRepository(),
);

final productPriceHistoryProvider =
    FutureProvider.family<List<ProductPriceHistory>, int>(
      (ref, productId) => ref
          .read(productPriceRepositoryProvider)
          .getHistory(productId, limit: 5),
    );

final productPriceHistoryAllProvider =
    FutureProvider.family<List<ProductPriceHistory>, int>(
      (ref, productId) =>
          ref.read(productPriceRepositoryProvider).getHistory(productId),
    );

final productPriceControllerProvider =
    StateNotifierProvider<ProductPriceController, AsyncValue<void>>(
      (ref) => ProductPriceController(ref),
    );

class ProductPriceController extends StateNotifier<AsyncValue<void>> {
  ProductPriceController(this.ref) : super(const AsyncData(null));
  final Ref ref;

  Future<void> updatePrices(int productId, PriceUpdateRequest request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(productPriceRepositoryProvider)
          .updatePrices(productId, request);
      ref.invalidate(productControllerProvider);
      ref.invalidate(productPriceHistoryProvider(productId));
    });
  }
}
