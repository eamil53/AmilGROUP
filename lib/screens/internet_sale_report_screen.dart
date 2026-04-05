import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/internet_sale.dart';
import '../providers/internet_sale_provider.dart';
import '../theme/app_theme.dart';

class InternetSalesReportScreen extends StatelessWidget {
  const InternetSalesReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FF),
      appBar: AppBar(
        title: const Text('İnternet Satışı Raporları'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.ttBlue, Color(0xFF003D82)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Consumer<InternetSaleProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) return const Center(child: CircularProgressIndicator());
          if (provider.sales.isEmpty) return _buildEmptyState();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryCards(provider),
                const SizedBox(height: 24),
                _buildCharSection('Satış Durum Dağılımı', _buildStatusChart(provider)),
                const SizedBox(height: 24),
                _buildSellerPerformance(provider),
                const SizedBox(height: 24),
                _buildRecentSalesList(provider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.analytics_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('Henüz satış verisi bulunamadı.', style: TextStyle(color: Colors.grey[600], fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(InternetSaleProvider provider) {
    return Row(
      children: [
        Expanded(child: _buildStatCard('Toplam Satış', provider.sales.length.toString(), Icons.shopping_bag, Colors.blue)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Aktif Abonelik', provider.countByStatus(InternetSaleStatus.aktif).toString(), Icons.check_circle, Colors.green)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildCharSection(String title, Widget chart) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          SizedBox(height: 200, child: chart),
        ],
      ),
    );
  }

  Widget _buildStatusChart(InternetSaleProvider provider) {
    final aktif = provider.countByStatus(InternetSaleStatus.aktif);
    final beklemede = provider.countByStatus(InternetSaleStatus.beklemede);
    final iptal = provider.countByStatus(InternetSaleStatus.iptal);
    final total = provider.sales.length;

    return PieChart(
      PieChartData(
        sectionsSpace: 4,
        centerSpaceRadius: 40,
        sections: [
          PieChartSectionData(value: aktif.toDouble(), color: Colors.green, radius: 50, title: '${(aktif/total*100).toStringAsFixed(0)}%', titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          PieChartSectionData(value: beklemede.toDouble(), color: Colors.orange, radius: 50, title: '${(beklemede/total*100).toStringAsFixed(0)}%', titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          PieChartSectionData(value: iptal.toDouble(), color: Colors.red, radius: 50, title: '${(iptal/total*100).toStringAsFixed(0)}%', titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSellerPerformance(InternetSaleProvider provider) {
    final performance = provider.salesBySellsman();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Satış Performansı (Personel)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...performance.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w500)),
                      Text('${entry.value} Adet', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.ttBlue)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: entry.value / provider.sales.length,
                    backgroundColor: Colors.grey[100],
                    color: AppTheme.ttBlue,
                    borderRadius: BorderRadius.circular(10),
                    minHeight: 8,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRecentSalesList(InternetSaleProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Son İşlemler', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: provider.sales.take(5).length,
          itemBuilder: (context, index) {
            final sale = provider.sales.reversed.toList()[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getStatusColor(sale.status).withOpacity(0.1),
                  child: Icon(Icons.person, color: _getStatusColor(sale.status)),
                ),
                title: Text(sale.customerFullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${sale.campaign} - ${DateFormat('dd MMM').format(sale.date)}'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(sale.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    sale.status.name.toUpperCase(),
                    style: TextStyle(color: _getStatusColor(sale.status), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Color _getStatusColor(InternetSaleStatus status) {
    switch (status) {
      case InternetSaleStatus.aktif: return Colors.green;
      case InternetSaleStatus.beklemede: return Colors.orange;
      case InternetSaleStatus.iptal: return Colors.red;
    }
  }
}
