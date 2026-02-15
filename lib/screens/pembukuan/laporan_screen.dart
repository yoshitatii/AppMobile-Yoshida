import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/pembukuan_provider.dart';
import '../../models/pembukuan.dart';

class LaporanScreen extends StatefulWidget {
  const LaporanScreen({super.key});

  @override
  State<LaporanScreen> createState() => _LaporanScreenState();
}

class _LaporanScreenState extends State<LaporanScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  List<Pembukuan> _laporanData = []; // ← PERBAIKAN: Ubah dari Map ke List
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadLaporan();
  }

  Future<void> _loadLaporan() async {
    setState(() => _isLoading = true);
    
    final provider = Provider.of<PembukuanProvider>(context, listen: false);
    final data = await provider.getLaporanPeriode(_startDate, _endDate);
    
    setState(() {
      _laporanData = data; // ← Sekarang tipe data sudah cocok
      _isLoading = false;
    });
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadLaporan();
    }
  }

  Map<String, double> _calculateSummary() {
    double totalPemasukan = 0;
    double totalPengeluaran = 0;

    for (var item in _laporanData) {
      if (item.jenis == 'pemasukan') {
        totalPemasukan += item.nominal;
      } else {
        totalPengeluaran += item.nominal;
      }
    }

    return {
      'pemasukan': totalPemasukan,
      'pengeluaran': totalPengeluaran,
      'saldo': totalPemasukan - totalPengeluaran,
    };
  }

  @override
  Widget build(BuildContext context) {
    final summary = _calculateSummary();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Keuangan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Pilih Periode',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Ringkasan
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Column(
                    children: [
                      Text(
                        '${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildSummaryCard('Pemasukan', summary['pemasukan']!, Colors.green),
                          _buildSummaryCard('Pengeluaran', summary['pengeluaran']!, Colors.red),
                          _buildSummaryCard('Saldo', summary['saldo']!, Colors.blue),
                        ],
                      ),
                    ],
                  ),
                ),
                // List Detail
                Expanded(
                  child: _laporanData.isEmpty
                      ? const Center(child: Text('Tidak ada data'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _laporanData.length,
                          itemBuilder: (context, index) {
                            final item = _laporanData[index];
                            final isPemasukan = item.jenis == 'pemasukan';
                            
                            return Card(
                              child: ListTile(
                                leading: Icon(
                                  isPemasukan ? Icons.arrow_upward : Icons.arrow_downward,
                                  color: isPemasukan ? Colors.green : Colors.red,
                                ),
                                title: Text(item.keterangan),
                                subtitle: Text(
                                  '${item.kategori} • ${DateFormat('dd/MM/yyyy').format(item.tanggal)}',
                                ),
                                trailing: Text(
                                  _formatCurrency(item.nominal),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isPemasukan ? Colors.green[700] : Colors.red[700],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryCard(String title, double amount, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        Text(
          _formatCurrency(amount),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}