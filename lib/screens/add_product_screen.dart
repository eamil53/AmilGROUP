import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../providers/stock_provider.dart';
import '../theme/app_theme.dart';

class AddProductScreen extends StatefulWidget {
  final Product? productToEdit;
  const AddProductScreen({super.key, this.productToEdit});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _imei1Controller = TextEditingController();
  final _imei2Controller = TextEditingController();
  final _snController = TextEditingController();
  final _colorController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _salePriceController = TextEditingController();
  final _bulkImeiController = TextEditingController();
  ProductCategory _category = ProductCategory.phone;
  int _quantity = 1;
  double _currentHakedis = 0.0;
  PurchaseType _purchaseType = PurchaseType.vadeli;
  bool _isBulkMode = false;
  final List<String> _scannedImeis = [];

  @override
  void initState() {
    super.initState();
    if (widget.productToEdit != null) {
      final p = widget.productToEdit!;
      _brandController.text = p.brand;
      _modelController.text = p.model;
      _colorController.text = p.color ?? '';
      _imei1Controller.text = p.imei1 ?? '';
      _imei2Controller.text = p.imei2 ?? '';
      _snController.text = p.serialNumber ?? '';
      _category = p.category;
      _quantity = p.quantity;
      _purchasePriceController.text = p.purchasePrice
          .toStringAsFixed(2)
          .replaceAll('.', ',');
      _salePriceController.text = p.salePrice
          .toStringAsFixed(2)
          .replaceAll('.', ',');
      _purchaseType = p.purchaseType;
      _updateHakedis(p.brand, p.model);
    }
  }

  void _updateHakedis(
    String brand,
    String model, {
    bool updatePurchasePrice = false,
    String? fullKey,
  }) {
    if ((brand.isNotEmpty && model.isNotEmpty) ||
        (fullKey != null && fullKey.isNotEmpty)) {
      final provider = context.read<StockProvider>();
      final excelData = fullKey != null
          ? provider.excelDataMap[fullKey.toUpperCase().trim()]
          : provider.getExcelProductData(brand, model);

      setState(() {
        _currentHakedis = excelData?['hakedis'] ?? 0.0;
        if (updatePurchasePrice && excelData != null) {
          final price = excelData['purchasePrice'] ?? 0.0;
          if (price > 0) {
            _purchasePriceController.text = price
                .toStringAsFixed(2)
                .replaceAll('.', ',');
          }
        }
      });
    } else {
      setState(() => _currentHakedis = 0.0);
    }
  }

  double _parsePrice(String value) {
    if (value.isEmpty) return 0.0;
    // Replace dots (thousands separator if any) and commas (decimal separator)
    // Common case: 1.234,56 or 1234,56
    String sanitized = value.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(sanitized) ?? 0.0;
  }

