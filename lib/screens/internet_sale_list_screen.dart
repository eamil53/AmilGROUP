import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/internet_sale.dart';
import '../providers/internet_sale_provider.dart';
import '../theme/app_theme.dart';

class InternetSaleListScreen extends StatefulWidget {
  const InternetSaleListScreen({super.key});

  @override
  State<InternetSaleListScreen> createState() => _InternetSaleListScreenState();
}

class _InternetSaleListScreenState extends State<InternetSaleListScreen> {
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('İnternet Satış Kayıtları'),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: Consumer<InternetSaleProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) return const Center(child: CircularProgressIndicator());
                
                final filteredSales = provider.sales.where((s) {
                  final search = _searchQuery.toLowerCase();
                  return s.customerFullName.toLowerCase().contains(search) ||
                         s.customerTc.contains(search) ||
                         s.xdslNo.contains(search);
                }).toList().reversed.toList();

                if (filteredSales.isEmpty) {
                  return const Center(child: Text('Kayıt bulunamadı.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredSales.length,
                  itemBuilder: (context, index) {
                    final sale = filteredSales[index];
                    return _buildSaleCard(sale, provider);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: TextField(
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(
          hintText: 'Müşteri adı, TC veya XDSL ara...',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildSaleCard(InternetSale sale, InternetSaleProvider provider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        title: Text(sale.customerFullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TC: ${sale.customerTc} | XDSL: ${sale.xdslNo}'),
            const SizedBox(height: 4),
            Row(
              children: [
                _StatusBadge(status: sale.status),
                if (sale.hasOldInternet) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      sale.isOldInternetCanceled ? 'ESKİ İPTAL EDİLDİ' : 'ESKİ İPTAL BEKLİYOR',
                      style: TextStyle(color: sale.isOldInternetCanceled ? Colors.green : Colors.purple, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                _buildDetailRow('Hesap No', sale.accountNo),
                _buildDetailRow('Kampanya', sale.campaign),
                _buildDetailRow('Paket Hızı', sale.speed),
                _buildDetailRow('Satış Tarihi', DateFormat('dd.MM.yyyy').format(sale.date)),
                _buildDetailRow('Satış Yapan', sale.sellerName),
                _buildDetailRow('Telefon', sale.phoneNo),
                if (sale.description.isNotEmpty)
                  _buildDetailRow('Açıklama', sale.description),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ActionButton(
                      label: 'DURUM GÜNCELLE',
                      icon: Icons.edit_note,
                      color: AppTheme.ttBlue,
                      onTap: () => _showStatusDialog(context, sale, provider),
                    ),
                    _ActionButton(
                      label: 'SİL',
                      icon: Icons.delete_outline,
                      color: Colors.red,
                      onTap: () => _confirmDelete(context, sale, provider),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        ],
      ),
    );
  }

  void _showStatusDialog(BuildContext context, InternetSale sale, InternetSaleProvider provider) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Durum Değiştir'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: InternetSaleStatus.values.map((status) {
              return ListTile(
                title: Text(status.name.toUpperCase()),
                leading: Radio<InternetSaleStatus>(
                  value: status,
                  groupValue: sale.status,
                  onChanged: (val) {
                    Navigator.pop(context);
                    if (val == InternetSaleStatus.aktif) {
                      _handleActivate(context, sale, provider);
                    } else {
                      sale.status = val!;
                      provider.updateSale(sale);
                    }
                  },
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _handleActivate(BuildContext context, InternetSale sale, InternetSaleProvider provider) {
    if (sale.hasOldInternet && !sale.isOldInternetCanceled) {
      _showStrictWarningDialog(context, sale, provider);
    } else {
      sale.status = InternetSaleStatus.aktif;
      provider.updateSale(sale);
    }
  }

  void _showStrictWarningDialog(BuildContext context, InternetSale sale, InternetSaleProvider provider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.red[50],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.red, width: 2)),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
              SizedBox(width: 10),
              Text('KRİTİK UYARI!', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Bu müşterinin ESKİ İNTERNETİ olduğu belirtilmiş.',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              const Text(
                'Eski internet aboneliğinin İPTAL EDİLDİĞİNDEN EMİN MİSİNİZ?\n\nÇift fatura çıkmaması için bu işlem hayati önem taşımaktadır!',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red[100], borderRadius: BorderRadius.circular(10)),
                child: const Text(
                  'Sorumluluğu alıyor musunuz?',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('HAYIR, KONTROL EDECEĞİM', style: TextStyle(color: Colors.black54)),
            ),
            ElevatedButton(
              onPressed: () {
                sale.status = InternetSaleStatus.aktif;
                sale.isOldInternetCanceled = true;
                provider.updateSale(sale);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Satış AKTİF edildi ve eski internet iptal edildi olarak işaretlendi.'), backgroundColor: Colors.green),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('EVET, İPTAL EDİLDİ / EMİNİM'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, InternetSale sale, InternetSaleProvider provider) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Kaydı Sil'),
          content: const Text('Bu satış kaydını silmek istediğinize emin misiniz?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İPTAL')),
            TextButton(
              onPressed: () {
                provider.deleteSale(sale.id);
                Navigator.pop(context);
              }, 
              child: const Text('SİL', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final InternetSaleStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case InternetSaleStatus.aktif: color = Colors.green; break;
      case InternetSaleStatus.beklemede: color = Colors.orange; break;
      case InternetSaleStatus.iptal: color = Colors.red; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
