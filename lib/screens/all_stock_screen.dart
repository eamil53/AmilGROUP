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
        title: const Text('Tüm Stok Listesi'),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.filter_list_rounded),
                if (_selectedCategory != null || _selectedPurchaseType != null || _showOnlyLowStock)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
            onPressed: _showFilterBottomSheet,
            tooltip: 'Filtrele',
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            onPressed: () => _confirmResetAll(context),
            tooltip: 'Tüm Veriyi Sıfırla',
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Stokta ara (Marka, Model, IMEI)...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.ttBlue),
                fillColor: Colors.white,
                filled: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
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

            if (filteredProducts.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.filter_list_off_rounded, size: 60, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text('Kriterlere uygun ürün bulunamadı', 
                      style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                    if (_selectedCategory != null || _selectedPurchaseType != null || _showOnlyLowStock || 
                        _searchQuery.isNotEmpty || _selectedBrand != null || _selectedModel != null)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedCategory = null;
                            _selectedPurchaseType = null;
                            _selectedBrand = null;
                            _selectedModel = null;
                            _showOnlyLowStock = false;
                            _searchQuery = '';
                          });
                        }, 
                        child: const Text('Filtreleri Temizle')
                      ),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: filteredProducts.length,
              padding: const EdgeInsets.only(top: 8, bottom: 80),
              itemBuilder: (context, index) {
                final product = filteredProducts[index];
                return _buildCompactProductRow(context, product);
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isLowStock ? Colors.red.withOpacity(0.1) : Colors.transparent,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _getCategoryColor(product.category).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getCategoryIcon(product.category),
              color: _getCategoryColor(product.category),
              size: 24,
            ),
          ),
          title: Text(
            '${product.brand} ${product.model}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          subtitle: Row(
            children: [
              if (product.color != null) ...[
                Text(product.color!, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text('•', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
              ],
              Text('Adet: ${product.quantity}', 
                style: TextStyle(color: isLowStock ? Colors.red : Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          trailing: Text(
            _currencyFormat.format(product.salePrice),
            style: const TextStyle(color: AppTheme.ttBlue, fontWeight: FontWeight.bold),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  _buildDetailRow('IMEI 1:', product.imei1 ?? '-'),
                  _buildDetailRow('Geliş Fiyatı:', _currencyFormat.format(product.purchasePrice)),
                  _buildDetailRow('Satış Fiyatı:', _currencyFormat.format(product.salePrice)),
                  _buildDetailRow(
                    'Kar (Birim):', 
                    _currencyFormat.format(product.salePrice - product.purchasePrice),
                    isProfit: true,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => _confirmDelete(context, product),
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        tooltip: 'Ürünü Sil',
                      ),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddProductScreen(productToEdit: product))),
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('Düzenle'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.ttBlue,
                            side: const BorderSide(color: AppTheme.ttBlue),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (product.quantity > 0) {
                              _showSellModal(context, product);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stokta ürün yok!')));
                            }
                          },
                          icon: const Icon(Icons.sell, size: 18),
                          label: const Text('SAT'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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
