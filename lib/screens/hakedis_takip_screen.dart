import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/stock_provider.dart';
import '../theme/app_theme.dart';

class HakedisTakipScreen extends StatefulWidget {
  const HakedisTakipScreen({super.key});

  @override
  State<HakedisTakipScreen> createState() => _HakedisTakipScreenState();
}

class _HakedisTakipScreenState extends State<HakedisTakipScreen> {
  HakedisStatus? _filterStatus;
  final format = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PORT Hakediş Takibi'),
        backgroundColor: AppTheme.ttBlue,
        foregroundColor: Colors.white,
      ),
      body: Consumer<StockProvider>(
        builder: (context, provider, child) {
          final temlikliSales = provider.sales.where((s) {
            final isTemlikli = s.paymentType == PaymentType.temlikli;
            final matchesStatus = _filterStatus == null || s.hakedisStatus == _filterStatus;
            return isTemlikli && matchesStatus;
          }).toList();

          return SafeArea(
            bottom: true,
            child: Column(
              children: [
                _buildFilterHeader(),
                _buildSummaryHeader(temlikliSales),
                Expanded(
                  child: temlikliSales.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: temlikliSales.length,
                          itemBuilder: (context, index) {
                            final sale = temlikliSales[index];
                            return _buildHakedisCard(context, sale);
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterHeader() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          FilterChip(
            label: const Text('Tümü'),
            selected: _filterStatus == null,
            onSelected: (val) => setState(() => _filterStatus = null),
            backgroundColor: Colors.white,
            selectedColor: AppTheme.ttBlue,
            labelStyle: TextStyle(color: _filterStatus == null ? Colors.white : AppTheme.ttBlue),
          ),
          const SizedBox(width: 8),
          _statusChip('Bekliyor', HakedisStatus.bekliyor, Colors.orange),
          const SizedBox(width: 8),
          _statusChip('Fatura Kesildi', HakedisStatus.faturaKesildi, Colors.blue),
          const SizedBox(width: 8),
          _statusChip('Ödeme Alındı', HakedisStatus.odemeAlindi, Colors.green),
        ],
      ),
    );
  }

  Widget _statusChip(String label, HakedisStatus status, Color color) {
    final isSelected = _filterStatus == status;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) => setState(() => _filterStatus = val ? status : null),
      backgroundColor: Colors.white,
      selectedColor: color,
      labelStyle: TextStyle(color: isSelected ? Colors.white : color),
    );
  }

  Widget _buildSummaryHeader(List<Sale> sales) {
    final pendingHakedis = sales.where((s) => s.hakedisStatus != HakedisStatus.odemeAlindi).fold(0.0, (sum, s) => sum + s.profit);
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.ttMagenta.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.ttMagenta.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Beklenen Hakediş:', style: TextStyle(fontWeight: FontWeight.bold)),
          Text(format.format(pendingHakedis), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.ttMagenta)),
        ],
      ),
    );
  }

  Widget _buildHakedisCard(BuildContext context, Sale sale) {
    Color statusColor = Colors.orange;
    String statusText = 'Hakediş Bekliyor';
    IconData statusIcon = Icons.hourglass_empty;

    if (sale.hakedisStatus == HakedisStatus.faturaKesildi) {
      statusColor = Colors.blue;
      statusText = 'Fatura Kesildi';
      statusIcon = Icons.receipt_long;
    } else if (sale.hakedisStatus == HakedisStatus.odemeAlindi) {
      statusColor = Colors.green;
      statusText = 'Ödeme Alındı (Cariye Geçti)';
      statusIcon = Icons.check_circle;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${sale.brand} ${sale.model}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(statusText, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Satış Tarihi: ${DateFormat('dd.MM.yyyy HH:mm').format(sale.soldAt)}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _infoItem('Hakediş Tutarı', format.format(sale.profit), AppTheme.ttMagenta),
                _infoItem('Ciro', format.format(sale.turnover), Colors.grey),
              ],
            ),
            const SizedBox(height: 16),
            if (sale.hakedisStatus != HakedisStatus.odemeAlindi)
              ElevatedButton(
                onPressed: () => _showStatusUpdateDialog(context, sale),
                style: ElevatedButton.styleFrom(
                  backgroundColor: statusColor,
                  minimumSize: const Size(double.infinity, 40),
                ),
                child: const Text('DURUM GÜNCELLE'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  void _showStatusUpdateDialog(BuildContext context, Sale sale) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hakediş Durumu Güncelle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.receipt, color: Colors.blue),
                title: const Text('Fatura Kesildi'),
                onTap: () {
                  context.read<StockProvider>().updateHakedisStatus(sale.id, HakedisStatus.faturaKesildi);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.paid, color: Colors.green),
                title: const Text('Ödeme Alındı (Cariye İşlendi)'),
                onTap: () {
                  context.read<StockProvider>().updateHakedisStatus(sale.id, HakedisStatus.odemeAlindi);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_turned_in_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('Hakediş kaydı bulunamadı.', style: TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }
}
