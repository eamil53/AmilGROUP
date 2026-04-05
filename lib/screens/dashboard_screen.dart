import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../models/product.dart';
import '../providers/stock_provider.dart';
import '../theme/app_theme.dart';
import 'add_product_screen.dart';
import 'product_list_screen.dart';
import 'hakedis_takip_screen.dart';
import 'critical_stock_screen.dart';
import 'debt_management_screen.dart';
import 'sales_report_screen.dart';
import 'all_stock_screen.dart';
import 'target_report_screen.dart';
import 'id_archive_screen.dart';
import 'internet_sale_entry_screen.dart';
import 'internet_sale_list_screen.dart';
import 'internet_sale_report_screen.dart';
import 'personnel_management_screen.dart';
import '../models/app_user.dart';
import '../providers/auth_provider.dart';
import '../providers/ui_provider.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

    return Scaffold(
      appBar: AppBar(
        title: const Text('ARELNET İLETİŞİM STOK'),
        actions: [
          IconButton(
            onPressed: () => context.read<AuthProvider>().logout(),
            icon: const Icon(Icons.logout),
            tooltip: 'Çıkış Yap',
          ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.ttBlue, Color(0xFF0056D2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Consumer2<StockProvider, AuthProvider>(
        builder: (context, provider, auth, child) {
          if (provider.isLoading || auth.isLoading) return _buildShimmerLoading();

          final counts = provider.getCategoryCounts();
          final lowStockCount = provider.lowStockProducts.length;
          final user = auth.currentUser;

          if (user == null) return const Center(child: Text('Giriş yapılmadı'));

          return RefreshIndicator(
            onRefresh: () async {
              await provider.fetchFromFirebase();
              await provider.syncExistingToFirestore();
            },
            child: SafeArea(
              bottom: true,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeHeader(user?.name ?? ''),
                    const SizedBox(height: 12),

                    if (user.isAdmin || user.canAccess('all_stock') || (user.isAdmin || user.canViewProfits()))
                      _buildSummarySection(
                        context,
                        provider,
                        currencyFormat,
                        user,
                      ),

                    const SizedBox(height: 20),

                    if (lowStockCount > 0 && (user.isAdmin || user.canAccess('critical_stock')))
                      _buildCriticalAlertBox(context, lowStockCount),

                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Operasyonel İşlemler',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Tooltip(
                          message: 'Menüleri sürükleyerek sıralayabilirsiniz',
                          child: Icon(
                            Icons.info_outline,
                            size: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Consumer<UIProvider>(
                      builder: (context, uiProvider, child) {
                        final allowedMenu = uiProvider.menuOrder
                            .where((k) => user?.canAccess(k) ?? false)
                            .toList();

                        return ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: allowedMenu.length,
                          onReorder: (oldIndex, newIndex) {
                            // Find the keys in the original list to update order correctly
                            final String itemKey = allowedMenu[oldIndex];
                            final int originalOldIndex = uiProvider.menuOrder
                                .indexOf(itemKey);

                            // Approximate new index in original list (this is tricky with filtered list)
                            // But for simple cases we just use the original keys
                            uiProvider.updateMenuOrder(
                              originalOldIndex,
                              newIndex,
                            );
                          },
                          itemBuilder: (context, index) {
                            final key = allowedMenu[index];

                            return Container(
                              key: ValueKey(key),
                              margin: const EdgeInsets.only(bottom: 12),
                              child: _buildReorderableMenuAction(
                                context,
                                key,
                                lowStockCount,
                                provider,
                              ),
                            );
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 30),
                    const Text(
                      'Kategoriler',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.1,
                      children: [
                        if (user != null && user.canAccessCategory('phone'))
                          _buildCategoryCard(
                            context,
                            'Telefon',
                            Icons.phone_android,
                            counts[ProductCategory.phone] ?? 0,
                            ProductCategory.phone,
                          ),
                        if (user != null && user.canAccessCategory('headset'))
                          _buildCategoryCard(
                            context,
                            'Kulaklık',
                            Icons.headphones,
                            counts[ProductCategory.headset] ?? 0,
                            ProductCategory.headset,
                          ),
                        if (user != null && user.canAccessCategory('watch'))
                          _buildCategoryCard(
                            context,
                            'Saat',
                            Icons.watch,
                            counts[ProductCategory.watch] ?? 0,
                            ProductCategory.watch,
                          ),
                        if (user != null && user.canAccessCategory('modem'))
                          _buildCategoryCard(
                            context,
                            'Modem',
                            Icons.router,
                            counts[ProductCategory.modem] ?? 0,
                            ProductCategory.modem,
                          ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWelcomeHeader(String name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Merhaba,',
          style: TextStyle(color: Colors.grey[600], fontSize: 16),
        ),
        Text(
          name,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.ttBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildCriticalAlertBox(BuildContext context, int count) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CriticalStockScreen()),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red[100]!),
          ),
          child: Row(
            children: [
              const Hero(
                tag: 'critical_icon',
                child: Icon(Icons.warning_amber_rounded, color: Colors.red),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$count ürün kritik stok seviyesinde!',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.red),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummarySection(
    BuildContext context,
    StockProvider provider,
    NumberFormat format,
    AppUser user,
  ) {
    return Column(
      children: [
        if (user.isAdmin || user.canAccess('all_stock'))
          _buildMainSummaryCard(
            context,
            provider.totalStock.toString(),
            'PORT Toplam Stok',
            AppTheme.ttBlue,
            Icons.inventory_2,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AllStockScreen()),
            ),
          ),
        if (user.isAdmin || user.canAccess('all_stock'))
          const SizedBox(height: 16),
        if (user.isAdmin || user.canViewProfits())
          Row(
            children: [
              Expanded(
                child: _buildMiniSummaryCard(
                  format.format(provider.totalTurnover),
                  'Toplam Ciro',
                  Colors.grey[700]!,
                  Icons.analytics,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMiniSummaryCard(
                  format.format(
                    provider.totalCashProfit + provider.totalTemlikliProfit,
                  ),
                  'Toplam Kâr',
                  Colors.green[700]!,
                  Icons.trending_up,
                ),
              ),
            ],
          ),
        const SizedBox(height: 24),
        if (user.isAdmin || user.canViewProfits())
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Cari Hesap Durumu (Stok Değeri)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        if (user.isAdmin || user.canViewProfits()) const SizedBox(height: 12),
        if (user.isAdmin || user.canViewProfits())
          Row(
            children: [
              Expanded(
                child: _buildCariCard(
                  format.format(provider.totalPortVadeliBalance),
                  'PORT Vadeli Borç',
                  AppTheme.ttBlue,
                  Icons.account_balance_wallet,
                  subtitle: 'Satış ve ödemeyle düşer',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DebtManagementScreen(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCariCard(
                  format.format(provider.totalNakitBalance),
                  'Nakit Cari (Stokta)',
                  Colors.orange[700]!,
                  Icons.payments,
                  subtitle: 'Ödenmiş stok',
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildCariCard(
    String value,
    String label,
    Color color,
    IconData icon, {
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 9,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainSummaryCard(
    BuildContext context,
    String value,
    String label,
    Color color,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(icon, color: Colors.white.withOpacity(0.5), size: 48),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniSummaryCard(
    String value,
    String label,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    String title,
    IconData icon,
    int count,
    ProductCategory category,
  ) {
    return Card(
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductListScreen(initialCategory: category),
          ),
        ),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Hero(
                tag: 'cat_icon_${category.name}',
                child: Icon(icon, size: 36, color: AppTheme.ttBlue),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$count Adet',
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReorderableMenuAction(
    BuildContext context,
    String key,
    int lowStockCount,
    StockProvider provider,
  ) {
    switch (key) {
      case 'internet_sale_entry':
        return _buildQuickActionButton(
          context,
          'İnternet Satışı Girişi',
          Icons.add_shopping_cart,
          Colors.orange[800]!,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const InternetSaleEntryScreen()),
          ),
          isReorderable: true,
        );
      case 'internet_sale_list':
        return _buildQuickActionButton(
          context,
          'İnternet Satış Kayıtları',
          Icons.view_headline,
          Colors.blueGrey[800]!,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const InternetSaleListScreen()),
          ),
          isReorderable: true,
        );
      case 'internet_sale_report':
        return _buildQuickActionButton(
          context,
          'İnternet Satış Raporları',
          Icons.query_stats,
          Colors.indigo[700]!,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const InternetSalesReportScreen(),
            ),
          ),
          isReorderable: true,
        );
      case 'all_stock':
        return _buildQuickActionButton(
          context,
          'Tüm Stok Listesi',
          Icons.inventory_2,
          AppTheme.ttBlue,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AllStockScreen()),
          ),
          isReorderable: true,
        );
      case 'critical_stock':
        return _buildQuickActionButton(
          context,
          'Kritik Stoklar !!!',
          Icons.warning_amber_rounded,
          Colors.red[700]!,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CriticalStockScreen()),
          ),
          badge: lowStockCount > 0 ? lowStockCount.toString() : null,
          isReorderable: true,
        );
      case 'hakedis_excel':
        return _buildQuickActionButton(
          context,
          'Hakediş Listesi Yükle (Excel)',
          Icons.upload_file,
          AppTheme.ttBlue,
          () async {
            final result = await provider.importHakedisExcel();
            if (result != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(result), backgroundColor: Colors.green),
              );
            }
          },
          isReorderable: true,
        );
      case 'hakedis_takip':
        return _buildQuickActionButton(
          context,
          'Hakediş Takibi (PORT)',
          Icons.assignment_turned_in,
          AppTheme.ttMagenta,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HakedisTakipScreen()),
          ),
          isReorderable: true,
        );
      case 'sales_report':
        return _buildQuickActionButton(
          context,
          'Satış Raporları & Analiz',
          Icons.bar_chart,
          Colors.green[700]!,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SalesReportScreen()),
          ),
          isReorderable: true,
        );
      case 'target_report':
        return _buildQuickActionButton(
          context,
          'Hedef & Performans Takibi',
          Icons.trending_up,
          AppTheme.ttBlue,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TargetReportScreen()),
          ),
          isReorderable: true,
        );
      case 'id_archive':
        return _buildQuickActionButton(
          context,
          'Kimlik Arşivi',
          Icons.contact_page_outlined,
          AppTheme.ttTurquoise,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const IDArchiveScreen()),
          ),
          isReorderable: true,
        );
      case 'add_product_camera':
        return _buildQuickActionButton(
          context,
          'Stok Kaydet (Kamera)',
          Icons.qr_code_scanner,
          AppTheme.ttTurquoise,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddProductScreen()),
          ),
          isReorderable: true,
        );
      case 'personnel_management':
        return _buildQuickActionButton(
          context,
          'Personel Yönetimi',
          Icons.people_alt_outlined,
          Colors.blueGrey[700]!,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PersonnelManagementScreen()),
          ),
          isReorderable: true,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildQuickActionButton(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    String? badge,
    bool isReorderable = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              if (isReorderable)
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(
                    Icons.drag_indicator,
                    color: Colors.grey,
                    size: 20,
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 150, height: 24, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
            const SizedBox(height: 20),
            Container(width: double.infinity, height: 140, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24))),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Container(height: 100, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)))),
                const SizedBox(width: 16),
                Expanded(child: Container(height: 100, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)))),
              ],
            ),
            const SizedBox(height: 32),
            Container(width: 120, height: 20, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 16),
            Container(width: double.infinity, height: 70, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))),
            const SizedBox(height: 12),
            Container(width: double.infinity, height: 70, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))),
            const SizedBox(height: 32),
            Container(width: 100, height: 20, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Container(height: 110, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)))),
                const SizedBox(width: 16),
                Expanded(child: Container(height: 110, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
