import 'package:flutter/foundation.dart';
import '../models/pembukuan.dart';
import '../services/database_helper.dart';

class PembukuanProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Pembukuan> _pembukuanList = [];
  bool _isLoading = false;

  List<Pembukuan> get pembukuanList => _pembukuanList;
  bool get isLoading => _isLoading;

  // Load pembukuan
  Future<void> loadPembukuan({int limit = 100}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final List<Map<String, dynamic>> maps = await _dbHelper.query(
        'pembukuan',
        orderBy: 'tanggal DESC',
        limit: limit,
      );

      _pembukuanList = maps.map((map) => Pembukuan.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error loading pembukuan: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Tambah pembukuan
  Future<bool> addPembukuan(Pembukuan pembukuan) async {
    try {
      final id = await _dbHelper.insert('pembukuan', pembukuan.toMap());
      if (id > 0) {
        await loadPembukuan();
        return true;
      }
    } catch (e) {
      debugPrint('Error adding pembukuan: $e');
    }
    return false;
  }

  // Update pembukuan
  Future<bool> updatePembukuan(Pembukuan pembukuan) async {
    try {
      final count = await _dbHelper.update(
        'pembukuan',
        pembukuan.toMap(),
        where: 'id = ?',
        whereArgs: [pembukuan.id],
      );
      if (count > 0) {
        await loadPembukuan();
        return true;
      }
    } catch (e) {
      debugPrint('Error updating pembukuan: $e');
    }
    return false;
  }

  // Hapus pembukuan
  Future<bool> deletePembukuan(int id) async {
    try {
      final count = await _dbHelper.delete(
        'pembukuan',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (count > 0) {
        await loadPembukuan();
        return true;
      }
    } catch (e) {
      debugPrint('Error deleting pembukuan: $e');
    }
    return false;
  }

  // Get laporan berdasarkan periode
  Future<Map<String, dynamic>> getLaporanPeriode(DateTime startDate, DateTime endDate) async {
    try {
      final List<Map<String, dynamic>> maps = await _dbHelper.query(
        'pembukuan',
        where: 'date(tanggal) BETWEEN date(?) AND date(?)',
        whereArgs: [
          startDate.toIso8601String(),
          endDate.toIso8601String(),
        ],
      );

      double totalPemasukan = 0;
      double totalPengeluaran = 0;

      for (var map in maps) {
        final pembukuan = Pembukuan.fromMap(map);
        if (pembukuan.jenis == 'pemasukan') {
          totalPemasukan += pembukuan.nominal;
        } else {
          totalPengeluaran += pembukuan.nominal;
        }
      }

      return {
        'total_pemasukan': totalPemasukan,
        'total_pengeluaran': totalPengeluaran,
        'saldo': totalPemasukan - totalPengeluaran,
        'data': maps.map((map) => Pembukuan.fromMap(map)).toList(),
      };
    } catch (e) {
      debugPrint('Error getting laporan: $e');
      return {
        'total_pemasukan': 0.0,
        'total_pengeluaran': 0.0,
        'saldo': 0.0,
        'data': [],
      };
    }
  }

  // Get total pemasukan dan pengeluaran hari ini
  Future<Map<String, double>> getTodaySummary() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    try {
      final List<Map<String, dynamic>> maps = await _dbHelper.query(
        'pembukuan',
        where: 'date(tanggal) >= date(?) AND date(tanggal) < date(?)',
        whereArgs: [
          today.toIso8601String(),
          tomorrow.toIso8601String(),
        ],
      );

      double pemasukan = 0;
      double pengeluaran = 0;

      for (var map in maps) {
        final pembukuan = Pembukuan.fromMap(map);
        if (pembukuan.jenis == 'pemasukan') {
          pemasukan += pembukuan.nominal;
        } else {
          pengeluaran += pembukuan.nominal;
        }
      }

      return {
        'pemasukan': pemasukan,
        'pengeluaran': pengeluaran,
        'saldo': pemasukan - pengeluaran,
      };
    } catch (e) {
      debugPrint('Error getting today summary: $e');
      return {
        'pemasukan': 0.0,
        'pengeluaran': 0.0,
        'saldo': 0.0,
      };
    }
  }
}