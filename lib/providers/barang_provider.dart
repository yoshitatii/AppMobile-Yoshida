import 'package:flutter/foundation.dart';
import '../models/barang.dart';
import '../services/database_helper.dart';

class BarangProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Barang> _barangList = [];
  bool _isLoading = false;

  List<Barang> get barangList => _barangList;
  bool get isLoading => _isLoading;

  // Load semua barang dengan lazy loading
  Future<void> loadBarang() async {
    _isLoading = true;
    notifyListeners();

    try {
      final List<Map<String, dynamic>> maps = await _dbHelper.query(
        'barang',
        orderBy: 'nama ASC',
      );

      _barangList = maps.map((map) => Barang.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error loading barang: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Tambah barang
  Future<bool> addBarang(Barang barang) async {
    try {
      final id = await _dbHelper.insert('barang', barang.toMap());
      if (id > 0) {
        await loadBarang();
        return true;
      }
    } catch (e) {
      debugPrint('Error adding barang: $e');
    }
    return false;
  }

  // Update barang
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
        await loadBarang();
        return true;
      }
    } catch (e) {
      debugPrint('Error updating barang: $e');
    }
    return false;
  }

  // Hapus barang
  Future<bool> deleteBarang(int id) async {
    try {
      final count = await _dbHelper.delete(
        'barang',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (count > 0) {
        await loadBarang();
        return true;
      }
    } catch (e) {
      debugPrint('Error deleting barang: $e');
    }
    return false;
  }

  // Cari barang berdasarkan kode atau nama
  Future<List<Barang>> searchBarang(String keyword) async {
    try {
      final List<Map<String, dynamic>> maps = await _dbHelper.query(
        'barang',
        where: 'kode LIKE ? OR nama LIKE ?',
        whereArgs: ['%$keyword%', '%$keyword%'],
        orderBy: 'nama ASC',
      );
      return maps.map((map) => Barang.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error searching barang: $e');
      return [];
    }
  }

  // Get barang by ID
  Future<Barang?> getBarangById(int id) async {
    try {
      final List<Map<String, dynamic>> maps = await _dbHelper.query(
        'barang',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (maps.isNotEmpty) {
        return Barang.fromMap(maps.first);
      }
    } catch (e) {
      debugPrint('Error getting barang: $e');
    }
    return null;
  }

  // Update stok barang
  Future<bool> updateStok(int barangId, int jumlah) async {
    try {
      final barang = await getBarangById(barangId);
      if (barang != null) {
        final updatedBarang = barang.copyWith(
          stok: barang.stok - jumlah,
          updatedAt: DateTime.now(),
        );
        return await updateBarang(updatedBarang);
      }
    } catch (e) {
      debugPrint('Error updating stok: $e');
    }
    return false;
  }
}