  void _scanBarcode(
    TextEditingController controller, {
    Function(String)? onScanned,
  }) async {
    final modalHeight = MediaQuery.of(context).size.height * 0.7;
    final scanWindow = Rect.fromCenter(
      center: Offset(MediaQuery.of(context).size.width / 2, modalHeight / 2),
      width: 300,
      height: 120,
    );

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                child: MobileScanner(
                  scanWindow: scanWindow,
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty) {
                      Navigator.pop(context, barcodes.first.displayValue);
                    }
                  },
                ),
              ),
              // Overlay Mask
              CustomPaint(
                painter: ScannerOverlayPainter(scanWindow),
                child: Container(),
              ),
              // Scan Window Decoration (Border)
              Positioned.fromRect(
                rect: scanWindow,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.ttMagenta, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              // Scanning Line
              _ScanningLine(scanWindow: scanWindow),
              // Header/Action buttons in modal
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Barkod / IMEI Okut',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 30,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ),
              const Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    'Barkodu kutu içine hizalayın',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (result != null) {
      if (onScanned != null) {
        onScanned(result);
      } else {
        setState(() => controller.text = result);
      }
    }
  }

  void _submitData() {
    if (_formKey.currentState!.validate()) {
      final provider = context.read<StockProvider>();

      if (_isBulkMode && _scannedImeis.isNotEmpty) {
        // Bulk mode check is handled when scanning, but double check against products list
        for (var imei in _scannedImeis) {
          final pEntry = Product(
            id: const Uuid().v4(),
            brand: _brandController.text,
            model: _modelController.text,
            imei1: imei,
            category: _category,
            purchasePrice: _parsePrice(_purchasePriceController.text),
            salePrice: _parsePrice(_salePriceController.text),
            createdAt: DateTime.now(),
          );
          final error = provider.getDuplicateInfo(pEntry);
          if (error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Hata: $error'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        }

        final List<Product> products = _scannedImeis.map((imei) {
          return Product(
            id: const Uuid().v4(),
            brand: _brandController.text,
            model: _modelController.text,
            color: _colorController.text.isNotEmpty
                ? _colorController.text
                : null,
            imei1: imei,
            category: _category,
            quantity: 1,
            purchasePrice: _parsePrice(_purchasePriceController.text),
            salePrice: _parsePrice(_salePriceController.text),
            createdAt: DateTime.now(),
            purchaseType: _purchaseType,
          );
        }).toList();
        provider.addProducts(products);
      } else {
        final productData = Product(
          id: widget.productToEdit?.id ?? const Uuid().v4(),
          brand: _brandController.text,
          model: _modelController.text,
          color: _colorController.text.isNotEmpty
              ? _colorController.text
              : null,
          imei1: _imei1Controller.text.isNotEmpty
              ? _imei1Controller.text
              : null,
          imei2: _imei2Controller.text.isNotEmpty
              ? _imei2Controller.text
              : null,
          serialNumber: _snController.text.isNotEmpty
              ? _snController.text
              : null,
          category: _category,
          quantity: _quantity,
          purchasePrice: _parsePrice(_purchasePriceController.text),
          salePrice: _parsePrice(_salePriceController.text),
          createdAt: widget.productToEdit?.createdAt ?? DateTime.now(),
          purchaseType: _purchaseType,
        );

        final error = provider.getDuplicateInfo(productData);
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Mükerrer Kayıt: $error'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        if (widget.productToEdit != null) {
          provider.updateProduct(productData);
        } else {
          provider.addProduct(productData);
        }
      }

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StockProvider>();
    final hakedisOptions = provider.hakedisMap.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.productToEdit != null ? 'Ürünü Düzenle' : 'Yeni Ürün Ekle',
        ),
      ),
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Kategori'),
                const SizedBox(height: 12),
                _buildCategorySelector(),
                const SizedBox(height: 24),
                _buildSectionHeader('Excel\'den Ürün Seçimi'),
                const SizedBox(height: 12),

                LayoutBuilder(
                  builder: (context, constraints) {
                    return Autocomplete<String>(
                      optionsBuilder: (textEditingValue) {
                        if (textEditingValue.text.isEmpty)
                          return const Iterable<String>.empty();
                        return hakedisOptions.where(
                          (option) => option.contains(
                            textEditingValue.text.toUpperCase(),
                          ),
                        );
                      },
                      onSelected: (String selection) {
                        final parts = selection.split(' ');
                        if (parts.isNotEmpty) {
                          final brand = parts[0];
                          final model = parts.sublist(1).join(' ');
                          setState(() {
                            _brandController.text = brand;
                            _modelController.text = model;
                          });
                          _updateHakedis(
                            brand,
                            model,
                            updatePurchasePrice: true,
                            fullKey: selection,
                          );
                        }
                      },
                      // Bu kısım RenderBox hatasını çözer
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4.0,
                            child: Container(
                              width: constraints.maxWidth,
                              constraints: const BoxConstraints(maxHeight: 200),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (BuildContext context, int index) {
                                  final String option = options.elementAt(
                                    index,
                                  );
                                  return ListTile(
                                    title: Text(
                                      option,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    onTap: () => onSelected(option),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                      fieldViewBuilder:
                          (context, controller, focusNode, onFieldSubmitted) {
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: const InputDecoration(
                                labelText: 'Hızlı Arama (Marka/Model Yazın)',
                                hintText: 'Excel listesinden otomatik bulur...',
                                prefixIcon: Icon(Icons.search),
                              ),
                            );
                          },
                    );
                  },
                ),
                const SizedBox(height: 24),
                _buildSectionHeader('Ürün Bilgileri'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _brandController,
                        decoration: const InputDecoration(
                          labelText: 'Marka',
                          prefixIcon: Icon(Icons.branding_watermark),
                        ),
                        validator: (v) => v!.isEmpty ? 'Gerekli' : null,
                        onChanged: (v) =>
                            _updateHakedis(v, _modelController.text),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _modelController,
                        decoration: const InputDecoration(
                          labelText: 'Model',
                          prefixIcon: Icon(Icons.devices),
                        ),
                        validator: (v) => v!.isEmpty ? 'Gerekli' : null,
                        onChanged: (v) =>
                            _updateHakedis(_brandController.text, v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _colorController,
                  decoration: const InputDecoration(
                    labelText: 'Renk (Örn: Siyah, Mavi)',
                    prefixIcon: Icon(Icons.palette),
                  ),
                ),

                if (_currentHakedis > 0)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tahmini Temlik Hakedişi: ${NumberFormat.currency(locale: 'tr_TR', symbol: '₺').format(_currentHakedis)}',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionHeader('Cihaz Tanımlayıcılar'),
                    Row(
                      children: [
                        const Text(
                          'Toplu Kayıt ',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Switch(
                          value: _isBulkMode,
                          onChanged: (v) => setState(() => _isBulkMode = v),
                          activeColor: AppTheme.ttMagenta,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!_isBulkMode) ...[
                  _buildScannerField('IMEI 1', _imei1Controller),
                  const SizedBox(height: 12),
                  _buildScannerField('IMEI 2 (Opsiyonel)', _imei2Controller),
                  const SizedBox(height: 12),
                  _buildScannerField('Seri No (Opsiyonel)', _snController),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Cihazları tek tek okutun. Her okutma ayrı bir ürün kaydeder.',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () async {
                            _scanBarcode(
                              _bulkImeiController,
                              onScanned: (res) => _addBulkImei(res),
                            );
                          },
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('KAMERA İLE OKUT'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.ttMagenta,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildBulkScanInput(),
                        const SizedBox(height: 12),
                        if (_scannedImeis.isNotEmpty)
                          Column(
                            children: _scannedImeis.asMap().entries.map((
                              entry,
                            ) {
                              return ListTile(
                                title: Text(
                                  'Cihaz ${entry.key + 1}: ${entry.value}',
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => setState(
                                    () => _scannedImeis.removeAt(entry.key),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                _buildSectionHeader('Fiyat Bilgileri'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _purchasePriceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Bayi Alış (₺)',
                          prefixIcon: Icon(Icons.download),
                        ),
                        validator: (v) => v!.isEmpty ? 'Gerekli' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _salePriceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Satış Fiyatı (₺)',
                          prefixIcon: Icon(Icons.upload),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Gerekli';
                          if (_parsePrice(v) <= 0) return 'Geçersiz fiyat';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSectionHeader('Alış Şekli (Cari Hesap)'),
                const SizedBox(height: 12),
                _buildPurchaseTypeSelector(),
                const SizedBox(height: 24),
                _buildSectionHeader('Stok Miktarı'),
                _buildQuantitySelector(),

                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _submitData,
                  child: Text(
                    widget.productToEdit != null ? 'GÜNCELLE' : 'STOK KAYDET',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppTheme.ttBlue,
      ),
    );
  }

  Widget _buildCategorySelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ProductCategory.values.map((cat) {
          final isSelected = _category == cat;
          String label = cat.toString().split('.').last;
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
          else
            label = 'Diğer';

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              selected: isSelected,
              label: Text(label),
              onSelected: (val) => setState(() => _category = cat),
              selectedColor: AppTheme.ttBlue,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppTheme.ttBlue,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPurchaseTypeSelector() {
    return Row(
      children: [
        Expanded(
          child: ChoiceChip(
            label: const Text('PORT VADELİ (BORÇ)'),
            selected: _purchaseType == PurchaseType.vadeli,
            onSelected: (val) =>
                setState(() => _purchaseType = PurchaseType.vadeli),
            selectedColor: AppTheme.ttBlue,
            labelStyle: TextStyle(
              color: _purchaseType == PurchaseType.vadeli
                  ? Colors.white
                  : AppTheme.ttBlue,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ChoiceChip(
            label: const Text('NAKİT ÖDENDİ'),
            selected: _purchaseType == PurchaseType.nakit,
            onSelected: (val) =>
                setState(() => _purchaseType = PurchaseType.nakit),
            selectedColor: Colors.green,
            labelStyle: TextStyle(
              color: _purchaseType == PurchaseType.nakit
                  ? Colors.white
                  : Colors.green,
            ),
          ),
        ),
      ],
    );
  }

  void _addBulkImei(String imei) {
    if (imei.isEmpty) return;

    final provider = context.read<StockProvider>();
    // Duplication check in products
    final dummyProduct = Product(
      id: '',
      brand: '',
      model: '',
      imei1: imei,
      category: _category,
      purchasePrice: 0,
      salePrice: 0,
      createdAt: DateTime.now(),
    );
    final error = provider.getDuplicateInfo(dummyProduct);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Zaten Kayıtlı: $error'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_scannedImeis.contains(imei)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu IMEI listede zaten var!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _scannedImeis.add(imei);
      _bulkImeiController.clear();
    });
  }

  Widget _buildBulkScanInput() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _bulkImeiController,
            decoration: const InputDecoration(
              labelText: 'IMEI Yazın veya Okutun',
              hintText: 'IMEI girip artıya basın',
            ),
            onFieldSubmitted: (v) => _addBulkImei(v),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle, color: AppTheme.ttBlue, size: 32),
          onPressed: () => _addBulkImei(_bulkImeiController.text),
        ),
      ],
    );
  }

  Widget _buildScannerField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.qr_code_scanner),
        suffixIcon: IconButton(
          icon: const Icon(Icons.camera_alt, color: AppTheme.ttMagenta),
          onPressed: () => _scanBarcode(controller),
        ),
      ),
    );
  }

  Widget _buildQuantitySelector() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text(
            _quantity.toString(),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          IconButton(
            onPressed: () => setState(() => _quantity++),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _colorController.dispose();
    _imei1Controller.dispose();
    _imei2Controller.dispose();
    _snController.dispose();
    _purchasePriceController.dispose();
    _salePriceController.dispose();
    _bulkImeiController.dispose();
    super.dispose();
  }
}

class ScannerOverlayPainter extends CustomPainter {
  final Rect scanWindow;
  ScannerOverlayPainter(this.scanWindow);

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(scanWindow, const Radius.circular(12)),
      );
    final backgroundPaint = Paint()..color = Colors.black.withOpacity(0.5);

    canvas.drawPath(
      Path.combine(PathOperation.difference, backgroundPath, cutoutPath),
      backgroundPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScanningLine extends StatefulWidget {
  final Rect scanWindow;
  const _ScanningLine({required this.scanWindow});

  @override
  State<_ScanningLine> createState() => _ScanningLineState();
}

class _ScanningLineState extends State<_ScanningLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final top =
            widget.scanWindow.top +
            (widget.scanWindow.height * _controller.value);
        return Positioned(
          top: top,
          left: widget.scanWindow.left,
          right: MediaQuery.of(context).size.width - widget.scanWindow.right,
          child: Container(
            height: 2,
            width: widget.scanWindow.width,
            decoration: BoxDecoration(
              color: AppTheme.ttMagenta,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.ttMagenta.withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
