import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_text_field.dart';
import '../data/product.dart';
import '../providers/product_provider.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.product});
  final Product? product;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  late final TextEditingController name,
      amount,
      restockLevel,
      costPrice,
      salePrice;
  InventoryUnit unit = InventoryUnit.package;
  Currency currency = Currency.usd;
  String? error;
  bool saving = false;

  bool get editing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    name = TextEditingController(text: p?.name);
    amount = TextEditingController(text: p == null ? '' : p.amount.toString());
    restockLevel = TextEditingController(
      text: (p?.restockLevel ?? 10).toString(),
    );
    costPrice = TextEditingController(text: p?.costPrice?.toString());
    salePrice = TextEditingController(text: p?.salePrice?.toString());
    unit = p?.unit ?? InventoryUnit.package;
    currency = p?.priceCurrency ?? Currency.usd;
  }

  @override
  void dispose() {
    for (final controller in [
      name,
      amount,
      restockLevel,
      costPrice,
      salePrice,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: editing ? 'ویرایش محصول' : 'افزودن محصول',
    body: ListView(
      children: [
        AppTextField(controller: name, label: 'نام محصول *'),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<InventoryUnit>(
          initialValue: unit,
          style: AppTextStyles.body,
          decoration: const InputDecoration(labelText: 'واحد *'),
          items: InventoryUnit.values
              .map(
                (item) =>
                    DropdownMenuItem(value: item, child: Text(item.label)),
              )
              .toList(),
          onChanged: (value) => setState(() => unit = value!),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: amount,
          label: 'مقدار *',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: restockLevel,
          label: 'حد خرید مجدد',
          hint: 'پیش‌فرض: ۱۰ واحد',
          keyboardType: TextInputType.number,
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
        AppTextField(
          controller: costPrice,
          label: 'قیمت خرید هر واحد',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: salePrice,
          label: 'قیمت فروش هر واحد',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Text(error!, style: const TextStyle(color: Colors.red)),
          ),
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            label: saving ? 'در حال ذخیره...' : 'ذخیره',
            onPressed: saving ? null : _save,
          ),
        ),
      ],
    ),
  );

  Future<void> _save() async {
    if (saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final amountValue = parseLocalizedDecimal(amount.text);
      if (name.text.trim().isEmpty) {
        throw const ProductValidationException('نام محصول الزامی است');
      }
      if (amountValue == null || amountValue < 0) {
        throw const ProductValidationException('مقدار باید یک عدد معتبر باشد');
      }
      final restockLevelValue = parseLocalizedDecimal(restockLevel.text);
      if (restockLevelValue == null || restockLevelValue < 0) {
        throw const ProductValidationException(
          'حد خرید مجدد باید یک عدد صفر یا بزرگ‌تر باشد',
        );
      }
      final cost = _int(costPrice);
      final sale = _int(salePrice);
      final now = DateTime.now();
      final p = Product(
        id: widget.product?.id,
        name: name.text.trim(),
        unit: unit,
        amount: amountValue,
        restockLevel: restockLevelValue,
        currentStockBase: amountValue,
        supportsCarton: unit == InventoryUnit.carton,
        supportsPackage: unit == InventoryUnit.package,
        supportsPocket: unit == InventoryUnit.pocket,
        itemsPerPackage: unit == InventoryUnit.package ? 1 : null,
        itemsPerPocket: unit == InventoryUnit.pocket ? 1 : null,
        itemsPerCartonDirect: unit == InventoryUnit.carton ? 1 : null,
        cartonSalePrice: unit == InventoryUnit.carton ? sale : null,
        packageSalePrice: unit == InventoryUnit.package ? sale : null,
        pocketSalePrice: unit == InventoryUnit.pocket ? sale : null,
        itemSalePrice: unit == InventoryUnit.item ? sale : null,
        costPrice: cost,
        salePrice: sale,
        priceCurrency: currency,
        createdAt: widget.product?.createdAt ?? now,
        updatedAt: now,
      );
      validateProduct(p);
      final controller = ref.read(productControllerProvider.notifier);
      if (editing) {
        await controller.updateProduct(p);
      } else {
        await controller.createProduct(p);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = e.toString();
        });
      }
    }
  }

  double? _int(TextEditingController controller) =>
      controller.text.trim().isEmpty
      ? null
      : parseLocalizedDecimal(controller.text);
}
