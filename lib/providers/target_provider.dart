import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../models/target.dart';

class TargetProvider extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;
  
  List<Personnel> _personnel = [];
  List<MonthlyTarget> _monthlyTargets = [];
  List<DailyAchievement> _dailyAchievements = [];
  bool _isLoading = true;

  StreamSubscription? _personnelSub;
  StreamSubscription? _targetsSub;
  StreamSubscription? _achievementsSub;

  List<Personnel> get personnel => _personnel;
  List<MonthlyTarget> get monthlyTargets => _monthlyTargets;
  List<DailyAchievement> get dailyAchievements => _dailyAchievements;
  bool get isLoading => _isLoading;

  TargetProvider() {
    _startListeners();
  }

  @override
  void dispose() {
    _personnelSub?.cancel();
    _targetsSub?.cancel();
    _achievementsSub?.cancel();
    super.dispose();
  }

  void _startListeners() {
    _isLoading = true;
    notifyListeners();

    _personnelSub = _db.collection('personnel').snapshots().listen((snap) {
      _personnel = snap.docs.map((doc) => Personnel.fromMap(doc.data())).toList();
      _isLoading = false;
      notifyListeners();
    });

    _targetsSub = _db.collection('monthly_targets').snapshots().listen((snap) {
      _monthlyTargets = snap.docs.map((doc) => MonthlyTarget.fromMap(doc.data())).toList();
      notifyListeners();
    });

    _achievementsSub = _db.collection('daily_achievements').snapshots().listen((snap) {
      _dailyAchievements = snap.docs.map((doc) => DailyAchievement.fromMap(doc.data())).toList();
      notifyListeners();
    });
  }

  // --- Actions ---

  Future<void> addDailyAchievement(DailyAchievement da) async {
    // da.id artık TargetEntryScreen tarafından pId_YYYYMM formatında üretiliyor.
    // Bu sayede aynı ay için girilen her veri bir öncekinin üzerine yazar (Topla-Gel değil, Üstüne Yaz senaryosu).
    await _db.collection('daily_achievements').doc(da.id).set(da.toMap());
  }

  Future<void> setMonthlyTarget(MonthlyTarget mt) async {
    // Predictable ID: personnelId_YYYYMM
    final docId = '${mt.personnelId}_${mt.month.year}${mt.month.month.toString().padLeft(2, '0')}';
    await _db.collection('monthly_targets').doc(docId).set(mt.toMap());
  }

  Future<void> notifyTeam(String title, String body) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      await _db.collection('notifications').add({
        'title': title,
        'body': body,
        'senderId': token, // Gönderen cihazın ID'si
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  Future<void> addPersonnel(Personnel p) async {
    await _db.collection('personnel').doc(p.id).set(p.toMap());
  }

  Future<void> deletePersonnel(String id) async {
    await _db.collection('personnel').doc(id).delete();
  }

  // Migration/Initialization tool
  Future<void> syncLocalToFirebase() async {
    // One-time sync or sample data if empty
    if (_personnel.isEmpty) {
      final List<Personnel> initial = [
        Personnel(id: '1', name: 'ASİYE ECEM TAVUKÇU', code: 'B227135'),
        Personnel(id: '2', name: 'ENVER AMİL', code: 'B116233'),
        Personnel(id: '3', name: 'MURAT İŞLER', code: 'B075216'),
        Personnel(id: '4', name: 'NEDRA KURT', code: 'B216957'),
      ];
      for (var p in initial) {
        await addPersonnel(p);
      }
    }
  }

  // --- Calculations ---

  int getTarget(String pId, DateTime month, TargetType type) {
    final mt = _monthlyTargets.firstWhere((e) => 
      e.personnelId == pId && e.month.year == month.year && e.month.month == month.month,
      orElse: () => MonthlyTarget(personnelId: pId, month: month, targets: {})
    );
    return mt.targets[type] ?? 0;
  }

  int getAchievement(String pId, DateTime month, TargetType type) {
    // Tüm kayıtları filtrele
    final achievements = _dailyAchievements
      .where((e) => e.personnelId == pId && e.date.year == month.year && e.date.month == month.month)
      .toList();
      
    if (achievements.isEmpty) return 0;
    
    // Eğer kümülatif/toplam ID formatına sahip bir kayıt varsa onu bul
    final monthlyDocId = '${pId}_${month.year}${month.month.toString().padLeft(2, '0')}';
    final monthlyEntry = achievements.where((e) => e.id == monthlyDocId).toList();
    
    if (monthlyEntry.isNotEmpty) {
      return monthlyEntry.first.counts[type] ?? 0;
    }
    
    // Eğer o aya ait toplam kaydı yoksa (eski veriler), en son girilen tek bir kaydı baz al
    return achievements.last.counts[type] ?? 0;
  }

  int getAchievementInRange(String pId, DateTime start, DateTime end, TargetType type) {
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day, 23, 59, 59);
    
    return _dailyAchievements
      .where((da) => da.personnelId == pId && da.date.isAfter(s.subtract(const Duration(seconds: 1))) && da.date.isBefore(e.add(const Duration(seconds: 1))))
      .fold(0, (sum, ach) => sum + (ach.counts[type] ?? 0));
  }

  int getTotalAchievementInRange(String pId, DateTime start, DateTime end) {
    int total = 0;
    for (var type in TargetType.values) {
      total += getAchievementInRange(pId, start, end, type);
    }
    return total;
  }

  // --- Dealer Wide (Total) ---
  int getDealerTarget(DateTime month, TargetType type) {
    return _personnel.fold(0, (sum, p) => sum + getTarget(p.id, month, type));
  }

  int getDealerAchievement(DateTime month, TargetType type) {
    return _personnel.fold(0, (sum, p) => sum + getAchievement(p.id, month, type));
  }

  int getDealerAchievementInRange(DateTime start, DateTime end, TargetType type) {
    return _personnel.fold(0, (sum, p) => sum + getAchievementInRange(p.id, start, end, type));
  }

  double getForecast(String pId, DateTime month, TargetType type) {
    final achieved = getAchievement(pId, month, type);
    final now = DateTime.now();
    
    if (month.year == now.year && month.month == now.month) {
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      final currentDay = now.day;
      if (currentDay == 0) return 0;
      return (achieved / currentDay) * daysInMonth;
    }
    return achieved.toDouble();
  }

  double getForecastPercentage(String pId, DateTime month, TargetType type) {
    final forecast = getForecast(pId, month, type);
    final target = getTarget(pId, month, type);
    if (target == 0) return 0;
    return (forecast / target) * 100;
  }

  double getAchievementPercentage(String pId, DateTime month, TargetType type) {
    final target = getTarget(pId, month, type);
    if (target == 0) return 0;
    return (getAchievement(pId, month, type) / target) * 100;
  }

  double getDealerTotalAchievementPercentage(DateTime month) {
    int totalTarget = 0;
    int totalAchieved = 0;
    for (var type in TargetType.values) {
      totalTarget += getDealerTarget(month, type);
      totalAchieved += getDealerAchievement(month, type);
    }
    if (totalTarget == 0) return 0;
    return (totalAchieved / totalTarget) * 100;
  }
}
