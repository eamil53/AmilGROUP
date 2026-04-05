import 'dart:convert';

enum TargetType {
  mobilFaturali,
  mobilFaturasiz,
  sabitInternet,
  tivibuIptv,
  tivibuUydu,
  cihazAkilli,
  cihazDiger,
}

class Personnel {
  final String id;
  final String name;
  final String code;

  Personnel({required this.id, required this.name, required this.code});

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'code': code};
  factory Personnel.fromMap(Map<String, dynamic> map) => Personnel(id: map['id'], name: map['name'], code: map['code']);
}

class MonthlyTarget {
  final String personnelId;
  final DateTime month;
  final Map<TargetType, int> targets;

  MonthlyTarget({
    required this.personnelId,
    required this.month,
    required this.targets,
  });

  Map<String, dynamic> toMap() => {
    'personnelId': personnelId,
    'month': month.toIso8601String(),
    'targets': targets.map((key, value) => MapEntry(key.index.toString(), value)),
  };

  factory MonthlyTarget.fromMap(Map<String, dynamic> map) => MonthlyTarget(
    personnelId: map['personnelId'],
    month: DateTime.parse(map['month']),
    targets: (map['targets'] as Map<String, dynamic>).map((key, value) => 
      MapEntry(TargetType.values[int.parse(key)], value as int)),
  );
}

class DailyAchievement {
  final String id;
  final String personnelId;
  final DateTime date;
  final Map<TargetType, int> counts;

  DailyAchievement({
    required this.id,
    required this.personnelId,
    required this.date,
    required this.counts,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'personnelId': personnelId,
    'date': date.toIso8601String(),
    'counts': counts.map((key, value) => MapEntry(key.index.toString(), value)),
  };

  factory DailyAchievement.fromMap(Map<String, dynamic> map) => DailyAchievement(
    id: map['id'],
    personnelId: map['personnelId'],
    date: DateTime.parse(map['date']),
    counts: (map['counts'] as Map<String, dynamic>).map((key, value) => 
      MapEntry(TargetType.values[int.parse(key)], value as int)),
  );
}
