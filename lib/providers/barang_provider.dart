import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/barang.dart';
import '../services/database_helper.dart';

class BarangProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Barang> _barangList = [];
  bool _isLoading = false;

  List<Barang> get barangList => _barangList;
  bool get isLoading => _isLoading;

  // 1. Mendapatkan data dari Database
Future<void> loadBarang({bool forceRefresh = false}) async {
  _isLoading = true;
  notifyListeners();
  
  try {
    final List<Map<String, dynamic>> maps = await _dbHelper.query('barang');
    
    print("DEBUG: Berhasil ambil dari DB. Jumlah: ${maps.length}");
    
    _barangList = maps.map((map) => Barang.fromMap(map)).toList();
  } catch (e) {
    print("DEBUG ERROR LOAD: $e");
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}

  // 2. Fungsi Filter Pencarian (Detail: Nama & Kode)
  List<Barang> filterBarang(String keyword) {
    if (keyword.isEmpty) return _barangList;
    
    final lowerCaseKeyword = keyword.toLowerCase();
    
    return _barangList.where((barang) {
      // Mencocokkan keyword dengan Nama atau Kode Barang
      final namaMatches = barang.nama.toLowerCase().contains(lowerCaseKeyword);
      final kodeMatches = barang.kode.toLowerCase().contains(lowerCaseKeyword);
      
      return namaMatches || kodeMatches;
    }).toList();
  }

  // 3. Tambah Barang
Future<bool> addBarang(Barang barang) async {
  try {
    final id = await _dbHelper.insert('barang', barang.toMap());
    print("DEBUG: Berhasil simpan ke DB. ID baru: $id");
    
    if (id > 0) {
      // PENTING: Reload dari database untuk memastikan data sync
      await loadBarang(forceRefresh: true);
      return true;
    }
  } catch (e) {
    print("DEBUG ERROR ADD: $e");
    debugPrint('Error Add Barang: $e');
  }
  return false;
}

  // 4. Update Barang (Digunakan di Form Edit)
  Future<bool> updateBarang(Barang barang) async {
    try {
      final updatedBarang = barang.copyWith(updatedAt: DateTime.now());
      final count = await _dbHelper.update(
        'barang',
        updatedBarang.toMap(),
        where: 'id = ?',
        whereArgs: [barang.id],
      );
      
      if (count > 0) {
        int index = _barangList.indexWhere((element) => element.id == barang.id);
        if (index != -1) {
          _barangList[index] = updatedBarang;
          _barangList.sort((a, b) => a.nama.compareTo(b.nama)); // Urutkan ulang jika nama berubah
          notifyListeners();
        }
        return true;
      }
    } catch (e) {
      debugPrint('Error Update Barang: $e');
    }
    return false;
  }

  // 5. Update Stok (Digunakan saat Transaksi Penjualan)
  Future<bool> updateStok(int barangId, int jumlahTerjual) async {
    try {
      int index = _barangList.indexWhere((b) => b.id == barangId);
      if (index != -1) {
        final barang = _barangList[index];
        final newStok = barang.stok - jumlahTerjual;
        
        final updated = barang.copyWith(stok: newStok, updatedAt: DateTime.now());
        
        await _dbHelper.update(
          'barang', 
          updated.toMap(), 
          where: 'id = ?', 
          whereArgs: [barangId]
        );
        
        _barangList[index] = updated;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Error Update Stok: $e');
    }
    return false;
  }

  // 6. Hapus Barang
  Future<bool> deleteBarang(int id) async {
    try {
      final count = await _dbHelper.delete(
        'barang',
        where: 'id = ?',
        whereArgs: [id],
      );
      
      if (count > 0) {
        _barangList.removeWhere((element) => element.id == id);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Error Delete Barang: $e');
    }
    return false;
  }
}