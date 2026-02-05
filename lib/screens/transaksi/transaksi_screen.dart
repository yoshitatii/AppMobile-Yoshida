import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/barang_provider.dart';
import '../../providers/transaksi_provider.dart';
import '../../providers/pembukuan_provider.dart'; // <--- Tambahan Beb
import '../../models/barang.dart';
import '../../models/transaksi.dart';
import '../../models/item_transaksi.dart';
import '../barang/barcode_scanner_screen.dart';

class TransaksiScreen extends StatefulWidget {
  const TransaksiScreen({super.key});

  @override
  State<TransaksiScreen> createState() => _TransaksiScreenState();
}

class _TransaksiScreenState extends State<TransaksiScreen> {
  final _kodeController = TextEditingController();
  final _bayarController = TextEditingController();
  
  List<ItemTransaksi> _keranjang = [];
  double _totalTagihanOtomatis = 0;

  @override
  void initState() {
    super.initState();
    Provider.of<BarangProvider>(context, listen: false).loadBarang();
  }

  @override
  void dispose() {
    _kodeController.dispose();
    _bayarController.dispose();
    super.dispose();
  }

  void _hitungTotalSemua() {
    double total = 0;
    for (var item in _keranjang) {
      total += item.subtotal;
    }
    setState(() {
      _totalTagihanOtomatis = total;
    });
  }

