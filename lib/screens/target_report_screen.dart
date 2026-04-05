import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/target.dart';
import '../providers/target_provider.dart';
import '../theme/app_theme.dart';
import 'target_entry_screen.dart';
import 'target_summary_screen.dart';
import 'personnel_analysis_screen.dart';

class TargetReportScreen extends StatefulWidget {
  const TargetReportScreen({super.key});

  @override
  State<TargetReportScreen> createState() => _TargetReportScreenState();
}

class _TargetReportScreenState extends State<TargetReportScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  Future<void> _selectMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      helpText: 'AY SEÇİN',
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month, 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TargetProvider>();
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: GestureDetector(
          onTap: _selectMonth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Hedef & Performans', style: TextStyle(fontSize: 16)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(DateFormat('MMMM yyyy', 'tr_TR').format(_selectedMonth), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal)),
                  const Icon(Icons.arrow_drop_down, size: 16),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TargetSummaryScreen())),
            tooltip: 'Nihai Çıktı',
          ),
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PersonnelAnalysisScreen())),
            tooltip: 'Detaylı Analiz',
          ),
          IconButton(
            icon: const Icon(Icons.edit_calendar),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TargetEntryScreen())),
            tooltip: 'Veri Girişi',
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppTheme.ttMagenta,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'MOBİL'),
            Tab(text: 'İNTERNET'),
            Tab(text: 'TV (TİVİBU)'),
            Tab(text: 'CİHAZ'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMobileTab(provider),
          _buildInternetTab(provider),
          _buildTvTab(provider),
          _buildDeviceTab(provider),
        ],
      ),
    );
  }

  Widget _buildMobileTab(TargetProvider provider) {
    return _buildReportTable(
      provider,
      [
        _ColumnDef('Faturalı Hedef', TargetType.mobilFaturali, isTarget: true),
        _ColumnDef('Faturalı Aktivite', TargetType.mobilFaturali),
        _ColumnDef('Faturalı HG %', TargetType.mobilFaturali, isPercentage: true),
        _ColumnDef('Faturasız Hedef', TargetType.mobilFaturasiz, isTarget: true),
        _ColumnDef('Faturasız Aktivite', TargetType.mobilFaturasiz),
        _ColumnDef('Faturasız HG %', TargetType.mobilFaturasiz, isPercentage: true),
        _ColumnDef('Mobil Toplam Hedef', TargetType.mobilFaturali, isTarget: true, combinedWith: TargetType.mobilFaturasiz),
        _ColumnDef('Mobil Toplam Aktivite', TargetType.mobilFaturali, combinedWith: TargetType.mobilFaturasiz),
        _ColumnDef('Mobil Toplam HG %', TargetType.mobilFaturali, isPercentage: true, combinedWith: TargetType.mobilFaturasiz, isTotalRowCombined: true),
        _ColumnDef('Kapanış Tahmini', TargetType.mobilFaturali, isForecast: true, combinedWith: TargetType.mobilFaturasiz),
      ],
      Colors.orange[400]!,
    );
  }

  Widget _buildInternetTab(TargetProvider provider) {
    return _buildReportTable(
      provider,
      [
        _ColumnDef('İnternet Hedef', TargetType.sabitInternet, isTarget: true),
        _ColumnDef('İnternet Satış', TargetType.sabitInternet),
        _ColumnDef('İnternet HG %', TargetType.sabitInternet, isPercentage: true),
        _ColumnDef('Kapanış Tahmini', TargetType.sabitInternet, isForecast: true),
        _ColumnDef('Kapanış HGO %', TargetType.sabitInternet, isForecastPercentage: true),
      ],
      Colors.cyan[400]!,
    );
  }

  Widget _buildTvTab(TargetProvider provider) {
    return _buildReportTable(
      provider,
      [
        _ColumnDef('IPTV Hedef', TargetType.tivibuIptv, isTarget: true),
        _ColumnDef('IPTV Aktivite', TargetType.tivibuIptv),
        _ColumnDef('IPTV HG %', TargetType.tivibuIptv, isPercentage: true),
        _ColumnDef('Uydu Hedef', TargetType.tivibuUydu, isTarget: true),
        _ColumnDef('Uydu Aktivite', TargetType.tivibuUydu),
        _ColumnDef('Uydu HG %', TargetType.tivibuUydu, isPercentage: true),
        _ColumnDef('Kapanış Tahmini', TargetType.tivibuIptv, isForecast: true, combinedWith: TargetType.tivibuUydu),
      ],
      Colors.blue[400]!,
    );
  }

  Widget _buildDeviceTab(TargetProvider provider) {
    return _buildReportTable(
      provider,
      [
        _ColumnDef('Akıllı Cihaz Hedef', TargetType.cihazAkilli, isTarget: true),
        _ColumnDef('Akıllı Satış', TargetType.cihazAkilli),
        _ColumnDef('Akıllı HG %', TargetType.cihazAkilli, isPercentage: true),
        _ColumnDef('Diğer Cihaz Hedef', TargetType.cihazDiger, isTarget: true),
        _ColumnDef('Diğer Satış', TargetType.cihazDiger),
        _ColumnDef('Diğer HG %', TargetType.cihazDiger, isPercentage: true),
        _ColumnDef('Kapanış Tahmini', TargetType.cihazAkilli, isForecast: true, combinedWith: TargetType.cihazDiger),
      ],
      Colors.green[400]!,
    );
  }

  Widget _buildReportTable(TargetProvider provider, List<_ColumnDef> columns, Color accentColor) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 65,
          dataRowHeight: 60,
          columnSpacing: 15,
          headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
          headingRowColor: MaterialStateProperty.all(AppTheme.ttBlue.withOpacity(0.9)),
          border: TableBorder.all(color: Colors.grey[200]!),
          columns: [
            const DataColumn(label: Text('PERSONEL')),
            ...columns.map((col) => DataColumn(
              label: Container(
                width: 90,
                alignment: Alignment.center,
                child: Text(col.title, textAlign: TextAlign.center, overflow: TextOverflow.visible),
              ),
            )),
          ],
          rows: [
            ...provider.personnel.map((p) {
              return DataRow(
                cells: [
                  DataCell(
                    InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PersonnelAnalysisScreen(initialPersonnel: p))),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, decoration: TextDecoration.underline, color: AppTheme.ttBlue)),
                          Text(p.code, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                  ...columns.map((col) {
                    String value = "";
                    Color? textColor;
                    FontWeight fontWeight = FontWeight.normal;

                    if (col.isPercentage) {
                      double pVal = 0;
                      if (col.combinedWith != null) {
                         // Combined HGO calculation: (Achieved1 + Achieved2) / (Target1 + Target2)
                         double t1 = provider.getTarget(p.id, _selectedMonth, col.type).toDouble();
                         double t2 = provider.getTarget(p.id, _selectedMonth, col.combinedWith!).toDouble();
                         double a1 = provider.getAchievement(p.id, _selectedMonth, col.type).toDouble();
                         double a2 = provider.getAchievement(p.id, _selectedMonth, col.combinedWith!).toDouble();
                         pVal = (t1 + t2 == 0) ? 0 : ((a1 + a2) / (t1 + t2)) * 100;
                      } else {
                         pVal = provider.getAchievementPercentage(p.id, _selectedMonth, col.type);
                      }
                      value = "${pVal.toStringAsFixed(1)}%";
                      textColor = pVal >= 100 ? Colors.green[700] : (pVal > 50 ? Colors.orange[800] : Colors.red[700]);
                      fontWeight = FontWeight.bold;
                    } else if (col.isForecast) {
                      double f1 = provider.getForecast(p.id, _selectedMonth, col.type);
                      if (col.combinedWith != null) {
                        double f2 = provider.getForecast(p.id, _selectedMonth, col.combinedWith!);
                        value = (f1 + f2).toStringAsFixed(1);
                      } else {
                        value = f1.toStringAsFixed(1);
                      }
                      fontWeight = FontWeight.bold;
                      textColor = AppTheme.ttMagenta;
                    } else if (col.isForecastPercentage) {
                      double fp = provider.getForecastPercentage(p.id, _selectedMonth, col.type);
                      value = "${fp.toStringAsFixed(1)}%";
                      fontWeight = FontWeight.bold;
                      textColor = AppTheme.ttMagenta;
                    } else if (col.isTarget) {
                      int t1 = provider.getTarget(p.id, _selectedMonth, col.type);
                      if (col.combinedWith != null) {
                        int t2 = provider.getTarget(p.id, _selectedMonth, col.combinedWith!);
                        value = (t1 + t2).toString();
                      } else {
                        value = t1.toString();
                      }
                      fontWeight = FontWeight.w600;
                    } else {
                      int a1 = provider.getAchievement(p.id, _selectedMonth, col.type);
                      if (col.combinedWith != null) {
                         int a2 = provider.getAchievement(p.id, _selectedMonth, col.combinedWith!);
                         value = (a1 + a2).toString();
                      } else {
                         value = a1.toString();
                      }
                    }

                    return DataCell(
                      Container(
                        width: 90,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: col.isPercentage || col.isForecast ? accentColor.withOpacity(0.05) : null,
                        ),
                        child: Text(value, style: TextStyle(fontWeight: fontWeight, color: textColor)),
                      ),
                    );
                  }),
                ],
              );
            }).toList(),
            // --- TOTAL ROW ---
            DataRow(
              color: MaterialStateProperty.all(Colors.grey[50]),
              cells: [
                const DataCell(Text('TOPLAM', style: TextStyle(fontWeight: FontWeight.bold))),
                ...columns.map((col) {
                  double total = 0;
                  String value = "";
                  
                  for (var p in provider.personnel) {
                    if (col.isForecast) {
                      total += provider.getForecast(p.id, _selectedMonth, col.type);
                      if (col.combinedWith != null) total += provider.getForecast(p.id, _selectedMonth, col.combinedWith!);
                    } else if (col.isTarget) {
                      total += provider.getTarget(p.id, _selectedMonth, col.type);
                      if (col.combinedWith != null) total += provider.getTarget(p.id, _selectedMonth, col.combinedWith!);
                    } else if (col.isPercentage || col.isForecastPercentage) {
                      // Handled below
                    } else {
                      total += provider.getAchievement(p.id, _selectedMonth, col.type).toDouble();
                      if (col.combinedWith != null) total += provider.getAchievement(p.id, _selectedMonth, col.combinedWith!).toDouble();
                    }
                  }

                  if (col.isPercentage) {
                    double totalHedef = 0;
                    double totalAktif = 0;
                    for (var p in provider.personnel) {
                       totalHedef += provider.getTarget(p.id, _selectedMonth, col.type);
                       totalAktif += provider.getAchievement(p.id, _selectedMonth, col.type);
                       if (col.combinedWith != null && col.isTotalRowCombined == true) {
                          totalHedef += provider.getTarget(p.id, _selectedMonth, col.combinedWith!);
                          totalAktif += provider.getAchievement(p.id, _selectedMonth, col.combinedWith!);
                       }
                    }
                    value = totalHedef == 0 ? "0.0%" : "${((totalAktif / totalHedef) * 100).toStringAsFixed(1)}%";
                  } else if (col.isForecastPercentage) {
                    double totalHedef = provider.personnel.fold(0, (sum, p) => sum + provider.getTarget(p.id, _selectedMonth, col.type));
                    double totalFor = provider.personnel.fold(0, (sum, p) => sum + provider.getForecast(p.id, _selectedMonth, col.type));
                    value = totalHedef == 0 ? "0.0%" : "${((totalFor / totalHedef) * 100).toStringAsFixed(1)}%";
                  } else {
                    value = total.toStringAsFixed(total % 1 == 0 ? 0 : 1);
                  }

                  return DataCell(Container(
                    width: 90, alignment: Alignment.center,
                    child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ));
                }).toList(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ColumnDef {
  final String title;
  final TargetType type;
  final bool isTarget;
  final bool isPercentage;
  final bool isForecast;
  final bool isForecastPercentage;
  final bool isTotalRowCombined;
  final TargetType? combinedWith;

  _ColumnDef(this.title, this.type, {
    this.isTarget = false, 
    this.isPercentage = false, 
    this.isForecast = false,
    this.isForecastPercentage = false,
    this.isTotalRowCombined = false,
    this.combinedWith,
  });
}
