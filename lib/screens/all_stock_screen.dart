import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/stock_provider.dart';
import '../theme/app_theme.dart';
import 'add_product_screen.dart';

class AllStockScreen extends StatefulWidget {
  const AllStockScreen({super.key});

  @override
  State<AllStockScreen> createState() => _AllStockScreenState();
}

class _AllStockScreenState extends State<AllStockScreen> {
  String _searchQuery = '';
  ProductCategory? _selectedCategory;
  PurchaseType? _selectedPurchaseType;
  String? _selectedBrand;
  String? _selectedModel;
  bool _showOnlyLowStock = false;
  final _currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

  void _showFilterBottomSheet() {
    final provider = context.read<StockProvider>();
    final allBrands = provider.products.map((p) => p.brand.toUpperCase().trim()).toSet().toList()..sort();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final availableModels = provider.products
              .where((p) => _selectedBrand == null || p.brand.toUpperCase().trim() == _selectedBrand)
              .map((p) => p.model.toUpperCase().trim())
              .toSet().toList()..sort();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24, right: 24, top: 24
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Filtreleme Seçenekleri', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedCategory = null;
                              _selectedPurchaseType = null;
                              _selectedBrand = null;
                              _selectedModel = null;
                              _showOnlyLowStock = false;
                            });
                            Navigator.pop(context);
                          }, 
                          child: const Text('Temizle')
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // MARKA
                    const Text('Marka', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedBrand,
                      isExpanded: true,
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                      hint: const Text('Tüm Markalar'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Tüm Markalar')),
                        ...allBrands.map((b) => DropdownMenuItem(value: b, child: Text(b))),
                      ],
                      onChanged: (val) {
                        setModalState(() {
                          _selectedBrand = val;
                          _selectedModel = null; // Marka değişince model sıfırlanır
                        });
                        setState(() {
                          _selectedBrand = val;
                          _selectedModel = null;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // MODEL
                    const Text('Model', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedModel,
                      isExpanded: true,
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                      hint: const Text('Tüm Modeller'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Tüm Modeller')),
                        ...availableModels.map((m) => DropdownMenuItem(value: m, child: Text(m))),
                      ],
                      onChanged: (val) {
                        setModalState(() => _selectedModel = val);
                        setState(() => _selectedModel = val);
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text('Kategori', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                           ...ProductCategory.values.map((cat) => Padding(
                             padding: const EdgeInsets.only(right: 8.0),
                             child: ChoiceChip(
                               label: Text(_getCategoryLabel(cat)),
                               selected: _selectedCategory == cat,
                               onSelected: (val) {
                                 setModalState(() => _selectedCategory = val ? cat : null);
                                 setState(() => _selectedCategory = val ? cat : null);
                               },
                             ),
                           ))
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Alış Türü (Cari)', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Vadeli (Borç)'),
                          selected: _selectedPurchaseType == PurchaseType.vadeli,
                          onSelected: (val) {
                             setModalState(() => _selectedPurchaseType = val ? PurchaseType.vadeli : null);
                             setState(() => _selectedPurchaseType = val ? PurchaseType.vadeli : null);
                          },
                        ),
                        const SizedBox(width: 12),
                        ChoiceChip(
                          label: const Text('Nakit'),
                          selected: _selectedPurchaseType == PurchaseType.nakit,
                          onSelected: (val) {
                             setModalState(() => _selectedPurchaseType = val ? PurchaseType.nakit : null);
                             setState(() => _selectedPurchaseType = val ? PurchaseType.nakit : null);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SwitchListTile(
                      title: const Text('Sadece Kritik Stokları Göster', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      value: _showOnlyLowStock, 
                      onChanged: (val) {
                        setModalState(() => _showOnlyLowStock = val);
                        setState(() => _showOnlyLowStock = val);
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('FİLTRELEYİ UYGULA')),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  String _getCategoryLabel(ProductCategory cat) {
    switch (cat) {
      case ProductCategory.phone: return 'Telefon';
      case ProductCategory.headset: return 'Kulaklık';
      case ProductCategory.watch: return 'Saat';
      case ProductCategory.modem: return 'Modem';
      case ProductCategory.demo: return 'Demo';
      case ProductCategory.returned: return 'İade';
      default: return 'Diğer';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('PORT Merkezi Stok'),
        elevation: 0,
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.tune_rounded),
                if (_selectedCategory != null || _selectedPurchaseType != null || _showOnlyLowStock || _selectedBrand != null || _selectedModel != null)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: Colors.red, border: Border.all(color: Colors.white, width: 2), shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
            onPressed: _showFilterBottomSheet,
            tooltip: 'Filtrele',
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5)),
                ],
              ),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Stokta ara (Marka, Model, IMEI)...',
                  prefixIcon: const Icon(Icons.search, color: AppTheme.ttBlue),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        bottom: true,
        child: Consumer<StockProvider>(
          builder: (context, provider, child) {
            final allBrands = provider.products
                .map((p) => p.brand.toUpperCase().trim())
                .toSet()
                .toList()
              ..sort();

            var filteredProducts = provider.searchProducts(_searchQuery);
            
            // Apply additional filters
            if (_selectedBrand != null) {
              filteredProducts = filteredProducts.where((p) => p.brand.toUpperCase().trim() == _selectedBrand).toList();
            }
            if (_selectedModel != null) {
              filteredProducts = filteredProducts.where((p) => p.model.toUpperCase().trim() == _selectedModel).toList();
            }
            if (_selectedCategory != null) {
              filteredProducts = filteredProducts.where((p) => p.category == _selectedCategory).toList();
            }
            if (_selectedPurchaseType != null) {
              filteredProducts = filteredProducts.where((p) => p.purchaseType == _selectedPurchaseType).toList();
            }
            if (_showOnlyLowStock) {
              filteredProducts = filteredProducts.where((p) => provider.getTotalQuantity(p.brand, p.model) <= provider.lowStockThreshold).toList();
            }

            return Column(
              children: [
                _buildQuickBrandFilters(allBrands),
                Expanded(
                  child: filteredProducts.isEmpty 
                    ? _buildNoResults() 
                    : ListView.builder(
                        itemCount: filteredProducts.length,
                        padding: const EdgeInsets.only(top: 4, bottom: 80),
                        itemBuilder: (context, index) {
                          final product = filteredProducts[index];
                          return _buildCompactProductRow(context, product);
                        },
                      ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddProductScreen())),
        label: const Text('Yeni Ürün Ekle'),
        icon: const Icon(Icons.add),
        backgroundColor: AppTheme.ttBlue,
      ),
    );
  }

  Widget _buildCompactProductRow(BuildContext context, Product product) {
    final provider = context.read<StockProvider>();
    bool isLowStock = provider.getTotalQuantity(product.brand, product.model) <= provider.lowStockThreshold;
    Color categoryColor = _getCategoryColor(product.category);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showProductQuickDetail(context, product),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getCategoryIcon(product.category),
                    color: categoryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${product.brand} ${product.model}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: -0.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (product.color != null) ...[
                             Text(product.color!, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                             const SizedBox(width: 6),
                          ],
                          _buildStockBadge(product.quantity, isLowStock),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _currencyFormat.format(product.salePrice),
                      style: const TextStyle(color: AppTheme.ttBlue, fontWeight: FontWeight.w900, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.purchaseType == PurchaseType.vadeli ? "VADELİ" : "NAKİT",
                      style: TextStyle(color: product.purchaseType == PurchaseType.vadeli ? AppTheme.ttMagenta : Colors.orange, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: Colors.grey[200], size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStockBadge(int quantity, bool isLowStock) {
    Color color = isLowStock ? Colors.red : Colors.green[600]!;
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$quantity Adet',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  void _showProductQuickDetail(BuildContext context, Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + MediaQuery.of(context).padding.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(product.category).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(_getCategoryIcon(product.category), color: _getCategoryColor(product.category), size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.brand, style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                        Text(product.model, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              _buildDetailRowFull('IMEI 1', product.imei1 ?? '-'),
              _buildDetailRowFull('IMEI 2', product.imei2 ?? '-'),
              _buildDetailRowFull('Seri No', product.serialNumber ?? '-'),
              const Divider(height: 32),
              _buildDetailRowFull('Alış Fiyatı', _currencyFormat.format(product.purchasePrice)),
              _buildDetailRowFull('Satış Fiyatı', _currencyFormat.format(product.salePrice), isBold: true),
              _buildDetailRowFull('Tahmini Kâr', _currencyFormat.format(product.salePrice - product.purchasePrice), color: Colors.green),
              const SizedBox(height: 40),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddProductScreen(productToEdit: product))),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: Text('DÜZENLE', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        if (product.quantity > 0) _showSellModal(context, product);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.ttMagenta,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text('HIZLI SAT', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildDetailRowFull(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.w600, fontSize: 15, color: color)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isProfit = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(
            value, 
            style: TextStyle(
              fontWeight: FontWeight.bold, 
              fontSize: 13,
              color: isProfit ? Colors.green[700] : Colors.black,
            )
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(ProductCategory category) {
    switch (category) {
      case ProductCategory.phone: return Icons.phone_android;
      case ProductCategory.headset: return Icons.headphones;
      case ProductCategory.watch: return Icons.watch;
      case ProductCategory.modem: return Icons.router;
      case ProductCategory.demo: return Icons.stars_rounded;
      case ProductCategory.returned: return Icons.assignment_return_rounded;
      default: return Icons.device_unknown;
    }
  }

  Color _getCategoryColor(ProductCategory category) {
    switch (category) {
      case ProductCategory.phone: return AppTheme.ttBlue;
      case ProductCategory.headset: return Colors.purple;
      case ProductCategory.watch: return Colors.orange;
      case ProductCategory.modem: return Colors.teal;
      case ProductCategory.demo: return Colors.amber;
      case ProductCategory.returned: return Colors.red;
      default: return Colors.grey;
    }
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
                  const Text('Satış Tipi', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('NAKİT'),
                          selected: paymentType == PaymentType.nakit,
                          onSelected: (val) => setModalState(() => paymentType = PaymentType.nakit),
                          selectedColor: AppTheme.ttBlue,
                          labelStyle: TextStyle(color: paymentType == PaymentType.nakit ? Colors.white : AppTheme.ttBlue),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('TEMLİKLİ'),
                          selected: paymentType == PaymentType.temlikli,
                          onSelected: (val) => setModalState(() => paymentType = PaymentType.temlikli),
                          selectedColor: AppTheme.ttMagenta,
                          labelStyle: TextStyle(color: paymentType == PaymentType.temlikli ? Colors.white : AppTheme.ttMagenta),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('Miktar', style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: quantityToSell > 1 ? () => setModalState(() => quantityToSell--) : null,
                        icon: const Icon(Icons.remove_circle_outline, size: 30),
                      ),
                      const SizedBox(width: 20),
                      Text(quantityToSell.toString(), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 20),
                      IconButton(
                        onPressed: quantityToSell < product.quantity ? () => setModalState(() => quantityToSell++) : null,
                        icon: const Icon(Icons.add_circle_outline, size: 30),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Satış Tutarı: ${_currencyFormat.format(product.salePrice * quantityToSell)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      context.read<StockProvider>().sellProduct(product.id, quantityToSell, paymentType);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(paymentType == PaymentType.nakit ? 'Nakit satış başarılı!' : 'Temlikli satış kaydedildi.'),
                          backgroundColor: paymentType == PaymentType.nakit ? Colors.green : Colors.orange,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: paymentType == PaymentType.nakit ? Colors.green : Colors.orange[700]),
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
  void _confirmDelete(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ürünü Sil'),
        content: Text('${product.brand} ${product.model} stoğunu silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
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

  Widget _buildQuickBrandFilters(List<String> brands) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: brands.length + 1,
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final brand = isAll ? 'HEPSİ' : brands[index - 1];
          final isSelected = isAll ? _selectedBrand == null : _selectedBrand == brand;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(brand),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedBrand = isAll ? null : (selected ? brand : null);
                  _selectedModel = null; // Reset model when brand changes
                });
              },
              selectedColor: AppTheme.ttBlue,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[600],
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: Colors.grey[100],
              padding: const EdgeInsets.symmetric(horizontal: 4),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide.none),
              showCheckmark: false,
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text('Ürün bulunamadı', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() {
              _selectedBrand = null;
              _selectedModel = null;
              _selectedCategory = null;
              _selectedPurchaseType = null;
              _showOnlyLowStock = false;
              _searchQuery = '';
            }),
            child: const Text('Tüm Filtreleri Temizle'),
          ),
        ],
      ),
    );
  void _confirmResetAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tüm Veriyi Sıfırla'),
        content: const Text('Tüm ürünler, satış kayıtları, ciro ve kar verileri sıfırlanacaktır. Bu işlem geri alınamaz!'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          TextButton(
            onPressed: () {
              context.read<StockProvider>().clearAllData();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tüm veriler sıfırlandı!'), backgroundColor: Colors.green));
            },
            child: const Text('HER ŞEYİ SIFIRLA', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
}
