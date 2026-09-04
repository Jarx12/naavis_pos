import 'package:flutter/material.dart';
import 'package:naavis_pos/features/catalog/domain/product_model.dart';

class VariationSelectionDialog extends StatelessWidget {
  final ProductDetailOut product;
  final Function(VariationOut selectedVariation) onVariationSelected;

  const VariationSelectionDialog({
    super.key,
    required this.product,
    required this.onVariationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            product.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Selecciona una variante (Precio: \$${product.finalPrice})',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: product.variations.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final variation = product.variations[index];
            final bool hasStock = variation.stock > 0;

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              title: Text(
                variation.variationType,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: hasStock ? Colors.black87 : Colors.grey[400],
                ),
              ),
              subtitle: Text(
                hasStock ? 'Stock disponible: ${variation.stock}' : 'Agotado',
                style: TextStyle(
                  color: hasStock ? Colors.green[700] : Colors.red[400],
                  fontSize: 12,
                ),
              ),
              trailing: ElevatedButton(
                onPressed: hasStock
                    ? () {
                        Navigator.of(context).pop();
                        onVariationSelected(variation);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                child: const Text('Agregar'),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}