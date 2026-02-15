import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/barang_provider.dart';
import '../../providers/transaksi_provider.dart';
import '../../providers/pembukuan_provider.dart';
import '../../models/barang.dart';
import '../../models/transaksi.dart';
import '../../models/item_transaksi.dart';
import '../barang/barcode_scanner_screen.dart';
import 'package:intl/intl.dart';

class TransaksiScreen extends StatefulWidget {
  const TransaksiScreen({super.key});

  @override
  State<TransaksiScreen> createState() => _TransaksiScreenState();
}

class _TransaksiScreenState extends State<TransaksiScreen> {
  final _kodeController = TextEditingController();
  final _bayarController = TextEditingController();
  final NumberFormat _formatter = NumberFormat.decimalPattern('id');
  
  List<Map<String, dynamic>> _keranjangBelanja = [];
  double _totalTagihanOtomatis = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BarangProvider>(context, listen: false).loadBarang();
    });
  }

  @override
  void dispose() {
    _kodeController.dispose();
    _bayarController.dispose();
    super.dispose();
  }

  void _hitungTotalSemua() {
    double total = 0;
    for (var item in _keranjangBelanja) {
      total += item['subtotal'];
    }
    setState(() {
      _totalTagihanOtomatis = total;
    });
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), 
      (Match m) => '${m[1]}.'
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating),
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
        int index = _keranjangBelanja.indexWhere((item) => item['barangId'] == barang.id);
        
        if (index == -1) {
          _keranjangBelanja.add({
            'barangId': barang.id,
            'nama': barang.nama,
            'hargaSatuanPcs': barang.hargaJual,
            'jumlah': 1,
            'satuanTerpilih': 'pcs',
            'pengali': 1,
            'isiPack': barang.isiPack,
            'isiBox': barang.isiBox,
            'subtotal': barang.hargaJual,
            'stokTersedia': barang.stok,
          });
        }
        _kodeController.clear();
        _hitungTotalSemua();
      });
    } else {
      _showSnackBar('Barang tidak ditemukan', Colors.orange);
    }
  }

  // FUNGSI PROSES TRANSAKSI
  Future<void> _proses() async {
    if (_keranjangBelanja.isEmpty) return;
    
    final bayarText = _bayarController.text.replaceAll('.', '');
    final bayar = double.tryParse(bayarText) ?? 0;

    if (bayar < _totalTagihanOtomatis) {
      _showSnackBar('Uang bayar kurang!', Colors.red);
      return;
    }

    final kembalian = bayar - _totalTagihanOtomatis;

    // --- LOGIKA SIMPAN KE DATABASE & UPDATE STOK ---
    final transaksiProvider = Provider.of<TransaksiProvider>(context, listen: false);
    final barangProvider = Provider.of<BarangProvider>(context, listen: false);
    final pembukuanProvider = Provider.of<PembukuanProvider>(context, listen: false);

    List<ItemTransaksi> keranjangFix = _keranjangBelanja.map((item) {
      return ItemTransaksi(
        transaksiId: 0, 
        barangId: item['barangId'],
        namaBarang: "${item['nama']} (${item['satuanTerpilih'].toString().toUpperCase()})",
        jumlah: item['jumlah'],
        harga: item['hargaSatuanPcs'] * item['pengali'],
        subtotal: item['subtotal'],
      );
    }).toList();

    final success = await transaksiProvider.saveTransaksi(
      Transaksi(
        nomorTransaksi: transaksiProvider.generateNomorTransaksi(),
        tanggal: DateTime.now(),
        totalHarga: _totalTagihanOtomatis,
        bayar: bayar,
        kembalian: kembalian,
      ),
      keranjangFix,
      pembukuanProvider
    );

    if (success) {
      // Update stok barang di provider/database
      for (var item in _keranjangBelanja) {
        int totalPcsKeluar = item['jumlah'] * (item['pengali'] as int);
        await barangProvider.updateStok(item['barangId'], totalPcsKeluar);
      }
      _showSuccessDialog(kembalian);
    }
  }

  void _showSuccessDialog(double kembalian) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 60),
            const SizedBox(height: 16),
            const Text('Transaksi Berhasil!', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              "Kembalian: Rp ${_formatCurrency(kembalian)}", 
              style: const TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold)
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _keranjangBelanja = [];
                _totalTagihanOtomatis = 0;
                _bayarController.clear();
              });
            }, 
            child: const Text('OK')
          )
        ],
      ),
    );
  }

  Widget _buildUnitButton(int index, String label, int multiplier, Color color) {
    var item = _keranjangBelanja[index];
    bool isSelected = item['satuanTerpilih'] == label.toLowerCase();

    return InkWell(
      onTap: () {
        setState(() {
          _keranjangBelanja[index]['satuanTerpilih'] = label.toLowerCase();
          _keranjangBelanja[index]['pengali'] = multiplier;
          _keranjangBelanja[index]['subtotal'] = (item['hargaSatuanPcs'] * multiplier) * item['jumlah'];
          _hitungTotalSemua();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kasir Penjualan'), backgroundColor: const Color(0xFF42709A)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final res = await Navigator.push(context, MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()));
                    if (res != null) _searchBarang(res);
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text("SCAN BARCODE"),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _kodeController,
                  decoration: const InputDecoration(hintText: "Cari Kode Manual...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
                  onSubmitted: _searchBarang,
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: _keranjangBelanja.length,
              itemBuilder: (context, index) {
                final item = _keranjangBelanja[index];
                String labelSatuan = item['satuanTerpilih'].toString().toUpperCase();
                double hargaSatuanPilihan = item['hargaSatuanPcs'] * item['pengali'];

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shopping_bag, color: Colors.blue),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['nama'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        "${item['jumlah']} $labelSatuan",
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                                      ),
                                      if (item['satuanTerpilih'] != 'pcs')
                                        Text(" (Isi ${item['pengali']})", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                      Text(
                                        " x ${_formatCurrency(hargaSatuanPilihan)}", 
                                        style: const TextStyle(fontSize: 12)
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              "Rp ${_formatCurrency(item['subtotal'])}", 
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)
                            ),
                            IconButton(onPressed: () => setState(() { _keranjangBelanja.removeAt(index); _hitungTotalSemua(); }), icon: const Icon(Icons.delete, color: Colors.red)),
                          ],
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Wrap(
                              spacing: 5,
                              children: [
                                _buildUnitButton(index, "PCS", 1, Colors.green),
                                if (item['isiPack'] > 1) _buildUnitButton(index, "PACK", item['isiPack'], Colors.orange),
                                if (item['isiBox'] > 1) _buildUnitButton(index, "BOX", item['isiBox'], Colors.blue),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(onPressed: () => setState(() { if(item['jumlah'] > 1) item['jumlah']--; item['subtotal'] = (item['hargaSatuanPcs'] * item['pengali']) * item['jumlah']; _hitungTotalSemua(); }), icon: const Icon(Icons.remove_circle_outline)),
                                Text("${item['jumlah']}"),
                                IconButton(onPressed: () => setState(() { item['jumlah']++; item['subtotal'] = (item['hargaSatuanPcs'] * item['pengali']) * item['jumlah']; _hitungTotalSemua(); }), icon: const Icon(Icons.add_circle_outline)),
                              ],
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black12)]),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                  children: [
                    const Text("Total Tagihan", style: TextStyle(fontWeight: FontWeight.bold)), 
                    Text("Rp ${_formatCurrency(_totalTagihanOtomatis)}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue))
                  ]
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _bayarController, 
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      if (newValue.text.isEmpty) return newValue;
                      final int value = int.parse(newValue.text);
                      final String newText = _formatter.format(value).replaceAll(',', '.');
                      return newValue.copyWith(
                        text: newText,
                        selection: TextSelection.collapsed(offset: newText.length),
                      );
                    }),
                  ],
                  decoration: const InputDecoration(
                    labelText: "Uang Bayar", 
                    prefixText: "Rp ",
                    border: OutlineInputBorder(),
                  )
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity, 
                  height: 50, 
                  child: ElevatedButton(
                    onPressed: _keranjangBelanja.isNotEmpty ? _proses : null, 
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green), 
                    child: const Text("PROSES TRANSAKSI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                  )
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}