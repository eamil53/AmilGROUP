import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/stock_provider.dart';
import '../theme/app_theme.dart';
import 'add_product_screen.dart';

class CriticalStockScreen extends StatelessWidget {
  const CriticalStockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kritik Stoklar'),
        backgroundColor: Colors.red[700],
      ),
      body: Consumer<StockProvider>(
        builder: (context, provider, child) {
          final lowStockItems = provider.lowStockProducts;

          if (lowStockItems.isEmpty) {
            return _buildEmptyState();
          }

          return SafeArea(
            bottom: true,
            child: Column(
              children: [
                _buildThresholdBanner(context, provider),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: lowStockItems.length,
                    itemBuilder: (context, index) {
                      final product = lowStockItems[index];
                      return _buildCriticalProductCard(context, product);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildThresholdBanner(BuildContext context, StockProvider provider) {
    return Container(
      width: double.infinity,
      color: Colors.red[50]?.withOpacity(0.5),
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Kritik Seviye Sınırı:', style: TextStyle(fontWeight: FontWeight.bold)),
          Row(
            children: [
              IconButton(onPressed: provider.lowStockThreshold > 1 ? () => provider.updateThreshold(provider.lowStockThreshold - 1) : null, icon: const Icon(Icons.remove_circle_outline, size: 20)),
              Text(provider.lowStockThreshold.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              IconButton(onPressed: () => provider.updateThreshold(provider.lowStockThreshold + 1), icon: const Icon(Icons.add_circle_outline, size: 20)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCriticalProductCard(BuildContext context, Product product) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFFFEBEE), // Colors.red[100] equivalent
          child: const Icon(Icons.warning_amber_rounded, color: Colors.red),
        ),
        title: Text('${product.brand} ${product.model}', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Kalan Miktar: ${product.quantity}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
        // Butonun sonsuz genişlemeye çalışmasını engellemek için SizedBox içine alıyoruz
        trailing: SizedBox(
          width: 100,
          child: ElevatedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddProductScreen(productToEdit: product))),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.ttBlue, 
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 40),
            ),
            child: const Text('GÜNCELLE', style: TextStyle(fontSize: 12)),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 80, color: Colors.green[200]),
          const SizedBox(height: 16),
          const Text('Harika! Kritik seviyede ürün yok.', style: TextStyle(fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }
}
