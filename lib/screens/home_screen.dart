import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/pembukuan_provider.dart';
import 'barang/barang_list_screen.dart';
import 'transaksi/transaksi_screen.dart';
import 'transaksi/riwayat_transaksi_screen.dart';
import 'pembukuan/pembukuan_screen.dart';
import 'pembukuan/laporan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500), // Dipercepat agar lebih responsif di low-end
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    _animationController.forward();
    
    // Inisialisasi data saat start
    WidgetsBinding.instance.addPostFrameCallback((_) {
       context.read<PembukuanProvider>().loadPembukuan();
    });
  }

  Future<void> _refreshData() async {
    await Provider.of<PembukuanProvider>(context, listen: false).loadPembukuan();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
  final days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
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
      backgroundColor: Colors.white, // Putih solid lebih ringan bagi GPU
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
                              authProvider.isPemilikToko ? Icons.person : Icons.store,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Selamat Datang,', style: TextStyle(color: Colors.white70, fontSize: 12)),
                              Text(
                                authProvider.displayName ?? 'Pengguna',
                                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
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
                      onPressed: () => _showLogoutDialog(context, authProvider),
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_formatDate(now), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        const SizedBox(height: 16),

                        // PERBAIKAN: Summary Card dengan Null Safety
                        if (authProvider.isPemilikToko) ...[
                          _buildFinancialSummary(),
                          const SizedBox(height: 20),
                        ],

                        const Text('Menu Utama', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  Widget _buildFinancialSummary() {
    return Consumer<PembukuanProvider>(
      builder: (context, provider, child) {
        return FutureBuilder<Map<String, double>>(
          future: provider.getTodaySummary(),
          builder: (context, snapshot) {
            // PERBAIKAN: Gunakan data default jika snapshot masih null atau loading
            final data = snapshot.data ?? {'pemasukan': 0.0, 'pengeluaran': 0.0};
            final totalIn = data['pemasukan'] ?? 0.0;
            final totalOut = data['pengeluaran'] ?? 0.0;
            final saldo = totalIn - totalOut;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!), // Border ganti Shadow
              ),
              child: Column(
                children: [
                  _rowSummary('Pemasukan Hari Ini', totalIn, Colors.green),
                  const Divider(height: 20),
                  _rowSummary('Pengeluaran Hari Ini', totalOut, Colors.orange),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Keuntungan', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        _formatCurrency(saldo),
                        style: TextStyle(fontWeight: FontWeight.bold, color: saldo >= 0 ? Colors.blue[800] : Colors.red),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _rowSummary(String label, double amount, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.black87)),
        Text(_formatCurrency(amount), style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(amount);
  }

  Widget _buildMenuGrid(BuildContext context, AuthProvider authProvider) {
    final List<MenuData> menus = authProvider.isPemilikToko 
      ? [
          MenuData('Barang', Icons.inventory, Colors.blue, () => _navigateTo(context, const BarangListScreen())),
          MenuData('Laporan', Icons.analytics, Colors.purple, () => _navigateTo(context, const LaporanScreen())),
          MenuData('Riwayat', Icons.history, Colors.orange, () => _navigateTo(context, const RiwayatTransaksiScreen())),
          MenuData('Pembukuan', Icons.book, Colors.green, () => _navigateTo(context, const PembukuanScreen())),
        ]
      : [
          MenuData('Transaksi', Icons.shopping_cart, Colors.green, () => _navigateTo(context, const TransaksiScreen())),
        ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: authProvider.isPemilikToko ? 2 : 1,
        childAspectRatio: authProvider.isPemilikToko ? 1.3 : 2.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: menus.length,
      itemBuilder: (context, index) {
        final menu = menus[index];
        return InkWell(
          onTap: menu.onTap,
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
                Text(menu.title, style: TextStyle(color: menu.color, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      },
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen))
        .then((_) => _refreshData());
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Keluar dari aplikasi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              authProvider.logout();
              Navigator.pop(context);
            }, 
            child: const Text('Ya', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }
}

// Letakkan ini di luar class utama (paling bawah file)
class MenuData {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  MenuData(this.title, this.icon, this.color, this.onTap);
}