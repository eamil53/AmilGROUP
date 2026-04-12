import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../models/customer_id.dart';

enum IDFilterType { all, age7to25, age18to25 }

class IDProvider extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  
  List<CustomerID> _customerIDs = [];
  bool _isLoading = true;
  IDFilterType _currentFilter = IDFilterType.all;
  StreamSubscription? _subscription;

  List<CustomerID> get customerIDs => _customerIDs;
  bool get isLoading => _isLoading;
  IDFilterType get currentFilter => _currentFilter;

  void setFilter(IDFilterType filter) {
    _currentFilter = filter;
    notifyListeners();
  }

  IDProvider() {
    _initFirestore();
  }

  void _initFirestore() {
    _isLoading = true;
    notifyListeners();

    _subscription = _db
        .collection('customer_ids')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      _customerIDs = snapshot.docs.map((doc) {
        final data = doc.data();
        return CustomerID.fromMap(data);
      }).toList();
      _isLoading = false;
      notifyListeners();
    }, onError: (e) {
      debugPrint("Firestore Stream Error: $e");
      _isLoading = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<String> _uploadImage(String localPath, String fileName) async {
    try {
      File file = File(localPath);
      if (!file.existsSync()) {
        debugPrint("Storage Upload Error: Yerel dosya bulunamadı: $localPath");
        return localPath; 
      }

      // Referans oluştur
      final Reference ref = _storage.ref().child('id_images').child(fileName);
      
      debugPrint("Storage: Upload başlatılıyor -> $fileName");
      
      // Yükleme işlemini başlat
      final UploadTask uploadTask = ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      
      // Yüklemenin tamamlanmasını bekle
      final TaskSnapshot snapshot = await uploadTask;
      debugPrint("Storage: Yükleme başarılı, URL alınıyor...");
      
      // Download URL'yi al (Bazen Firebase gecikmeli cevap verebilir, 3 kez deneyelim)
      String? downloadUrl;
      int retries = 0;
      while (retries < 3) {
        try {
          downloadUrl = await snapshot.ref.getDownloadURL();
          break;
        } catch (e) {
          retries++;
          if (retries >= 3) {
            debugPrint("Storage: URL alma denemesi $retries başarısız: $e");
            rethrow;
          }
          debugPrint("Storage: URL henüz hazır değil, bekleniyor ($retries/3)...");
          await Future.delayed(const Duration(seconds: 1));
        }
      }
      
      if (downloadUrl == null) throw Exception("Download URL alınamadı.");
      
      debugPrint("Storage: Başarılı -> $downloadUrl");
      return downloadUrl;
    } catch (e) {
      debugPrint("Storage HATA ($fileName): $e");
      // Eğer hata "object-not-found" ise Firebase Console'dan Storage'ın aktif olduğundan emin olunmalıdır.
      if (e.toString().contains('object-not-found')) {
        throw Exception("Firebase Storage hatası: Nesne bulunamadı. Lütfen Firebase Console'da Storage servisinin açık olduğundan ve kuralların izin verdiğinden emin olun.");
      }
      rethrow;
    }
  }

  Future<void> addCustomerID(CustomerID id) async {
    try {
      // 1. Upload images first
      String frontUrl = id.frontImagePath;
      String backUrl = id.backImagePath;

      if (!frontUrl.startsWith('http')) {
        frontUrl = await _uploadImage(id.frontImagePath, '${id.id}_front.jpg');
      }
      if (!backUrl.startsWith('http')) {
        backUrl = await _uploadImage(id.backImagePath, '${id.id}_back.jpg');
      }

      // 2. Create updated object with URLs
      final updatedID = CustomerID(
        id: id.id,
        name: id.name,
        surname: id.surname,
        birthDate: id.birthDate,
        frontImagePath: frontUrl,
        backImagePath: backUrl,
        createdAt: id.createdAt,
      );

      // 3. Save to Firestore
      await _db.collection('customer_ids').doc(id.id).set(updatedID.toMap());
    } catch (e) {
      debugPrint("Error adding customer ID to Firebase: $e");
      rethrow;
    }
  }

  int _calculateAge(DateTime birthDate) {
    DateTime now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month || (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Future<void> deleteCustomerID(String id) async {
    try {
      // Find the item first to get image paths for deletion
      final doc = await _db.collection('customer_ids').doc(id).get();
      if (!doc.exists) return;
      
      final data = doc.data()!;
      final frontUrl = data['frontImagePath'] as String?;
      final backUrl = data['backImagePath'] as String?;

      // Delete from Storage
      if (frontUrl != null && frontUrl.startsWith('http')) {
        try {
          await _storage.refFromURL(frontUrl).delete();
        } catch (e) {
          debugPrint("Error deleting front image: $e");
        }
      }
      if (backUrl != null && backUrl.startsWith('http')) {
        try {
          await _storage.refFromURL(backUrl).delete();
        } catch (e) {
          debugPrint("Error deleting back image: $e");
        }
      }

      // Delete from Firestore
      await _db.collection('customer_ids').doc(id).delete();
    } catch (e) {
      debugPrint("Error deleting customer ID from Firebase: $e");
    }
  }

  List<CustomerID> searchIDs(String query) {
    List<CustomerID> filteredList = _customerIDs;

    // Apply age filter
    if (_currentFilter != IDFilterType.all) {
      filteredList = filteredList.where((id) {
        if (id.birthDate == null) return false;
        final age = _calculateAge(id.birthDate!);
        if (_currentFilter == IDFilterType.age7to25) {
          return age >= 7 && age <= 25;
        } else if (_currentFilter == IDFilterType.age18to25) {
          return age >= 18 && age <= 25;
        }
        return true;
      }).toList();
    }

    if (query.isEmpty) return filteredList;
    
    final lowercaseQuery = query.toLowerCase();
    return filteredList.where((e) {
      return e.name.toLowerCase().contains(lowercaseQuery) ||
             e.surname.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }
}
