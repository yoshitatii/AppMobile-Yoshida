import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/transaksi.dart';
import '../models/item_transaksi.dart';
import '../models/pembukuan.dart'; // Import Model Pembukuan
import '../providers/pembukuan_provider.dart'; // Import Provider Pembukuan
import '../services/database_helper.dart';

class TransaksiProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Transaksi> _transaksiList = [];
  bool _isLoading = false;

  List<ItemTransaksi> _keranjang = [];

  List<Transaksi> get transaksiList => _transaksiList;
  bool get isLoading => _isLoading;
  List<ItemTransaksi> get keranjang => _keranjang;

  double get totalBelanja {
    return _keranjang.fold(0, (sum, item) => sum + item.subtotal);
  }

  void tambahBarang(ItemTransaksi itemBaru) {
    final index = _keranjang.indexWhere((item) => item.barangId == itemBaru.barangId);

    if (index >= 0) {
      int jumlahBaru = _keranjang[index].jumlah + itemBaru.jumlah;
      _keranjang[index] = ItemTransaksi(
        transaksiId: 0,
        barangId: itemBaru.barangId,
        namaBarang: itemBaru.namaBarang,
        jumlah: jumlahBaru,
        harga: itemBaru.harga,
        subtotal: jumlahBaru * itemBaru.harga,
      );
    } else {
      _keranjang.add(itemBaru);
    }
    notifyListeners(); 
  }

  void hapusDariKeranjang(int index) {
    _keranjang.removeAt(index);
    notifyListeners();
  }

  void clearKeranjang() {
    _keranjang.clear();
    notifyListeners();
  }

  String generateNomorTransaksi() {
    final now = DateTime.now();
    final formatter = DateFormat('yyyyMMddHHmmss');
    return 'TRX${formatter.format(now)}';
  }

  Future<void> loadTransaksi({int limit = 50}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final List<Map<String, dynamic>> maps = await _dbHelper.query(
        'transaksi',
        orderBy: 'tanggal DESC',
        limit: limit,
      );
      
      _transaksiList = maps.map((map) => Transaksi.fromMap(map)).toList().cast<Transaksi>();
    } catch (e) {
      debugPrint('Error loading transaksi: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- BAGIAN SAKTI: SIMPAN TRANSAKSI + OTOMATIS KE PEMBUKUAN ---
  // Kita tambahkan parameter PembukuanProvider di sini beb
  Future<bool> saveTransaksi(
    Transaksi transaksi, 
    List<ItemTransaksi> items, 
    PembukuanProvider pembukuanProvider // <--- Tambahan ini beb
  ) async {
    try {
      // 1. Simpan data utama transaksi
      final transaksiId = await _dbHelper.insert('transaksi', transaksi.toMap());
      
      if (transaksiId > 0) {
        // 2. Simpan semua rincian barang (item) yang dibeli
        for (var item in items) {
          final itemFinal = ItemTransaksi(
            transaksiId: transaksiId,
            barangId: item.barangId,
            namaBarang: item.namaBarang,
            jumlah: item.jumlah,
            harga: item.harga,
            subtotal: item.subtotal,
          );
          await _dbHelper.insert('item_transaksi', itemFinal.toMap());
        }

        // 3. LOGIKA OTOMATIS KE PEMBUKUAN (Jawaban buat Dospem)
        final entriPembukuan = Pembukuan(
          jenis: 'Pemasukan',
          tanggal: DateTime.now(), // Ambil waktu sekarang
          nominal: transaksi.totalHarga, // Total belanja otomatis jadi nominal pembukuan
          kategori: 'Penjualan',
          keterangan: 'Penjualan Otomatis: ${transaksi.nomorTransaksi}',
        );

        // Langsung panggil fungsi addPembukuan dari provider-nya
        await pembukuanProvider.addPembukuan(entriPembukuan);
        
        // 4. Refresh list riwayat dan kosongkan keranjang
        await loadTransaksi();
        _keranjang.clear();
        return true;
      }
    } catch (e) {
      debugPrint('Error saving transaksi & pembukuan: $e');
    }
    return false;
  }

  Future<List<ItemTransaksi>> getItemTransaksi(int transaksiId) async {
    try {
      final List<Map<String, dynamic>> maps = await _dbHelper.query(
        'item_transaksi',
        where: 'transaksi_id = ?',
        whereArgs: [transaksiId],
      );
      return maps.map((map) => ItemTransaksi.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error getting item transaksi: $e');
      return [];
    }
  }

  Future<bool> deleteTransaksi(int id) async {
    try {
      await _dbHelper.delete('item_transaksi', where: 'transaksi_id = ?', whereArgs: [id]);
      final count = await _dbHelper.delete('transaksi', where: 'id = ?', whereArgs: [id]);
      
      if (count > 0) {
        await loadTransaksi();
        return true;
      }
    } catch (e) {
      debugPrint('Error deleting transaksi: $e');
    }
    return false;
  }
}