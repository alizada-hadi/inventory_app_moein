import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/jalali_date_utils.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/section_title.dart';
import '../../products/data/product.dart';
import '../../products/data/product_conversion.dart';
import '../../products/providers/product_provider.dart';
import '../../products/presentation/product_picker.dart';
import '../data/sale.dart';
import '../providers/sale_provider.dart';

class SaleFormScreen extends ConsumerStatefulWidget {
  const SaleFormScreen({super.key, this.sale, this.initialProduct});
  final Sale? sale;
  final Product? initialProduct;

  @override
  ConsumerState<SaleFormScreen> createState() => _SaleFormScreenState();
}

class _SaleFormScreenState extends ConsumerState<SaleFormScreen> {
  late final TextEditingController quantity, price, note;
  int? productId;
  StockUnit unit = StockUnit.item;
  Currency currency = Currency.usd;
  DateTime saleDate = DateTime.now();
  String? error;
  bool saving = false;

  bool get editing => widget.sale != null;

  @override
  void initState() {
    super.initState();
    final sale = widget.sale;
    productId = sale?.productId ?? widget.initialProduct?.id;
    unit = sale?.unit ?? StockUnit.item;
    if (sale == null && widget.initialProduct != null) {
      unit = _supportedUnits(widget.initialProduct!).first;
    }
    currency =
        sale?.currency ?? widget.initialProduct?.priceCurrency ?? Currency.usd;
    saleDate = sale?.saleDate ?? DateTime.now();
    quantity = TextEditingController(text: sale?.quantity.toString());
    price = TextEditingController(
      text:
          sale?.unitPrice.toString() ??
          (widget.initialProduct == null
              ? null
              : salePriceForUnit(widget.initialProduct!, unit).toString()),
    );
    note = TextEditingController(text: sale?.note);
  }

