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
import '../providers/target_provider.dart';
import '../models/target.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Eğer stoklar boşsa arka planda bir kez çekmeye çalış
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<StockProvider>(context, listen: false);
      if (provider.products.isEmpty) {
        provider.fetchFromFirebase();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: false,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildDashboardHome(context),
          const AllStockScreen(),
          const InternetSaleEntryScreen(),
          const AddProductScreen(),
          const PersonnelManagementScreen(),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.ttMagenta.withOpacity(0.3 + (_animationController.value * 0.4)),
                  blurRadius: 10 + (_animationController.value * 15),
                  spreadRadius: 2 + (_animationController.value * 6),
                ),
              ],
            ),
            child: FloatingActionButton(
              heroTag: null,
              onPressed: () => setState(() => _selectedIndex = 2),
              backgroundColor: AppTheme.ttMagenta,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              child: const Icon(Icons.shopping_cart_checkout_rounded, size: 28, color: Colors.white),
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 10,
        color: Colors.white,
        elevation: 16,
        child: SizedBox(
          height: 65,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home_filled, 'Özet', 0),
              _buildNavItem(Icons.inventory_2_outlined, 'Stoklar', 1),
              const SizedBox(width: 48), // Orta buton boşluğu
              _buildNavItem(Icons.qr_code_scanner_outlined, 'Stok Kaydı', 3),
              _buildNavItem(Icons.group_outlined, 'Personel', 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 26, color: isSelected ? AppTheme.ttBlue : Colors.grey[400]),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? AppTheme.ttBlue : Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardHome(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

    return Scaffold(
      appBar: AppBar(
        title: const Text('BAYİ YÖNETİM SİSTEMİ'),
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
      body: Consumer3<StockProvider, AuthProvider, TargetProvider>(
        builder: (context, provider, auth, targetProvider, child) {
          if (provider.isLoading || auth.isLoading || targetProvider.isLoading)
            return _buildShimmerLoading();

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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildImmersiveHeader(user.name ?? ''),
                    const SizedBox(height: 16),

                    // YENİ: Hedef & Performans Kartı (En Üstte) - Artık tek ana kart
                    if (user.isAdmin || user.canAccess('target_report')) ...[
                      _buildTargetPerformanceStatus(context, targetProvider),
                    ],

                    const SizedBox(height: 24),

                    if (user.isAdmin || user.canViewProfits()) ...[
                      const _SectionHeader(title: 'Finansal Özet'),
                      const SizedBox(height: 12),
                      _buildStatsHub(context, provider, currencyFormat),
                    ],

                    const SizedBox(height: 32),
                    const _SectionHeader(title: 'Operasyonel Merkez', subtitle: 'Hızlı işlemler ve yönetim'),
                    const SizedBox(height: 16),
                  
                  Consumer<UIProvider>(
                    builder: (context, uiProvider, child) {
                      final allowedMenu = uiProvider.menuOrder
                          .where((k) => user?.canAccess(k) ?? false)
                          .toList();

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: allowedMenu.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.95,
                        ),
                        itemBuilder: (context, index) {
                          final key = allowedMenu[index];
                          return _buildGridAction(context, key, lowStockCount, provider);
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 32),
                  const _SectionHeader(title: 'Envanter Dağılımı'),
                  const SizedBox(height: 16),
                  _buildCategoryRow(context, counts, user),
                  const SizedBox(height: 48),
                ],
              ),

              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildImmersiveHeader(String name) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppTheme.ttBlue.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.account_circle_outlined, color: AppTheme.ttBlue, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BAŞARI MOBİL PORTALI',
                  style: TextStyle(color: Colors.grey[400], fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2),
                ),
                Text(
                  name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: -0.2),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green[100]!)),
            child: Row(
              children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('AKTİF', style: TextStyle(color: Colors.green[700], fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
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

  Widget _buildStatsHub(BuildContext context, StockProvider provider, NumberFormat format) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _buildMetricCard('TOPLAM CİRO', format.format(provider.totalTurnover), Colors.blue[800]!, Icons.analytics_rounded),
        _buildMetricCard('TOPLAM KÂR', format.format(provider.totalCashProfit + provider.totalTemlikliProfit), Colors.green[700]!, Icons.trending_up_rounded),
        _buildMetricCard(
          'VADELİ BORÇ', 
          format.format(provider.totalPortVadeliBalance), 
          AppTheme.ttMagenta, 
          Icons.account_balance_wallet_rounded,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtManagementScreen())),
        ),
        _buildMetricCard('NAKİT CARİ', format.format(provider.totalNakitBalance), Colors.orange[800]!, Icons.payments_rounded),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, Color color, IconData icon, {VoidCallback? onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.1)),
            boxShadow: [BoxShadow(color: color.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  Icon(icon, color: color, size: 16),
                ],
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              ),
            ],
          ),
        ),
      ),
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
    final provider = context.read<StockProvider>();
    final counts = provider.getCategoryCounts();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
            gradient: LinearGradient(
              colors: [Colors.white, Colors.grey[50]!],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                          const SizedBox(height: 2),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black87)),
                              const SizedBox(width: 6),
                              Text('ADET', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[400])),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: Colors.grey[300]),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.03),
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16))
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildCorporateIndicator(Icons.phone_android, 'Tel', counts[ProductCategory.phone] ?? 0),
                    _buildCorporateIndicator(Icons.headphones, 'Kulaklık', counts[ProductCategory.headset] ?? 0),
                    _buildCorporateIndicator(Icons.watch, 'Saat', counts[ProductCategory.watch] ?? 0),
                    _buildCorporateIndicator(Icons.router, 'Modem', counts[ProductCategory.modem] ?? 0),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCorporateIndicator(IconData icon, String label, int count) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[400], size: 12),
        const SizedBox(width: 4),
        Text(count.toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54)),
      ],
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

  Widget _buildGridAction(BuildContext context, String key, int lowStockCount, StockProvider provider) {
    IconData icon;
    String label;
    Color color;
    VoidCallback onTap;

    switch (key) {
      case 'internet_sale_entry':
        icon = Icons.add_shopping_cart_rounded; label = 'Yeni İnternet\nSatışı'; color = Colors.orange[800]!;
        onTap = () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InternetSaleEntryScreen()));
        break;
      case 'internet_sale_list':
        icon = Icons.list_alt_rounded; label = 'İnternet\nSatışları'; color = Colors.blueGrey[800]!;
        onTap = () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InternetSaleListScreen()));
        break;
      case 'internet_sale_report':
        icon = Icons.assessment_rounded; label = 'İnternet\nRaporları'; color = Colors.indigo[700]!;
        onTap = () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InternetSalesReportScreen()));
        break;
      case 'all_stock':
        icon = Icons.inventory_2_rounded; label = 'Tüm Stok\nListesi'; color = AppTheme.ttBlue;
        onTap = () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AllStockScreen()));
        break;
      case 'critical_stock':
        icon = Icons.warning_rounded; label = 'Kritik\nStoklar'; color = Colors.red[700]!;
        onTap = () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CriticalStockScreen()));
        break;
      case 'hakedis_excel':
        icon = Icons.file_upload_rounded; label = 'Excel\nYükle'; color = Colors.teal[700]!;
        onTap = () async {
          final result = await provider.importHakedisExcel();
          if (result != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result), backgroundColor: Colors.green));
          }
        };
        break;
      case 'hakedis_takip':
        icon = Icons.check_circle_outline_rounded; label = 'Hakediş\nTakibi'; color = AppTheme.ttMagenta;
        onTap = () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HakedisTakipScreen()));
        break;
      case 'sales_report':
        icon = Icons.bar_chart_rounded; label = 'Satış\nRaporları'; color = Colors.green[700]!;
        onTap = () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesReportScreen()));
        break;
      case 'target_report':
        icon = Icons.auto_graph_rounded; label = 'Hedef &\nPerformans'; color = Colors.blue[600]!;
        onTap = () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TargetReportScreen()));
        break;
      case 'id_archive':
        icon = Icons.folder_shared_rounded; label = 'Kimlik\nArşivi'; color = Colors.brown[600]!;
        onTap = () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IDArchiveScreen()));
        break;
      case 'personnel_management':
        icon = Icons.badge_rounded; label = 'Personel\nYönetimi'; color = Colors.cyan[800]!;
        onTap = () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PersonnelManagementScreen()));
        break;
      case 'add_product_camera':
        icon = Icons.camera_enhance_rounded; label = 'Barkod ile\nStok Kaydı'; color = Colors.purple[700]!;
        onTap = () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddProductScreen()));
        break;
      default:
        return const SizedBox.shrink();
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.08)),
          ),
          child: Stack(
            children: [
              if (key == 'critical_stock' && lowStockCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Text(lowStockCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: color.withOpacity(0.08), shape: BoxShape.circle),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[800], fontSize: 11, fontWeight: FontWeight.bold, height: 1.1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildCategoryRow(BuildContext context, Map<ProductCategory, int> counts, AppUser? user) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          if (user?.canAccessCategory('phone') ?? false)
            _buildCategoryMiniCard(context, 'Telefon', Icons.phone_android, counts[ProductCategory.phone] ?? 0, ProductCategory.phone),
          const SizedBox(width: 12),
          if (user?.canAccessCategory('headset') ?? false)
            _buildCategoryMiniCard(context, 'Kulaklık', Icons.headphones, counts[ProductCategory.headset] ?? 0, ProductCategory.headset),
          const SizedBox(width: 12),
          if (user?.canAccessCategory('watch') ?? false)
            _buildCategoryMiniCard(context, 'Saat', Icons.watch, counts[ProductCategory.watch] ?? 0, ProductCategory.watch),
          const SizedBox(width: 12),
          if (user?.canAccessCategory('modem') ?? false)
            _buildCategoryMiniCard(context, 'Modem', Icons.router, counts[ProductCategory.modem] ?? 0, ProductCategory.modem),
        ],
      ),
    );
  }

  Widget _buildCategoryMiniCard(BuildContext context, String title, IconData icon, int count, ProductCategory category) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductListScreen(initialCategory: category))),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: AppTheme.ttBlue),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            Text('$count Adet', style: TextStyle(color: Colors.grey[500], fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetPerformanceStatus(BuildContext context, TargetProvider provider) {
    final now = DateTime.now();
    final achievementRatio = provider.getDealerTotalAchievementPercentage(now);
    
    // Geçen gün oranı
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final currentDay = now.day;
    final timeRatio = (currentDay / daysInMonth) * 100;
    
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (achievementRatio >= timeRatio) {
      statusColor = Colors.green;
      statusText = 'HEDEFE UYGUN';
      statusIcon = Icons.trending_up;
    } else if (achievementRatio >= timeRatio * 0.7) {
      statusColor = Colors.orange;
      statusText = 'DİKKAT: GERİDE';
      statusIcon = Icons.trending_flat;
    } else {
      statusColor = Colors.red;
      statusText = 'RİSKLİ DURUM';
      statusIcon = Icons.trending_down;
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 4,
      shadowColor: statusColor.withOpacity(0.2),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TargetReportScreen())),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [statusColor.withOpacity(0.05), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: statusColor.withOpacity(0.2), width: 1.5),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AYLIK HEDEF PERFORMANSI',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMMM yyyy', 'tr_TR').format(now).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.ttBlue,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(statusIcon, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '%${achievementRatio.toStringAsFixed(1)} Gerçekleşti',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: statusColor,
                              ),
                            ),
                            Text(
                              'Zaman: %${timeRatio.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Stack(
                          children: [
                            Container(
                              height: 10,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: (achievementRatio / 100).clamp(0, 1),
                              child: Container(
                                height: 10,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [statusColor, statusColor.withOpacity(0.7)],
                                  ),
                                  borderRadius: BorderRadius.circular(5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: statusColor.withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Zaman göstergesi (küçük bir çizgi)
                            Positioned(
                              left: (MediaQuery.of(context).size.width - 80) * (timeRatio / 100),
                              child: Container(
                                height: 10,
                                width: 2,
                                color: Colors.black.withOpacity(0.3),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatMini(
                    'Mobil', 
                    '${provider.getDealerAchievement(now, TargetType.mobilFaturali) + provider.getDealerAchievement(now, TargetType.mobilFaturasiz)}',
                    Colors.orange,
                  ),
                  _buildStatMini(
                    'İnternet', 
                    '${provider.getDealerAchievement(now, TargetType.sabitInternet)}',
                    Colors.cyan,
                  ),
                  _buildStatMini(
                    'Tivibu', 
                    '${provider.getDealerAchievement(now, TargetType.tivibuIptv) + provider.getDealerAchievement(now, TargetType.tivibuUydu)}',
                    Colors.blue,
                  ),
                  _buildStatMini(
                    'Cihaz', 
                    '${provider.getDealerAchievement(now, TargetType.cihazAkilli) + provider.getDealerAchievement(now, TargetType.cihazDiger)}',
                    Colors.green,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatMini(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: Colors.grey[500],
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
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
            Container(
              width: 150,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Container(
              width: 120,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              width: 100,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 110,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    height: 110,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _SectionHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.ttBlue, letterSpacing: -0.5)),
        if (subtitle != null)
          Text(subtitle!, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
      ],
    );
  }
}
