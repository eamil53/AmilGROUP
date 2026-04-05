import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_user.dart';

class AuthProvider extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;
  AppUser? _currentUser;
  bool _isLoading = true;
  StreamSubscription? _userSubscription;
  StreamSubscription? _rolesSubscription;

  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;

  AuthProvider() {
    _checkSavedSession();
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    _rolesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedCode = prefs.getString('auth_user_code');
    
    if (savedCode != null) {
      _startUserStream(savedCode);
    } else {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _startUserStream(String code) {
    _userSubscription?.cancel();
    _userSubscription = _db.collection('users')
        .where('code', isEqualTo: code)
        .snapshots()
        .listen((snap) {
          if (snap.docs.isNotEmpty) {
            _currentUser = AppUser.fromMap(snap.docs.first.data());
            _startRolesStream(); // Start listening to roles for this user
          } else {
            _currentUser = null;
            _rolesSubscription?.cancel();
          }
          _isLoading = false;
          notifyListeners();
        });
  }

  // Listen to 'roles' collection to catch internal changes in allowedModules
  void _startRolesStream() {
    if (_currentUser == null) return;
    
    if (_currentUser!.roles.isEmpty) {
      _currentUser!.rolesObjects = [];
      _rolesSubscription?.cancel();
      notifyListeners();
      return;
    }
    
    _rolesSubscription?.cancel();
    _rolesSubscription = _db.collection('roles')
        .where(FieldPath.documentId, whereIn: _currentUser!.roles)
        .snapshots()
        .listen((snap) {
          if (_currentUser != null) {
            _currentUser!.rolesObjects = snap.docs.map((doc) => AppRole.fromMap(doc.data())).toList();
            notifyListeners(); // Refresh UI when role definitions change
          }
        });
  }

  Future<bool> login(String bCode, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final snap = await _db.collection('users')
          .where('code', isEqualTo: bCode.toUpperCase().trim())
          .where('password', isEqualTo: password)
          .get();

      if (snap.docs.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_user_code', bCode.toUpperCase().trim());
        _startUserStream(bCode.toUpperCase().trim());
        return true;
      }
    } catch (e) {
      debugPrint("Login failed: $e");
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    _userSubscription?.cancel();
    _rolesSubscription?.cancel();
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_user_code');
    notifyListeners();
  }

  Future<void> initializeUsers() async {
    final snapRole = await _db.collection('roles').get();
    if (snapRole.docs.isEmpty) {
      final List<AppRole> initialRoles = [
        // Module Specific Roles
        AppRole(id: 'role_internet_entry', name: 'İnternet Satış Giriş', allowedModules: ['internet_sale_entry']),
        AppRole(id: 'role_p_manage', name: 'Personel Yönetimi', allowedModules: ['personnel_management']),
        AppRole(id: 'role_internet_list', name: 'İnternet Satış Listesi', allowedModules: ['internet_sale_list']),
        AppRole(id: 'role_internet_report', name: 'İnternet Satış Raporu', allowedModules: ['internet_sale_report']),
        AppRole(id: 'role_all_stock', name: 'Tüm Ürün Stoğu Görüntüleme', allowedModules: ['all_stock']),
        AppRole(id: 'role_critical_stock', name: 'Kritik Stok Takibi', allowedModules: ['critical_stock']),
        AppRole(id: 'role_hakedis_excel', name: 'Excel Hakediş Yükleme', allowedModules: ['hakedis_excel']),
        AppRole(id: 'role_hakedis_takip', name: 'Hakediş Takibi', allowedModules: ['hakedis_takip']),
        AppRole(id: 'role_sales_report', name: 'Satış Analiz Raporu', allowedModules: ['sales_report']),
        AppRole(id: 'role_target_report', name: 'Hedef Takibi', allowedModules: ['target_report']),
        AppRole(id: 'role_id_archive', name: 'Kimlik Arşivi', allowedModules: ['id_archive']),
        AppRole(id: 'role_add_product', name: 'Kamera ile Stok Kaydı', allowedModules: ['add_product_camera']),
        AppRole(id: 'role_profits_view', name: 'Karlılık İzleme', allowedModules: ['profits_view']),
        
        // Category Specific Roles
        AppRole(id: 'role_cat_phone', name: 'Telefon Kategorisi', allowedModules: [], allowedCategories: ['phone']),
        AppRole(id: 'role_cat_headset', name: 'Kulaklık Kategorisi', allowedModules: [], allowedCategories: ['headset']),
        AppRole(id: 'role_cat_watch', name: 'Saat Kategorisi', allowedModules: [], allowedCategories: ['watch']),
        AppRole(id: 'role_cat_modem', name: 'Modem Kategorisi', allowedModules: [], allowedCategories: ['modem']),
      ];

      final batch = _db.batch();
      for (var role in initialRoles) {
        batch.set(_db.collection('roles').doc(role.id), role.toMap());
      }
      await batch.commit();
    }

    final snapUser = await _db.collection('users').get();
    if (snapUser.docs.isEmpty) {
      final List<AppUser> initialUsers = [
        AppUser(id: '1', name: 'ENVER AMİL', code: 'B116233', roles: [], isAdmin: true, password: '123'),
        AppUser(id: '2', name: 'MURAT İŞLER', code: 'B075216', roles: ['role_internet_report', 'role_sales_report', 'role_profits_view', 'role_cat_phone', 'role_critical_stock'], password: '123'),
        AppUser(id: '3', name: 'NEDRA KURT', code: 'B216957', roles: ['role_internet_entry', 'role_internet_list', 'role_target_report', 'role_id_archive', 'role_cat_phone'], password: '123'),
        AppUser(id: '4', name: 'ASİYE ECEM TAVUKÇU', code: 'B227135', roles: ['role_internet_entry', 'role_add_product', 'role_cat_phone', 'role_cat_modem', 'role_cat_headset'], password: '123'),
      ];

      final batch = _db.batch();
      for (var user in initialUsers) {
        batch.set(_db.collection('users').doc(user.id), user.toMap());
      }
      await batch.commit();
    }
  }
}