  String _formatCurrency(double amount) {
    final parts = amount.toStringAsFixed(0).split('').reversed.toList();
    final formatted = <String>[];
    for (var i = 0; i < parts.length; i++) {
      if (i > 0 && i % 3 == 0) formatted.add('.');
      formatted.add(parts[i]);
    }
    return 'Rp ${formatted.reversed.join()}';
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _searchBarang(String kode) async {
    if (kode.isEmpty) return;
    
    final barangProvider = Provider.of<BarangProvider>(context, listen: false);
    final barang = barangProvider.barangList.firstWhere(
      (b) => b.kode.toLowerCase() == kode.toLowerCase(),
      orElse: () => Barang(kode: '', nama: '', hargaBeli: 0, hargaJual: 0, stok: 0),
    );

    if (barang.kode.isNotEmpty) {
      if (barang.stok <= 0) {
        _showSnackBar('Stok ${barang.nama} Habis!', Colors.red);
        return;
      }

      setState(() {
        int index = _keranjang.indexWhere((item) => item.barangId == barang.id);
        
        if (index != -1) {
          final itemLama = _keranjang[index];
          final jumlahBaru = itemLama.jumlah + 1;

          if (jumlahBaru > barang.stok) {
            _showSnackBar('Stok tidak cukup!', Colors.orange);
          } else {
            _keranjang[index] = ItemTransaksi(
              transaksiId: itemLama.transaksiId,
              barangId: itemLama.barangId,
              namaBarang: itemLama.namaBarang,
              jumlah: jumlahBaru,
              harga: itemLama.harga,
              subtotal: jumlahBaru * itemLama.harga,
            );
          }
        } else {
          _keranjang.add(ItemTransaksi(
            transaksiId: 0,
            barangId: barang.id!,
            namaBarang: barang.nama,
            jumlah: 1,
            harga: barang.hargaJual,
            subtotal: barang.hargaJual,
          ));
        }
        _kodeController.clear();
        _hitungTotalSemua();
      });
    } else {
      _showSnackBar('Barang tidak ditemukan', Colors.orange);
    }
  }

  Future<void> _scanBarcode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
    );
    if (result != null && result.isNotEmpty) {
      _searchBarang(result);
    }
  }

  // --- BAGIAN PROSES: SEKARANG DENGAN AUTO-PEMBUKUAN BEB ---
  Future<void> _proses() async {
    if (_keranjang.isEmpty) return;

    final bayar = double.tryParse(_bayarController.text.replaceAll('.', '')) ?? 0;

    if (bayar < _totalTagihanOtomatis) {
      _showSnackBar('Uang bayar kurang!', Colors.red);
      return;
    }

    final kembalian = bayar - _totalTagihanOtomatis;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Konfirmasi Transaksi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildConfirmRow('Total', _totalTagihanOtomatis, Colors.blue),
            _buildConfirmRow('Bayar', bayar, Colors.green),
            _buildConfirmRow('Kembali', kembalian, Colors.orange, bold: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Proses')),
        ],
      ),
    );

    if (confirm == true) {
      final transaksiProvider = Provider.of<TransaksiProvider>(context, listen: false);
      final barangProvider = Provider.of<BarangProvider>(context, listen: false);
      final pembukuanProvider = Provider.of<PembukuanProvider>(context, listen: false); // <--- Ambil Provider Pembukuan
      
      // Kirim data transaksi beserta pProvider-nya beb!
      final success = await transaksiProvider.saveTransaksi(
        Transaksi(
          nomorTransaksi: transaksiProvider.generateNomorTransaksi(),
          tanggal: DateTime.now(),
          totalHarga: _totalTagihanOtomatis,
          bayar: bayar,
          kembalian: kembalian,
        ),
        _keranjang,
        pembukuanProvider // <--- Ini kunci rahasia buat dospem kamu!
      );

      if (success) {
        // Update stok barang di DB
        for (var item in _keranjang) {
          await barangProvider.updateStok(item.barangId, item.jumlah);
        }
        
        setState(() {
          _keranjang = [];
          _totalTagihanOtomatis = 0;
          _bayarController.clear();
        });
        _showSuccessDialog(kembalian);
      }
    }
  }

  void _showSuccessDialog(double kembalian) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 60),
            const SizedBox(height: 16),
            const Text('Berhasil!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('Kembalian: ${_formatCurrency(kembalian)}', 
              style: const TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Data otomatis masuk ke Pembukuan', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          )
        ],
      ),
    );
  }

  Widget _buildConfirmRow(String label, double amount, Color color, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        Text(_formatCurrency(amount), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Transaksi Penjualan'),
        backgroundColor: const Color(0xFF42709A),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // HEADER SCAN
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF63A4FF), Color(0xFF83C3FF)]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _scanBarcode,
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Icon(Icons.qr_code_scanner, size: 50, color: Colors.white),
                              SizedBox(height: 12),
                              Text('SCAN BARCODE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                              Text('Tap untuk memindai barcode barang', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // INPUT MANUAL
                  TextField(
                    controller: _kodeController,
                    decoration: InputDecoration(
                      labelText: 'Cari Kode Barang Manual',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onSubmitted: _searchBarang,
                  ),
                  const SizedBox(height: 20),

                  // DAFTAR BARANG YANG DIBELI
                  if (_keranjang.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 50),
                      child: Text('Belum ada barang di keranjang', style: TextStyle(color: Colors.grey)),
                    ),

                  ..._keranjang.map((item) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green.shade200),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 30),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.namaBarang, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text('Harga: ${_formatCurrency(item.harga)} x ${item.jumlah}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(_formatCurrency(item.subtotal), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                            IconButton(
                              onPressed: () => setState(() {
                                _keranjang.remove(item);
                                _hitungTotalSemua();
                              }), 
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20)
                            ),
                          ],
                        ),
                      ],
                    ),
                  )).toList(),
                ],
              ),
            ),
          ),

          // PANEL PEMBAYARAN DI BAWAH
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Tagihan:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(_formatCurrency(_totalTagihanOtomatis), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue)),
                  ],
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _bayarController,
                  decoration: const InputDecoration(
                    labelText: 'Uang Bayar (Rp)',
                    prefixText: 'Rp. ',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      if (newValue.text.isEmpty) return newValue.copyWith(text: '');
                      final int num = int.parse(newValue.text.replaceAll('.', ''));
                      final String formatted = num.toString().replaceAllMapped(
                        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');
                      return newValue.copyWith(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
                    }),
                  ],
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _keranjang.isNotEmpty ? _proses : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('PROSES TRANSAKSI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}