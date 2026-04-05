import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/target.dart';
import '../providers/target_provider.dart';
import '../theme/app_theme.dart';

class TargetSummaryScreen extends StatefulWidget {
  const TargetSummaryScreen({super.key});

  @override
  State<TargetSummaryScreen> createState() => _TargetSummaryScreenState();
}

class _TargetSummaryScreenState extends State<TargetSummaryScreen> {
  final GlobalKey _boundaryKey = GlobalKey();

  Future<void> _exportAsPng() async {
    try {
      RenderRepaintBoundary? boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      
      final bytes = byteData.buffer.asUint8List();

      final pdf = pw.Document();
      final imageW = pw.MemoryImage(bytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.copyWith(
            width: imageW.width?.toDouble(),
            height: imageW.height?.toDouble(),
            marginLeft: 0, marginTop: 0, marginRight: 0, marginBottom: 0,
          ),
          build: (pw.Context context) {
            return pw.Center(child: pw.Image(imageW));
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'Performans_Nihai_Rapor.pdf',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rapor dışa aktarılmaya hazır!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TargetProvider>();
    final DateTime now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nihai Performans Çıktısı'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: _exportAsPng,
            tooltip: 'Görsel (PNG) Çıktı Al',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: provider.isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: RepaintBoundary(
                  key: _boundaryKey,
                  child: Container(
                    color: Colors.white,
                    child: DataTable(
                      headingRowHeight: 80,
                      dataRowHeight: 60,
                      columnSpacing: 10,
                      headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
                      headingRowColor: MaterialStateProperty.all(AppTheme.ttBlue),
                      border: TableBorder.all(color: Colors.grey[300]!),
                      columns: [
                        const DataColumn(label: Text('PERSONEL')),
                        ..._buildColumns(),
                      ],
                      rows: [
                        ...provider.personnel.map((p) => _buildDataRow(p, provider, now)),
                        _buildTotalRow(provider, now),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
    );
  }

  List<DataColumn> _buildColumns() {
    return [
      // Mobil Toplam
      _col('MOBİL\nHEDEF', Colors.orange, bold: true),
      _col('MOBİL\nAKTİVİTE', Colors.orange, bold: true),
      _col('MOBİL\nHGO %', Colors.orange, bold: true),
      // İnternet
      _col('İNT.\nHEDEF', Colors.cyan),
      _col('İNT.\nSATIŞ', Colors.cyan),
      _col('İNT.\nHGO %', Colors.cyan),
      // TV Toplam
      _col('TV\nHEDEF', Colors.blue, bold: true),
      _col('TV\nAKTİVASYON', Colors.blue, bold: true),
      _col('TV\nHGO %', Colors.blue, bold: true),
      // Cihaz Toplam
      _col('CİHAZ\nHEDEF', Colors.green, bold: true),
      _col('CİHAZ\nSATIŞ', Colors.green, bold: true),
      _col('CİHAZ\nHGO %', Colors.green, bold: true),
      // Forecast
      _col('GENEL\nFORECAST', AppTheme.ttMagenta, bold: true),
    ];
  }

  DataColumn _col(String label, Color color, {bool bold = false}) {
    return DataColumn(
      label: Container(
        width: 85,
        alignment: Alignment.center,
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: bold ? FontWeight.w900 : FontWeight.bold)),
      ),
    );
  }

  DataRow _buildDataRow(Personnel p, TargetProvider provider, DateTime month) {
    return DataRow(
      cells: [
        DataCell(Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
        // Mobil Toplam
        _cell((provider.getTarget(p.id, month, TargetType.mobilFaturali) + provider.getTarget(p.id, month, TargetType.mobilFaturasiz)).toString(), bold: true),
        _cell((provider.getAchievement(p.id, month, TargetType.mobilFaturali) + provider.getAchievement(p.id, month, TargetType.mobilFaturasiz)).toString(), bold: true),
        _pCell(_calcCombinedHGO(p.id, provider, month, [TargetType.mobilFaturali, TargetType.mobilFaturasiz]), bold: true),
        // İnternet
        _cell(provider.getTarget(p.id, month, TargetType.sabitInternet).toString()),
        _cell(provider.getAchievement(p.id, month, TargetType.sabitInternet).toString()),
        _pCell(provider.getAchievementPercentage(p.id, month, TargetType.sabitInternet)),
        // TV Toplam
        _cell((provider.getTarget(p.id, month, TargetType.tivibuIptv) + provider.getTarget(p.id, month, TargetType.tivibuUydu)).toString(), bold: true),
        _cell((provider.getAchievement(p.id, month, TargetType.tivibuIptv) + provider.getAchievement(p.id, month, TargetType.tivibuUydu)).toString(), bold: true),
        _pCell(_calcCombinedHGO(p.id, provider, month, [TargetType.tivibuIptv, TargetType.tivibuUydu]), bold: true),
        // Cihaz Toplam
        _cell((provider.getTarget(p.id, month, TargetType.cihazAkilli) + provider.getTarget(p.id, month, TargetType.cihazDiger)).toString(), bold: true),
        _cell((provider.getAchievement(p.id, month, TargetType.cihazAkilli) + provider.getAchievement(p.id, month, TargetType.cihazDiger)).toString(), bold: true),
        _pCell(_calcCombinedHGO(p.id, provider, month, [TargetType.cihazAkilli, TargetType.cihazDiger]), bold: true),
        // Overall Forecast
        _cell(_calcCombinedForecast(p.id, provider, month).toStringAsFixed(1), bold: true, color: AppTheme.ttMagenta),
      ],
    );
  }

  DataRow _buildTotalRow(TargetProvider provider, DateTime month) {
    return DataRow(
      color: MaterialStateProperty.all(Colors.grey[100]),
      cells: [
        const DataCell(Text('TOPLAM', style: TextStyle(fontWeight: FontWeight.bold))),
        // Mobil Total
        _tCell(provider, month, [TargetType.mobilFaturali, TargetType.mobilFaturasiz], false, bold: true),
        _tCell(provider, month, [TargetType.mobilFaturali, TargetType.mobilFaturasiz], true, bold: true),
        _tPCell(provider, month, [TargetType.mobilFaturali, TargetType.mobilFaturasiz], bold: true),
        // İnternet Total
        _tCell(provider, month, [TargetType.sabitInternet], false),
        _tCell(provider, month, [TargetType.sabitInternet], true),
        _tPCell(provider, month, [TargetType.sabitInternet]),
        // TV Total
        _tCell(provider, month, [TargetType.tivibuIptv, TargetType.tivibuUydu], false, bold: true),
        _tCell(provider, month, [TargetType.tivibuIptv, TargetType.tivibuUydu], true, bold: true),
        _tPCell(provider, month, [TargetType.tivibuIptv, TargetType.tivibuUydu], bold: true),
        // Cihaz Total
        _tCell(provider, month, [TargetType.cihazAkilli, TargetType.cihazDiger], false, bold: true),
        _tCell(provider, month, [TargetType.cihazAkilli, TargetType.cihazDiger], true, bold: true),
        _tPCell(provider, month, [TargetType.cihazAkilli, TargetType.cihazDiger], bold: true),
        // Total Forecast
         DataCell(Container(width: 85, alignment: Alignment.center, child: Text(
           provider.personnel.fold(0.0, (sum, p) => sum + _calcCombinedForecast(p.id, provider, month)).toStringAsFixed(1),
           style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.ttMagenta)
         ))),
      ],
    );
  }

  DataCell _tCell(TargetProvider provider, DateTime month, List<TargetType> types, bool isAchieved, {bool bold = false}) {
    double total = 0;
    for (var p in provider.personnel) {
      for (var t in types) {
        total += isAchieved ? provider.getAchievement(p.id, month, t).toDouble() : provider.getTarget(p.id, month, t).toDouble();
      }
    }
    return _cell(total.toStringAsFixed(0), bold: bold);
  }

  DataCell _tPCell(TargetProvider provider, DateTime month, List<TargetType> types, {bool bold = false}) {
    double totalH = 0;
    double totalA = 0;
    for (var p in provider.personnel) {
       for (var t in types) {
          totalH += provider.getTarget(p.id, month, t);
          totalA += provider.getAchievement(p.id, month, t);
       }
    }
    double p = totalH == 0 ? 0 : (totalA / totalH) * 100;
    return _pCell(p, bold: bold);
  }

  DataCell _cell(String text, {bool bold = false, Color? color}) {
    return DataCell(Container(
      width: 70,
      alignment: Alignment.center,
      child: Text(text, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color)),
    ));
  }

  DataCell _pCell(double percentage, {bool bold = false}) {
     final color = percentage >= 100 ? Colors.green[700] : (percentage > 50 ? Colors.orange[800] : Colors.red[700]);
     return DataCell(Container(
        width: 70,
        alignment: Alignment.center,
        child: Text("${percentage.toStringAsFixed(1)}%", 
          style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w600, color: color, fontSize: 11)),
     ));
  }

  DataCell _totalCell(int index, TargetProvider provider, DateTime month) {
    // This is a manual mapper for the 22 columns
    double total = 0;
    
    // Simplification: calculate based on column index
    // 0:MobilFatH, 1:MobilFatA, 2:MobilFat%, ...
    // To make it accurate, we'd rebuild the logic, but for brevity:
    return DataCell(Container(width: 70, alignment: Alignment.center, child: const Text("-", style: TextStyle(fontWeight: FontWeight.bold))));
  }

  double _calcCombinedHGO(String pId, TargetProvider provider, DateTime month, List<TargetType> types) {
    double totalH = 0;
    double totalA = 0;
    for (var t in types) {
      totalH += provider.getTarget(pId, month, t);
      totalA += provider.getAchievement(pId, month, t);
    }
    return totalH == 0 ? 0 : (totalA / totalH) * 100;
  }

  double _calcCombinedForecast(String pId, TargetProvider provider, DateTime month) {
    double totalF = 0;
    for (var t in TargetType.values) {
      totalF += provider.getForecast(pId, month, t);
    }
    return totalF;
  }
}
