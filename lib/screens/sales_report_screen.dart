import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/product.dart';
import '../providers/stock_provider.dart';
import '../theme/app_theme.dart';

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  DateTimeRange? _dateRange;
  final format = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
  int _selectedYear = DateTime.now().year;
  String? _selectedProductKey; // 'Marka Model' formatında

  @override
  void initState() {
    super.initState();
    // Default to last 30 days
    _dateRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now().add(const Duration(days: 1)),
    );
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _dateRange,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.ttBlue,
              onPrimary: Colors.white,
              onSurface: AppTheme.ttBlue,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StockProvider>();
    
    // Bitiş tarihine 1 gün ekleyerek o günün sonuna kadar olan tüm satışları kapsıyoruz
    final effectiveEnd = _dateRange?.end.add(const Duration(hours: 23, minutes: 59, seconds: 59));

    final filteredSales = provider.getFilteredSales(
      start: _dateRange?.start,
      end: effectiveEnd,
    );

    final totalProfit = filteredSales.fold(0.0, (sum, s) => sum + s.profit);
    final totalTurnover = filteredSales.fold(0.0, (sum, s) => sum + s.turnover);
    final cashProfit = filteredSales.where((s) => s.paymentType == PaymentType.nakit).fold(0.0, (sum, s) => sum + s.profit);
    final temlikProfit = filteredSales.where((s) => s.paymentType == PaymentType.temlikli).fold(0.0, (sum, s) => sum + s.profit);

    // Ürün bazlı filtreleme için anahtarları çıkarıyoruz
    final productKeys = filteredSales.map((s) => '${s.brand} ${s.model}').toSet().toList();
    productKeys.sort();

    // Seçili ürüne göre filtreleme
    final displaySales = (_selectedProductKey == null || _selectedProductKey == 'Tümü')
      ? filteredSales 
      : filteredSales.where((s) => '${s.brand} ${s.model}' == _selectedProductKey).toList();
    
    final selectedProductCount = displaySales.fold(0, (sum, s) => sum + s.quantity);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Satış Raporları'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _selectDateRange,
          ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildDateHeader(),
              _buildSummaryRow(totalTurnover, totalProfit),
              _buildDetailedSummary(cashProfit, temlikProfit),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 30, 20, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Yıllık Kâr Grafiği', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              _buildYearSelector(),
              _buildProfitChart(provider),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 30, 20, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Ürün Bazlı Filtrele', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              _buildProductDropdown(productKeys, selectedProductCount),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 10, 20, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Dönem Satışları', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              _buildSalesList(displaySales),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      color: AppTheme.ttBlue.withOpacity(0.05),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${DateFormat('dd MMM').format(_dateRange!.start)} - ${DateFormat('dd MMM yyyy').format(_dateRange!.end)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          TextButton.icon(
            onPressed: _selectDateRange,
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Dönem Değiştir'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(double turnover, double profit) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(child: _summaryBox('Toplam Ciro', format.format(turnover), AppTheme.ttBlue)),
          const SizedBox(width: 16),
          Expanded(child: _summaryBox('Toplam Kâr', format.format(profit), Colors.green[700]!)),
        ],
      ),
    );
  }

  Widget _buildDetailedSummary(double cash, double temlik) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        ),
        child: Column(
          children: [
            _detailedRow('Nakit Kârı', format.format(cash), Colors.grey[700]!),
            const Divider(height: 24),
            _detailedRow('Temlik Hakediş Kârı', format.format(temlik), AppTheme.ttMagenta),
          ],
        ),
      ),
    );
  }

  Widget _detailedRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
      ],
    );
  }

  Widget _summaryBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildYearSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          const Text('Yıl: ', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          DropdownButton<int>(
            value: _selectedYear,
            items: [2023, 2024, 2025, 2026].map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedYear = val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfitChart(StockProvider provider) {
    final monthlyData = provider.getMonthlySalesData(_selectedYear);
    final values = monthlyData.values.toList();
    final maxValue = values.fold(0.0, (max, v) => v > max ? v : max);

    return Container(
      height: 250,
      padding: const EdgeInsets.fromLTRB(20, 20, 30, 10),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxValue * 1.2,
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < monthlyData.keys.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(monthlyData.keys.elementAt(index), style: const TextStyle(fontSize: 10)),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          barGroups: monthlyData.entries.toList().asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.value,
                  color: AppTheme.ttBlue,
                  width: 12,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildProductDropdown(List<String> options, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedProductKey ?? 'Tümü',
                isExpanded: true,
                items: ['Tümü', ...options].map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
                onChanged: (val) => setState(() => _selectedProductKey = val),
              ),
            ),
          ),
          if (_selectedProductKey != null && _selectedProductKey != 'Tümü')
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Icon(Icons.shopping_bag, size: 16, color: AppTheme.ttMagenta),
                  const SizedBox(width: 8),
                  Text(
                    'Dönemdeki Satış Adedi: ',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  Text(
                    count.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.ttMagenta),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSalesList(List<Sale> sales) {
    if (sales.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(40.0),
        child: Text('Bu dönemde satış bulunmamaktadır.', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sales.length,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemBuilder: (context, index) {
        final sale = sales[sales.length - 1 - index]; // Newest first
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text('${sale.brand} ${sale.model}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text(DateFormat('dd.MM.yyyy HH:mm').format(sale.soldAt), style: const TextStyle(fontSize: 11)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(format.format(sale.salePrice), style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Kâr: ${format.format(sale.profit)}', style: TextStyle(color: Colors.green[700], fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      },
    );
  }
}
