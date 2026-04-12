import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/target.dart';
import '../providers/target_provider.dart';
import '../theme/app_theme.dart';
import '../services/ai_service.dart';

enum DateRangeType { daily, weekly, monthly, yearly, custom }

class PersonnelAnalysisScreen extends StatefulWidget {
  final Personnel? initialPersonnel;
  const PersonnelAnalysisScreen({super.key, this.initialPersonnel});

  @override
  State<PersonnelAnalysisScreen> createState() => _PersonnelAnalysisScreenState();
}

class _PersonnelAnalysisScreenState extends State<PersonnelAnalysisScreen> {
  Personnel? _selectedPersonnel; 
  bool _isDealerMode = false;
  DateTime _selectedDate = DateTime.now(); // Used for month navigation


  DateRangeType _rangeType = DateRangeType.monthly;
  DateTimeRange _customRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    _selectedPersonnel = widget.initialPersonnel;
    if (_selectedPersonnel == null) _isDealerMode = true;
  }

  DateTime get _start {
    switch (_rangeType) {
      case DateRangeType.daily: return DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      case DateRangeType.weekly: return _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
      case DateRangeType.monthly: return DateTime(_selectedDate.year, _selectedDate.month, 1);
      case DateRangeType.yearly: return DateTime(_selectedDate.year, 1, 1);
      case DateRangeType.custom: return _customRange.start;
    }
  }

  DateTime get _end {
    switch (_rangeType) {
      case DateRangeType.daily: return _selectedDate.add(const Duration(hours: 23, minutes: 59));
      case DateRangeType.weekly: return _selectedDate.add(Duration(days: 7 - _selectedDate.weekday, hours: 23, minutes: 59));
      case DateRangeType.monthly: return DateTime(_selectedDate.year, _selectedDate.month + 1, 0, 23, 59);
      case DateRangeType.yearly: return DateTime(_selectedDate.year, 12, 31, 23, 59);
      case DateRangeType.custom: return _customRange.end;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TargetProvider>();
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        title: GestureDetector(
          onTap: _selectDate,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_isDealerMode ? 'Bayi Performansı' : 'Personel Analizi', style: const TextStyle(fontSize: 16)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(DateFormat('MMMM yyyy', 'tr_TR').format(_selectedDate), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
                  const Icon(Icons.arrow_drop_down, size: 14),
                ],
              ),
            ],
          ),
        ),
        elevation: 0,
        backgroundColor: _isDealerMode ? AppTheme.ttMagenta : AppTheme.ttBlue,
      ),
      body: provider.isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPersonnelSelector(provider),
                const SizedBox(height: 20),
                _buildRangeSelector(),
                const SizedBox(height: 24),
                _buildSummarySection(provider),
                const SizedBox(height: 24),
                _buildAnalysisSection(provider),
                const SizedBox(height: 24),
                _buildDetailedCategorySection(provider),
                const SizedBox(height: 24),
                _buildCategoryChart(provider),
                const SizedBox(height: 24),
                _buildTrendChart(provider),
                const SizedBox(height: 40),
              ],
            ),
          ),
    );
  }




  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Widget _buildPersonnelSelector(TargetProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _isDealerMode ? 'dealer' : _selectedPersonnel?.id,
          isExpanded: true,
          items: [
            const DropdownMenuItem(
              value: 'dealer',
              child: Text('TÜM BAYİ (TOPLAM)', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.ttMagenta)),
            ),
            ...provider.personnel.map((p) => DropdownMenuItem(
              value: p.id,
              child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            )),
          ],
          onChanged: (val) {
            setState(() {
              if (val == 'dealer') {
                _isDealerMode = true;
                _selectedPersonnel = null;
              } else {
                _isDealerMode = false;
                _selectedPersonnel = provider.personnel.firstWhere((p) => p.id == val);
              }
            });
          },
        ),
      ),
    );
  }

  Widget _buildRangeSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _rangeButton('Günlük', DateRangeType.daily),
          _rangeButton('Haftalık', DateRangeType.weekly),
          _rangeButton('Aylık', DateRangeType.monthly),
          _rangeButton('Yıllık', DateRangeType.yearly),
          _rangeButton('Özel', DateRangeType.custom),
        ],
      ),
    );
  }

  Widget _rangeButton(String label, DateRangeType type) {
    bool isSelected = _rangeType == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (val) {
          if (type == DateRangeType.custom) {
            _selectDateRange();
          } else {
            setState(() => _rangeType = type);
          }
        },
        selectedColor: _isDealerMode ? AppTheme.ttMagenta : AppTheme.ttBlue,
        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _customRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _customRange = picked;
        _rangeType = DateRangeType.custom;
      });
    }
  }

  Widget _buildSummarySection(TargetProvider provider) {
    int total = 0;
    if (_isDealerMode) {
      for (var type in TargetType.values) {
        total += provider.getDealerAchievementInRange(_start, _end, type);
      }
    } else {
      total = provider.getTotalAchievementInRange(_selectedPersonnel!.id, _start, _end);
    }
    
    // Monthly comparison logic - based on selected date
    int currentMonthTarget = 0;
    int currentMonthAchieved = 0;
    for (var type in TargetType.values) {
      if (_isDealerMode) {
        currentMonthTarget += provider.getDealerTarget(_selectedDate, type);
        currentMonthAchieved += provider.getDealerAchievement(_selectedDate, type);
      } else {
        currentMonthTarget += provider.getTarget(_selectedPersonnel!.id, _selectedDate, type);
        currentMonthAchieved += provider.getAchievement(_selectedPersonnel!.id, _selectedDate, type);
      }
    }
    
    double achievementRatio = currentMonthTarget == 0 ? 0 : (currentMonthAchieved / currentMonthTarget) * 100;
    
    return Row(
      children: [
        Expanded(child: _statCard('Dönem Satışı', total.toString(), Icons.shopping_basket, _isDealerMode ? AppTheme.ttMagenta : Colors.blue)),
        const SizedBox(width: 12),
        Expanded(child: _statCard('Ay Hedef %', '${achievementRatio.toStringAsFixed(1)}%', Icons.track_changes, Colors.orange)),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        ],
      ),
    );
  }

  _GidisatResult _calculateGidisat(int achieved, int target, DateTime month) {
    final now = DateTime.now();
    double monthProgress = 0;

    if (month.year < now.year || (month.year == now.year && month.month < now.month)) {
      monthProgress = 1.0; // Past month is complete
    } else if (month.year > now.year || (month.year == now.year && month.month > now.month)) {
      monthProgress = 0.0; // Future month hasn't started
    } else {
      // Current month progress
      final int dayOfMonth = now.day;
      final int daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      monthProgress = dayOfMonth / daysInMonth;
    }

    if (target == 0) {
      if (achieved > 0) {
        return _GidisatResult("Bonus", Colors.purple, "Hedefsiz aktivasyon katkısı sağlanıyor.", 100, 100, monthProgress * 100);
      } else {
        return _GidisatResult("Hedef Yok", Colors.grey, "Bu kategori veya personel için hedef tanımlanmamış.", 0, 0, monthProgress * 100);
      }
    }

    final double completionRate = achieved / target;
    
    String status = "Beklenen";
    Color color = Colors.blue;
    String advice = "";

    if (completionRate >= monthProgress) {
      status = "Hızlı";
      color = Colors.green;
      advice = monthProgress >= 1.0 ? "Hedef başarıyla tamamlandı." : "Hedefin önündesiniz.";
    } else if (completionRate >= (monthProgress * 0.75)) {
      status = "Normal";
      color = Colors.orange;
      advice = monthProgress >= 1.0 ? "Hedef tam olarak yakalanamadı." : "Kritik eşiğe yakın.";
    } else {
      status = "Riskli";
      color = Colors.red;
      advice = monthProgress >= 1.0 ? "Hedefin gerisinde kalındı." : "Hızlanmanız gerek.";
    }

    final double forecast = monthProgress <= 0 ? 0 : (achieved / monthProgress);
    final double forecastPercent = (forecast / target) * 100;

    return _GidisatResult(status, color, advice, completionRate * 100, forecastPercent, monthProgress * 100);
  }

  Widget _buildAnalysisSection(TargetProvider provider) {
    int totalTarget = 0;
    int totalAchieved = 0;
    for (var type in TargetType.values) {
      if (_isDealerMode) {
        totalTarget += provider.getDealerTarget(_selectedDate, type);
        totalAchieved += provider.getDealerAchievement(_selectedDate, type);
      } else {
        totalTarget += provider.getTarget(_selectedPersonnel!.id, _selectedDate, type);
        totalAchieved += provider.getAchievement(_selectedPersonnel!.id, _selectedDate, type);
      }
    }

    final result = _calculateGidisat(totalAchieved, totalTarget, _selectedDate);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: result.color.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: result.color.withOpacity(0.05), blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_isDealerMode ? 'Bayi Gidişat Analizi' : 'Genel Gidişat Analizi', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: result.color, borderRadius: BorderRadius.circular(12)),
                child: Text(result.status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _analysisRow('Ayın Geçen Kısmı', '${result.monthProgress.toStringAsFixed(0)}%'),
          _analysisRow('Hedef Gerçekleşme', '${result.completionRate.toStringAsFixed(1)}%'),
          _analysisRow('Kapanış Tahmini (Asonu)', '${result.forecast.toStringAsFixed(1)}%', isBold: true),
          const Divider(height: 32),
          Text(
            _isDealerMode 
              ? "Tüm personellerin toplam performansı temel alınmıştır. ${result.advice}" 
              : result.advice, 
            style: TextStyle(color: result.color, fontWeight: FontWeight.w500, fontSize: 14)
          ),
        ],
      ),
    );
  }



  Widget _buildDetailedCategorySection(TargetProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text('Kategori Bazlı Gidişat', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.1,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: TargetType.values.length,
          itemBuilder: (context, index) {
            final type = TargetType.values[index];
            int target = _isDealerMode ? provider.getDealerTarget(_selectedDate, type) : provider.getTarget(_selectedPersonnel!.id, _selectedDate, type);
            int achieved = _isDealerMode ? provider.getDealerAchievement(_selectedDate, type) : provider.getAchievement(_selectedPersonnel!.id, _selectedDate, type);
            final res = _calculateGidisat(achieved, target, _selectedDate);

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: target == 0 ? Colors.grey[200]! : res.color.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_formatEnum(type), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const Spacer(),
                  Row(
                    children: [
                      Text('$achieved', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(' / $target', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: target == 0 ? 0 : (achieved / target).clamp(0, 1),
                    color: res.color,
                    backgroundColor: res.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(res.status, style: TextStyle(color: res.color, fontSize: 10, fontWeight: FontWeight.bold)),
                      Text('${res.completionRate.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  String _formatEnum(TargetType type) {
    switch (type) {
      case TargetType.mobilFaturali: return 'MOBİL FATURALI';
      case TargetType.mobilFaturasiz: return 'MOBİL FATURASIZ';
      case TargetType.sabitInternet: return 'SABİT İNTERNET';
      case TargetType.tivibuIptv: return 'TİVİBU IPTV';
      case TargetType.tivibuUydu: return 'TİVİBU UYDU';
      case TargetType.cihazAkilli: return 'AKILLI CİHAZ';
      case TargetType.cihazDiger: return 'DİĞER CİHAZ';
    }
  }

  Widget _analysisRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700], fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: isBold ? AppTheme.ttMagenta : null)),
        ],
      ),
    );
  }

  Widget _buildCategoryChart(TargetProvider provider) {
    final data = <PieChartSectionData>[];
    int index = 0;
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.red, Colors.purple, Colors.cyan, Colors.indigo, Colors.amber];
    
    for (var type in TargetType.values) {
      int val = 0;
      if (_isDealerMode) {
        val = provider.getDealerAchievementInRange(_start, _end, type);
      } else {
        val = provider.getAchievementInRange(_selectedPersonnel!.id, _start, _end, type);
      }

      if (val > 0) {
        data.add(PieChartSectionData(
          value: val.toDouble(),
          title: val.toString(),
          color: colors[index % colors.length],
          radius: 60,
          showTitle: true,
          titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
        ));
        index++;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Kategori Satış Dağılımı', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: data.isEmpty 
              ? const Center(child: Text('Bu dönemde henüz satış yok'))
              : PieChart(PieChartData(sections: data, centerSpaceRadius: 40)),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            children: TargetType.values.map((type) {
                int val = _isDealerMode 
                  ? provider.getDealerAchievementInRange(_start, _end, type)
                  : provider.getAchievementInRange(_selectedPersonnel!.id, _start, _end, type);
                if (val == 0) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: colors[TargetType.values.indexOf(type) % colors.length], shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text(_formatEnum(type), style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChart(TargetProvider provider) {
    List<FlSpot> spots = [];
    final daysToFetch = _rangeType == DateRangeType.custom 
        ? _end.difference(_start).inDays + 1 
        : (_rangeType == DateRangeType.yearly ? 12 : 7);
    
    for (int i = 0; i < daysToFetch; i++) {
      DateTime d = _start.add(Duration(days: i));
      if (d.isAfter(_end)) break;
      
      int dayTotal = 0;
      for (var type in TargetType.values) {
        if (_isDealerMode) {
          dayTotal += provider.getDealerAchievementInRange(d, d, type);
        } else {
          dayTotal += provider.getAchievementInRange(_selectedPersonnel!.id, d, d, type);
        }
      }
      spots.add(FlSpot(i.toDouble(), dayTotal.toDouble()));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Satış Trendi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(
                show: true, 
                rightTitles: AxisTitles(), 
                topTitles: AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false)
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots.isEmpty ? [const FlSpot(0, 0)] : spots,
                  isCurved: true,
                  color: _isDealerMode ? AppTheme.ttMagenta : AppTheme.ttBlue,
                  barWidth: 4,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(show: true, color: (_isDealerMode ? AppTheme.ttMagenta : AppTheme.ttBlue).withOpacity(0.1)),
                ),
              ],
            )),
          ),
        ],
      ),
    );
  }
}

class _GidisatResult {
  final String status;
  final Color color;
  final String advice;
  final double completionRate;
  final double forecast;
  final double monthProgress;

  _GidisatResult(this.status, this.color, this.advice, this.completionRate, this.forecast, this.monthProgress);
}
