// TODO Implement this library.
import 'package:flutter/material.dart';

class ProductDetailAnalyticsScreen extends StatelessWidget {
  final String productId;
  final String productName;

  const ProductDetailAnalyticsScreen({
    super.key,
    required this.productId,
    required this.productName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(productName),
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Text(
          //$productName
          'Bu sayfa geliştirilmeye devam ediyor',
          style: const TextStyle(
            fontSize: 18,
            color: Color.fromARGB(255, 229, 7, 7),
          ),
        ),
      ),
    );
  }
}
