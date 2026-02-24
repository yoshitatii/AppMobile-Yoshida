import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/transaksi_provider.dart';
import 'barang/barang_list_screen.dart';
import 'transaksi/transaksi_screen.dart';
import 'transaksi/riwayat_transaksi_screen.dart';
import 'pembukuan/laporan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransaksiProvider>().loadTransaksi();
    });
  }

  Future<void> _refreshData() async {
    await Provider.of<TransaksiProvider>(context, listen: false).loadTransaksi();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    final days = [
      'Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'
    ];
    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];

    final dayName = days[date.weekday % 7];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year;

    return '$dayName, $day $month $year';
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: RefreshIndicator(
            onRefresh: _refreshData,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: 160,
                  pinned: true,
                  elevation: 0,
                  backgroundColor: Colors.blue[800],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                      color: Colors.blue[800],
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.white24,
                            child: Icon(
                              authProvider.isPemilikToko
                                  ? Icons.person
                                  : Icons.store,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Selamat Datang,',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 12)),
                              Text(
                                authProvider.displayName ?? 'Pengguna',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      onPressed: () =>
                          _showLogoutDialog(context, authProvider),
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_formatDate(now),
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 12)),
                        const SizedBox(height: 16),

                        // Ringkasan keuangan hanya untuk pemilik toko
                        if (authProvider.isPemilikToko) ...[
                          _buildFinancialSummary(),
                          const SizedBox(height: 20),
                        ],

                        const Text('Menu Utama',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        _buildMenuGrid(context, authProvider),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Ringkasan keuangan diambil dari data transaksi hari ini
  Widget _buildFinancialSummary() {
    return Consumer<TransaksiProvider>(
      builder: (context, provider, child) {
        return FutureBuilder<Map<String, double>>(
          future: provider.getTodayTransactionSummary(),
          builder: (context, snapshot) {
            final totalPenjualan =
                snapshot.data?['total_penjualan'] ?? 0.0;
            final jumlahTransaksi =
                (snapshot.data?['jumlah_transaksi'] ?? 0.0).toInt();

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Ringkasan Hari Ini',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$jumlahTransaksi transaksi',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Pendapatan',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                          Text('Dari penjualan hari ini',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                      Text(
                        _formatCurrency(totalPenjualan),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.blue[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Hint untuk melihat pendapatan bersih
                  GestureDetector(
                    onTap: () => _navigateTo(
                        context, const LaporanScreen()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.green.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.analytics,
                              size: 14, color: Colors.green[700]),
                          const SizedBox(width: 6),
                          Text(
                            'Lihat Laporan & Pendapatan Bersih →',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
            locale: 'id', symbol: 'Rp ', decimalDigits: 0)
        .format(amount);
  }

  Widget _buildMenuGrid(BuildContext context, AuthProvider authProvider) {
    // ✅ Menu Pembukuan dihapus — laporan sudah ada di fitur Laporan
    final List<MenuData> menus = authProvider.isPemilikToko
        ? [
            MenuData('Barang', Icons.inventory, Colors.blue,
                () => _navigateTo(context, const BarangListScreen())),
            MenuData('Laporan', Icons.analytics, Colors.purple,
                () => _navigateTo(context, const LaporanScreen())),
            MenuData('Riwayat', Icons.history, Colors.orange,
                () => _navigateTo(context, const RiwayatTransaksiScreen())),
          ]
        : [
            MenuData('Transaksi', Icons.shopping_cart, Colors.green,
                () => _navigateTo(context, const TransaksiScreen())),
          ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: authProvider.isPemilikToko ? 3 : 1,
        childAspectRatio: authProvider.isPemilikToko ? 1.0 : 2.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: menus.length,
      itemBuilder: (context, index) {
        final menu = menus[index];
        return InkWell(
          onTap: menu.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: menu.color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: menu.color.withOpacity(0.2)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(menu.icon, color: menu.color, size: 30),
                const SizedBox(height: 8),
                Text(menu.title,
                    style: TextStyle(
                        color: menu.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ],
            ),
          ),
        );
      },
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.push(
            context, MaterialPageRoute(builder: (context) => screen))
        .then((_) => _refreshData());
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Keluar dari aplikasi?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          TextButton(
            onPressed: () {
              authProvider.logout();
              Navigator.pop(context);
            },
            child:
                const Text('Ya', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class MenuData {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  MenuData(this.title, this.icon, this.color, this.onTap);
}