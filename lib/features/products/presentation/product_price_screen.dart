import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/jalali_date_utils.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/section_title.dart';
import '../../purchases/providers/purchase_provider.dart';
import '../data/product.dart';
import '../data/product_conversion.dart';
import '../data/product_price_repository.dart';
import '../providers/product_price_provider.dart';

class ProductPriceScreen extends ConsumerStatefulWidget {
  const ProductPriceScreen({super.key, required this.product});
  final Product product;
  @override
  ConsumerState<ProductPriceScreen> createState() => _ProductPriceScreenState();
}

class _ProductPriceScreenState extends ConsumerState<ProductPriceScreen> {
  late final TextEditingController carton, package, item;
  late Currency currency;
  String? error;

  @override
  void initState() {
    super.initState();
    carton = TextEditingController(
      text: widget.product.cartonSalePrice?.toString(),
    );
    package = TextEditingController(
      text: widget.product.packageSalePrice?.toString(),
    );
    item = TextEditingController(
      text: widget.product.itemSalePrice?.toString(),
    );
    currency = widget.product.priceCurrency;
  }

  @override
  void dispose() {
    carton.dispose();
    package.dispose();
    item.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final latestPurchase = ref
        .watch(productPurchasesProvider(widget.product.id!))
        .valueOrNull
        ?.firstOrNull;
    final unit = _registeredStockUnit;
    final controller = _controllerFor(unit);
    final current = _currentPrice(unit);
    return AppScaffold(
      title: 'تغییر قیمت فروش',
      body: ListView(
        children: [
          Text(widget.product.name, style: AppTextStyles.pageTitle),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: ListTile(
              leading: const Icon(Icons.shopping_cart_outlined),
              title: const Text('آخرین قیمت خرید'),
              subtitle: Text(
                latestPurchase == null
                    ? 'هنوز خریدی ثبت نشده است'
                    : '${formatCurrency(latestPurchase.unitCost, latestPurchase.currency)} / ${latestPurchase.unit.label}',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionTitle('قیمت فروش'),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'واحد ثبت‌شده: ${unit.label}',
                    style: AppTextStyles.muted,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: controller,
                    label: 'قیمت جدید هر ${unit.label}',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'قیمت فعلی: ${current == null ? 'تعیین نشده' : formatCurrency(current, widget.product.priceCurrency)}',
                    style: AppTextStyles.muted,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          DropdownButtonFormField<Currency>(
            initialValue: currency,
            style: AppTextStyles.body,
            decoration: const InputDecoration(labelText: 'ارز قیمت‌ها'),
            items: Currency.values
                .map(
                  (value) =>
                      DropdownMenuItem(value: value, child: Text(value.label)),
                )
                .toList(),
            onChanged: (value) => setState(() => currency = value!),
          ),
          if (currency != widget.product.priceCurrency)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.md),
              child: Text(
                'تغییر ارز قیمت‌ها باعث تبدیل خودکار مبلغ‌ها نمی‌شود.',
                style: TextStyle(color: Colors.red),
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: AppButton(label: 'ذخیره قیمت‌ها', onPressed: _save),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  StockUnit get _registeredStockUnit => switch (widget.product.unit) {
    InventoryUnit.carton => StockUnit.carton,
    InventoryUnit.package => StockUnit.package,
    InventoryUnit.pocket => StockUnit.pocket,
    InventoryUnit.item => StockUnit.item,
  };

  TextEditingController _controllerFor(StockUnit unit) => switch (unit) {
    StockUnit.carton => carton,
    StockUnit.package => package,
    StockUnit.pocket => item,
    StockUnit.item => item,
  };

  num? _currentPrice(StockUnit unit) => switch (unit) {
    StockUnit.carton => widget.product.cartonSalePrice,
    StockUnit.package => widget.product.packageSalePrice,
    StockUnit.pocket => widget.product.pocketSalePrice,
    StockUnit.item => widget.product.itemSalePrice,
  };

  Future<void> _save() async {
    if (currency != widget.product.priceCurrency) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تغییر ارز قیمت‌ها'),
          content: const Text(
            'تغییر ارز قیمت‌ها باعث تبدیل خودکار مبلغ‌ها نمی‌شود.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('لغو'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('تأیید'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    try {
      final request = PriceUpdateRequest(
        cartonPrice: _registeredStockUnit == StockUnit.carton
            ? _value(carton)
            : null,
        packagePrice: _registeredStockUnit == StockUnit.package
            ? _value(package)
            : null,
        itemPrice: _registeredStockUnit == StockUnit.item ? _value(item) : null,
        currency: currency,
        effectiveDate: DateTime.now(),
      );
      await ref
          .read(productPriceControllerProvider.notifier)
          .updatePrices(widget.product.id!, request);
      final state = ref.read(productPriceControllerProvider);
      if (state.hasError) throw state.error!;
      if (mounted) Navigator.pop(context);
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    }
  }

  num? _value(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return null;
    final value = parseLocalizedDecimal(text);
    if (value == null) {
      throw const ProductValidationException('قیمت معتبر نیست');
    }
    return value;
  }
}

class ProductPriceHistoryScreen extends ConsumerWidget {
  const ProductPriceHistoryScreen({super.key, required this.product});
  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AppScaffold(
    title: 'تاریخچه قیمت',
    body: ref
        .watch(productPriceHistoryAllProvider(product.id!))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(error.toString())),
          data: (history) => history.isEmpty
              ? const Center(child: Text('هنوز تغییر قیمتی ثبت نشده است'))
              : ListView.separated(
                  itemCount: history.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, index) {
                    final entry = history[index];
                    return Card(
                      child: ListTile(
                        title: Text(
                          entry.unit.label,
                          style: AppTextStyles.sectionTitle,
                        ),
                        subtitle: Text(
                          '${entry.oldPrice == null ? 'تعیین نشده' : formatNumber(entry.oldPrice!)} ← ${formatNumber(entry.newPrice)} ${entry.currency.label}\n${JalaliDateUtils.format(entry.effectiveDate)}',
                          style: AppTextStyles.muted,
                        ),
                      ),
                    );
                  },
                ),
        ),
  );
}
