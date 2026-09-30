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
import '../data/purchase.dart';
import '../providers/purchase_provider.dart';

class PurchaseFormScreen extends ConsumerStatefulWidget {
  const PurchaseFormScreen({super.key, this.purchase, this.initialProduct});
  final Purchase? purchase;
  final Product? initialProduct;

  @override
  ConsumerState<PurchaseFormScreen> createState() => _PurchaseFormScreenState();
}

class _PurchaseFormScreenState extends ConsumerState<PurchaseFormScreen> {
  late final TextEditingController quantity, unitCost, note;
  int? productId;
  StockUnit unit = StockUnit.item;
  Currency currency = Currency.usd;
  DateTime purchaseDate = DateTime.now();
  String? error;
  bool saving = false;

  bool get editing => widget.purchase != null;

  @override
  void initState() {
    super.initState();
    final purchase = widget.purchase;
    productId = purchase?.productId ?? widget.initialProduct?.id;
    unit = purchase?.unit ?? _registeredUnit(widget.initialProduct);
    currency =
        purchase?.currency ??
        widget.initialProduct?.priceCurrency ??
        Currency.usd;
    purchaseDate = purchase?.purchaseDate ?? DateTime.now();
    quantity = TextEditingController(text: purchase?.quantity.toString());
    unitCost = TextEditingController(text: purchase?.unitCost.toString());
    note = TextEditingController(text: purchase?.note);
  }

  @override
  void dispose() {
    quantity.dispose();
    unitCost.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productState = ref.watch(productControllerProvider);
    final products = [
      ...productState.items,
      if (widget.initialProduct != null &&
          !productState.items.any(
            (item) => item.id == widget.initialProduct!.id,
          ))
        widget.initialProduct!,
    ];
    Product? product = widget.initialProduct;
    for (final item in products) {
      if (item.id == productId) product = item;
    }
    final units = product == null ? <StockUnit>[] : _supportedUnits(product);
    if (product != null && !units.contains(unit)) unit = units.first;
    return AppScaffold(
      title: editing ? 'ویرایش خرید' : 'ثبت خرید',
      body: ListView(
        children: [
          const SectionTitle('محصول'),
          const SizedBox(height: AppSpacing.sm),
          ProductPickerField(
            value: product,
            onSelected: (selected) => setState(() {
              productId = selected.id;
              currency = selected.priceCurrency;
              unit = _registeredUnit(selected);
            }),
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionTitle('جزئیات خرید'),
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
            onChanged: (value) => setState(() => unit = value!),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: unitCost,
            label: 'قیمت خرید هر ${unit.label}',
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
                labelText: 'تاریخ خرید',
                suffixIcon: Icon(Icons.calendar_month_outlined),
              ),
              child: Text(JalaliDateUtils.format(purchaseDate)),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(controller: note, label: 'یادداشت (اختیاری)'),
          if (product != null) _summary(product),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: saving ? 'در حال ذخیره...' : 'ثبت خرید',
              onPressed: product == null || saving ? null : _save,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _summary(Product product) {
    final quantityValue = parseLocalizedDecimal(quantity.text);
    final costValue = parseLocalizedDecimal(unitCost.text);
    if (quantityValue == null ||
        costValue == null ||
        quantityValue <= 0 ||
        costValue < 0) {
      return const SizedBox.shrink();
    }
    final base = ProductConversion.convertToBase(product, quantityValue, unit);
    final breakdown = ProductConversion.breakdown(
      product,
      product.currentStockBase + base,
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
            Text('مجموع خرید', style: AppTextStyles.muted),
            const SizedBox(height: 4),
            Text(
              formatCurrency(quantityValue * costValue, currency),
              style: AppTextStyles.sectionTitle,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('موجودی پس از خرید: $stock', style: AppTextStyles.muted),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showAfghanJalaliDatePicker(
      context,
      initialDate: Jalali.fromDateTime(purchaseDate),
      firstDate: Jalali(1300, 1, 1),
      lastDate: Jalali(1500, 12, 29),
    );
    if (picked != null) setState(() => purchaseDate = picked.toDateTime());
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
      final costValue = parseLocalizedDecimal(unitCost.text);
      if (selectedProductId == null) {
        throw const PurchaseValidationException('لطفاً محصول را انتخاب کنید');
      }
      if (quantityValue == null || quantityValue <= 0) {
        throw const PurchaseValidationException('مقدار باید بیشتر از صفر باشد');
      }
      if (costValue == null || costValue < 0) {
        throw const PurchaseValidationException('قیمت خرید معتبر نیست');
      }
      final now = DateTime.now();
      final value = Purchase(
        id: widget.purchase?.id,
        productId: selectedProductId,
        quantity: quantityValue,
        unit: unit,
        quantityBase: 0,
        unitCost: costValue,
        currency: currency,
        totalCost: 0,
        purchaseDate: purchaseDate,
        note: note.text.trim().isEmpty ? null : note.text.trim(),
        createdAt: widget.purchase?.createdAt ?? now,
        updatedAt: now,
      );
      final controller = ref.read(purchaseControllerProvider.notifier);
      if (editing) {
        await controller.updatePurchase(value);
      } else {
        await controller.createPurchase(value);
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

  StockUnit _registeredUnit(Product? product) {
    if (product == null) return StockUnit.item;
    return switch (product.unit) {
      InventoryUnit.carton => StockUnit.carton,
      InventoryUnit.package => StockUnit.package,
      InventoryUnit.pocket => StockUnit.pocket,
      InventoryUnit.item => StockUnit.item,
    };
  }
}
