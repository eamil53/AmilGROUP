import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/stock_provider.dart';
import '../theme/app_theme.dart';
import '../utils/pdf_helper.dart';
import 'add_product_screen.dart';

class ProductListScreen extends StatefulWidget {
  final ProductCategory? initialCategory;
  const ProductListScreen({super.key, this.initialCategory});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  String _searchQuery = '';
  ProductCategory? _selectedCategory;
  final format = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PORT Stok'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'PDF Olarak İndir',
            onPressed: () {
              final provider = context.read<StockProvider>();
              if (provider.products.isNotEmpty) {
                PdfHelper.generateStockPdf(provider.products);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Lokalde indirilecek ürün bulunamadı.'),
                  ),
                );
              }
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Marka, Model veya IMEI Ara...',
                prefixIcon: const Icon(Icons.search),
                fillColor: Colors.white,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
        ),
      ),
      body: Consumer<StockProvider>(
        builder: (context, provider, child) {
          final filteredProducts = provider.searchProducts(_searchQuery).where((
            p,
          ) {
            return _selectedCategory == null || p.category == _selectedCategory;
          }).toList();

          return Column(
            children: [
              _buildFilterChips(),
              Expanded(
                child: filteredProducts.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = filteredProducts[index];
                          return _buildProductCard(context, product);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      child: Row(
        children: [
          FilterChip(
            label: const Text('Tümü'),
            selected: _selectedCategory == null,
            onSelected: (selected) => setState(() => _selectedCategory = null),
            backgroundColor: Colors.white,
            selectedColor: AppTheme.ttBlue,
            labelStyle: TextStyle(
              color: _selectedCategory == null ? Colors.white : AppTheme.ttBlue,
            ),
          ),
          const SizedBox(width: 8),
          ...ProductCategory.values.map((cat) {
            String label = 'Diğer';
            if (cat == ProductCategory.phone)
              label = 'Telefon';
            else if (cat == ProductCategory.headset)
              label = 'Kulaklık';
            else if (cat == ProductCategory.watch)
              label = 'Saat';
            else if (cat == ProductCategory.modem)
              label = 'Modem';
            else if (cat == ProductCategory.demo)
              label = 'Demo';
            else if (cat == ProductCategory.returned)
              label = 'Terse Alınan';

            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilterChip(
                label: Text(label),
                selected: _selectedCategory == cat,
                onSelected: (selected) =>
                    setState(() => _selectedCategory = cat),
                backgroundColor: Colors.white,
                selectedColor: AppTheme.ttBlue,
                labelStyle: TextStyle(
                  color: _selectedCategory == cat
                      ? Colors.white
                      : AppTheme.ttBlue,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Product product) {
    IconData icon = Icons.device_unknown;
    if (product.category == ProductCategory.phone)
      icon = Icons.phone_android;
    else if (product.category == ProductCategory.headset)
      icon = Icons.headphones;
    else if (product.category == ProductCategory.watch) {
      icon = Icons.watch;
    } else if (product.category == ProductCategory.modem) {
      icon = Icons.router;
    } else if (product.category == ProductCategory.demo) {
      icon = Icons.stars_rounded;
    } else if (product.category == ProductCategory.returned) {
      icon = Icons.assignment_return_rounded;
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.ttBlue.withOpacity(0.1),
          child: Icon(icon, color: AppTheme.ttBlue, size: 20),
        ),
        title: Text(
          '${product.brand} ${product.model}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          'Renk: ${product.color ?? '-'} | Adet: ${product.quantity} | Satış: ${format.format(product.salePrice)}',
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          _buildDetailRow('Geliş Fiyatı:', format.format(product.purchasePrice)),
          _buildDetailRow('Satış Fiyatı:', format.format(product.salePrice)),
          _buildDetailRow(
            'Kar (Birim):',
            format.format(product.salePrice - product.purchasePrice),
          ),
          const Divider(),
          _buildDetailRow('Renk:', product.color ?? '-'),
          _buildDetailRow('IMEI 1:', product.imei1 ?? '-'),
          _buildDetailRow('IMEI 2:', product.imei2 ?? '-'),
          _buildDetailRow('Seri No:', product.serialNumber ?? '-'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _confirmDelete(context, product),
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.grey,
                  ),
                  label: const Text('Sil', style: TextStyle(color: Colors.grey)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey[200]!),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddProductScreen(productToEdit: product),
                    ),
                  ),
                  icon: const Icon(Icons.edit, size: 18, color: AppTheme.ttBlue),
                  label: const Text(
                    'Düzenle',
                    style: TextStyle(color: AppTheme.ttBlue),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.ttBlue),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: product.quantity > 0
                      ? () => _showSellModal(context, product)
                      : null,
                  icon: const Icon(Icons.sell, size: 18),
                  label: const Text('SAT'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showSellModal(BuildContext context, Product product) {
    int quantityToSell = 1;
    PaymentType paymentType = PaymentType.nakit;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Satış İşlemi (PORT)',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${product.brand} ${product.model}',
                    style: TextStyle(color: AppTheme.ttBlue, fontSize: 18),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Satış Tipi',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('NAKİT'),
                          selected: paymentType == PaymentType.nakit,
                          onSelected: (val) => setModalState(
                            () => paymentType = PaymentType.nakit,
                          ),
                          selectedColor: AppTheme.ttBlue,
                          labelStyle: TextStyle(
                            color: paymentType == PaymentType.nakit
                                ? Colors.white
                                : AppTheme.ttBlue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('TEMLİKLİ'),
                          selected: paymentType == PaymentType.temlikli,
                          onSelected: (val) => setModalState(
                            () => paymentType = PaymentType.temlikli,
                          ),
                          selectedColor: AppTheme.ttMagenta,
                          labelStyle: TextStyle(
                            color: paymentType == PaymentType.temlikli
                                ? Colors.white
                                : AppTheme.ttMagenta,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Miktar',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: quantityToSell > 1
                            ? () => setModalState(() => quantityToSell--)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline, size: 30),
                      ),
                      const SizedBox(width: 20),
                      Text(
                        quantityToSell.toString(),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 20),
                      IconButton(
                        onPressed: quantityToSell < product.quantity
                            ? () => setModalState(() => quantityToSell++)
                            : null,
                        icon: const Icon(Icons.add_circle_outline, size: 30),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Satış Tutarı: ${format.format(product.salePrice * quantityToSell)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (paymentType == PaymentType.temlikli)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Temlikli hakediş PORT takibine eklenecektir.',
                        style: TextStyle(
                          color: Colors.orange[800],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      context.read<StockProvider>().sellProduct(
                        product.id,
                        quantityToSell,
                        paymentType,
                      );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            paymentType == PaymentType.nakit
                                ? 'Nakit satış başarılı!'
                                : 'Temlikli satış kaydedildi, hakediş bekliyor.',
                          ),
                          backgroundColor: paymentType == PaymentType.nakit
                              ? Colors.green
                              : Colors.orange,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: paymentType == PaymentType.nakit
                          ? Colors.green
                          : Colors.orange[700],
                    ),
                    child: const Text('SATIŞI ONAYLA'),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Aradığınız ürünü bulamadık.',
            style: TextStyle(color: Colors.grey[500], fontSize: 18),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ürünü Sil'),
        content: Text(
          '${product.brand} ${product.model} stoğunu silmek istediğinize emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              context.read<StockProvider>().deleteProduct(product.id);
              Navigator.pop(context);
            },
            child: const Text('SİL', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
