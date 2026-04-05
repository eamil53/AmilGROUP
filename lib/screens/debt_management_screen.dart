import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/stock_provider.dart';
import '../theme/app_theme.dart';

class DebtManagementScreen extends StatefulWidget {
  const DebtManagementScreen({super.key});

  @override
  State<DebtManagementScreen> createState() => _DebtManagementScreenState();
}

class _DebtManagementScreenState extends State<DebtManagementScreen> {
  final _amountController = TextEditingController();
  final _descController = TextEditingController();

  void _showAddPaymentModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20, right: 20, top: 20
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ödeme Yap', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Ödeme Tutarı (TL)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.money),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Açıklama (Opsiyonel)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  final amount = double.tryParse(_amountController.text);
                  if (amount != null && amount > 0) {
                    context.read<StockProvider>().addDebtPayment(amount, _descController.text);
                    _amountController.clear();
                    _descController.clear();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ödeme başarıyla kaydedildi.'), backgroundColor: Colors.green));
                  }
                },
                child: const Text('KAYDET'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StockProvider>();
    final currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

    return Scaffold(
      appBar: AppBar(title: const Text('PORT Vadeli Borç Yönetimi')),
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            _buildDebtHeader(provider, currencyFormat),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.history, color: AppTheme.ttBlue),
                  SizedBox(width: 8),
                  Text('Ödeme Geçmişi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Expanded(
              child: provider.payments.isEmpty 
                ? const Center(child: Text('Henüz bir ödeme kaydı bulunmuyor.'))
                : ListView.builder(
                    itemCount: provider.payments.length,
                    itemBuilder: (context, index) {
                      final payment = provider.payments.reversed.toList()[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.green,
                            child: Icon(Icons.arrow_downward, color: Colors.white),
                          ),
                          title: Text(currencyFormat.format(payment.amount), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                          subtitle: Text(payment.description ?? 'Borç Ödemesi'),
                          trailing: Text(DateFormat('dd.MM.yyyy').format(payment.date)),
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddPaymentModal,
        label: const Text('Ödeme Ekle'),
        icon: const Icon(Icons.add_card),
        backgroundColor: AppTheme.ttMagenta,
      ),
    );
  }

  Widget _buildDebtHeader(StockProvider provider, NumberFormat currencyFormat) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.ttBlue,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          const Text('GÜNCEL KALAN BORÇ', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text(
            currencyFormat.format(provider.totalPortVadeliBalance),
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildMiniStats(provider, currencyFormat),
        ],
      ),
    );
  }

  Widget _buildMiniStats(StockProvider provider, NumberFormat currencyFormat) {
    double totalPayments = provider.payments.fold(0.0, (sum, p) => sum + p.amount);
    double initialDebt = provider.totalPortVadeliBalance + totalPayments;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _miniStatItem('Port Stok Değeri', initialDebt, currencyFormat),
        Container(width: 1, height: 30, color: Colors.white24),
        _miniStatItem('Toplam Yapılan Ödeme', totalPayments, currencyFormat),
      ],
    );
  }

  Widget _miniStatItem(String label, double value, NumberFormat format) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        const SizedBox(height: 4),
        Text(format.format(value), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
