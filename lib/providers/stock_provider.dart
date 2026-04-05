import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/product.dart';
import '../utils/notification_service.dart';

class StockProvider extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;
  List<Product> _products = [];
  List<Sale> _sales = [];
  List<DebtPayment> _payments = [];
  Map<String, Map<String, double>> _excelDataMap = {}; 
  bool _isLoading = true;
  int _lowStockThreshold = 2; // Default limit for alerts

  List<Product> get products => _products;
  List<Sale> get sales => _sales;
  List<DebtPayment> get payments => _payments;
  bool get isLoading => _isLoading;
  Map<String, double> get hakedisMap => _excelDataMap.map((key, value) => MapEntry(key, value['hakedis'] ?? 0.0));
  Map<String, Map<String, double>> get excelDataMap => _excelDataMap;
  int get lowStockThreshold => _lowStockThreshold;

  StockProvider() {
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    
    final String? productsJson = prefs.getString('stok_products');
    if (productsJson != null) {
      final List<dynamic> decoded = json.decode(productsJson);
      _products = decoded.map((e) => Product.fromMap(e)).toList();
    }

    final String? salesJson = prefs.getString('stok_sales');
    if (salesJson != null) {
      final List<dynamic> decoded = json.decode(salesJson);
      _sales = decoded.map((e) => Sale.fromMap(e)).toList();
    }
    
    final String? paymentsJson = prefs.getString('stok_payments');
    if (paymentsJson != null) {
      final List<dynamic> decoded = json.decode(paymentsJson);
      _payments = decoded.map((e) => DebtPayment.fromMap(e)).toList();
    }

    // New excel data map
    final String? excelJson = prefs.getString('excel_product_data');
    if (excelJson != null) {
      final map = json.decode(excelJson) as Map<String, dynamic>;
      _excelDataMap = map.map((key, value) => MapEntry(key, Map<String, double>.from(value)));
    } else {
      // Migrate from old hakedis map if exists
      final String? hakedisJson = prefs.getString('por_hakedis_map');
      if (hakedisJson != null) {
        final oldMap = Map<String, double>.from(json.decode(hakedisJson));
        oldMap.forEach((key, value) {
          _excelDataMap[key] = {'hakedis': value, 'purchasePrice': 0.0};
        });
      }
    }

    _lowStockThreshold = prefs.getInt('stok_low_threshold') ?? 2;

    _isLoading = false;
    notifyListeners();

    // İlk açılışta verileri Firebase'e bir kez senkronize etmeyi teklif edebiliriz
    // veya otomatik yapabiliriz. Burada otomatik yapıyoruz:
    if (prefs.getBool('firebase_initial_sync_done') != true) {
      await syncExistingToFirestore();
      await prefs.setBool('firebase_initial_sync_done', true);
    }
  }

  Future<void> fetchFromFirebase() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // Try fetching from both collections to be sure
      final productSnap = await _db.collection('products').get();
      final stokProductSnap = await _db.collection('stok_products').get();
      
      final List<Product> listFromProducts = productSnap.docs.map((doc) => Product.fromMap(doc.data())).toList();
      final List<Product> listFromStokProducts = stokProductSnap.docs.map((doc) => Product.fromMap(doc.data())).toList();

      // Merge and remove duplicates by ID
      final Map<String, Product> combinedMap = {};
      for (var p in listFromProducts) combinedMap[p.id] = p;
      for (var p in listFromStokProducts) combinedMap[p.id] = p;
      
      _products = combinedMap.values.toList();

      // Fetch Sales
      final saleSnap = await _db.collection('sales').get();
      _sales = saleSnap.docs.map((doc) => Sale.fromMap(doc.data())).toList();

      // Fetch Payments
      final paymentSnap = await _db.collection('payments').get();
      _payments = paymentSnap.docs.map((doc) => DebtPayment.fromMap(doc.data())).toList();

      await _saveData();
      debugPrint("Data fetched from Firebase successfully (${_products.length} products found)");
    } catch (e) {
      debugPrint("Firebase fetch failed: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> syncExistingToFirestore() async {
    try {
      final batch = _db.batch();
      
      for (var product in _products) {
        batch.set(_db.collection('products').doc(product.id), product.toMap());
      }
      
      for (var sale in _sales) {
        batch.set(_db.collection('sales').doc(sale.id), sale.toMap());
      }
      
      for (var payment in _payments) {
        batch.set(_db.collection('payments').doc(payment.id), payment.toMap());
      }

      if (_excelDataMap.isNotEmpty) {
        batch.set(_db.collection('settings').doc('excel_data'), _excelDataMap);
      }

      await batch.commit();
      debugPrint("Firebase sync completed successfully");
    } catch (e) {
      debugPrint("Firebase sync failed: $e");
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setString('stok_products', json.encode(_products.map((e) => e.toMap()).toList()));
    await prefs.setString('stok_sales', json.encode(_sales.map((e) => e.toMap()).toList()));
    await prefs.setString('stok_payments', json.encode(_payments.map((e) => e.toMap()).toList()));
    await prefs.setString('excel_product_data', json.encode(_excelDataMap));
    await prefs.setInt('stok_low_threshold', _lowStockThreshold);
  }

  Future<void> updateThreshold(int value) async {
    _lowStockThreshold = value;
    await _saveData();
    notifyListeners();
  }

  Future<void> addProduct(Product product) async {
    _products.add(product);
    await _saveData();
    await _db.collection('products').doc(product.id).set(product.toMap());
    notifyListeners();
  }

  Future<void> addProducts(List<Product> products) async {
    _products.addAll(products);
    await _saveData();
    
    final batch = _db.batch();
    for (var product in products) {
      batch.set(_db.collection('products').doc(product.id), product.toMap());
    }
    await batch.commit();
    
    notifyListeners();
  }

  Future<void> updateProduct(Product product) async {
    final index = _products.indexWhere((p) => p.id == product.id);
    if (index != -1) {
      _products[index] = product;
      await _saveData();
      await _db.collection('products').doc(product.id).set(product.toMap());
      notifyListeners();
    }
  }

  Future<void> deleteProduct(String id) async {
    _products.removeWhere((p) => p.id == id);
    await _saveData();
    await _db.collection('products').doc(id).delete();
    notifyListeners();
  }

  Future<void> clearAllData() async {
    _products.clear();
    _sales.clear();
    _payments.clear();
    await _saveData();
    
    // Firebase verilerini de temizlemek gerekebilir (dikkatli kullanıılmalı)
    // await _db.collection('products').get().then((snapshot) {
    //   for (var doc in snapshot.docs) doc.reference.delete();
    // });
    
    notifyListeners();
  }

  bool isDuplicate(Product product) {
    return _products.any((p) {
      // Don't compare with itself when updating
      if (p.id == product.id) return false;

      // Check IMEI 1
      if (product.imei1 != null && product.imei1!.isNotEmpty) {
        if (p.imei1 == product.imei1 || p.imei2 == product.imei1) return true;
      }

      // Check IMEI 2
      if (product.imei2 != null && product.imei2!.isNotEmpty) {
        if (p.imei1 == product.imei2 || p.imei2 == product.imei2) return true;
      }

      // Check Serial Number
      if (product.serialNumber != null && product.serialNumber!.isNotEmpty) {
        if (p.serialNumber == product.serialNumber) return true;
      }

      return false;
    });
  }

  String? getDuplicateInfo(Product product) {
    for (var p in _products) {
      if (p.id == product.id) continue;
      
      if (product.imei1 != null && product.imei1!.isNotEmpty) {
        if (p.imei1 == product.imei1 || p.imei2 == product.imei1) return "IMEI 1 (${product.imei1}) zaten kayıtlı!";
      }
      if (product.imei2 != null && product.imei2!.isNotEmpty) {
        if (p.imei1 == product.imei2 || p.imei2 == product.imei2) return "IMEI 2 (${product.imei2}) zaten kayıtlı!";
      }
      if (product.serialNumber != null && product.serialNumber!.isNotEmpty) {
        if (p.serialNumber == product.serialNumber) return "Seri No (${product.serialNumber}) zaten kayıtlı!";
      }
    }
    return null;
  }

  Future<String?> importHakedisExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result != null) {
        final file = File(result.files.single.path!);
        var bytes = file.readAsBytesSync();
        var decoder = SpreadsheetDecoder.decodeBytes(bytes, update: false);
        
        String? sheetName;
        for (var name in decoder.tables.keys) {
          if (name.contains('Fiyat Listesi') || name.contains('Hakediş') || name.contains('Sheet1')) {
            sheetName = name;
            break;
          }
        }
        
        sheetName ??= decoder.tables.keys.first;
        var table = decoder.tables[sheetName]!;

        // Column indices (initialized to -1 to detect first match)
        int markaCol = -1;
        int modelCol = -1;
        int purchaseCol = -1;
        int primCol = -1;
        int startRow = 3;

        // Try to identify columns from the first 15 rows
        for (int i = 0; i < 15 && i < table.maxRows; i++) {
          final row = table.rows[i];
          int matches = 0;
          for (int j = 0; j < row.length; j++) {
            final val = row[j]?.toString().toLowerCase().trim() ?? '';
            
            if (val == 'marka' && markaCol == -1) { markaCol = j; matches++; }
            if (val == 'model' && modelCol == -1) { modelCol = j; matches++; }
            
            if ((val.contains('bayi alış') || val.contains('bayi aliş') || val == 'fiyat' || val == 'maliyet') && purchaseCol == -1) { 
              if (!val.contains('kontrat') && !val.contains('peşin')) {
                purchaseCol = j; 
                matches++;
              }
            }
            if ((val.contains('prim') || val.contains('hakediş') || val.contains('hakedis')) && primCol == -1) { 
              primCol = j; 
              matches++;
            }
          }
          // We need at least 3 matching headers to consider this a header row
          if (matches >= 3) {
            startRow = i + 1;
            break;
          }
        }

        // Fallback to defaults if not found
        if (markaCol == -1) markaCol = 2;
        if (modelCol == -1) modelCol = 3;
        if (purchaseCol == -1) purchaseCol = 4;
        if (primCol == -1) primCol = 6;

        int importedCount = 0;
        int priceFoundCount = 0;
        
        // Helper to parse Turkish currency format (1.234,56)
        double parseCurrency(String val) {
          if (val.isEmpty) return 0.0;
          // Remove anything that is not a digit, comma or dot
          String filtered = val.replaceAll(RegExp(r'[^0-9,.]'), '');
          if (filtered.isEmpty) return 0.0;
          
          if (filtered.contains('.') && filtered.contains(',')) {
            // Thousands separator (.) and decimal separator (,) used: 1.234,56
            return double.tryParse(filtered.replaceAll('.', '').replaceAll(',', '.')) ?? 0.0;
          } else if (filtered.contains(',')) {
            // Only decimal separator (,) used: 1234,56
            return double.tryParse(filtered.replaceAll(',', '.')) ?? 0.0;
          } else {
            // Standard format or only dot used: 1234.56
            return double.tryParse(filtered) ?? 0.0;
          }
        }

        for (int i = startRow; i < table.maxRows; i++) {
          var row = table.rows[i];
          if (row.length <= markaCol || row.length <= modelCol) continue;

          var markaCell = row[markaCol]?.toString().trim() ?? '';
          var modelCell = row[modelCol]?.toString().trim() ?? '';
          
          if (markaCell.isEmpty || modelCell.isEmpty) continue;

          var purchaseCell = row.length > purchaseCol ? row[purchaseCol]?.toString().trim() ?? '' : '';
          var primCell = row.length > primCol ? row[primCol]?.toString().trim() ?? '' : '';

          double prim = parseCurrency(primCell);
          double purchase = parseCurrency(purchaseCell);
          
          // If both are 0, it's likely a divider row or empty row
          if (prim == 0 && purchase == 0) continue;

          if (purchase > 0) priceFoundCount++;

          final key = "${markaCell.toUpperCase()} ${modelCell.toUpperCase()}";
          _excelDataMap[key] = {
            'hakedis': prim,
            'purchasePrice': purchase,
          };
          importedCount++;
        }
        
        await _saveData();
        notifyListeners();
        return "$importedCount ürün yüklendi ($priceFoundCount tanesinde alış fiyatı bulundu).";
      }
    } catch (e) {
      return "Hata: ${e.toString()}";
    }
    return null;
  }

  Map<String, double>? getExcelProductData(String brand, String model) {
    final key = "${brand.toUpperCase().trim()} ${model.toUpperCase().trim()}";
    if (_excelDataMap.containsKey(key)) {
      return _excelDataMap[key];
    }
    
    // Fuzzy match if no exact match
    for (var entry in _excelDataMap.entries) {
      String entryKey = entry.key.toUpperCase().trim();
      if (key.contains(entryKey) || entryKey.contains(key)) {
        return entry.value;
      }
    }
    return null;
  }

  double getHakedisAmount(String brand, String model) {
    final data = getExcelProductData(brand, model);
    return data?['hakedis'] ?? 0.0;
  }

  Future<void> sellProduct(String productId, int quantity, PaymentType paymentType) async {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index != -1 && _products[index].quantity >= quantity) {
      final product = _products[index];
      product.quantity -= quantity;

      // Check for low stock notification
      if (product.quantity <= _lowStockThreshold) {
        NotificationService.showLowStockAlert("${product.brand} ${product.model}", product.quantity);
      }

      double hakedisAmount = 0.0;
      if (paymentType == PaymentType.nakit) {
        hakedisAmount = product.salePrice - product.purchasePrice;
      } else {
        hakedisAmount = getHakedisAmount(product.brand, product.model);
      }

      final sale = Sale(
        id: const Uuid().v4(),
        productId: productId,
        brand: product.brand,
        model: product.model,
        quantity: quantity,
        salePrice: product.salePrice,
        purchasePrice: product.purchasePrice,
        hakedisAmount: hakedisAmount,
        soldAt: DateTime.now(),
        paymentType: paymentType,
        hakedisStatus: paymentType == PaymentType.temlikli ? HakedisStatus.bekliyor : HakedisStatus.odemeAlindi,
      );
      _sales.add(sale);

      await _saveData();
      
      // Sync to Firebase
      final batch = _db.batch();
      batch.set(_db.collection('sales').doc(sale.id), sale.toMap());
      batch.set(_db.collection('products').doc(productId), product.toMap());
      await batch.commit();
      
      notifyListeners();
    }
  }

  int getTotalQuantity(String brand, String model) {
    return _products
        .where((p) => p.brand.toUpperCase().trim() == brand.toUpperCase().trim() && 
                      p.model.toUpperCase().trim() == model.toUpperCase().trim())
        .fold(0, (sum, p) => sum + p.quantity);
  }

  List<Product> get lowStockProducts {
    final Map<String, int> groupedQuantities = {};
    final Map<String, Product> firstOccurrences = {};

    for (var p in _products) {
      final key = "${p.brand.toUpperCase().trim()} ${p.model.toUpperCase().trim()}";
      groupedQuantities[key] = (groupedQuantities[key] ?? 0) + p.quantity;
      firstOccurrences.putIfAbsent(key, () => p);
    }

    return firstOccurrences.entries
        .where((entry) => groupedQuantities[entry.key]! <= _lowStockThreshold)
        .map((entry) => entry.value)
        .toList();
  }

  Future<void> updateHakedisStatus(String saleId, HakedisStatus status) async {
    final index = _sales.indexWhere((s) => s.id == saleId);
    if (index != -1) {
      _sales[index].hakedisStatus = status;
      await _saveData();
      await _db.collection('sales').doc(saleId).update({'hakedisStatus': status.index});
      notifyListeners();
    }
  }

  int get totalStock => _products.fold(0, (sum, p) => sum + p.quantity);
  
  // Cari Hesaplar
  double get totalPortVadeliBalance {
    double stockValue = _products
      .where((p) => p.purchaseType == PurchaseType.vadeli)
      .fold(0.0, (sum, p) => sum + (p.purchasePrice * p.quantity));
      
    double totalPayments = _payments.fold(0.0, (sum, p) => sum + p.amount);
    
    return stockValue - totalPayments;
  }
  
  Future<void> addDebtPayment(double amount, String? description) async {
    final payment = DebtPayment(
      id: const Uuid().v4(),
      amount: amount,
      date: DateTime.now(),
      description: description,
    );
    _payments.add(payment);
    await _saveData();
    await _db.collection('payments').doc(payment.id).set(payment.toMap());
    notifyListeners();
  }
      
  double get totalNakitBalance => _products
      .where((p) => p.purchaseType == PurchaseType.nakit)
      .fold(0.0, (sum, p) => sum + (p.purchasePrice * p.quantity));

  // Stats for Dashboard
  double get totalCashProfit => _sales.where((s) => s.paymentType == PaymentType.nakit).fold(0.0, (sum, s) => sum + s.profit);
  double get totalTemlikliProfit => _sales.where((s) => s.paymentType == PaymentType.temlikli).fold(0.0, (sum, s) => sum + s.profit);
  double get totalTurnover => _sales.fold(0.0, (sum, s) => sum + s.turnover);

  // Advanced Reporting Methods
  List<Sale> getFilteredSales({DateTime? start, DateTime? end}) {
    return _sales.where((s) {
      if (start != null && s.soldAt.isBefore(start)) return false;
      if (end != null && s.soldAt.isAfter(end)) return false;
      return true;
    }).toList();
  }

  Map<String, double> getMonthlySalesData(int year) {
    final data = <String, double>{};
    for (int month = 1; month <= 12; month++) {
      final monthSales = _sales.where((s) => s.soldAt.year == year && s.soldAt.month == month);
      final profit = monthSales.fold(0.0, (sum, s) => sum + s.profit);
      data[DateFormat('MMM').format(DateTime(year, month))] = profit;
    }
    return data;
  }

  double getPeriodProfit(DateTime start, DateTime end) {
    return getFilteredSales(start: start, end: end).fold(0.0, (sum, s) => sum + s.profit);
  }

  double getPeriodTurnover(DateTime start, DateTime end) {
    return getFilteredSales(start: start, end: end).fold(0.0, (sum, s) => sum + s.turnover);
  }

  Map<ProductCategory, int> getCategoryCounts() {
    final counts = <ProductCategory, int>{};
    for (var cat in ProductCategory.values) {
      counts[cat] = _products.where((p) => p.category == cat).fold(0, (sum, p) => sum + p.quantity);
    }
    return counts;
  }

  List<Product> searchProducts(String query) {
    if (query.isEmpty) return _products;
    final lowercaseQuery = query.toLowerCase();
    return _products.where((p) {
      return p.brand.toLowerCase().contains(lowercaseQuery) ||
             p.model.toLowerCase().contains(lowercaseQuery) ||
             (p.color ?? '').toLowerCase().contains(lowercaseQuery) ||
             (p.imei1 ?? '').toLowerCase().contains(lowercaseQuery);
    }).toList();
  }
}
