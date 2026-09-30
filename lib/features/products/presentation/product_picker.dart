import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_text_field.dart';
import '../data/product.dart';
import '../providers/product_provider.dart';

class ProductPickerField extends StatelessWidget {
  const ProductPickerField({
    super.key,
    required this.value,
    required this.onSelected,
  });

  final Product? value;
  final ValueChanged<Product> onSelected;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: () async {
      final selected = await showModalBottomSheet<Product>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _ProductPickerSheet(selected: value),
      );
      if (selected != null) onSelected(selected);
    },
    child: InputDecorator(
      decoration: const InputDecoration(
        labelText: 'محصول',
        suffixIcon: Icon(Icons.arrow_drop_down),
      ),
      child: Text(value?.name ?? 'انتخاب محصول'),
    ),
  );
}

class _ProductPickerSheet extends ConsumerStatefulWidget {
  const _ProductPickerSheet({this.selected});
  final Product? selected;

  @override
  ConsumerState<_ProductPickerSheet> createState() =>
      _ProductPickerSheetState();
}

class _ProductPickerSheetState extends ConsumerState<_ProductPickerSheet> {
  late final TextEditingController search;
  List<Product> products = const [];
  bool loading = true;
  int request = 0;

  @override
  void initState() {
    super.initState();
    search = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _load([String query = '']) async {
    final currentRequest = ++request;
    setState(() => loading = true);
    try {
      final page = await ref
          .read(productRepositoryProvider)
          .getProductsPage(query: query, limit: 20);
      if (!mounted || currentRequest != request) return;
      setState(() {
        products = page.items;
        loading = false;
      });
    } catch (_) {
      if (mounted && currentRequest == request) {
        setState(() {
          products = const [];
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .7,
        child: Column(
          children: [
            AppTextField(
              controller: search,
              label: 'جستجوی محصول یا بارکد',
              prefix: const Icon(Icons.search),
              onChanged: _load,
            ),
            const SizedBox(height: AppSpacing.md),
            if (loading) const LinearProgressIndicator(),
            Expanded(
              child: products.isEmpty && !loading
                  ? const Center(child: Text('محصولی پیدا نشد'))
                  : ListView.separated(
                      itemCount: products.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final product = products[index];
                        return ListTile(
                          title: Text(product.name),
                          subtitle: product.barcode == null
                              ? null
                              : Text(product.barcode!),
                          trailing: product.id == widget.selected?.id
                              ? const Icon(Icons.check, color: Colors.blue)
                              : null,
                          onTap: () => Navigator.pop(context, product),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}