  @override
  void dispose() {
    quantity.dispose();
    price.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productControllerProvider).items;
    Product? product;
    for (final item in products) {
      if (item.id == productId) product = item;
    }
    product ??= widget.initialProduct;
    final units = product == null ? <StockUnit>[] : _supportedUnits(product);
    if (product != null && !units.contains(unit)) unit = units.first;
    final requestedBase = product == null ? null : _requestedBase(product);
    final hasStock = product != null && product.currentStockBase > 0;
    final enoughStock =
        requestedBase != null && requestedBase <= product!.currentStockBase;
    return AppScaffold(
      title: editing ? 'ویرایش فروش' : 'ثبت فروش',
      body: ListView(
        children: [
          const SectionTitle('محصول'),
          const SizedBox(height: AppSpacing.sm),
          ProductPickerField(
            value: product,
            onSelected: (selected) => setState(() {
              productId = selected.id;
              currency = selected.priceCurrency;
              unit = _supportedUnits(selected).first;
              price.text = salePriceForUnit(selected, unit).toString();
            }),
          ),
          if (product != null) _currentStock(product),
          const SizedBox(height: AppSpacing.xl),
          const SectionTitle('جزئیات فروش'),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: quantity,
            label: 'مقدار',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<StockUnit>(
            initialValue: units.contains(unit) ? unit : null,
            style: AppTextStyles.body,
            decoration: const InputDecoration(labelText: 'واحد'),
            items: units
                .map(
                  (item) =>
                      DropdownMenuItem(value: item, child: Text(item.label)),
                )
                .toList(),
            onChanged: (value) {
              if (value == null || product == null) return;
              setState(() {
                unit = value;
                if (!editing) {
                  price.text = salePriceForUnit(product!, unit).toString();
                }
              });
            },
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: price,
            label: 'قیمت فروش هر ${unit.label}',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<Currency>(
            initialValue: currency,
            style: AppTextStyles.body,
            decoration: const InputDecoration(labelText: 'ارز'),
            items: Currency.values
                .map(
                  (item) =>
                      DropdownMenuItem(value: item, child: Text(item.label)),
                )
                .toList(),
            onChanged: (value) => setState(() => currency = value!),
          ),
          const SizedBox(height: AppSpacing.md),
          InkWell(
            onTap: _selectDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'تاریخ فروش',
                suffixIcon: Icon(Icons.calendar_month_outlined),
              ),
              child: Text(JalaliDateUtils.format(saleDate)),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(controller: note, label: 'یادداشت (اختیاری)'),
          if (product != null)
            _summary(product, requestedBase, hasStock, enoughStock),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: saving ? 'در حال ذخیره...' : 'ثبت فروش',
              onPressed: !saving && product != null && hasStock && enoughStock
                  ? _save
                  : null,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _currentStock(Product product) {
    final stock = ProductConversion.breakdown(
      product,
      product.currentStockBase,
    );
    final value = [
      if (stock.cartons > 0) '${formatNumber(stock.cartons)} کارتن',
      if (stock.packages > 0) '${formatNumber(stock.packages)} بسته',
      if (stock.pockets > 0) '${formatNumber(stock.pockets)} پاکت',
      '${formatNumber(stock.items)} عدد',
    ].join('، ');
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Text('موجودی فعلی: $value', style: AppTextStyles.muted),
    );
  }

  Widget _summary(
    Product product,
    num? requestedBase,
    bool hasStock,
    bool enoughStock,
  ) {
    final quantityValue = parseLocalizedDecimal(quantity.text);
    final priceValue = parseLocalizedDecimal(price.text);
    if (quantityValue == null ||
        priceValue == null ||
        quantityValue <= 0 ||
        priceValue < 0) {
      return const SizedBox.shrink();
    }
    final base = requestedBase ?? 0;
    final remaining = product.currentStockBase - base;
    final breakdown = ProductConversion.breakdown(
      product,
      remaining < 0 ? 0 : remaining,
    );
    final stock = [
      if (breakdown.cartons > 0) '${formatNumber(breakdown.cartons)} کارتن',
      if (breakdown.packages > 0) '${formatNumber(breakdown.packages)} بسته',
      if (breakdown.pockets > 0) '${formatNumber(breakdown.pockets)} پاکت',
      '${formatNumber(breakdown.items)} عدد',
    ].join('، ');
    return Card(
      margin: const EdgeInsets.only(top: AppSpacing.xl),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('مجموع فروش', style: AppTextStyles.muted),
            const SizedBox(height: 4),
            Text(
              formatCurrency(quantityValue * priceValue, currency),
              style: AppTextStyles.sectionTitle,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              enoughStock && hasStock
                  ? 'موجودی پس از فروش: $stock'
                  : 'موجودی کافی نیست.',
              style: TextStyle(
                color: enoughStock && hasStock ? null : Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  num? _requestedBase(Product product) {
    final value = parseLocalizedDecimal(quantity.text);
    return value == null || value <= 0
        ? null
        : calculateSaleQuantityBase(product, value, unit);
  }

  Future<void> _selectDate() async {
    final picked = await showAfghanJalaliDatePicker(
      context,
      initialDate: Jalali.fromDateTime(saleDate),
      firstDate: Jalali(1300, 1, 1),
      lastDate: Jalali(1500, 12, 29),
    );
    if (picked != null) setState(() => saleDate = picked.toDateTime());
  }

  Future<void> _save() async {
    if (saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final selectedProductId = productId;
      final quantityValue = parseLocalizedDecimal(quantity.text);
      final priceValue = parseLocalizedDecimal(price.text);
      if (selectedProductId == null) {
        throw const SaleValidationException('لطفاً محصول را انتخاب کنید');
      }
      if (quantityValue == null || quantityValue <= 0) {
        throw const SaleValidationException('مقدار باید بیشتر از صفر باشد');
      }
      if (priceValue == null || priceValue < 0) {
        throw const SaleValidationException('قیمت فروش معتبر نیست');
      }
      final now = DateTime.now();
      final value = Sale(
        id: widget.sale?.id,
        productId: selectedProductId,
        quantity: quantityValue,
        unit: unit,
        quantityBase: 0,
        unitPrice: priceValue,
        currency: currency,
        totalAmount: 0,
        saleDate: saleDate,
        note: note.text.trim().isEmpty ? null : note.text.trim(),
        createdAt: widget.sale?.createdAt ?? now,
        updatedAt: now,
      );
      final controller = ref.read(saleControllerProvider.notifier);
      if (editing) {
        await controller.updateSale(value);
      } else {
        await controller.createSale(value);
      }
      if (mounted) Navigator.pop(context);
    } catch (exception) {
      if (mounted) {
        setState(() {
          saving = false;
          error = exception.toString();
        });
      }
    }
  }

  List<StockUnit> _supportedUnits(Product product) => [
    if (product.supportsCarton) StockUnit.carton,
    if (product.supportsPackage) StockUnit.package,
    if (product.supportsPocket) StockUnit.pocket,
    StockUnit.item,
  ];
}
