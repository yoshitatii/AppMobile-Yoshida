import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/pembukuan.dart';

// PembukuanProvider disederhanakan:
// Hanya menyimpan data pengeluaran manual (beli stok, biaya operasional, dll)
// Kalkulasi Pendapatan Bersih ada di LaporanScreen (Pendapatan - Pengeluaran)
class PembukuanProvider with ChangeNotifier {
  List<Pembukuan> _pembukuanList = [];
  bool _isLoading = false;

  List<Pembukuan> get pembukuanList => _pembukuanList;
  bool get isLoading => _isLoading;

  // Total semua pengeluaran yang dicatat
  double get totalPengeluaran => _pembukuanList
      .where((item) => item.jenis.toLowerCase() == 'pengeluaran')
      .fold(0.0, (sum, item) => sum + item.nominal);

  // Total semua pemasukan yang dicatat (dari transaksi otomatis)
  double get totalPemasukan => _pembukuanList
      .where((item) => item.jenis.toLowerCase() == 'pemasukan')
      .fold(0.0, (sum, item) => sum + item.nominal);

  // ─── LOAD & SAVE DATA ────────────────────────────────────────

  Future<void> loadPembukuan() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final String? dataString = prefs.getString('pembukuan_data');

    if (dataString != null) {
      final List<dynamic> decodedData = json.decode(dataString);
      _pembukuanList =
          decodedData.map((item) => Pembukuan.fromMap(item)).toList();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData =
        json.encode(_pembukuanList.map((item) => item.toMap()).toList());
    await prefs.setString('pembukuan_data', encodedData);
  }

  // ─── CRUD ────────────────────────────────────────────────────

  Future<void> addPembukuan(Pembukuan data) async {
    final newEntry = Pembukuan(
      id: data.id ?? DateTime.now().millisecondsSinceEpoch,
      jenis: data.jenis,
      nominal: data.nominal,
      kategori: data.kategori,
      keterangan: data.keterangan,
      tanggal: data.tanggal,
      isAuto: data.isAuto,
      source: data.source,
    );
    _pembukuanList.insert(0, newEntry);
    await _saveToPrefs();
    notifyListeners();
  }

  Future<void> deletePembukuan(int id) async {
    _pembukuanList.removeWhere((element) => element.id == id);
    await _saveToPrefs();
    notifyListeners();
  }

  Future<void> deletePembukuanByKeterangan(String keterangan) async {
    _pembukuanList.removeWhere((element) => element.keterangan == keterangan);
    await _saveToPrefs();
    notifyListeners();
  }

  // Ambil data pengeluaran dalam periode tertentu
  // Berguna jika LaporanScreen ingin mengambil pengeluaran dari provider ini
  Future<List<Pembukuan>> getPengeluaranPeriode(
      DateTime start, DateTime end) async {
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay =
        DateTime(end.year, end.month, end.day, 23, 59, 59);

    return _pembukuanList
        .where((item) =>
            item.jenis.toLowerCase() == 'pengeluaran' &&
            item.tanggal
                .isAfter(startDay.subtract(const Duration(seconds: 1))) &&
            item.tanggal
                .isBefore(endDay.add(const Duration(seconds: 1))))
        .toList();
  }

  // Ringkasan pengeluaran hari ini
  double getTodayPengeluaran() {
    final today = DateTime.now();
    return _pembukuanList
        .where((item) =>
            item.jenis.toLowerCase() == 'pengeluaran' &&
            item.tanggal.year == today.year &&
            item.tanggal.month == today.month &&
            item.tanggal.day == today.day)
        .fold<double>(0.0, (sum, item) => sum + item.nominal);
  }
}