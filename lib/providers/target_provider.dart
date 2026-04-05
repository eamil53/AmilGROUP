import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    // We use a predictable ID to avoid duplicates (personnelId_YYYYMMDD)
    final docId = '${da.personnelId}_${da.date.year}${da.date.month.toString().padLeft(2, '0')}${da.date.day.toString().padLeft(2, '0')}';
    await _db.collection('daily_achievements').doc(docId).set(da.toMap());
  }

  Future<void> setMonthlyTarget(MonthlyTarget mt) async {
    // Predictable ID: personnelId_YYYYMM
    final docId = '${mt.personnelId}_${mt.month.year}${mt.month.month.toString().padLeft(2, '0')}';
    await _db.collection('monthly_targets').doc(docId).set(mt.toMap());
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
    return _dailyAchievements
      .where((e) => e.personnelId == pId && e.date.year == month.year && e.date.month == month.month)
      .fold(0, (sum, e) => sum + (e.counts[type] ?? 0));
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
}
