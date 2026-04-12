import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/internet_sale.dart';

class InternetSaleProvider extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;
  List<InternetSale> _sales = [];
  bool _isLoading = true;
  StreamSubscription? _subscription;
  
  // Varsayılan olarak şu anki ayı seç
  String _selectedMonth = "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}";

  List<InternetSale> get sales => _sales;
  bool get isLoading => _isLoading;
  String get selectedMonth => _selectedMonth;

  InternetSaleProvider() {
    _initFirestoreStream();
  }

  void _initFirestoreStream() {
    _subscription?.cancel();
    _isLoading = true;
    notifyListeners();

    // Seçili aya göre dinleme işlemi
    _subscription = _db
        .collection('internet_sales')
        .doc(_selectedMonth)
        .collection('records')
        .orderBy('date', descending: true)
        .snapshots()
        .listen((snapshot) {
      _sales = snapshot.docs.map((doc) => InternetSale.fromMap(doc.data())).toList();
      _isLoading = false;
      notifyListeners();
    }, onError: (e) {
      debugPrint("InternetSale Stream Error: $e");
      _isLoading = false;
      notifyListeners();
    });
  }

  void setMonth(String monthId) {
    if (_selectedMonth != monthId) {
      _selectedMonth = monthId;
      _initFirestoreStream();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> addSale(InternetSale sale) async {
    try {
      // Ay bazında dokümantasyon yoluna kaydet
      await _db
          .collection('internet_sales')
          .doc(sale.monthId)
          .collection('records')
          .doc(sale.id)
          .set(sale.toMap());
    } catch (e) {
      debugPrint("Firebase add failed: $e");
      rethrow;
    }
  }

  Future<void> updateSale(InternetSale sale) async {
    try {
      await _db
          .collection('internet_sales')
          .doc(sale.monthId)
          .collection('records')
          .doc(sale.id)
          .set(sale.toMap());
    } catch (e) {
      debugPrint("Firebase update failed: $e");
      rethrow;
    }
  }

  Future<void> deleteSale(String id) async {
    try {
      await _db
          .collection('internet_sales')
          .doc(_selectedMonth)
          .collection('records')
          .doc(id)
          .delete();
    } catch (e) {
      debugPrint("Firebase delete failed: $e");
      rethrow;
    }
  }

  // Reporting helpers
  int countByStatus(InternetSaleStatus status) => _sales.where((s) => s.status == status).length;
  
  Map<String, int> salesBySellsman() {
    final map = <String, int>{};
    for (var sale in _sales) {
      map[sale.sellerName] = (map[sale.sellerName] ?? 0) + 1;
    }
    return map;
  }
}
