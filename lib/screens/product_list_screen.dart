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
        title: const Text('PORT Stok Yönetimi'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'PDF Raporu',
            onPressed: () {
              final provider = context.read<StockProvider>();
              if (provider.products.isNotEmpty) {
                PdfHelper.generateStockPdf(provider.products);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Lokalde indirilecek ürün bulunamadı.')),
                );
              }
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Marka, Model veya IMEI Ara...',
                  prefixIcon: const Icon(Icons.search, color: AppTheme.ttBlue),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
              ),
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
    Color iconColor = AppTheme.ttBlue;
    
    if (product.category == ProductCategory.phone) icon = Icons.phone_android;
    else if (product.category == ProductCategory.headset) icon = Icons.headphones;
    else if (product.category == ProductCategory.watch) icon = Icons.watch;
    else if (product.category == ProductCategory.modem) icon = Icons.router;
    else if (product.category == ProductCategory.demo) { icon = Icons.stars_rounded; iconColor = Colors.orange; }
    else if (product.category == ProductCategory.returned) { icon = Icons.assignment_return_rounded; iconColor = Colors.red; }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent, splashColor: Colors.transparent),
          child: ExpansionTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    '${product.brand} ${product.model}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: -0.2),
                  ),
                ),
                _buildStockStatusBadge(product.quantity),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Text(
                    format.format(product.salePrice),
                    style: const TextStyle(color: AppTheme.ttBlue, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '| ${product.color ?? "-"}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              const Divider(height: 1),
              const SizedBox(height: 12),
              _buildModernDetailRow('Alış Fiyatı', format.format(product.purchasePrice)),
              _buildModernDetailRow('Satış Fiyatı', format.format(product.salePrice)),
              _buildModernDetailRow(
                'Tahmini Kâr', 
                format.format(product.salePrice - product.purchasePrice),
                valueColor: Colors.green[700],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildCompactDetailRow('IMEI 1', product.imei1 ?? '-'),
                    _buildCompactDetailRow('IMEI 2', product.imei2 ?? '-'),
                    _buildCompactDetailRow('Seri No', product.serialNumber ?? '-'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _actionIconButton(Icons.delete_outline, Colors.red, () => _confirmDelete(context, product)),
                  const SizedBox(width: 8),
                  _actionIconButton(Icons.edit_outlined, AppTheme.ttBlue, () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AddProductScreen(productToEdit: product)),
                  )),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: product.quantity > 0 ? () => _showSellModal(context, product) : null,
                      icon: const Icon(Icons.shopping_cart_checkout_outlined, size: 18),
                      label: const Text('HIZLI SATIŞ', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.ttMagenta,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockStatusBadge(int quantity) {
    Color color = Colors.green;
    String label = 'STOKTA';
    if (quantity <= 0) {
      color = Colors.red;
      label = 'YOK';
    } else if (quantity <= 2) {
      color = Colors.orange;
      label = 'AZ';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$quantity $label',
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildModernDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: valueColor)),
        ],
      ),
    );
  }

  Widget _buildCompactDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$label: ', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _actionIconButton(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 20),
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
