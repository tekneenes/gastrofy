// lib/widgets/product_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/product_model.dart';
class ProductCard extends StatelessWidget {
  final ProductModel product;
  final bool isFixed;

  const ProductCard({super.key, required this.product, this.isFixed = false});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isFixed
            ? const BorderSide(color: Colors.blueAccent, width: 3)
            : BorderSide.none,
      ),
      color: isFixed ? Colors.blue[50] : Colors.white,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.fastfood,
                    size: 40, color: Colors.orange[700]), // Ürün ikonu
                const SizedBox(height: 8),
                Text(
                  product.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  NumberFormat.currency(locale: 'tr_TR', symbol: '₺')
                      .format(product.price),
                  style: const TextStyle(color: Colors.green, fontSize: 14),
                ),
              ],
            ),
          ),
          if (isFixed)
            Positioned(
              top: 5,
              right: 5,
              child: Tooltip(
                message: 'Sabitlenmiş Ürün',
                child: Icon(Icons.push_pin, color: Colors.blueAccent, size: 20),
              ),
            ),
        ],
      ),
    );
  }
}
